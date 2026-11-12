class_name TableSplash
extends Node2D
## Всплеск в точке клика по пустому столу (М22, DESIGN.md §6): пыль и щепки; в Безумии —
## лужица туши, брызги и мелкие щупальца. Покадрово (TableClickBalance.SPLASH_FPS), целые
## пиксели, частицы задаются при создании (RNG снаружи), потом удаляет себя.

signal finished

const B := preload("res://ui/table/props/table_click_balance.gd")
const P := preload("res://ui/sprites/kraken_palette.gd")

var mad := false
var _time := 0.0
## Частица: v — скорость, c — цвет, s — размер, life — кадров, fall — падает ли, floor — где
## лежит (px ниже точки клика).
var _parts: Array[Dictionary] = []
## Щупальце: x — смещение от центра, h — наибольшая высота, phase.
var _tentacles: Array[Dictionary] = []


static func make(at: Vector2i, p_mad: bool, rng: RandomNumberGenerator) -> TableSplash:
	var s := TableSplash.new()
	s.mad = p_mad
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if p_mad:
		s._make_ink(rng)
	else:
		s._make_dust(rng)
	return s


func frames() -> int:
	return B.MAD_SPLASH_FRAMES if mad else B.SPLASH_FRAMES


func frame() -> int:
	return int(_time * B.SPLASH_FPS)


func is_finished() -> bool:
	return frame() >= frames()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var before := frame()
	_time += delta
	if is_finished():
		set_process(false)
		finished.emit()
		queue_free()
		return
	if frame() != before:
		queue_redraw()


# --- Частицы ------------------------------------------------------------------------------

func _make_dust(rng: RandomNumberGenerator) -> void:
	var colors := [P.BONE, P.PARCHMENT, P.SLATE]
	for i in rng.randi_range(B.DUST_COUNT.x, B.DUST_COUNT.y):
		var a := rng.randf_range(-PI, 0.0)
		_parts.append({"v": Vector2.from_angle(a) * rng.randf_range(B.DUST_SPEED.x, B.DUST_SPEED.y)
				+ Vector2(0, -8), "c": colors[rng.randi_range(0, colors.size() - 1)],
				"s": Vector2i.ONE, "life": rng.randi_range(5, B.SPLASH_FRAMES), "fall": false,
				"floor": 0})
	var wood := [P.WOOD, P.DARK_WOOD, P.BONE]
	for i in rng.randi_range(B.SPLINTER_COUNT.x, B.SPLINTER_COUNT.y):
		var a := rng.randf_range(-PI * 0.85, -PI * 0.15)
		_parts.append({"v": Vector2.from_angle(a) * rng.randf_range(B.SPLINTER_SPEED.x,
				B.SPLINTER_SPEED.y), "c": wood[rng.randi_range(0, wood.size() - 1)],
				"s": Vector2i(2, 1) if rng.randf() < 0.5 else Vector2i(1, 2),
				"life": B.SPLASH_FRAMES, "fall": true, "floor": rng.randi_range(1, 3)})


func _make_ink(rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(B.INK_COUNT.x, B.INK_COUNT.y):
		var a := rng.randf_range(-PI * 0.9, -PI * 0.1)
		_parts.append({"v": Vector2.from_angle(a) * rng.randf_range(B.INK_SPEED.x, B.INK_SPEED.y),
				"c": P.INK, "s": Vector2i(2, 2) if rng.randf() < 0.6 else Vector2i.ONE,
				"life": rng.randi_range(8, B.MAD_SPLASH_FRAMES), "fall": true,
				"floor": rng.randi_range(0, 3)})
	var count := rng.randi_range(B.MAD_TENTACLES.x, B.MAD_TENTACLES.y)
	for i in count:
		_tentacles.append({"x": -3 + i * 6 / maxi(count - 1, 1) + rng.randi_range(-1, 1),
				"h": rng.randi_range(B.MAD_TENTACLE_HEIGHT.x, B.MAD_TENTACLE_HEIGHT.y),
				"phase": rng.randf_range(0.0, TAU)})


func _part_pos(p: Dictionary, f: int) -> Vector2i:
	var t := f / B.SPLASH_FPS
	var at: Vector2 = p.v * t
	if p.fall:
		at.y += 0.5 * B.GRAVITY * t * t
		at.y = minf(at.y, p.floor)
	return Vector2i(at.round())


# --- Рисунок ------------------------------------------------------------------------------

func _draw() -> void:
	var f := frame()
	if mad:
		_draw_puddle(f)
		for t in _tentacles:
			PropArt.draw_tentacle(self, Vector2i(t.x, 0), _tentacle_height(t.h, f),
					t.phase + f * 0.9, 1.0, 2)
	elif f < 2:
		_draw_impact(f)
	for p in _parts:
		if f >= p.life:
			continue
		var at := _part_pos(p, f)
		PropArt.px(self, at, p.c, p.s)
		if mad and p.s.x > 1:
			PropArt.px(self, at, P.VIOLET)   # блик, иначе тушь не видна на тёмном дереве


## Удар: крестик, потом точки пошире.
func _draw_impact(f: int) -> void:
	var r := 1 + f * 2
	for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, -r), Vector2i(0, r)]:
		PropArt.px(self, d, P.PARCHMENT if f == 0 else P.BONE)
	if f == 0:
		PropArt.px(self, Vector2i.ZERO, P.PARCHMENT)


## Лужица туши: растёт, держится, сохнет к концу.
func _draw_puddle(f: int) -> void:
	var left := frames() - f
	var w := mini(3 + f * 2, 9) if left > 4 else maxi(left * 2 - 1, 1)
	PropArt.px(self, Vector2i(-w / 2, 0), P.INK, Vector2i(w, 1))
	if w > 3:
		PropArt.px(self, Vector2i(-w / 2 + 1, -1), P.INK, Vector2i(w - 2, 1))
		PropArt.px(self, Vector2i(-w / 2 + 1, 1), P.INK, Vector2i(w - 2, 1))
		PropArt.px(self, Vector2i(-w / 2, 0), P.VIOLET)
		PropArt.px(self, Vector2i(-w / 2 + w - 1, 0), P.VIOLET)


## Щупальце из лужи: вырастает, извивается, уходит обратно.
func _tentacle_height(h: int, f: int) -> int:
	var up := mini(f + 1, 5)
	var down := maxi(frames() - 1 - f, 0)
	return mini(h * up / 5, h * down / 5 + 1) if down < 5 else h * up / 5
