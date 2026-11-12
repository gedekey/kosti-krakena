class_name TableClicks
extends Control
## Клики по столу (М22, DESIGN.md §6, референс — Hearthstone). Чистая косметика, только у себя:
## в матч и в сеть ничего не идёт.
##
## Слой во весь экран сразу над фоном. Кнопки, чашка, портреты и подсказки к терминам лежат
## выше и забирают свои клики сами; сюда доходят только клики мимо них. Клик по пустому
## месту стола (TableLayout.CLICK_AREA, кроме панелей и мест соперников) — всплеск (TableSplash)
## со стуком; в Безумии — тушь и щупальца. Предметы (TableProp) — из набора TablePropSet.

signal splashed(at: Vector2i, mad: bool)

var _rng: RandomNumberGenerator
var _is_mad: Callable
var _blocked: Array[Rect2i] = []
var _props: Array[TableProp] = []
var _prop_layer: Control
var _splash_layer: Node2D
var _since_splash := INF


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_prop_layer = Control.new()
	_prop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prop_layer)
	_splash_layer = Node2D.new()
	add_child(_splash_layer)


## is_mad() → bool: свой игрок в Безумии. rng — для разброса частиц и выбора реакций.
func setup(is_mad: Callable, rng: RandomNumberGenerator = null) -> void:
	_is_mad = is_mad
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


## Расставить предметы набора (прежние убираются). null — без предметов.
func set_props(prop_set: TablePropSet) -> void:
	for p in _props:
		_prop_layer.remove_child(p)
		p.queue_free()
	_props.clear()
	if prop_set == null:
		return
	for slot in prop_set.props:
		if slot == null or not PropArt.has_kind(slot.kind):
			push_warning("Table prop skipped: %s" % (slot.kind if slot != null else &"null"))
			continue
		var prop := TableProp.make(slot, _rng)
		_prop_layer.add_child(prop)
		_props.append(prop)


func props() -> Array[TableProp]:
	return _props


func prop(kind: StringName) -> TableProp:
	for p in _props:
		if p.kind == kind:
			return p
	return null


## Где клик не даёт всплеска сверх панелей середины стола (места соперников).
func set_blocked_rects(rects: Array[Rect2i]) -> void:
	_blocked = rects.duplicate()


func can_splash_at(at: Vector2) -> bool:
	if not Rect2(TableLayout.CLICK_AREA).has_point(at):
		return false
	for r in TableLayout.CLICK_BLOCKED + _blocked:
		if Rect2(r).has_point(at):
			return false
	return true


func splash_count() -> int:
	var n := 0
	for s in _splash_layer.get_children():
		if not s.is_queued_for_deletion():
			n += 1
	return n


func splashes() -> Array[TableSplash]:
	var out: Array[TableSplash] = []
	for s in _splash_layer.get_children():
		if not s.is_queued_for_deletion():
			out.append(s as TableSplash)
	return out


## Всплеск в точке (экранные пиксели); null — мимо стола или слишком часто.
func splash_at(at: Vector2) -> TableSplash:
	if not can_splash_at(at) or _since_splash < TableClickBalance.SPLASH_MIN_INTERVAL:
		return null
	_since_splash = 0.0
	var live := splashes()
	if live.size() >= TableClickBalance.SPLASH_MAX:
		live[0].queue_free()
	var mad: bool = _is_mad.call() if _is_mad.is_valid() else false
	var s := TableSplash.make(Vector2i(at.floor()), mad, _rng)
	_splash_layer.add_child(s)
	Sound.play(SoundCatalog.INK_SPLAT if mad else SoundCatalog.TABLE_KNOCK)
	splashed.emit(Vector2i(at.floor()), mad)
	return s


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		accept_event()
		splash_at(get_global_transform() * mb.position)


func _process(delta: float) -> void:
	_since_splash += delta
