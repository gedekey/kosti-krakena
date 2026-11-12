class_name SlideShow
extends Control
## Слайды вступления (5) и финала (4) кампании (М23, DESIGN.md §8г). Картинка — SlideArt
## (заглушка до М25), текст печатается по буквам. Клик (или «Дальше») — допечатать /
## следующий слайд, «Пропустить» — сразу конец.

signal finished

const INTRO: Array[StringName] = [&"intro_1", &"intro_2", &"intro_3", &"intro_4", &"intro_5"]
const FINALE: Array[StringName] = [&"finale_1", &"finale_2", &"finale_3", &"finale_4"]

var next_button: Button
var skip_button: Button
var _art: SlideArt
var _text: TypedLabel
var _slides: Array[StringName] = []
var _index := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = KrakenPalette.INK
	back.size = MenuLayout.SCREEN
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_art = SlideArt.new()
	TableKit.place(_art, CampaignLayout.SLIDE_ART_RECT)
	add_child(_art)
	var panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(panel, CampaignLayout.SLIDE_TEXT_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var margin := TutorialLayout.margin(CampaignLayout.SLIDE_TEXT_MARGIN)
	panel.add_child(margin)
	_text = TypedLabel.make(TableKit.TEXT, TutorialLayout.text_width(
			CampaignLayout.SLIDE_TEXT_RECT.size.x, CampaignLayout.SLIDE_TEXT_MARGIN))
	margin.add_child(_text)
	skip_button = TableKit.button("CAMP_SKIP")
	TableKit.place(skip_button, CampaignLayout.SCENE_SKIP_RECT)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	next_button = TableKit.button("CAMP_NEXT", Sprites.ButtonKind.BID)
	TableKit.place(next_button, CampaignLayout.SCENE_NEXT_RECT)
	next_button.pressed.connect(advance)
	add_child(next_button)
	hide()


## Ключ текста слайда: CAMP_INTRO_<N> / CAMP_FINALE_<N>.
static func text_key(id: StringName) -> String:
	return "CAMP_" + String(id).to_upper()


func play(slides: Array[StringName]) -> void:
	_slides = slides
	_index = 0
	show()
	_show_slide()


func advance() -> void:
	if not visible:
		return
	if not _text.is_done():
		_text.finish()
		return
	_index += 1
	if _index >= _slides.size():
		_end()
	else:
		_show_slide()


func skip() -> void:
	if visible:
		_end()


func is_playing() -> bool:
	return visible


func current_slide() -> StringName:
	return _slides[_index] if visible and _index < _slides.size() else &""


func _show_slide() -> void:
	_art.show_slide(_slides[_index])
	_text.type_text(tr(text_key(_slides[_index])))


func _end() -> void:
	_text.finish()
	hide()
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()
