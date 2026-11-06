extends SceneTree
## Сборка пиксельных шрифтов из текстовых исходников ui/fonts/src/*.txt в FontFile (.res).
##
## Запуск (из папки проекта):
##   godot --headless --path . -s res://tools/build_fonts.gd
##   godot --headless --path . -s res://tools/build_fonts.gd -- --preview=C:/tmp/fonts
## С --preview дополнительно сохраняет атласы в PNG (для просмотра глазами).
##
## Формат исходника описан в шапке ui/fonts/src/body.txt.
## Шрифт битмапный: глифы 1:1 по пикселям, сглаживания нет, системный фолбэк выключен
## (нехватающий символ сразу виден квадратиком, а тест покрытия его ловит).

const ATLAS_WIDTH := 256
const ATLAS_PADDING := 1
## Межстрочный зазор под выносными элементами.
const LINE_GAP := 1

const FONTS := [
	{src = "res://ui/fonts/src/body.txt", out = "res://ui/fonts/kraken_body.res",
		name = "Kraken Body", style = &"plain"},
	{src = "res://ui/fonts/src/title.txt", out = "res://ui/fonts/kraken_title.res",
		name = "Kraken Title", style = &"stone"},
	{src = "res://ui/fonts/src/title.txt", out = "res://ui/fonts/kraken_title_glow.res",
		name = "Kraken Title Glow", style = &"glow"},
]

# Палитра — из ART_PROMPTS.md.
const OUTLINE := Color("#0d0b14")
const STONE_HIGHLIGHT := Color("#e8d9b0")
const STONE_BASE := Color("#c9a66b")
const STONE_SHADOW := Color("#7a5a36")
const STONE_MOSS := Color("#3fa66b")
## Каждый N-й пиксель основной заливки «камня» — мох (детерминированный хэш).
const MOSS_EVERY := 9
const GLOW_CORE := Color("#9cff57")
const GLOW_EDGE := Color("#3fa66b")
const GLOW_HALO := Color(0.247, 0.651, 0.42, 0.55)

const NBSP := 0x00A0


func _init() -> void:
	var preview_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			preview_dir = arg.trim_prefix("--preview=")
	var ok := true
	for spec: Dictionary in FONTS:
		ok = _build(spec, preview_dir) and ok
	quit(0 if ok else 1)


func _build(spec: Dictionary, preview_dir: String) -> bool:
	var parsed := _parse(spec.src)
	if parsed.is_empty():
		return false
	var meta: Dictionary = parsed.meta
	var glyphs: Array = parsed.glyphs
	var margin := 0 if spec.style == &"plain" else 1

	# Картинки глифов.
	var images: Array[Image] = []
	for g: Dictionary in glyphs:
		images.append(_render_glyph(g, margin, spec.style))

	# Полочная упаковка в атлас.
	var positions: Array[Vector2i] = []
	var x := ATLAS_PADDING
	var y := ATLAS_PADDING
	var shelf := 0
	for img in images:
		if x + img.get_width() + ATLAS_PADDING > ATLAS_WIDTH:
			x = ATLAS_PADDING
			y += shelf + ATLAS_PADDING
			shelf = 0
		positions.append(Vector2i(x, y))
		x += img.get_width() + ATLAS_PADDING
		shelf = maxi(shelf, img.get_height())
	var atlas := Image.create_empty(ATLAS_WIDTH, y + shelf + ATLAS_PADDING, false, Image.FORMAT_RGBA8)
	for i in images.size():
		atlas.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), positions[i])

	# Метрики: базовая линия под последней строкой заглавной.
	var ascent: int = meta.accent + meta.cap + margin
	var descent: int = meta.descent + margin + LINE_GAP
	var size := ascent + descent

	var font := FontFile.new()
	font.font_name = spec.name
	font.fixed_size = size
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.allow_system_fallback = false
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	var key := Vector2i(size, 0)
	font.set_texture_image(0, key, 0, atlas)
	font.set_cache_ascent(0, size, ascent)
	font.set_cache_descent(0, size, descent)

	var defined := {}
	for i in glyphs.size():
		var g: Dictionary = glyphs[i]
		var img := images[i]
		var codes: Array = g.chars.duplicate()
		if meta.caps_only:
			for c: int in g.chars:
				var lower := String.chr(c).to_lower().unicode_at(0)
				if lower != c:
					codes.append(lower)
		for c: int in codes:
			if defined.has(c):
				if c in g.chars:
					push_error("%s: символ «%s» описан дважды" % [spec.src, String.chr(c)])
					return false
				continue  # строчная уже нарисована отдельно
			defined[c] = true
			font.set_glyph_texture_idx(0, key, c, 0)
			font.set_glyph_uv_rect(0, key, c, Rect2(positions[i], img.get_size()))
			font.set_glyph_size(0, key, c, Vector2(img.get_size()))
			font.set_glyph_offset(0, key, c, Vector2(0, -(margin + g.up.size() + meta.cap)))
			font.set_glyph_advance(0, size, c, Vector2(g.width + 2 * margin + meta.spacing, 0))
	for c in [0x20, NBSP]:
		font.set_glyph_texture_idx(0, key, c, -1)
		font.set_glyph_size(0, key, c, Vector2.ZERO)
		font.set_glyph_advance(0, size, c, Vector2(meta.space, 0))

	var err := ResourceSaver.save(font, spec.out)
	if err != OK:
		push_error("Не удалось сохранить %s: %s" % [spec.out, error_string(err)])
		return false
	print("%s: %d глифов, размер %d, атлас %dx%d" % [spec.out, defined.size(), size,
			atlas.get_width(), atlas.get_height()])
	if not preview_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(preview_dir)
		atlas.save_png(preview_dir.path_join(spec.out.get_file().get_basename() + ".png"))
	return true


