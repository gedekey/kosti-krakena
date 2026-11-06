class_name GeneratedArt
extends RefCounted
## М14: подключение арта из assets/generated/ (имена и размеры — ART_PROMPTS.md).
##
## Файл подхватывает генератор атласов (tools/build_sprites.gd). Если файла нет, остаётся
## заглушка М8. Обработка каждого изображения (prepare):
##   1. хромакей #00ff00 → прозрачность;
##   2. обрезка по центру до пропорций цели и даунскейл nearest-neighbor;
##   3. каждый пиксель → ближайший цвет KrakenPalette, полупрозрачность → да/нет по порогу.
## Нарисованные в проекте через pxl (art/*.px.js, tools/build_art.ps1) уже в палитре и
## нужного размера — для них обработка ничего не меняет.

const ROOT := "res://assets/generated/"
const PORTRAIT_DIR := "portraits/"
const BACKGROUND_DIR := "backgrounds/"

## Имена файлов портретов, если отличаются от id персонажа.
const PORTRAIT_FILES := {&"plague_cultist": "cultist", &"deep_one": "deepone"}
const BACKGROUND_FILES := {
	Sprites.Background.TAVERN: "tavern_table", Sprites.Background.MENU: "main_menu",
	Sprites.Background.VICTORY: "victory", Sprites.Background.DEFEAT: "defeat",
}

const CHROMA_KEY := Color(0.0, 1.0, 0.0)
## Насколько цвет может отличаться от хромакея (расстояние в RGB, 0..√3).
const CHROMA_TOLERANCE := 0.35
## Альфа ниже порога — прозрачный пиксель, выше — непрозрачный.
const ALPHA_THRESHOLD := 0.5


static func portrait_path(character: StringName, mad: bool) -> String:
	var file: String = PORTRAIT_FILES.get(character, String(character))
	return ROOT + PORTRAIT_DIR + "%s_%s.png" % [file, "mad" if mad else "normal"]


static func background_path(kind: Sprites.Background) -> String:
	return ROOT + BACKGROUND_DIR + BACKGROUND_FILES[kind] + ".png"


## Готовый портрет 64×64 в палитре или null, если файла нет.
static func load_portrait(character: StringName, mad: bool) -> Image:
	var src := _load(portrait_path(character, mad))
	return prepare(src, Sprites.PORTRAIT_SIZE, false) if src != null else null


## Готовый фон 640×360 в палитре (без прозрачности) или null, если файла нет.
static func load_background(kind: Sprites.Background) -> Image:
	var src := _load(background_path(kind))
	return prepare(src, Sprites.BACKGROUND_SIZE, true) if src != null else null


## Приводит изображение к размеру и палитре. opaque — прозрачность заливается ближайшим
## к исходному цветом палитры (для фонов).
static func prepare(src: Image, size: Vector2i, opaque: bool) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_crop_to_aspect(img, size)
	if img.get_size() != size:
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	for y in size.y:
		for x in size.x:
			var c := img.get_pixel(x, y)
			var keyed := _is_chroma(c)
			if not opaque and (keyed or c.a < ALPHA_THRESHOLD):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, KrakenPalette.INK if keyed else nearest(c))
	return img


## Ближайший цвет палитры (евклидово расстояние в RGB), непрозрачный.
static func nearest(c: Color) -> Color:
	var best := KrakenPalette.INK
	var best_d := INF
	for p: Color in KrakenPalette.BY_LETTER.values():
		var d := Vector3(c.r - p.r, c.g - p.g, c.b - p.b).length_squared()
		if d < best_d:
			best_d = d
			best = p
	return best


static func _is_chroma(c: Color) -> bool:
	return Vector3(c.r - CHROMA_KEY.r, c.g - CHROMA_KEY.g, c.b - CHROMA_KEY.b).length() \
			< CHROMA_TOLERANCE and c.a > 0.0


static func _crop_to_aspect(img: Image, size: Vector2i) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# w/h против size.x/size.y — в целых, без дробей.
	if w * size.y > h * size.x:
		var nw := h * size.x / size.y
		_crop(img, Rect2i((w - nw) / 2, 0, nw, h))
	elif w * size.y < h * size.x:
		var nh := w * size.y / size.x
		_crop(img, Rect2i(0, (h - nh) / 2, w, nh))


static func _crop(img: Image, rect: Rect2i) -> void:
	var part := img.get_region(rect)
	img.copy_from(part)


static func _load(path: String) -> Image:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		push_warning("GeneratedArt: не удалось прочитать %s" % path)
		return null
	return img
