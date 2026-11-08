extends GutTest
## М14: подключение арта из assets/generated/ — обработка и что оно реально в атласах.


func _image(w: int, h: int, color: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


func _only_palette(img: Image, allow_transparent: bool) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a8 == 0 and allow_transparent:
				continue
			if not KrakenPalette.contains(c):
				return false
	return true


func test_nearest_maps_to_palette() -> void:
	assert_eq(GeneratedArt.nearest(KrakenPalette.FIRE), KrakenPalette.FIRE)
	assert_eq(GeneratedArt.nearest(Color("#ffb040")), KrakenPalette.FIRE)
	assert_eq(GeneratedArt.nearest(Color.BLACK), KrakenPalette.INK)
	assert_eq(GeneratedArt.nearest(Color("#7a1520")), KrakenPalette.BLOOD)


func test_prepare_downscales_nearest_and_quantizes() -> void:
	# 128×128: левая половина «почти огонь», правая — «почти кровь».
	var src := _image(128, 128, Color("#ffb040"))
	src.fill_rect(Rect2i(64, 0, 64, 128), Color("#801a28"))
	var out := GeneratedArt.prepare(src, Vector2i(64, 64), false)
	assert_eq(out.get_size(), Vector2i(64, 64))
	assert_eq(out.get_pixel(10, 10), KrakenPalette.FIRE)
	assert_eq(out.get_pixel(50, 10), KrakenPalette.BLOOD)
	assert_true(_only_palette(out, true))


func test_prepare_chroma_key_and_alpha_threshold() -> void:
	var src := _image(64, 64, Color(0.02, 0.98, 0.05))   # почти #00ff00
	src.fill_rect(Rect2i(0, 0, 8, 8), Color(1, 0.7, 0.28, 0.3))   # полупрозрачное — прочь
	src.fill_rect(Rect2i(20, 20, 8, 8), KrakenPalette.LIME)       # свечение — не хромакей
	var out := GeneratedArt.prepare(src, Vector2i(64, 64), false)
	assert_eq(out.get_pixel(40, 40).a8, 0, "хромакей → прозрачный")
	assert_eq(out.get_pixel(2, 2).a8, 0, "ниже порога → прозрачный")
	assert_eq(out.get_pixel(22, 22), KrakenPalette.LIME)


func test_prepare_crops_to_aspect_and_fills_opaque() -> void:
	# 1920×1200 (16:10) → обрезка до 16:9 по центру → 640×360, полосы сверху/снизу срезаны.
	var src := _image(1920, 1200, KrakenPalette.WOOD)
	src.fill_rect(Rect2i(0, 0, 1920, 60), Color(1, 0, 0))
	src.fill_rect(Rect2i(0, 1140, 1920, 60), Color(0, 0, 0, 0))
	var out := GeneratedArt.prepare(src, Sprites.BACKGROUND_SIZE, true)
	assert_eq(out.get_size(), Sprites.BACKGROUND_SIZE)
	assert_eq(out.get_pixel(5, 0), KrakenPalette.WOOD)
	assert_eq(out.get_pixel(5, 359), KrakenPalette.WOOD)
	assert_eq(out.detect_alpha(), Image.ALPHA_NONE)


func test_paths_follow_art_prompts_names() -> void:
	assert_eq(GeneratedArt.portrait_path(&"plague_cultist", true),
			"res://assets/generated/portraits/cultist_mad.png")
	assert_eq(GeneratedArt.portrait_path(&"scholar", false),
			"res://assets/generated/portraits/scholar_normal.png")
	assert_eq(GeneratedArt.background_path(Sprites.Background.MENU),
			"res://assets/generated/backgrounds/main_menu.png")
	assert_null(GeneratedArt.load_portrait(&"no_such_character", false), "нет файла — заглушка")
	assert_eq(GeneratedArt.die_path(Sprites.DiceSet.BONE, 6),
			"res://assets/generated/dice/bone_6.png")
	assert_null(GeneratedArt.load_die(Sprites.DiceSet.OBSIDIAN, 1), "нет файла — рисуется кодом")


func test_bone_dice_are_drawn_by_author() -> void:
	# Костяной набор (тот, что за столом) — все шесть граней из assets/generated/dice/,
	# одного размера: силуэт (непрозрачные пиксели) у всех граней совпадает.
	var silhouette := _silhouette(GeneratedArt.load_die(Sprites.DiceSet.BONE, 1))
	for face in range(1, 7):
		var img := GeneratedArt.load_die(Sprites.DiceSet.BONE, face)
		assert_not_null(img, "грань %d" % face)
		if img != null:
			assert_eq(img.get_size(), Sprites.DIE_SIZE)
			assert_true(_only_palette(img, true), "грань %d в палитре" % face)
			assert_eq(_silhouette(img), silhouette, "грань %d того же размера" % face)


func _silhouette(img: Image) -> PackedByteArray:
	var out := PackedByteArray()
	for y in img.get_height():
		for x in img.get_width():
			out.append(1 if img.get_pixel(x, y).a > 0.5 else 0)
	return out


func test_every_portrait_and_background_is_drawn() -> void:
	# Весь арт М14 на месте: у каждого персонажа оба портрета, все четыре фона.
	for id in Sprites.portrait_characters():
		for mad in [false, true]:
			var img := GeneratedArt.load_portrait(id, mad)
			assert_not_null(img, "%s %s" % [id, mad])
			if img != null:
				assert_true(_only_palette(img, true), "%s в палитре" % id)
	for kind: Sprites.Background in GeneratedArt.BACKGROUND_FILES:
		assert_not_null(GeneratedArt.load_background(kind), str(kind))
	var tavern := Image.load_from_file(ProjectSettings.globalize_path(Sprites.BACKGROUND_PATH))
	var menu := Image.load_from_file(ProjectSettings.globalize_path(
			Sprites.BACKGROUND_PATHS[Sprites.Background.MENU]))
	assert_false(tavern.get_data() == menu.get_data(), "у меню свой фон")
