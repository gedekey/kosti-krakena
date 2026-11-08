extends Node
## Снимок экрана сцены (М16, проверка раскладки):
##   godot --path . res://tools/shot/shot.tscn -- [--touch] scene=res://scenes/table.tscn out=C:/x.png [wait=3]
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var scene: PackedScene = load(args.get("scene", "res://scenes/table.tscn"))
	add_child(scene.instantiate())
	await get_tree().create_timer(float(args.get("wait", "3"))).timeout
	get_viewport().get_texture().get_image().save_png(args.get("out", "user://shot.png"))
	get_tree().quit()
