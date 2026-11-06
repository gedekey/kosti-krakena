extends GutTest
## М10: визуальные эффекты. Листы эффектов (палитра, кадры), FxSprite, отклик стола на каждое
## событие матча, секретность своих трюков, Безумие (края экрана, портреты), скорость.

const Scene := preload("res://scenes/table.tscn")
const LIST_PATH := "res://ui/fx/src/fx_list.json"
const Phase := MatchController.Phase


func before_each() -> void:
	MatchSetup.pending = null
	Settings.set_value(&"bot_speed", 1.0)


func after_all() -> void:
	Settings.set_value(&"bot_speed", Settings.DEFAULTS[&"bot_speed"])


func _table(seed_value: int, opponents: Array[StringName] = []) -> Control:
	Rng.set_master_seed(seed_value)
	var setup := MatchSetup.from_settings()
	setup.opponents = opponents
	setup.opponent_count = 3
	MatchSetup.pending = setup
	return add_child_autofree(Scene.instantiate())


func _to_bidding(screen: Control) -> void:
	if screen._controller.phase == Phase.ROLL:
		screen._roll_button.pressed.emit()


# --- Листы -----------------------------------------------------------------------

func test_every_listed_effect_has_a_sheet() -> void:
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	for name: String in list.effects:
		assert_true(FxSprite.has_effect(StringName(name)), "лист %s собран" % name)
	assert_eq(FxSprite.names().size(), list.effects.size(), "лишних листов нет")


func test_sheets_use_only_palette_colors_and_fit_their_grid() -> void:
	for name: StringName in FxSprite.names():
		var info := FxSprite.info(name)
		var img: Image = (load(info.path) as Texture2D).get_image()
		img.decompress()
		var rows := ceili(float(info.count) / info.columns)
		assert_eq(img.get_width(), info.frame.x * info.columns, "%s: ширина" % name)
		assert_eq(img.get_height(), info.frame.y * rows, "%s: высота" % name)
		var bad := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a8 > 0 and not KrakenPalette.contains(Color(c, 1.0)):
					bad += 1
		assert_eq(bad, 0, "%s: только цвета палитры" % name)
		assert_true(FxSprite.duration(name) > 0.3 and FxSprite.duration(name) < 6.0,
				"%s: разумная длительность" % name)


func test_fx_sprite_plays_once_and_frees_itself() -> void:
	var fx := FxSprite.make(&"poof", Vector2(10.4, 20.6))
	add_child(fx)
	assert_eq(fx.position, Vector2(10, 21), "целые пиксели")
	assert_eq(fx.frame, 0)
	fx.advance(FxSprite.duration(&"poof") * 0.5)
	assert_true(fx.frame > 0 and not fx.is_finished())
	watch_signals(fx)
	fx.advance(FxSprite.duration(&"poof"))
	assert_signal_emitted(fx, "finished")
	assert_true(fx.is_queued_for_deletion())


func test_fx_sprite_speed() -> void:
	var fast := FxSprite.make(&"slam", Vector2.ZERO, 2.0)
	add_child_autofree(fast)
	fast.advance(FxSprite.duration(&"slam") * 0.51)
	assert_true(fast.is_finished(), "вдвое быстрее — вдвое короче")


# --- Отклик стола ----------------------------------------------------------------

func test_roll_rattles_cups_spins_dice_and_raises_dust() -> void:
	var screen := _table(11)
	var fx: TableFx = screen._fx
	if screen._controller.phase != Phase.ROLL:
		pass_test("раунд начался без броска игрока")
		return
	screen._roll_button.pressed.emit()
	assert_true(screen._own.is_rolling(), "свои кубики крутятся")
	assert_eq(screen._own.shown_dice(), screen._controller.view_for(0).own_dice,
			"под анимацией — настоящие грани")
	await wait_seconds(TableFx.RATTLE_TIME + TableFx.SLAM_TIME + 0.2)
	assert_false(screen._own.is_rolling())
	var dust := fx.active_effects().count(&"slam")
	assert_eq(dust, screen._controller.player_count(), "пыль под каждой чашкой")


func test_dice_lost_and_gained() -> void:
	var screen := _table(12)
	_to_bidding(screen)
	var fx: TableFx = screen._fx
	fx.clear_effects()
	Events.dice_count_changed.emit(1, 4, -1)
	assert_has(fx.active_effects(), &"poof")
	Events.dice_count_changed.emit(2, 5, 1)
	assert_has(fx.active_effects(), &"gain")
	fx.clear_effects()
	Events.dice_count_changed.emit(0, 5, 0)
	assert_eq(fx.active_effects().size(), 0, "кубик сохранён — без облачка")


func test_evidence_caught_accusation_and_madness() -> void:
	var screen := _table(13)
	_to_bidding(screen)
	var fx: TableFx = screen._fx
	fx.clear_effects()
	Events.evidence_shown.emit(2)
	assert_has(fx.active_effects(), &"evidence", "щупальца у портрета")
	Events.cheat_failed.emit(1, Cheat.Kind.PEEK)
	assert_has(fx.active_effects(), &"caught", "пойман — восклицание")
	fx.clear_effects()
	Events.accusation_made.emit(0, 3, true)
	assert_has(fx.active_effects(), &"caught", "верное обвинение — пойман")
	fx.clear_effects()
	Events.accusation_made.emit(0, 3, false)
	assert_false(fx.active_effects().has(&"caught"), "ложное обвинение — без восклицания")
	Events.madness_began.emit(2)
	assert_has(fx.active_effects(), &"madness")
	assert_false(screen._madness.is_active(), "Безумие бота — края экрана не трогаем")


