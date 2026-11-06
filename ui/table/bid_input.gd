class_name BidInput
extends VBoxContainer
## Ввод ставки (М9): два счётчика ◀ ▶ — количество и грань — и подсказка минимальной
## ставки. Допустимость решает PlayerView (правила не дублируются).

signal changed

var quantity := 1
var face := 2

var _view: PlayerView
var _q_left: TextureButton
var _q_right: TextureButton
var _q_label: Label
var _f_left: TextureButton
var _f_right: TextureButton
var _f_die: TextureRect
var _hint_row: HBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := TableKit.hbox(3)
	add_child(row)
	row.add_child(TableKit.label("TABLE_QUANTITY", TableKit.TEXT_MUTED))
	_q_left = _arrow(row, false, _shift_quantity.bind(-1))
	var q_field := TableKit.panel(Sprites.PanelKind.FIELD)
	q_field.custom_minimum_size = Vector2i(24, 16)
	row.add_child(q_field)
	_q_label = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	q_field.add_child(_q_label)
	_q_right = _arrow(row, true, _shift_quantity.bind(1))
	row.add_child(TableKit.label("  ", TableKit.TEXT))
	row.add_child(TableKit.label("TABLE_FACE", TableKit.TEXT_MUTED))
	_f_left = _arrow(row, false, _shift_face.bind(-1))
	_f_die = TableKit.die_rect(face)
	row.add_child(_f_die)
	_f_right = _arrow(row, true, _shift_face.bind(1))
	_hint_row = TableKit.hbox(2)
	add_child(_hint_row)
	_refresh()


## Новый ход или новая ставка на столе: подставить минимальную допустимую ставку.
func reset_to_lowest(view: PlayerView) -> void:
	_view = view
	var lowest := view.lowest_bid() if view != null else null
	if lowest != null:
		quantity = lowest.quantity
		face = lowest.face
	_refresh()


func set_view(view: PlayerView, enabled: bool) -> void:
	_view = view
	for b in [_q_left, _q_right, _f_left, _f_right]:
		b.disabled = not enabled
	_refresh()


func is_legal() -> bool:
	return _view != null and _view.is_legal(MatchAction.make_bid(quantity, face))


func action() -> MatchAction:
	return MatchAction.make_bid(quantity, face)


func shift_quantity(step: int) -> void:
	_shift_quantity(step)


func shift_face(step: int) -> void:
	_shift_face(step)


func _arrow(row: HBoxContainer, right: bool, handler: Callable) -> TextureButton:
	var b := TableKit.arrow(right)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(handler)
	row.add_child(b)
	return b


func _max_quantity() -> int:
	return maxi(1, _view.max_bid_quantity()) if _view != null else 1


func _shift_quantity(step: int) -> void:
	quantity = clampi(quantity + step, 1, _max_quantity())
	_refresh()
	changed.emit()


## Грань листается по кругу среди разрешённых; количество подтягивается до минимума.
func _shift_face(step: int) -> void:
	var faces: Array[int] = [1, 2, 3, 4, 5, 6]
	if _view != null and not _view.allowed_faces().is_empty():
		faces = _view.allowed_faces()
	var i := faces.find(face)
	if i < 0:
		i = 0 if step > 0 else faces.size() - 1
	else:
		i = wrapi(i + step, 0, faces.size())
	face = faces[i]
	if _view != null:
		var min_q := _view.min_quantity_for_face(face)
		if min_q != PerudoRules.NOT_ALLOWED and quantity < min_q:
			quantity = mini(min_q, _max_quantity())
	_refresh()
	changed.emit()


func _refresh() -> void:
	if _q_label == null:
		return
	_q_label.text = str(quantity)
	TableKit.set_die(_f_die, face)
	TableKit.clear(_hint_row)
	if _view == null:
		return
	var min_q := _view.min_quantity_for_face(face)
	if min_q == PerudoRules.NOT_ALLOWED:
		_hint_row.add_child(TableKit.label("TABLE_FACE_NOT_ALLOWED", TableKit.TEXT_ALERT))
	elif min_q > _view.max_bid_quantity():
		_hint_row.add_child(TableKit.label("TABLE_FACE_TOO_HIGH", TableKit.TEXT_ALERT))
	else:
		_hint_row.add_child(TableKit.label(tr("TABLE_MIN_BID") % min_q, TableKit.TEXT_MUTED))
		_hint_row.add_child(TableKit.die_rect(face))
