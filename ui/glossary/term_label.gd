class_name TermLabel
extends RichTextLabel
## Текст с подсвеченными игровыми терминами (М13, доп.): термины из словаря Glossary
## выделены цветом и подчёркнуты; правая кнопка мыши по термину (на сенсорном экране —
## тап) открывает подсказку TermTips. Наведение подсказку не открывает. Текст задаётся через set_term_text(ключ или готовый текст, числа).
## Простой текст без разметки — plain_text().

## Термин, который не подсвечивать (в собственной подсказке термина).
var exclude_term: StringName = &""
var _source := ""
var _args: Array = []
var _color := TableKit.TEXT
var _center := false
## Термин под курсором (по сигналам наведения RichTextLabel) — его откроет ПКМ.
var _hovered: StringName = &""


## color — цвет обычного текста; center — по центру; width > 0 — перенос по словам
## в этой ширине, иначе одна строка по ширине текста.
static func make(color := TableKit.TEXT, center := false, width := 0) -> TermLabel:
	var l := TermLabel.new()
	l.setup(color, center, width)
	return l


func setup(color := TableKit.TEXT, center := false, width := 0) -> TermLabel:
	_color = color
	_center = center
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	selection_enabled = false
	context_menu_enabled = false
	shortcut_keys_enabled = false
	meta_underlined = true
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	if width > 0:
		set_wrap_width(width)
	else:
		autowrap_mode = TextServer.AUTOWRAP_OFF
	add_theme_color_override("default_color", color)
	add_theme_color_override("font_shadow_color", TableKit.TEXT_SHADOW)
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	if not meta_hover_started.is_connected(_on_meta_hover_started):
		meta_hover_started.connect(_on_meta_hover_started)
		meta_hover_ended.connect(_on_meta_hover_ended)
		meta_clicked.connect(_on_meta_clicked)
		gui_input.connect(_on_gui_input)
	return self


## Перенос по словам в ширине width. Ширина ставится сразу и в size: высота по
## содержимому (fit_content) считается от текущей ширины, а не от минимальной.
func set_wrap_width(width: int) -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_minimum_size.x = width
	size.x = width


## source — ключ локализации или готовый текст; args — числа/строки для подстановки.
func set_term_text(source: String, args: Array = []) -> void:
	_source = source
	_args = args
	_render()


func source_text() -> String:
	return _source


func set_text_color(color: Color) -> void:
	_color = color
	add_theme_color_override("default_color", color)
	_render()


func plain_text() -> String:
	return get_parsed_text()


## Id терминов, подсвеченных сейчас (по порядку).
func terms() -> Array[StringName]:
	var result: Array[StringName] = []
	for m in TermTips.glossary.find_terms(_plain(), exclude_term):
		result.append(m.id)
	return result


func _plain() -> String:
	var text := tr(_source)
	return text % _args if not _args.is_empty() else text


func _render() -> void:
	var body := TermTips.glossary.markup(_plain(), TableKit.TEXT_TERM, exclude_term)
	text = "[center]%s[/center]" % body if _center else body


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _source != "":
		_render()


func hovered_term() -> StringName:
	return _hovered


func _on_meta_hover_started(meta: Variant) -> void:
	_hovered = StringName(str(meta))


func _on_meta_hover_ended(_meta: Variant) -> void:
	_hovered = &""


## ПКМ по термину под курсором.
func _on_gui_input(event: InputEvent) -> void:
	if _hovered == &"" or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == TermTips.OPEN_BUTTON and mb.pressed:
		accept_event()
		TermTips.toggle_term(self, _hovered)


## Тап по термину на сенсорном экране (ЛКМ на ПК подсказку не открывает).
func _on_meta_clicked(meta: Variant) -> void:
	if TermTips.touch_mode:
		TermTips.toggle_term(self, StringName(str(meta)))