func test_own_tricks_are_shown_only_to_the_player() -> void:
	var screen := _table(14)
	_to_bidding(screen)
	var fx: TableFx = screen._fx
	fx.clear_effects()
	var bot_outcome := CheatOutcome.new(1, CheatAction.new(Cheat.Kind.ABYSS_WHISPER, -1, -1, 3))
	Events.cheat_resolved.emit(bot_outcome)
	assert_eq(fx.active_effects().size(), 0, "чужой удачный трюк — секрет")
	var whisper := CheatOutcome.new(0, CheatAction.new(Cheat.Kind.ABYSS_WHISPER, -1, -1, 3))
	Events.cheat_resolved.emit(whisper)
	assert_has(fx.active_effects(), &"whisper", "Шёпот Бездны")
	var sleight := CheatOutcome.new(0, CheatAction.new(Cheat.Kind.SLEIGHT, -1, 0))
	Events.cheat_resolved.emit(sleight)
	assert_has(fx.active_effects(), &"trick")


func test_human_madness_edges_and_portraits() -> void:
	var screen := _table(15)
	_to_bidding(screen)
	var mc: MatchController = screen._controller
	assert_false(screen._madness.visible)
	mc.debug_set_sanity(0, 0)
	assert_true(screen._madness.is_active(), "Безумие игрока — края экрана")
	assert_true(screen._madness.visible)
	assert_true(screen._own.is_portrait_wobbling(), "свой портрет плывёт")
	assert_has(screen._fx.active_effects(), &"madness")
	await wait_seconds(MadnessOverlay.ONSET_TIME * 0.3)
	assert_gt(screen._madness.intensity(), 1.0, "всплеск при наступлении")
	await wait_seconds(MadnessOverlay.ONSET_TIME)
	assert_almost_eq(screen._madness.intensity(), 1.0, 0.01, "потом — обычный уровень")
	screen._on_rematch()
	assert_false(screen._madness.is_active(), "реванш — снова в своём уме")
	assert_false(screen._own.is_portrait_wobbling())


func test_mad_bot_portrait_wobbles() -> void:
	var screen := _table(16)
	var seat: SeatView = screen._seats[1]
	assert_false(seat.is_portrait_wobbling())
	seat.set_mad(true)
	assert_true(seat.is_portrait_wobbling())
	var mat := seat._portrait.material as ShaderMaterial
	var region: Vector4 = mat.get_shader_parameter(&"region")
	assert_true(region.z > 0.0 and region.z < 1.0, "область портрета в атласе передана")
	seat.set_mad(false)
	assert_false(seat.is_portrait_wobbling())


func test_reveal_shows_dice_one_by_one() -> void:
	var screen := _table(17)
	_to_bidding(screen)
	var mc: MatchController = screen._controller
	var steps := 0
	while mc.phase == Phase.BIDDING and steps < 200:
		steps += 1
		if mc.is_waiting_for_human():
			if not screen._liar_button.disabled:
				screen._liar_button.pressed.emit()
			else:
				screen._bid_button.pressed.emit()
		else:
			screen._on_timer()
	var panel: RoundResultPanel = screen._result_panel
	if screen._last_reveal == null:
		pass_test("раунд кончился без вскрытия")
		return
	assert_true(panel.is_revealing(), "кубики проявляются")
	assert_eq(panel._reveal_dice[-1].modulate.a, 0.0, "последний кубик ещё не виден")
	await wait_seconds(RoundResultPanel.REVEAL_STEP * 30 + 1.0)
	assert_false(panel.is_revealing())
	assert_eq(panel._reveal_tail[0].modulate, Color.WHITE, "итог виден")


func test_effects_follow_bot_speed() -> void:
	var screen := _table(18)
	var fx: TableFx = screen._fx
	Settings.set_value(&"bot_speed", 2.0)
	var sprite := fx.spawn(&"poof", Vector2.ZERO)
	assert_eq(sprite.speed, 2.0)
	screen._spectating = true
	assert_eq(fx.spawn(&"poof", Vector2.ZERO).speed, 2.0 * TableLayout.SPECTATE_SPEED,
			"«Досмотреть ×2» — эффекты тоже быстрее")


func test_effect_count_is_capped() -> void:
	var screen := _table(19)
	var fx: TableFx = screen._fx
	fx.clear_effects()
	for i in TableFx.MAX_EFFECTS + 10:
		fx.spawn(&"slam", Vector2.ZERO)
	assert_eq(fx.active_effects().size(), TableFx.MAX_EFFECTS)


func test_shakes_return_nodes_to_place() -> void:
	var screen := _table(20)
	var fx: TableFx = screen._fx
	var seat: SeatView = screen._seats[1]
	var origin := seat.position
	fx.rattle(seat, 2, 0.2)
	fx.rattle(seat, 2, 0.2)  # повторная тряска не сбивает исходную точку
	await wait_seconds(0.5)
	assert_eq(seat.position, origin)
	var screen_origin := screen.position
	fx.shake_screen()
	await wait_seconds(TableFx.SCREEN_SHAKE_TIME + 0.3)
	assert_eq(screen.position, screen_origin)
