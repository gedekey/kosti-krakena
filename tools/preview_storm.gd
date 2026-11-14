extends SceneTree
## Run with a rendering driver; writes 24 deterministic frames at 8 fps.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var art := SlideArt.new()
	art.size = Vector2(640, 260)
	viewport.add_child(art)
	art.show_slide(&"intro_1")
	art.set_process(false)
	var output := "res://art/campaign_imagegen/storm/preview"
	DirAccess.make_dir_recursive_absolute(output)
	var contact := Image.create(1920, 780, false, Image.FORMAT_RGBA8)
	var scene_index := 0
	for id in ["intro_1", "intro_2", "intro_3", "intro_4", "intro_5", "finale_1", "finale_2", "finale_3", "finale_4"]:
		art.show_slide(StringName(id))
		var moments := [0.0, 2.0, 6.0]
		if id == "intro_1":
			moments = []
			for i in 24:
				moments.append(i / 8.0)
		for i in moments.size():
			art._t = moments[i]
			art.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output + "/%s_%02d.png" % [id, i])
		art._t = 2.0
		art.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		contact.blit_rect(viewport.get_texture().get_image(), Rect2i(0, 0, 640, 260), Vector2i(scene_index % 3 * 640, scene_index / 3 * 260))
		scene_index += 1
	contact.save_png(output + "/contact_sheet.png")
	quit()
