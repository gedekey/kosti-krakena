extends SceneTree
## Сборка листов эффектов (М10): берёт отрендеренные pixelfx листы (PNG + JSON, см. build_fx.ps1),
## приводит каждый пиксель к палитре KrakenPalette (альфа — ступенями), обрезает кадры по общей
## рамке и пишет ui/fx/fx_<имя>.png и сгенерированный ui/fx/fx_sheets.gd.
##
##   godot --headless --path . -s res://tools/build_fx.gd -- --raw=C:/tmp/kraken_fx_raw

const LIST_PATH := "res://ui/fx/src/fx_list.json"
const OUT_DIR := "res://ui/fx"
const OUT_SHEETS := "res://ui/fx/fx_sheets.gd"
## Пиксели прозрачнее этого выбрасываются; остальная альфа — ступенями по 1/ALPHA_STEPS.
const ALPHA_CUTOFF := 0.14
const ALPHA_STEPS := 4
## Сколько столбцов кадров в выходном листе.
const OUT_COLUMNS := 8


func _init() -> void:
	var raw := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--raw="):
			raw = arg.trim_prefix("--raw=")
	if raw == "":
		push_error("--raw=<папка с листами pixelfx> не указан")
		quit(1)
		return
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	var sheets := {}
	var ok := true
	for name: String in list.effects:
		var id: String = list.effects[name].id
		var base := raw.path_join(name).path_join(id).path_join(id.get_file())
		var info := _build(name, base, _colors_of(list.effects[name].opts))
		if info.is_empty():
			ok = false
		else:
			sheets[name] = info
	ok = _write_sheets(sheets) and ok
	print("FX: %d sheets" % sheets.size())
	quit(0 if ok else 1)


## Все цвета из опций эффекта: к ним (а не ко всей палитре) и приводим пиксели, чтобы
## промежуточные оттенки не уходили в чужой цвет (тёмно-зелёное → дерево).
func _colors_of(value: Variant) -> Array[Color]:
	var out: Array[Color] = []
	if value is String and (value as String).begins_with("#"):
		var c := Color(value)
		assert(KrakenPalette.contains(c), "Цвет не из палитры: %s" % value)
		out.append(c)
	elif value is Array:
		for v in value:
			out.append_array(_colors_of(v))
	elif value is Dictionary:
		for v in value.values():
			out.append_array(_colors_of(v))
	return out


func _build(name: String, base: String, colors: Array[Color]) -> Dictionary:
	var src := Image.load_from_file(base + ".png")
	var meta_json = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	if src == null or meta_json == null:
		push_error("Нет листа %s" % base)
		return {}
	src.convert(Image.FORMAT_RGBA8)
	var px: Dictionary = meta_json.meta.pixelfx
	var frame := Vector2i(int(px.frameSize[0]), int(px.frameSize[1]))
	var count := int(px.frames)
	var cols := int(px.columns)

	# Кадры → в палитру; общая рамка непустых пикселей.
	var frames: Array[Image] = []
	var used := Rect2i()
	for i in count:
		var img := src.get_region(Rect2i(Vector2i(i % cols, i / cols) * frame, frame))
		_quantize(img, colors)
		var r := img.get_used_rect()
		if r.has_area():
			used = r if not used.has_area() else used.merge(r)
		frames.append(img)
	# Последние пустые кадры — не нужны (эффект уже кончился).
	while count > 1 and not frames[count - 1].get_used_rect().has_area():
		frames.pop_back()
		count -= 1

	var out_cols := mini(OUT_COLUMNS, count)
	var rows := ceili(float(count) / out_cols)
	var out := Image.create(used.size.x * out_cols, used.size.y * rows, false, Image.FORMAT_RGBA8)
	for i in count:
		out.blit_rect(frames[i], used, Vector2i(i % out_cols, i / out_cols) * used.size)
	var path := OUT_DIR.path_join("fx_%s.png" % name)
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Не сохранить %s: %s" % [path, error_string(err)])
		return {}
	return {
		"path": path, "frame": used.size, "columns": out_cols, "count": count,
		"fps": float(px.fps), "pivot": Vector2i(int(px.pivot[0]), int(px.pivot[1])) - used.position,
	}


func _quantize(img: Image, colors: Array[Color]) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < ALPHA_CUTOFF:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var p := _nearest(c, colors)
			p.a = clampf(ceilf(c.a * ALPHA_STEPS - 0.5) / ALPHA_STEPS, 1.0 / ALPHA_STEPS, 1.0)
			img.set_pixel(x, y, p)


func _nearest(c: Color, colors: Array[Color]) -> Color:
	var best := KrakenPalette.INK
	var best_d := INF
	for p: Color in colors:
		# Взвешенное расстояние (глаз чувствительнее к зелёному).
		var d := 2.0 * pow(c.r - p.r, 2) + 4.0 * pow(c.g - p.g, 2) + 3.0 * pow(c.b - p.b, 2)
		if d < best_d:
			best_d = d
			best = p
	return best


func _write_sheets(sheets: Dictionary) -> bool:
	var lines := PackedStringArray([
		"extends RefCounted",
		"## СГЕНЕРИРОВАНО tools/build_fx.gd — не править руками.",
		"## Листы эффектов: путь, размер кадра, столбцы, число кадров, fps, точка привязки в кадре.",
		"",
		"const SHEETS := {",
	])
	var names := sheets.keys()
	names.sort()
	for name: String in names:
		var s: Dictionary = sheets[name]
		lines.append('\t&"%s": {"path": "%s", "frame": Vector2i(%d, %d), "columns": %d, "count": %d, "fps": %.1f, "pivot": Vector2i(%d, %d)},' % [
			name, s.path, s.frame.x, s.frame.y, s.columns, s.count, s.fps, s.pivot.x, s.pivot.y])
	lines.append("}")
	var f := FileAccess.open(OUT_SHEETS, FileAccess.WRITE)
	if f == null:
		push_error("Не записать %s" % OUT_SHEETS)
		return false
	f.store_string("\n".join(lines) + "\n")
	return true
