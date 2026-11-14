class_name SlideArt
extends Control
## ImageGen cinematic layers and integer pixel motion.
## The anonymous hero silhouette suits every player portrait.

const RAIN := Color(0.53, 0.67, 0.78, 0.45)
const FLASH := Color(0.65, 0.78, 0.95, 0.24)
const GLOW := Color(1.0, 0.7, 0.28, 0.18)          # огонь

## Шторм: период молнии и сколько длится вспышка (с).
const LIGHTNING_PERIOD := 2.4
const LIGHTNING_FLASH := 0.14
## Качка корабля / лодки: амплитуда (px) и скорость.
const SHIP_BOB := 3.0
const BOAT_BOB := 2.0
const SINK_SPEED := 10.0
const SINK_MAX := 70
## Финал 4: глаз начинает открываться через EYE_DELAY с.
const EYE_DELAY := 1.0
const EYE_OPEN_TIME := 1.3

## Какой слайд: &"intro_1"…&"intro_5", &"finale_1"…&"finale_4".
var slide: StringName = &""
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_slide(id: StringName) -> void:
	slide = id
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Фон слайда (имя картинки в CampaignArt).
static func background_name(id: StringName) -> StringName:
	match id:
		&"intro_1":
			return &"storm_background"
		&"intro_2":
			return &"cinematic_rocks"
		&"intro_3":
			return &"cinematic_shore"
		&"intro_4":
			return &"cinematic_door"
		&"intro_5":
			return &"cinematic_bar"
		&"finale_1":
			return &"cinematic_fallen"
		&"finale_2":
			return &"cinematic_ruin"
		&"finale_3":
			return &"cinematic_dawn"
		&"finale_4":
			return &"cinematic_deep"
	return &""


func _draw() -> void:
	var bg := background_name(slide)
	if bg == &"":
		draw_rect(Rect2(Vector2.ZERO, size), KrakenPalette.INK)
		return
	_tex(bg, Vector2i.ZERO)
	match slide:
		&"intro_1":
			_storm()
		&"intro_2":
			var flash := fmod(_t, LIGHTNING_PERIOD) < LIGHTNING_FLASH
			if fmod(_t, LIGHTNING_PERIOD) < LIGHTNING_FLASH * 2.0:
				_tex(&"slide_bolt", Vector2i(474, 0))
			_tex(&"cinematic_wreck", Vector2i(190, 55 + _bob(SHIP_BOB, 2.3)))
			_tex(&"cinematic_rocks_foreground", Vector2i(_bob(1.0, 1.1), _bob(1.0, 1.7)))
			_rain(80)
			if flash:
				draw_rect(Rect2(Vector2.ZERO, size), FLASH)
		&"intro_3":
			_tex(&"cinematic_shore_foreground", Vector2i(_bob(1.0, 0.9), _bob(1.0, 1.2)))
			_tex(&"cinematic_hero", Vector2i(240, 190))
			_flicker(Vector2i(560, 55), 5.0)
			_rain(30)
		&"intro_4":
			var sway := roundi(sin(_t * 1.3))
			_flicker(Vector2i(525 + sway, 54), 4.0, 14)
			_tex(&"slide_lantern", Vector2i(518 + sway, 42))
			# Герой у самой двери, ростом чуть ниже неё (ступни на пороге).
			_tex(&"cinematic_hero_door", Vector2i(365, 95))
			_rain(60)
		&"intro_5":
			_tex(&"cinematic_hob", Vector2i(255, 25 + _bob(1.0, 1.2)))
			_tex(&"cinematic_counter", Vector2i(0, 160))
			_flicker(Vector2i(129, 91), 3.2, 8)
			_flicker(Vector2i(494, 89), 4.1, 6)
			# Герой спиной на переднем плане, в масштабе портрета Хоба (низ обрезан краем).
			_tex(&"cinematic_hero_back", Vector2i(20, 104))
		&"finale_1":
			_sinking_deep_one()
		&"finale_2":
			for i in 4:
				var y := posmod(int(_t * (38.0 + i * 9.0)) + i * 53, 260)
				var x := 145 + i * 106
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 9, y + 2), Vector2(x + 5, y + 4), Vector2(x - 2, y + 2)]), Color(0.09, 0.11, 0.14))
				draw_line(Vector2(x, y), Vector2(x + 9, y + 2), Color(0.26, 0.27, 0.28))
			for x in [90, 500]:
				for i in 8:
					var y := 35 + posmod(i * 23 + int(_t * 65.0), 180)
					draw_rect(Rect2(x + i % 3 * 2, y, 1, 8), Color(0.42, 0.57, 0.61, 0.35))
			_ripples(Vector2i(320, 242 + _bob(1.0, 1.0)))
		&"finale_3":
			var bob := _bob(BOAT_BOB, 2.0)
			_tex(&"cinematic_boat", Vector2i(310, 120 + bob))
			_ripples(Vector2i(360, 175 + bob))
		&"finale_4":
			_tex(&"cinematic_boat", Vector2i(288, 1 + _bob(1.0, 2.0)))
			if _t >= EYE_DELAY:
				var eye := CampaignArt.texture(&"cinematic_eye")
				var height := eye_visible_height(_t)
				if height > 0:
					var offset := (90 - height) / 2
					draw_texture_rect_region(eye, Rect2(200, 145 + offset, 240, height), Rect2(0, offset, 240, height))


