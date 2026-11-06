class_name ChoicePanel
extends PanelContainer
## Всплывающая панель выбора (М9): заголовок, кнопки вариантов, «Отмена».
## Для обвинения и шагов меню трюков.

signal picked(value: Variant)
signal cancelled

## Вариант: текст (или ключ), иконка, доступен ли, значение.
class Choice:
	var text: String
	var icon: Texture2D
	var enabled := true
	var value: Variant
	var tooltip := ""

	func _init(p_text: String, p_value: Variant, p_icon: Texture2D = null,
			p_enabled := true) -> void:
		text = p_text
		value = p_value
		icon = p_icon
		enabled = p_enabled


var _title: Label
var _grid: GridContainer
var _footer: Label
var _cancel: Button
var _buttons: Array[Button] = []
## Показывать «Отмена» (М13: у предложения обучения свой вариант «Не сейчас»).
var show_cancel := true


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := TableKit.vbox(4)
	add_child(box)
	_title = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)
	_footer = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_footer)
	_cancel = TableKit.button("TABLE_CANCEL")
	_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel.pressed.connect(func() -> void:
		hide()
		cancelled.emit())
	box.add_child(_cancel)
	hide()


func open(title: String, choices: Array[Choice], columns := 1, footer := "",
		width := TableLayout.POPUP_WIDTH) -> void:
	_title.text = title
	_footer.text = footer
	_footer.visible = footer != ""
	_cancel.visible = show_cancel
	_grid.columns = columns
	TableKit.clear(_grid)
	_buttons.clear()
	for c in choices:
		var b := TableKit.button(c.text)
		b.icon = c.icon
		b.disabled = not c.enabled
		b.tooltip_text = c.tooltip
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if columns == 1 else HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value: Variant = c.value
		b.pressed.connect(func() -> void: picked.emit(value))
		_grid.add_child(b)
		_buttons.append(b)
	custom_minimum_size = Vector2i(width, 0)
	size = Vector2i(width, 0)
	show()
	reset_size()
	position = Vector2i(TableLayout.POPUP_CENTER.x - int(size.x) / 2,
			TableLayout.POPUP_CENTER.y - int(size.y) / 2)


func buttons() -> Array[Button]:
	return _buttons


func cancel() -> void:
	_cancel.pressed.emit()
