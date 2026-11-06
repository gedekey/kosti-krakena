extends GutTest
## М8: атласы спрайтов собраны, актуальны, покрывают всё нужное и держат палитру.

const ATLASES := [Sprites.MAIN_ATLAS_PATH, Sprites.PORTRAIT_ATLAS_PATH, Sprites.BACKGROUND_PATH]

static var _built: Dictionary = {}


func _build() -> Dictionary:
	if _built.is_empty():
		_built = SpritePainter.new().build()
	return _built


func _load_png(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func test_atlases_are_up_to_date() -> void:
	# Если упал: исходники поменялись, а атласы нет. Пересоберите tools/build_sprites.gd.
	var built := _build()
	var images := {
		Sprites.MAIN_ATLAS_PATH: built.main, Sprites.PORTRAIT_ATLAS_PATH: built.portraits,
		Sprites.BACKGROUND_PATH: built.background,
	}
	for path: String in images:
		var saved := _load_png(path)
		var fresh: Image = images[path]
		saved.convert(Image.FORMAT_RGBA8)
		assert_eq(saved.get_size(), fresh.get_size(), path)
		assert_true(saved.get_data() == fresh.get_data(), path + " совпадает с генератором")
	var regions: GDScript = load(Sprites.REGIONS_PATH)
	assert_eq(regions.MAIN, built.main_regions)
	assert_eq(regions.PORTRAITS, built.portrait_regions)
	assert_eq(regions.NINE_PATCH, built.nine_patch)


func test_atlases_use_only_palette_colors() -> void:
	for path: String in ATLASES:
		var img := _load_png(path)
		img.convert(Image.FORMAT_RGBA8)
		var bad := 0
		var first := ""
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a8 == 0 or KrakenPalette.contains(c):
					continue
				bad += 1
				if first.is_empty():
					first = "(%d, %d) #%s" % [x, y, c.to_html()]
		assert_eq(bad, 0, "%s: чужие цвета, первый %s" % [path, first])


func test_background_is_opaque_and_full_size() -> void:
	var img := _load_png(Sprites.BACKGROUND_PATH)
	assert_eq(img.get_size(), Sprites.BACKGROUND_SIZE)
	assert_false(img.detect_alpha() != Image.ALPHA_NONE, "фон без прозрачности")
	assert_eq(Sprites.background().get_size(), Vector2(Sprites.BACKGROUND_SIZE))


func test_regions_fit_inside_atlases() -> void:
	var regions: GDScript = load(Sprites.REGIONS_PATH)
	var main_rect := Rect2i(Vector2i.ZERO, _load_png(Sprites.MAIN_ATLAS_PATH).get_size())
	for name: StringName in regions.MAIN:
		assert_true(main_rect.encloses(regions.MAIN[name]), name)
	var portrait_rect := Rect2i(Vector2i.ZERO, _load_png(Sprites.PORTRAIT_ATLAS_PATH).get_size())
	for name: StringName in regions.PORTRAITS:
		assert_true(portrait_rect.encloses(regions.PORTRAITS[name]), name)


func test_dice_have_all_faces_and_roll_frames() -> void:
	for dice_set: Sprites.DiceSet in Sprites.DICE_SET_IDS:
		var faces := {}
		for face in range(1, 7):
			var tex := Sprites.die(dice_set, face)
			assert_eq(tex.get_size(), Vector2(Sprites.DIE_SIZE))
			faces[_region_bytes(Sprites.die_name(dice_set, face))] = face
		assert_eq(faces.size(), 6, "все грани различаются")
		for frame in Sprites.DIE_ROLL_FRAMES:
			assert_eq(Sprites.die_roll(dice_set, frame).get_size(), Vector2(Sprites.DIE_SIZE))
	assert_ne(_region_bytes(Sprites.die_name(Sprites.DiceSet.BONE, 4)),
			_region_bytes(Sprites.die_name(Sprites.DiceSet.OBSIDIAN, 4)), "наборы различаются")


func test_cups_open_and_closed() -> void:
	for style: Sprites.CupStyle in Sprites.CUP_STYLE_IDS:
		for open in [false, true]:
			assert_eq(Sprites.cup(style, open).get_size(), Vector2(Sprites.CUP_SIZE))
		assert_ne(_region_bytes(Sprites.cup_name(style, true)),
				_region_bytes(Sprites.cup_name(style, false)))
	assert_true(Sprites.has(&"shadow_cup") and Sprites.has(&"shadow_die"))


func test_every_trick_has_an_icon() -> void:
	for kind: Cheat.Kind in Cheat.ALL:
		assert_eq(Sprites.trick_icon(kind).get_size(), Vector2(Sprites.ICON_SIZE), str(kind))
	for name in [Sprites.ICON_SANITY, Sprites.ICON_EVIDENCE, Sprites.ICON_MADNESS,
			Sprites.ICON_DICE, Sprites.ICON_ACCUSE]:
		assert_eq(Sprites.texture(name).get_size(), Vector2(Sprites.ICON_SIZE), name)
	for full in [true, false]:
		assert_eq(Sprites.sanity_pip(full).get_size(), Vector2(Sprites.SANITY_PIP_SIZE))


func test_every_character_has_both_portraits() -> void:
	var ids := Sprites.portrait_characters()
	for p in BotRoster.all():
		assert_has(ids, p.id, "бот %s" % p.id)
	for id in ids:
		assert_true(Sprites.has_portrait(id), id)
		for mad in [false, true]:
			assert_eq(Sprites.portrait(id, mad).get_size(), Vector2(Sprites.PORTRAIT_SIZE))
		assert_ne(_portrait_bytes(id, false), _portrait_bytes(id, true), "%s: Безумие видно" % id)


func test_ui_kit_styleboxes() -> void:
	for kind: Sprites.ButtonKind in Sprites.BUTTON_KIND_IDS:
		for state: Sprites.ButtonState in Sprites.BUTTON_STATE_IDS:
			var box := Sprites.button_style(kind, state)
			assert_not_null(box.texture)
			assert_gt(box.texture_margin_left, 0.0)
			assert_true(box.region_rect.has_area())
	var pressed := Sprites.button_style(Sprites.ButtonKind.BID, Sprites.ButtonState.PRESSED)
	var normal := Sprites.button_style(Sprites.ButtonKind.BID, Sprites.ButtonState.NORMAL)
	assert_gt(pressed.content_margin_top, normal.content_margin_top, "нажатая — текст ниже")
	for kind: Sprites.PanelKind in Sprites.PANEL_IDS:
		assert_true(Sprites.panel(kind).region_rect.has_area(), str(kind))
	for right in [false, true]:
		for state: Sprites.ButtonState in Sprites.BUTTON_STATE_IDS:
			assert_eq(Sprites.texture(Sprites.arrow_name(right, state)).get_size(),
					Vector2(Sprites.ARROW_SIZE))


func test_style_button_sets_all_states() -> void:
	var button: Button = autofree(Button.new())
	Sprites.style_button(button, Sprites.ButtonKind.LIAR)
	for slot in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(button.has_theme_stylebox_override(slot), slot)
	assert_true(button.has_theme_color_override("font_disabled_color"))


func _region_bytes(name: StringName) -> PackedByteArray:
	var regions: GDScript = load(Sprites.REGIONS_PATH)
	return _load_png(Sprites.MAIN_ATLAS_PATH).get_region(regions.MAIN[name]).get_data()


func _portrait_bytes(id: StringName, mad: bool) -> PackedByteArray:
	var regions: GDScript = load(Sprites.REGIONS_PATH)
	return _load_png(Sprites.PORTRAIT_ATLAS_PATH) \
			.get_region(regions.PORTRAITS[Sprites.portrait_name(id, mad)]).get_data()
