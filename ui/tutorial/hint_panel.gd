class_name HintPanel
extends Control
## Подсказка при первом использовании (М13, DESIGN.md §7): первый трюк, первое обвинение,
## наступление своего Безумия. Затемнение во весь экран, панель с иконкой, заголовком,
## текстом и «Понятно». Каждая подсказка показывается один раз — флаг в Stats ставится
## в момент показа (сохраняется в user://profile.cfg).

signal dismissed(flag: StringName)

## Флаг → [заголовок, текст, иконка]. Тексты форматируются числами баланса (_args).
const TOPICS := {
	Stats.FLAG_HINT_TRICKS: ["HINT_TRICKS_TITLE", "HINT_TRICKS_TEXT", Sprites.ICON_SANITY],
	Stats.FLAG_HINT_ACCUSE: ["HINT_ACCUSE_TITLE", "HINT_ACCUSE_TEXT", Sprites.ICON_ACCUSE],
	Stats.FLAG_HINT_MADNESS: ["HINT_MADNESS_TITLE", "HINT_MADNESS_TEXT", Sprites.ICON_MADNESS],
}

var ok_button: Button
var _flag: StringName
var _then: Callable
var _panel: PanelContainer
var _icon: TextureRect
var _title: Label
var _text: Label


static func wants(flag: StringName) -> bool:
	return TOPICS.has(flag) and not Stats.has_flag(flag)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = TutorialLayout.HINT_DIM
	dim.size = TableLayout.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(_panel, TutorialLayout.HINT_RECT)
	add_child(_panel)
	var margin := TutorialLayout.margin(TutorialLayout.HINT_MARGIN)
	_panel.add_child(margin)
	var box := TableKit.vbox(4)
	margin.add_child(box)
	var head := TableKit.hbox(6)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(head)
	_icon = TableKit.icon_rect(Sprites.texture(Sprites.ICON_SANITY))
	head.add_child(_icon)
	_title = TableKit.title("")
	head.add_child(_title)
	_text = TableKit.label("", TableKit.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = TutorialLayout.text_width(TutorialLayout.HINT_RECT.size.x,
			TutorialLayout.HINT_MARGIN)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_text)
	ok_button = TableKit.button("HINT_OK", Sprites.ButtonKind.BID)
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_button.pressed.connect(_on_ok)
	box.add_child(ok_button)
	hide()


## Показать подсказку flag; then вызовется после «Понятно».
func open(flag: StringName, then: Callable = Callable()) -> void:
	var topic: Array = TOPICS[flag]
	_flag = flag
	_then = then
	_title.text = topic[0]
	_text.text = tr(topic[1]) % _args(flag)
	_icon.texture = Sprites.texture(topic[2])
	Stats.set_flag(flag)
	show()


func current_flag() -> StringName:
	return _flag if visible else &""


func _on_ok() -> void:
	hide()
	var then := _then
	_then = Callable()
	dismissed.emit(_flag)
	if then.is_valid():
		then.call()


func _args(flag: StringName) -> Array:
	match flag:
		Stats.FLAG_HINT_TRICKS:
			return [CheatBalance.START_SANITY, CheatBalance.CAUGHT_DICE_PENALTY]
		Stats.FLAG_HINT_ACCUSE:
			return [CheatBalance.CAUGHT_DICE_PENALTY, CheatBalance.FALSE_ACCUSATION_PENALTY]
		Stats.FLAG_HINT_MADNESS:
			return [roundi(MadnessBalance.HALLUCINATION_CHANCE * 100.0)]
	return []


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_on_ok()
