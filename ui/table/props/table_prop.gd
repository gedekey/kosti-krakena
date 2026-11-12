class_name TableProp
extends Control
## «Живой» предмет на столе (М22, DESIGN.md §6): по клику (на Android — тапу) показывает одну
## из 2–3 реакций (PropArt) со звуком. Пока реакция идёт и ещё TableClickBalance.PROP_COOLDOWN
## после неё — клики глотает молча (без спама). Только у себя: в матч и в сеть ничего не идёт.

signal reacted(kind: StringName, reaction: StringName)

var kind: StringName
## Текущая реакция; "" — покой.
var reaction: StringName = &""
var _rng: RandomNumberGenerator
var _time := 0.0
var _idle_time := 0.0
var _cooldown := 0.0
var _last: StringName = &""
## Точка опоры рисунка в локальных пикселях (середина нижнего края зоны нажатия).
var _foot := Vector2i.ZERO


static func make(slot: TablePropSlot, rng: RandomNumberGenerator) -> TableProp:
	var prop := TableProp.new()
	prop.setup(slot.kind, slot.foot, rng)
	return prop


func setup(p_kind: StringName, foot: Vector2i, rng: RandomNumberGenerator) -> void:
	assert(PropArt.has_kind(p_kind), "Unknown table prop: %s" % p_kind)
	kind = p_kind
	_rng = rng
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	var hit := PropArt.hit_size(kind)
	if TouchUI.enabled():
		hit = hit.max(TableClickBalance.PROP_TOUCH_HIT)
	size = hit
	custom_minimum_size = hit
	position = Vector2i(foot.x - hit.x / 2, foot.y - hit.y)
	_foot = Vector2i(hit.x / 2, hit.y)


## Зона нажатия в экранных пикселях.
func hit_rect() -> Rect2i:
	return Rect2i(Vector2i(position), Vector2i(size))


func is_reacting() -> bool:
	return reaction != &""


## Можно ли сейчас вызвать реакцию (не идёт и пауза прошла).
func can_react() -> bool:
	return not is_reacting() and _cooldown <= 0.0


## Клик по предмету: реакция, если можно. true — предмет откликнулся.
func poke() -> bool:
	if not can_react():
		return false
	var options := PropArt.reactions(kind)
	if options.size() > 1:
		options.erase(_last)     # подряд одна и та же — скучно
	reaction = options[_rng.randi_range(0, options.size() - 1)]
	_last = reaction
	_time = 0.0
	Sound.play(PropArt.CUES[reaction])
	if reaction == &"blow":
		Sound.play_later(SoundCatalog.CANDLE_FLARE,
				PropArt.BLOW_RELIGHT_FRAME / TableClickBalance.PROP_FPS)
	reacted.emit(kind, reaction)
	queue_redraw()
	return true


func frame() -> int:
	return int(_time * TableClickBalance.PROP_FPS)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		# Клик по предмету — его, даже на паузе реакции: всплеска под ним не будет.
		accept_event()
		poke()


func _process(delta: float) -> void:
	advance(delta)


## Продвинуть время (из _process и из тестов).
func advance(delta: float) -> void:
	var idle_before := int(_idle_time * TableClickBalance.PROP_IDLE_FPS)
	_idle_time += delta
	var redraw := int(_idle_time * TableClickBalance.PROP_IDLE_FPS) != idle_before
	if is_reacting():
		var before := frame()
		_time += delta
		if frame() >= PropArt.frame_count(kind, reaction):
			reaction = &""
			_cooldown = TableClickBalance.PROP_COOLDOWN
		redraw = redraw or frame() != before or not is_reacting()
	elif _cooldown > 0.0:
		_cooldown -= delta
	if redraw:
		queue_redraw()


func _draw() -> void:
	PropArt.draw(self, kind, reaction, frame(),
			int(_idle_time * TableClickBalance.PROP_IDLE_FPS), _foot)
