extends SceneTree
## Rebuild the approved ImageGen pilot without quantizing its marine palette.
const SOURCE := "res://art/campaign_imagegen/storm/"
const OUTPUT := "res://assets/generated/campaign/"

func _initialize() -> void:
	var background := Image.load_from_file(SOURCE + "background.png")
	var ship := Image.load_from_file(SOURCE + "ship.png")
	if background == null or ship == null:
		quit(1)
		return
	background.convert(Image.FORMAT_RGBA8)
	background.resize(640, 260, Image.INTERPOLATE_NEAREST)
	ship.convert(Image.FORMAT_RGBA8)
	ship.resize(300, 205, Image.INTERPOLATE_NEAREST)
	var waves := Image.create(640, 260, false, Image.FORMAT_RGBA8)
	for x in 640:
		var top := 230
		for y in range(196, 240):
			var color := background.get_pixel(x, y)
			if color.r + color.g + color.b > 1.45:
				top = y
				break
		for y in range(top, 260):
			waves.set_pixel(x, y, background.get_pixel(x, y))
	var failed := false
	for entry in [[background, "storm_background"], [ship, "storm_ship"], [waves, "storm_foreground"]]:
		if entry[0].save_png(OUTPUT + entry[1] + ".png") != OK:
			failed = true
	for name: String in ["rocks", "shore", "door", "bar", "fallen", "ruin", "dawn", "deep"]:
		var source := "res://art/campaign_imagegen/scenes/" + name + ".png"
		if not FileAccess.file_exists(source):
			push_error("Missing cinematic source: " + source)
			quit(1)
			return
		var image := Image.load_from_file(source)
		if image == null:
			failed = true
			continue
		image.convert(Image.FORMAT_RGBA8)
		image.resize(640, 260, Image.INTERPOLATE_NEAREST)
		if image.save_png(OUTPUT + "cinematic_" + name + ".png") != OK:
			failed = true
		if name == "rocks" or name == "shore":
			var foam := Image.create(640, 260, false, Image.FORMAT_RGBA8)
			for y in 260:
				for x in 640:
					var color := image.get_pixel(x, y)
					var in_water := y >= 218 if name == "rocks" else (x < 220 and y > 170 + x / 5)
					if in_water and (name == "rocks" or color.r + color.g + color.b > 1.35):
						foam.set_pixel(x, y, color)
			if foam.save_png(OUTPUT + "cinematic_" + name + "_foreground.png") != OK:
				failed = true
	var sprite_sizes := {"hob": Vector2i(150, 175), "boss": Vector2i(150, 185), "boat": Vector2i(100, 55), "eye": Vector2i(240, 90), "wreck": Vector2i(270, 185), "counter": Vector2i(640, 100)}
	for name: String in sprite_sizes:
		var source := "res://art/campaign_imagegen/scenes/" + name + ".png"
		var image := Image.load_from_file(source)
		if image == null:
			push_error("Missing cinematic sprite: " + source)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		var dimensions: Vector2i = sprite_sizes[name]
		var used := image.get_used_rect()
		if used.has_area():
			var padded := used.grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			image = image.get_region(padded)
		image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_NEAREST)
		if image.save_png(OUTPUT + "cinematic_" + name + ".png") != OK:
			failed = true
	var hero := Image.load_from_file("res://art/campaign_imagegen/scenes/hero.png")
	if hero == null:
		quit(1)
		return
	hero.convert(Image.FORMAT_RGBA8)
	hero = hero.get_region(hero.get_used_rect())
	var hero_sizes := {"hero": Vector2i(26, 44), "hero_door": Vector2i(72, 145), "hero_back": Vector2i(85, 210)}
	for name: String in hero_sizes:
		var dimensions: Vector2i = hero_sizes[name]
		var fitted := hero.duplicate() as Image
		var scale := minf(float(dimensions.x - 2) / hero.get_width(), float(dimensions.y - 2) / hero.get_height())
		fitted.resize(maxi(1, roundi(hero.get_width() * scale)), maxi(1, roundi(hero.get_height() * scale)), Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(fitted, Rect2i(Vector2i.ZERO, fitted.get_size()), Vector2i((dimensions.x - fitted.get_width()) / 2, dimensions.y - fitted.get_height() - 1))
		if canvas.save_png(OUTPUT + "cinematic_" + name + ".png") != OK:
			failed = true
	quit(1 if failed else 0)
