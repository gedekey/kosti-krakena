extends SceneTree
## Сборка атласов спрайтов (М8): рисует SpritePainter, сохраняет PNG и регионы.
##
## Запуск (из папки проекта), затем импорт:
##   godot --headless --path . -s res://tools/build_sprites.gd
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/build_sprites.gd -- --preview=C:/tmp/sprites
## С --preview дополнительно сохраняет атласы увеличенными ×4 (для просмотра глазами).

const OUT_REGIONS := "res://ui/sprites/sprite_regions.gd"
const PREVIEW_SCALE := 4


func _init() -> void:
	var preview_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="):
			preview_dir = arg.trim_prefix("--preview=")
	var result := SpritePainter.new().build()
	var ok := true
	var images := {
		Sprites.MAIN_ATLAS_PATH: result.main,
		Sprites.PORTRAIT_ATLAS_PATH: result.portraits,
		Sprites.BACKGROUND_PATH: result.background,
	}
	for path: String in images:
		var img: Image = images[path]
		ok = _save_png(img, path) and ok
		if preview_dir != "":
			var big := img.duplicate() as Image
			big.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE,
					Image.INTERPOLATE_NEAREST)
			DirAccess.make_dir_recursive_absolute(preview_dir)
			big.save_png(preview_dir.path_join(path.get_file()))
	ok = _write_regions(result) and ok
	print("Sprites: %d in main atlas, %d portraits" % [result.main_regions.size(),
			result.portrait_regions.size()])
	quit(0 if ok else 1)


func _save_png(img: Image, path: String) -> bool:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Cannot save %s: %s" % [path, error_string(err)])
		return false
	return true


func _write_regions(result: Dictionary) -> bool:
	var lines := PackedStringArray([
		"extends RefCounted",
		"## СГЕНЕРИРОВАНО tools/build_sprites.gd — не править руками.",
		"## Регионы спрайтов в атласах и поля девятисрезов (слева, сверху, справа, снизу).",
		"",
	])
	lines.append_array(_dict_const("MAIN", result.main_regions))
	lines.append("")
	lines.append_array(_dict_const("PORTRAITS", result.portrait_regions))
	lines.append("")
	lines.append("const NINE_PATCH := {")
	for name: StringName in result.nine_patch:
		var m: Array = result.nine_patch[name]
		lines.append("\t&\"%s\": [%d, %d, %d, %d]," % [name, m[0], m[1], m[2], m[3]])
	lines.append("}")
	var file := FileAccess.open(OUT_REGIONS, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % OUT_REGIONS)
		return false
	file.store_string("\n".join(lines) + "\n")
	return true


func _dict_const(const_name: String, regions: Dictionary) -> PackedStringArray:
	var out := PackedStringArray(["const %s := {" % const_name])
	for name: StringName in regions:
		var r: Rect2i = regions[name]
		out.append("\t&\"%s\": Rect2i(%d, %d, %d, %d)," % [name, r.position.x, r.position.y,
				r.size.x, r.size.y])
	out.append("}")
	return out
