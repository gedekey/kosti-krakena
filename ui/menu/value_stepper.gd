class_name ValueStepper
extends HBoxContainer
## Строка «Подпись  ◀ значение ▶» (М11). Значение и что можно листать — решает экран.

signal stepped(delta: int)

var left_arrow: TextureButton
var right_arrow: TextureButton
var _caption: Label
var _value: Label


func setup(caption: String, caption_width: int, field_width: int) -> ValueStepper:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = TableKit.label(caption, TableKit.TEXT_MUTED)
	_caption.custom_minimum_size.x = caption_width
	_caption.visible = caption != "" or caption_width > 0
	add_child(_caption)
	left_arrow = _arrow(false, -1)
	var field := TableKit.panel(Sprites.PanelKind.FIELD)
	field.custom_minimum_size = Vector2i(field_width, 16)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	_value = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	field.add_child(_value)
	right_arrow = _arrow(true, 1)
	return self


func caption_label() -> Label:
	return _caption


func set_value_text(text: String) -> void:
	_value.text = text


func value_text() -> String:
	return _value.text


func set_can_step(can_left: bool, can_right: bool) -> void:
	left_arrow.disabled = not can_left
	right_arrow.disabled = not can_right


func _arrow(right: bool, delta: int) -> TextureButton:
	var b := TableKit.arrow(right)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: stepped.emit(delta))
	add_child(b)
	return b