# --- Детали --------------------------------------------------------------------

static func eye_visible_height(time: float) -> int:
	return roundi(clampf((time - EYE_DELAY) / EYE_OPEN_TIME, 0.0, 1.0) * 45.0) * 2

## Layered storm illustration with integer pixel motion.
func _storm() -> void:
	var ship := CampaignArt.texture(&"storm_ship")
	var at := Vector2i(140 + roundi(sin(_t * 0.8) * 2.0), 20 + _bob(3.0, 1.6))
	for y in range(0, 150, 10):
		var flutter := roundi(sin(_t * 3.5 + y * 0.025))
		draw_texture_rect_region(ship, Rect2(at.x + flutter, at.y + y, 300, 10),
				Rect2(0, y, 300, 10))
	draw_texture_rect_region(ship, Rect2(at.x, at.y + 150, 300, 55), Rect2(0, 150, 300, 55))
	var waves := CampaignArt.texture(&"storm_foreground")
	# Crop a few pixels inside the source, so oscillation never exposes an edge.
	var shift := roundi(sin(_t * 1.1) * 2.0)
	draw_texture_rect_region(waves, Rect2(-4 + shift, 1 + _bob(1.0, 1.7), 640, 260), Rect2(0, 0, 640, 260))
	draw_texture_rect_region(waves, Rect2(632 + shift, 1, 8, 260), Rect2(632, 0, 8, 260))
	for i in 70:
		var x := posmod(int(i * 53 - _t * 80.0), 640)
		var y := posmod(int(i * 37 + _t * 260.0), 260)
		draw_line(Vector2(x, y), Vector2(x - 2, y + 5), Color(0.53, 0.67, 0.78, 0.45))
	var phase := fmod(_t + 1.0, 4.8)
	if phase < 0.10 or (phase > 0.23 and phase < 0.29):
		var points := [Vector2i(480, 0), Vector2i(465, 30), Vector2i(476, 29), Vector2i(451, 65), Vector2i(461, 61), Vector2i(437, 110)]
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.76, 0.87, 1.0), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.65, 0.78, 0.95, 0.13))

func _tex(name: StringName, at: Vector2i) -> void:
	draw_texture(CampaignArt.texture(name), at)


func _bob(amplitude: float, speed: float) -> int:
	return roundi(sin(_t * speed) * amplitude)


## Косые капли по 3 пикселя, летят вниз-влево.
func _rain(count: int) -> void:
	var w := size.x
	var h := size.y
	for i in count:
		var x := int(fmod(i * 53.0 - _t * 60.0, w) + w) % int(w)
		var y := int(fmod(i * 37.0 + _t * 300.0, h))
		for k in 3:
			draw_rect(Rect2(x - k, y + k * 2, 1, 2), RAIN)


## Огонёк вдали / фонарь: пятно света пульсирует (радиус в пикселях).
func _flicker(at: Vector2i, speed: float, radius := 6) -> void:
	var f := 0.6 + 0.4 * absf(sin(_t * speed))
	draw_circle(Vector2(at), radius, Color(GLOW, GLOW.a * f))
	draw_circle(Vector2(at), maxi(1, radius / 2), Color(GLOW, GLOW.a * 2.0 * f))


## Рябь у лодки: две полоски пены расходятся в стороны.
func _ripples(at: Vector2i) -> void:
	var spread := int(fmod(_t * 6.0, 12.0))
	for side in [-1, 1]:
		draw_rect(Rect2(at.x + side * (34 + spread) - 3, at.y, 6, 1), KrakenPalette.BONE)


## Финал 1: отдельный рисунок Глубоководного оседает за край пола и гаснет.
func _sinking_deep_one() -> void:
	const FLOOR_Y := 220
	const SCALE := 1
	var tex := CampaignArt.texture(&"cinematic_boss")
	var elapsed := maxf(0.0, _t - 1.5)
	var top := 35 + mini(SINK_MAX, int(elapsed * SINK_SPEED))
	var visible_rows := (FLOOR_Y - top) / SCALE
	if visible_rows <= 0:
		return
	var a := clampf(1.0 - elapsed / 4.5, 0.0, 1.0)
	draw_texture_rect_region(tex, Rect2(245, top, tex.get_width(), visible_rows),
			Rect2(0, 0, tex.get_width(), mini(visible_rows, tex.get_height())), Color(1, 1, 1, a))
