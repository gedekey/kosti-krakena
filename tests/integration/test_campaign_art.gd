extends GutTest
## М25: арт кампании — портрет Хоба, детали таверны и предметы стола по уровням, слайды
## (фоны, спрайты, анимации), карта таверны. Всё в палитре и нужного размера.

const TableScene := preload("res://scenes/table.tscn")


func before_each() -> void:
	MatchSetup.pending = null
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)
	Campaign.reset()


func after_each() -> void:
	MatchSetup.pending = null
	Campaign.reset()
	Ranks.reset()
	Stats.reset()
	Stats.clear_flags()
	Achievements.reset()


## Все непрозрачные пиксели — из палитры игры.
func _assert_palette(tex: Texture2D, what: String) -> void:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var bad := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 != 0 and not KrakenPalette.contains(c):
				bad += 1
	assert_eq(bad, 0, "%s: всё в палитре" % what)


# --- Хоб -------------------------------------------------------------------------------

func test_hob_portrait_is_authors_picture_in_portrait_size() -> void:
	var tex := HobPortrait.texture()
	assert_not_null(tex)
	assert_eq(Vector2i(tex.get_size()), Sprites.PORTRAIT_SIZE)
	assert_same(HobPortrait.texture(), tex, "кэш: та же текстура")
	_assert_palette(tex, "Хоб")
	var img := tex.get_image()
	assert_eq(img.get_pixel(0, 0).a8, 0, "фон вырезан")
	assert_eq(img.get_pixel(32, 32).a8, 255, "лицо на месте")


# --- Уровни: детали таверны и предметы ---------------------------------------------------

func test_every_level_has_tavern_details_over_background() -> void:
	for level in CampaignLevels.all():
		var tex := level.background_overlay
		assert_not_null(tex, "уровень %d: детали" % level.number)
		if tex == null:
			continue
		assert_eq(Vector2i(tex.get_size()), Sprites.BACKGROUND_SIZE, "во весь экран")
		_assert_palette(tex, "детали уровня %d" % level.number)
		# Стол (ниже пола таверны) — для кубиков и чашек: деталей там нет.
		var img := tex.get_image()
		for y in range(TableLayout.OWN_PANEL_RECT.position.y, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a8 != 0:
					fail_test("уровень %d: деталь на столе (%d, %d)" % [level.number, x, y])
					return


func test_levels_have_own_table_props() -> void:
	var expected := {
		1: [], 2: [PropArt.SHELL], 3: [PropArt.CRYSTAL], 4: [PropArt.CULT_CANDLE],
		5: [PropArt.CULT_CANDLE, PropArt.SHELL], 6: [PropArt.CULT_CANDLE, PropArt.CRYSTAL],
	}
	for level in CampaignLevels.all():
		var set := level.table_props
		if level.number == 1:
			assert_null(set, "уровень 1 — обычный стол")
			continue
		assert_not_null(set, "уровень %d: свой набор" % level.number)
		var kinds: Array = []
		for slot in set.props:
			assert_true(PropArt.has_kind(slot.kind), "известный предмет %s" % slot.kind)
			kinds.append(slot.kind)
		for k: StringName in expected[level.number]:
			assert_has(kinds, k, "уровень %d: %s" % [level.number, k])


func test_campaign_table_shows_level_details() -> void:
	Rng.set_master_seed(6)
	var level := CampaignLevels.get_level(6)
	MatchSetup.pending = MatchSetup.for_campaign(level, &"player1")
	var t: Control = add_child_autofree(TableScene.instantiate())
	assert_not_null(t._background_overlay)
	assert_eq(t._background_overlay.texture, level.background_overlay)
	assert_eq(t._background_overlay.get_parent(), t._background, "тот же оттенок, что у фона")
	assert_eq(t._background_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "клики насквозь")
	var kinds: Array = []
	for p in t._clicks.props():
		kinds.append(p.kind)
	assert_has(kinds, PropArt.CRYSTAL)


func test_plain_table_has_no_campaign_details() -> void:
	Rng.set_master_seed(2)
	MatchSetup.pending = MatchSetup.from_settings()
	var t: Control = add_child_autofree(TableScene.instantiate())
	assert_null(t._background_overlay)


## Новые предметы проигрывают все реакции до конца и возвращаются в покой.
func test_campaign_props_play_every_reaction() -> void:
	for kind in [PropArt.CULT_CANDLE, PropArt.CRYSTAL, PropArt.SHELL]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var p: TableProp = add_child_autofree(TableProp.make(TablePropSlot.make(kind,
				Vector2i(100, 100)), rng))
		for r: StringName in PropArt.reactions(kind):
			p.reaction = r
			p._time = 0.0
			for f in PropArt.frame_count(kind, r):
				p.queue_redraw()
				await get_tree().process_frame
				p.advance(1.0 / TableClickBalance.PROP_FPS)
			assert_false(p.is_reacting(), "%s/%s: реакция закончилась" % [kind, r])
			p._cooldown = 0.0


# --- Слайды и карта -----------------------------------------------------------------------

func test_every_slide_has_background_in_slide_size() -> void:
	for id in SlideShow.INTRO + SlideShow.FINALE:
		var name := SlideArt.background_name(id)
		assert_ne(name, &"", "%s: фон" % id)
		assert_true(CampaignArt.has(name), "%s: картинка %s" % [id, name])
		var tex := CampaignArt.texture(name)
		assert_eq(Vector2i(tex.get_size()), CampaignLayout.SLIDE_ART_RECT.size, "%s: размер" % id)
		_assert_palette(tex, String(name))


func test_slide_sprites_and_animations_exist() -> void:
	for name in [&"slide_ship", &"slide_wreck", &"slide_bolt", &"slide_hero", &"slide_hero_back", &"slide_hero_door", &"slide_lantern",
			&"slide_counter", &"slide_flame", &"slide_plank", &"slide_boat"]:
		assert_true(CampaignArt.has(name), "спрайт %s" % name)
	for name: StringName in CampaignArt.ANIM_FRAMES:
		var strip := CampaignArt.texture(name)
		var count: int = CampaignArt.ANIM_FRAMES[name]
		assert_eq(strip.get_width() % count, 0, "%s: кадры ровные" % name)
		var first := CampaignArt.anim_frame(name, 0.0)
		assert_eq(int(first.region.size.x), strip.get_width() / count)
	# Глаз в финале открывается один раз и остаётся открытым.
	var last := CampaignArt.anim_frame(&"slide_eye", 100.0, false)
	assert_eq(last, CampaignArt.frame(&"slide_eye", CampaignArt.ANIM_FRAMES[&"slide_eye"] - 1))


func test_slide_art_draws_every_slide() -> void:
	var art: SlideArt = add_child_autofree(SlideArt.new())
	art.size = Vector2(CampaignLayout.SLIDE_ART_RECT.size)
	for id in SlideShow.INTRO + SlideShow.FINALE:
		art.show_slide(id)
		for t in [0.0, 1.0, 6.0]:
			art._t = t
			art.queue_redraw()
			await get_tree().process_frame
		assert_eq(art.slide, id)


func test_tavern_map_picture_fills_map_rect() -> void:
	var tex := CampaignArt.texture(CampaignArt.MAP)
	assert_eq(Vector2i(tex.get_size()), CampaignLayout.MAP_RECT.size)
	_assert_palette(tex, "карта")
