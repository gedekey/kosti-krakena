class_name SlideArt
extends Control
## Картинка слайда вступления / финала — ЗАГЛУШКА М23 (М25 нарисует настоящие слайды
## в pxl). Простые фигуры с анимацией: шторм, волны, молния, огонёк, глаз Кракена.
## Герой — силуэт. Координаты целые, без сглаживания.

const SKY_STORM := Color8(0x14, 0x16, 0x26)
const SKY_DAWN := Color8(0x6a, 0x3a, 0x3a)
const SEA := Color8(0x12, 0x2a, 0x34)
const SEA_LIGHT := Color8(0x2a, 0x4a, 0x54)
const RAIN := Color(0.6, 0.7, 0.8, 0.5)
const ROCK := Color8(0x24, 0x22, 0x24)
const WOOD := Color8(0x3a, 0x26, 0x1a)
const WOOD_LIGHT := Color8(0x5a, 0x3e, 0x2a)
const SAND := Color8(0x5a, 0x4e, 0x3a)
const GLOW := Color8(0xf0, 0xb8, 0x50)
const FLASH := Color(0.9, 0.92, 1.0, 1)
const SILHOUETTE := Color8(0x08, 0x08, 0x0c)
const EYE_GREEN := Color8(0x8c, 0xe0, 0x70)
const SUN := Color8(0xf0, 0xa0, 0x50)

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


func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	match slide:
		&"intro_1":
			_storm(w, h, false)
		&"intro_2":
			_storm(w, h, true)
		&"intro_3":
			_shore(w, h)
		&"intro_4":
			_door(w, h)
		&"intro_5":
			_bar(w, h)
		&"finale_1":
			_eyes_fading(w, h)
		&"finale_2":
			_collapse(w, h)
		&"finale_3":
			_dawn(w, h)
		&"finale_4":
			_eye_below(w, h)
		_:
			draw_rect(Rect2(0, 0, w, h), SKY_STORM)


# --- Слайды --------------------------------------------------------------------

func _storm(w: int, h: int, lightning: bool) -> void:
	var flash := lightning and fmod(_t, 2.4) < 0.12
	draw_rect(Rect2(0, 0, w, h), FLASH if flash else SKY_STORM)
	if lightning:
		for i in 3:
			draw_polygon(PackedVector2Array([Vector2(380 + i * 70, h), Vector2(420 + i * 70, 150 - i * 20),
					Vector2(460 + i * 70, h)]), PackedColorArray([ROCK]))
	var tilt := sin(_t * 1.6) * (8.0 if not lightning else 14.0)
	_ship(Vector2i(200 + (60 if lightning else 0), 170), tilt)
	_waves(w, h, 180, 1.0)
	_rain(w, h)
	if lightning and fmod(_t, 2.4) < 0.3:
		var pts := PackedVector2Array([Vector2(470, 0), Vector2(450, 50), Vector2(480, 60),
				Vector2(455, 120), Vector2(490, 130), Vector2(460, 180)])
		draw_polyline(pts, FLASH, 2.0)


func _shore(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), SKY_STORM)
	_waves(w, h, 150, 0.5)
	draw_rect(Rect2(0, 190, w, h - 190), SAND)
	var flicker := 0.6 + 0.4 * absf(sin(_t * 5.0))
	draw_rect(Rect2(520, 120, 3, 3), Color(GLOW, flicker))
	_hero(Vector2i(180, 190))
	_rain(w, h)


func _door(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), SKY_STORM)
	draw_rect(Rect2(200, 40, 240, h - 40), WOOD)
	for y in range(48, h, 12):
		draw_line(Vector2(200, y), Vector2(440, y), WOOD_LIGHT)
	draw_rect(Rect2(280, 120, 80, h - 120), SILHOUETTE)
	draw_rect(Rect2(270, 60, 100, 24), WOOD_LIGHT)
	var glow := 0.7 + 0.3 * sin(_t * 4.0)
	draw_circle(Vector2(390, 100), 14.0, Color(GLOW, 0.25 * glow))
	draw_rect(Rect2(386, 94, 8, 12), Color(GLOW, glow))
	_hero(Vector2i(250, h))
	_rain(w, h)


func _bar(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), Color8(0x1c, 0x14, 0x12))
	var hob := HobPortrait.texture()
	draw_texture_rect(hob, Rect2(256, 60, 128, 128), false)
	draw_rect(Rect2(0, 180, w, h - 180), WOOD)
	draw_rect(Rect2(0, 180, w, 6), WOOD_LIGHT)
	for x in [120, 520]:
		var f := 0.7 + 0.3 * sin(_t * 6.0 + x)
		draw_rect(Rect2(x, 160, 4, 20), Color8(0xd8, 0xc8, 0xa0))
		draw_rect(Rect2(x, 154, 4, 6), Color(GLOW, f))
	_hero(Vector2i(90, h))


