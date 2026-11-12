class_name TavernMap
extends Control
## Карта таверны с 6 точками уровней (М23, DESIGN.md §8г) — ЗАГЛУШКА рисунка до М25:
## пол, стены, стойка, окно, столы, люк в подвал. Путь между точками подсвечивается
## по мере прохождения. Клик по открытой точке — point_pressed(номер уровня).
## Логики здесь нет: что открыто и пройдено — из CampaignProgress.

signal point_pressed(level: int)

const FLOOR := Color8(0x2a, 0x1e, 0x18)
const PLANK := Color8(0x34, 0x26, 0x1e)
const WALL := Color8(0x14, 0x10, 0x10)
const FURNITURE := Color8(0x4a, 0x34, 0x24)
const WINDOW := Color8(0x2a, 0x3a, 0x52)
const PATH_DIM := Color(0.5, 0.45, 0.4, 0.35)
const PATH_LIT := KrakenPalette.FIRE
const POINT_LOCKED := Color(0.4, 0.38, 0.42, 1)
const POINT_OPEN := KrakenPalette.FIRE
const POINT_DONE := KrakenPalette.LIME

## Номер уровня → кнопка точки.
var points := {}
var _levels: Array[CampaignLevel] = []
var _progress: CampaignProgress
var _selected := 0


func setup(levels: Array[CampaignLevel]) -> void:
	_levels = levels
	TableKit.place(self, CampaignLayout.MAP_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var origin := CampaignLayout.MAP_RECT.position
	for level in levels:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		# На сенсорном экране зона нажатия больше рисунка точки (М16).
		var hit := CampaignLayout.POINT_SIZE
		if TouchUI.enabled():
			hit = hit.max(TouchUI.ARROW_HIT)
		b.position = level.map_point - origin - hit / 2
		b.size = hit
		b.tooltip_text = level.name_key
		b.pressed.connect(func() -> void: point_pressed.emit(level.number))
		add_child(b)
		points[level.number] = b
		var caption := TableKit.backed_label(level.place_key, TableKit.TEXT_MUTED,
				HORIZONTAL_ALIGNMENT_CENTER)
		caption.position = level.map_point - origin + Vector2i(-50,
				CampaignLayout.POINT_SIZE.y / 2 + CampaignLayout.POINT_LABEL_GAP)
		caption.size = Vector2i(100, PixelFonts.BODY_SIZE + 1)
		caption.clip_text = true
		add_child(caption)


func show_progress(progress: CampaignProgress, selected: int) -> void:
	_progress = progress
	_selected = selected
	for n: int in points:
		var b: Button = points[n]
		b.disabled = not progress.is_unlocked(n)
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW if b.disabled \
				else Control.CURSOR_POINTING_HAND
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, FLOOR)
	for y in range(0, int(size.y), 10):
		draw_line(Vector2(0, y), Vector2(size.x, y), PLANK)
	draw_rect(r, WALL, false, 4.0)
	var o := Vector2(CampaignLayout.MAP_RECT.position)
	# Стойка (уровень 6), окно (3), длинный стол (2), задняя комната (4), люк (5), дверь (1).
	draw_rect(Rect2(Vector2(300, 90) - o, Vector2(96, 14)), FURNITURE)
	draw_rect(Rect2(Vector2(40, 96) - o, Vector2(6, 40)), WINDOW)
	draw_rect(Rect2(Vector2(170, 214) - o, Vector2(90, 10)), FURNITURE)
	draw_line(Vector2(180, 40) - o, Vector2(180, 130) - o, WALL, 3.0)
	draw_rect(Rect2(Vector2(314, 244) - o, Vector2(32, 18)), Color8(0x10, 0x0c, 0x0a))
	draw_rect(Rect2(Vector2(60, 312) - o, Vector2(70, 6)), FURNITURE)
	if _levels.is_empty():
		return
	for i in range(1, _levels.size()):
		var a := Vector2(_levels[i - 1].map_point) - o
		var b := Vector2(_levels[i].map_point) - o
		var lit := _progress != null and _progress.is_completed(_levels[i - 1].number)
		_dashed(a, b, PATH_LIT if lit else PATH_DIM)
	for level in _levels:
		var c := Vector2(level.map_point) - o
		var color := POINT_LOCKED
		if _progress != null and _progress.is_completed(level.number):
			color = POINT_DONE
		elif _progress != null and _progress.is_unlocked(level.number):
			color = POINT_OPEN
		var half := Vector2(CampaignLayout.POINT_SIZE / 2)
		if level.number == _selected:
			draw_rect(Rect2(c - half - Vector2(2, 2), half * 2 + Vector2(4, 4)), TableKit.TEXT)
		draw_rect(Rect2(c - half, half * 2), WALL)
		draw_rect(Rect2(c - half + Vector2(2, 2), half * 2 - Vector2(4, 4)), color)


func _dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 1.0)
	var t := 0.0
	while t < length:
		var p := (a + dir * t).round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), color)
		t += 7.0