# --- Разбор исходника -------------------------------------------------------------

func _parse(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Нет файла %s" % path)
		return {}
	var meta := {cap = 7, accent = 0, descent = 0, spacing = 1, space = 3, caps_only = false}
	var glyphs: Array = []
	var current: Dictionary = {}
	var line_no := 0
	for raw in file.get_as_text().split("\n"):
		line_no += 1
		var line := raw.strip_edges(false, true)
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("@"):
			var parts := line.substr(1).split(" ", false)
			if parts[0] == "caps_only":
				meta.caps_only = true
			else:
				meta[parts[0]] = int(parts[1])
			continue
		if line.begins_with("== "):
			current = {chars = [], up = [], rows = [], line = line_no, width = 0}
			for token in line.substr(3).split(" ", false):
				if token.length() != 1:
					push_error("%s:%d: ожидался один символ, а не «%s»" % [path, line_no, token])
					return {}
				current.chars.append(token.unicode_at(0))
			glyphs.append(current)
			continue
		if current.is_empty():
			push_error("%s:%d: строка вне глифа" % [path, line_no])
			return {}
		if line.begins_with("^"):
			current.up.append(line.substr(1))
		else:
			current.rows.append(line)

	for g: Dictionary in glyphs:
		var all_rows: Array = g.up + g.rows
		var width: int = all_rows[0].length()
		var where := "%s:%d (%s)" % [path, g.line, String.chr(g.chars[0])]
		for row: String in all_rows:
			if row.length() != width:
				push_error("%s: строки разной ширины" % where)
				return {}
			for ch in row:
				if ch != "#" and ch != ".":
					push_error("%s: недопустимый символ «%s»" % [where, ch])
					return {}
		if g.up.size() > meta.accent:
			push_error("%s: слишком много строк над заглавной" % where)
			return {}
		if g.rows.size() < meta.cap or g.rows.size() > meta.cap + meta.descent:
			push_error("%s: строк %d, ожидалось %d..%d" % [where, g.rows.size(), meta.cap,
					meta.cap + meta.descent])
			return {}
		g.width = width
	return {meta = meta, glyphs = glyphs}


# --- Отрисовка глифа ----------------------------------------------------------------

func _render_glyph(g: Dictionary, margin: int, style: StringName) -> Image:
	var rows: Array = g.up + g.rows
	var w: int = g.width
	var h := rows.size()
	var ink := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and rows[y][x] == "#"
	var img := Image.create_empty(w + 2 * margin, h + 2 * margin, false, Image.FORMAT_RGBA8)
	for py in img.get_height():
		for px in img.get_width():
			var x := px - margin
			var y := py - margin
			var color := Color(0, 0, 0, 0)
			if ink.call(x, y):
				color = _ink_color(style, not ink.call(x, y - 1), not ink.call(x, y + 1),
						_hash(x, y, g.chars[0]))
			elif margin > 0 and _touches_ink(ink, x, y):
				color = GLOW_HALO if style == &"glow" else OUTLINE
			img.set_pixel(px, py, color)
	return img


func _ink_color(style: StringName, top_edge: bool, bottom_edge: bool, hash_value: int) -> Color:
	match style:
		&"stone":
			if top_edge:
				return STONE_HIGHLIGHT
			if bottom_edge:
				return STONE_SHADOW
			return STONE_MOSS if hash_value % MOSS_EVERY == 0 else STONE_BASE
		&"glow":
			return GLOW_EDGE if bottom_edge else GLOW_CORE
	return Color.WHITE


func _touches_ink(ink: Callable, x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and ink.call(x + dx, y + dy):
				return true
	return false


func _hash(x: int, y: int, seed_value: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (seed_value * 83492791))
