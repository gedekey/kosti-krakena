class_name TermTooltip
extends PanelContainer
## Пиксельная панель-подсказка термина (М13, доп.): название и описание. В описании
## тоже подсвечены термины — наведение на них открывает следующую подсказку (TermTips).

var term: StringName
var _title: Label
var _text: TermLabel


func _init() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := TutorialLayout.margin(TutorialLayout.TERM_TIP_MARGIN)
	add_child(margin)
	var box := TableKit.vbox(2)
	margin.add_child(box)
	_title = TableKit.label("", TableKit.TEXT_TERM)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_title)
	_text = TermLabel.make(TableKit.TEXT, false, TutorialLayout.text_width(
			TutorialLayout.TERM_TIP_WIDTH, TutorialLayout.TERM_TIP_MARGIN))
	box.add_child(_text)


func show_term(id: StringName) -> void:
	term = id
	_title.text = TermTips.glossary.title(id)
	_text.exclude_term = id
	_text.set_term_text(TermTips.glossary.description(id))
	custom_minimum_size = Vector2i(TutorialLayout.TERM_TIP_WIDTH, 0)
	size = Vector2i(TutorialLayout.TERM_TIP_WIDTH, 0)
	reset_size()


func title_text() -> String:
	return _title.text


func description() -> TermLabel:
	return _text


## Поставить рядом с anchor: под ним, а если не влезает — над ним; не за краями экрана.
func place_near(anchor: Rect2) -> void:
	reset_size()
	var screen := Vector2(TableLayout.SCREEN)
	var pad := TutorialLayout.TERM_TIP_SCREEN_PAD
	var gap := TutorialLayout.TERM_TIP_GAP
	var y := anchor.end.y + gap
	if y + size.y > screen.y - pad:
		y = anchor.position.y - gap - size.y
	var x := anchor.position.x
	position = Vector2i(roundi(clampf(x, pad, maxf(pad, screen.x - pad - size.x))),
			roundi(clampf(y, pad, maxf(pad, screen.y - pad - size.y))))
