class_name TutorialCoach
extends Control
## Тренер обучающего матча (М13): панель с текстом текущего шага (слева сверху),
## «Пропустить» (справа сверху), мигающая рамка вокруг кнопки, которую ждёт шаг,
## и итог обучения. Шаги ведёт TutorialDirector; правил здесь нет.
## Пропуск и прохождение ставят Stats.FLAG_TUTORIAL_DONE.

var skip_button: Button
var play_button: Button
var rules_button: Button
var menu_button: Button

var _director: TutorialDirector
var _target_for: Callable        # func(command) -> Control (null — подсвечивать нечего)
var _panel: PanelContainer
var _caption: Label
var _text: TermLabel
var _frame: Control
var _finish: PanelContainer
var _blink := 0.0
## Кнопка, вокруг которой рамка (её место пересчитывается каждый кадр — вёрстка
## контейнеров стола успевает сложиться).
var _target: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(_panel, TutorialLayout.COACH_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var margin := TutorialLayout.margin(TutorialLayout.COACH_MARGIN)
	_panel.add_child(margin)
	var box := TableKit.vbox(2)
	margin.add_child(box)
	_caption = TableKit.label("", TableKit.TEXT_GOOD)
	box.add_child(_caption)
	_text = TermLabel.make(TableKit.TEXT, false, TutorialLayout.text_width(
			TutorialLayout.COACH_RECT.size.x, TutorialLayout.COACH_MARGIN))
	box.add_child(_text)

	skip_button = TableKit.button("TUT_SKIP")
	TableKit.place(skip_button, TutorialLayout.SKIP_RECT)
	skip_button.pressed.connect(_on_skip)
	add_child(skip_button)

	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	_frame.hide()
	add_child(_frame)

	_build_finish()
	hide()


## Подключить к режиссёру. target_for(command) — кнопка стола, которую подсветить.
func setup(director: TutorialDirector, target_for: Callable) -> void:
	_director = director
	_target_for = target_for
	_finish.hide()
	_panel.show()
	skip_button.show()
	show()
	refresh(false)


## Перерисовать по текущему шагу. popup_open — на столе открыто меню (рамку прячем).
func refresh(popup_open: bool) -> void:
	if _director == null or _finish.visible:
		return
	var step := _director.step()
	_caption.text = tr("TUT_CAPTION") % [mini(_director.index + 1, _director.step_count() - 1),
			_director.step_count() - 1]
	if _director.is_ready():
		_text.set_text_color(TableKit.TEXT)
		_text.set_term_text(step.coach_key)
	else:
		_text.set_text_color(TableKit.TEXT_MUTED)
		_text.set_term_text("TUT_WAIT")
	_target = null
	if _director.is_ready() and not popup_open and _target_for.is_valid():
		_target = _target_for.call(step.command)
	_place_frame()


func coach_text() -> String:
	return _text.source_text()


func is_highlighting() -> bool:
	return _frame.visible


func highlight_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size)


func is_finish_shown() -> bool:
	return _finish.visible


## Обучение пройдено: итог с переходами.
func show_finish() -> void:
	Stats.set_flag(Stats.FLAG_TUTORIAL_DONE)
	_panel.hide()
	_target = null
	_frame.hide()
	skip_button.hide()
	_finish.show()


func _process(delta: float) -> void:
	_place_frame()
	if not _frame.visible:
		return
	_blink += delta
	# Мигание ступенями (pixel-art): ярко / притушено.
	var on := fmod(_blink, TutorialLayout.HIGHLIGHT_BLINK * 2.0) < TutorialLayout.HIGHLIGHT_BLINK
	_frame.modulate.a = 1.0 if on else 0.35


func _place_frame() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree() 			or _finish.visible:
		_frame.hide()
		return
	var r := Rect2i(_target.get_global_rect())
	var pad := TutorialLayout.HIGHLIGHT_PAD
	var pos := r.position - Vector2i(pad, pad)
	var size := r.size + Vector2i(pad, pad) * 2
	if Vector2i(_frame.position) != pos or Vector2i(_frame.size) != size:
		_frame.position = pos
		_frame.size = size
		_frame.queue_redraw()
	_frame.show()


func _draw_frame() -> void:
	var w := TutorialLayout.HIGHLIGHT_WIDTH
	var s := _frame.size
	var c := TutorialLayout.HIGHLIGHT_COLOR
	_frame.draw_rect(Rect2(0, 0, s.x, w), c)
	_frame.draw_rect(Rect2(0, s.y - w, s.x, w), c)
	_frame.draw_rect(Rect2(0, 0, w, s.y), c)
	_frame.draw_rect(Rect2(s.x - w, 0, w, s.y), c)


func _build_finish() -> void:
	_finish = TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(_finish, TutorialLayout.FINISH_RECT)
	_finish.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_finish)
	var margin := TutorialLayout.margin(TutorialLayout.FINISH_MARGIN)
	_finish.add_child(margin)
	var box := TableKit.vbox(6)
	margin.add_child(box)
	box.add_child(TableKit.title("TUT_DONE_TITLE", true))
	var text := TermLabel.make(TableKit.TEXT, false, TutorialLayout.text_width(
			TutorialLayout.FINISH_RECT.size.x, TutorialLayout.FINISH_MARGIN))
	text.set_term_text("TUT_DONE")
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text)
	var row := TableKit.hbox(4)
	box.add_child(row)
	play_button = _finish_button(row, "TUT_DONE_PLAY", ScreenNav.OPPONENTS, Sprites.ButtonKind.BID)
	rules_button = _finish_button(row, "MENU_RULES", ScreenNav.RULES)
	menu_button = _finish_button(row, "TABLE_MENU", ScreenNav.MAIN_MENU)
	_finish.hide()


func _finish_button(row: HBoxContainer, key: String, path: String,
		kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := TableKit.button(key, kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(ScreenNav.go.bind(path))
	row.add_child(b)
	return b


func _on_skip() -> void:
	Stats.set_flag(Stats.FLAG_TUTORIAL_DONE)
	ScreenNav.go(ScreenNav.MAIN_MENU)
