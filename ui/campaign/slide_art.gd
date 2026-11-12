class_name SlideArt
extends Control
## Картинка слайда вступления / финала (М25, DESIGN.md §8г). Фон слайда и всё, что движется
## (корабль, обломки, молния, волны, прибой, лодка, глаз Кракена), нарисованы в pxl
## (art/campaign.px.js, CampaignArt); здесь — только расстановка и движение. Дождь, вспышка
## молнии и мерцание огоньков — простые пиксельные фигуры. Координаты целые.
## Герой — силуэт: подходит к любому портрету игрока.

const RAIN := Color(0.79, 0.65, 0.42, 0.45)        # кость, полупрозрачная
const FLASH := Color(0.91, 0.85, 0.69, 0.55)       # пергамент
const FAR_FLASH := Color(0.91, 0.85, 0.69, 0.12)
const GLOW := Color(1.0, 0.7, 0.28, 0.18)          # огонь

## Шторм: период молнии и сколько длится вспышка (с).
const LIGHTNING_PERIOD := 2.4
const LIGHTNING_FLASH := 0.14
const FAR_LIGHTNING_PERIOD := 3.7
## Качка корабля / лодки: амплитуда (px) и скорость.
const SHIP_BOB := 3.0
const BOAT_BOB := 2.0
## Финал 1: Глубоководный оседает (px/с, предел) и гаснет за FADE_TIME с.
const SINK_SPEED := 10.0
const SINK_MAX := 70
const FADE_TIME := 5.0
## Финал 2: вода поднимается (px/с) от WATER_START до WATER_MAX.
const WATER_START := 24
const WATER_SPEED := 16.0
const WATER_MAX := 150
## Финал 4: глаз начинает открываться через EYE_DELAY с.
const EYE_DELAY := 1.0

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
			return &"slide_storm"
		&"intro_2":
			return &"slide_rocks"
		&"intro_3":
			return &"slide_shore"
		&"intro_4":
			return &"slide_door"
		&"intro_5":
			return &"slide_bar"
		&"finale_1":
			return &"slide_fallen"
		&"finale_2":
			return &"slide_ruin"
		&"finale_3":
			return &"slide_dawn"
		&"finale_4":
			return &"slide_deep"
	return &""


func _draw() -> void:
	var bg := background_name(slide)
	if bg == &"":
		draw_rect(Rect2(Vector2.ZERO, size), KrakenPalette.INK)
		return
	_tex(bg, Vector2i.ZERO)
	match slide:
		&"intro_1":
			_tex(&"slide_ship", Vector2i(260, 92 + _bob(SHIP_BOB, 1.6)))
			_anim(&"slide_waves", Vector2i(0, 200))
			_rain(70)
			if fmod(_t, FAR_LIGHTNING_PERIOD) < LIGHTNING_FLASH:
				draw_rect(Rect2(Vector2.ZERO, size), FAR_FLASH)
		&"intro_2":
			var flash := fmod(_t, LIGHTNING_PERIOD) < LIGHTNING_FLASH
			if fmod(_t, LIGHTNING_PERIOD) < LIGHTNING_FLASH * 2.0:
				_tex(&"slide_bolt", Vector2i(474, 0))
			_tex(&"slide_wreck", Vector2i(340, 132 + _bob(SHIP_BOB, 2.3)))
			_anim(&"slide_waves", Vector2i(0, 202))
			_rain(80)
			if flash:
				draw_rect(Rect2(Vector2.ZERO, size), FLASH)
		&"intro_3":
			_anim(&"slide_surf", Vector2i(0, 184))
			_tex(&"slide_hero", Vector2i(170, 176))
			_flicker(Vector2i(526, 78), 5.0)
			_rain(30)
		&"intro_4":
			var sway := roundi(sin(_t * 1.3))
			_flicker(Vector2i(450 + sway, 86), 4.0, 14)
			_tex(&"slide_lantern", Vector2i(443 + sway, 74))
			# Герой у самой двери, ростом чуть ниже неё (ступни на пороге).
			_tex(&"slide_hero_door", Vector2i(284, 92))
			_rain(60)
		&"intro_5":
			draw_texture_rect(HobPortrait.texture(), Rect2(256, 50, 128, 128), false)
			_tex(&"slide_counter", Vector2i(0, 154))
			for x in [120, 520]:
				_candle_flame(Vector2i(x + 1, 150))
			# Герой спиной на переднем плане, в масштабе портрета Хоба (низ обрезан краем).
			_tex(&"slide_hero_back", Vector2i(20, 104))
		&"finale_1":
			_sinking_deep_one()
		&"finale_2":
			for i in 8:
				var y := int(fmod(_t * (60.0 + i * 13.0) + i * 40.0, size.y))
				_tex(&"slide_plank", Vector2i(30 + i * 76, y - 7))
			var level := mini(WATER_MAX, WATER_START + int(_t * WATER_SPEED))
			var top := int(size.y) - level
			draw_rect(Rect2(0, top + 14, size.x, level), KrakenPalette.NIGHT)
			_anim(&"slide_waves", Vector2i(0, top))
		&"finale_3":
			var bob := _bob(BOAT_BOB, 2.0)
			_tex(&"slide_boat", Vector2i(288, 110 + bob))
			_ripples(Vector2i(320, 162 + bob))
		&"finale_4":
			_tex(&"slide_boat", Vector2i(288, 10 + _bob(BOAT_BOB, 2.0)))
			if _t >= EYE_DELAY:
				_anim(&"slide_eye", Vector2i(220, 150), false, _t - EYE_DELAY)


# --- Детали --------------------------------------------------------------------

func _tex(name: StringName, at: Vector2i) -> void:
	draw_texture(CampaignArt.texture(name), at)


func _anim(name: StringName, at: Vector2i, loop := true, t := -1.0) -> void:
	draw_texture(CampaignArt.anim_frame(name, _t if t < 0.0 else t, loop), at)


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


func _candle_flame(at: Vector2i) -> void:
	var dx := 1 if fmod(_t * 6.0, 2.0) < 1.0 else 0
	_flicker(at + Vector2i(1, 2), 6.0, 8)
	_tex(&"slide_flame", at + Vector2i(dx, 0))


## Рябь у лодки: две полоски пены расходятся в стороны.
func _ripples(at: Vector2i) -> void:
	var spread := int(fmod(_t * 6.0, 12.0))
	for side in [-1, 1]:
		draw_rect(Rect2(at.x + side * (34 + spread) - 3, at.y, 6, 1), KrakenPalette.BONE)


## Финал 1: Глубоководный (портрет в Безумии) оседает за край пола и гаснет.
func _sinking_deep_one() -> void:
	const FLOOR_Y := 170
	const SCALE := 2
	var tex := Sprites.portrait(&"deep_one", true)
	var top := 40 + mini(SINK_MAX, int(_t * SINK_SPEED))
	var visible_rows := (FLOOR_Y - top) / SCALE
	if visible_rows <= 0:
		return
	var a := clampf(1.0 - _t / FADE_TIME, 0.25, 1.0)
	draw_texture_rect_region(tex, Rect2(256, top, 64 * SCALE, visible_rows * SCALE),
			Rect2(0, 0, 64, visible_rows), Color(1, 1, 1, a))
