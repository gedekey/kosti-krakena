class_name TypedLabel
extends Label
## Текст, который печатается по буквам (сцены с Хобом, слайды — М23).
## Скорость — CampaignBalance.TYPE_CHARS_PER_SEC; finish() — сразу весь текст.

signal finished_typing

var _shown := 0.0


static func make(color := TableKit.TEXT, width := 0) -> TypedLabel:
	var l := TypedLabel.new()
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0:
		l.custom_minimum_size.x = width
	return l


## Начать печатать text (ключ локализации или готовая строка).
func type_text(value: String) -> void:
	text = value
	_shown = 0.0
	visible_characters = 0
	set_process(true)


func is_done() -> bool:
	return visible_characters < 0 or visible_characters >= get_total_character_count()


func finish() -> void:
	visible_characters = -1
	set_process(false)
	finished_typing.emit()


func _process(delta: float) -> void:
	_shown += delta * CampaignBalance.TYPE_CHARS_PER_SEC
	visible_characters = int(_shown)
	if visible_characters >= get_total_character_count():
		finish()