func _eyes_fading(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), Color8(0x0a, 0x12, 0x14))
	var a := clampf(1.0 - _t / 4.0, 0.0, 1.0)
	for x in [270, 350]:
		draw_rect(Rect2(x, 110, 20, 10), Color(EYE_GREEN, a))
	for i in 6:
		draw_rect(Rect2(150 + i * 60, 200 + (i % 2) * 6, 10, 10), Color8(0xe8, 0xe0, 0xd0))


func _collapse(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), Color8(0x1c, 0x14, 0x12))
	for i in 8:
		var y := fmod(_t * (60.0 + i * 13.0) + i * 40.0, float(h))
		draw_rect(Rect2(40 + i * 75, int(y), 30, 6), WOOD_LIGHT)
	var water := mini(h, 120 + int(_t * 20.0))
	draw_rect(Rect2(0, h - water, w, water), SEA)
	_waves(w, h, h - water, 0.8)


func _dawn(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, h), SKY_DAWN)
	draw_circle(Vector2(320, 170), 40.0, SUN)
	_waves(w, h, 170, 0.3)
	draw_rect(Rect2(0, 190, 260, 8), WOOD)
	for x in range(10, 260, 50):
		draw_rect(Rect2(x, 190, 6, 40), WOOD)
	var bob := int(sin(_t * 2.0) * 2.0)
	_boat(Vector2i(300, 196 + bob))


func _eye_below(w: int, h: int) -> void:
	draw_rect(Rect2(0, 0, w, 60), SKY_DAWN)
	draw_rect(Rect2(0, 60, w, h - 60), SEA)
	var bob := int(sin(_t * 2.0) * 2.0)
	_boat(Vector2i(300, 60 + bob))
	var open := clampf(_t / 5.0, 0.0, 1.0)
	var ry := maxf(1.0, 30.0 * open)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(320 + cos(a) * 90.0, 190 + sin(a) * ry))
	draw_polygon(pts, PackedColorArray([Color8(0x7a, 0x90, 0x40)]))
	draw_rect(Rect2(316, 190 - int(ry * 0.8), 8, int(ry * 1.6) + 1), SILHOUETTE)


# --- Детали --------------------------------------------------------------------

func _waves(w: int, h: int, top: int, strength: float) -> void:
	draw_rect(Rect2(0, top, w, h - top), SEA)
	for row in 4:
		var y := top + row * 14
		for x in range(0, w, 8):
			var dy := int(sin(x * 0.05 + _t * 2.0 + row) * 4.0 * strength)
			draw_rect(Rect2(x, y + dy, 6, 2), SEA_LIGHT)


func _rain(w: int, h: int) -> void:
	for i in 60:
		var x := fmod(i * 53.0 + _t * 120.0, float(w))
		var y := fmod(i * 37.0 + _t * 300.0, float(h))
		draw_line(Vector2(int(x), int(y)), Vector2(int(x) - 3, int(y) + 8), RAIN)


func _ship(at: Vector2i, tilt_deg: float) -> void:
	draw_set_transform(Vector2(at), deg_to_rad(tilt_deg))
	draw_polygon(PackedVector2Array([Vector2(-60, 0), Vector2(60, 0), Vector2(44, 18),
			Vector2(-44, 18)]), PackedColorArray([SILHOUETTE]))
	draw_rect(Rect2(-2, -70, 4, 70), SILHOUETTE)
	draw_polygon(PackedVector2Array([Vector2(2, -66), Vector2(40, -20), Vector2(2, -20)]),
			PackedColorArray([Color8(0x30, 0x2c, 0x2c)]))
	draw_set_transform(Vector2.ZERO)


func _boat(at: Vector2i) -> void:
	draw_polygon(PackedVector2Array([Vector2(at.x - 24, at.y - 6), Vector2(at.x + 24, at.y - 6),
			Vector2(at.x + 16, at.y + 4), Vector2(at.x - 16, at.y + 4)]),
			PackedColorArray([WOOD]))
	_hero(Vector2i(at.x, at.y - 6))


## Силуэт героя: ноги на точке at (низ фигуры).
func _hero(at: Vector2i) -> void:
	draw_rect(Rect2(at.x - 5, at.y - 30, 10, 20), SILHOUETTE)
	draw_rect(Rect2(at.x - 4, at.y - 10, 3, 10), SILHOUETTE)
	draw_rect(Rect2(at.x + 1, at.y - 10, 3, 10), SILHOUETTE)
	draw_circle(Vector2(at.x, at.y - 35), 5.0, SILHOUETTE)
