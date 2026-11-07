class_name PauseMenu
extends Control
## Меню паузы стола (М17): Esc во время матча. Затемнение во весь экран и панель
## «Продолжить игру», «Сдаться», «Выйти в меню». Пауза дерева — забота стола;
## само меню работает и на паузе (PROCESS_MODE_ALWAYS). Esc в открытом меню — «Продолжить».

signal resume_pressed
signal surrender_pressed
signal quit_pressed

var resume_button: Button
var surrender_button: Button
var quit_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = TableLayout.PAUSE_DIM
	dim.size = TableLayout.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(panel, TableLayout.PAUSE_RECT)
	add_child(panel)
	var margin := TutorialLayout.margin(TableLayout.PAUSE_MARGIN)
	panel.add_child(margin)
	var box := TableKit.vbox(TableLayout.PAUSE_GAP)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	box.add_child(TableKit.title("PAUSE_TITLE", true))
	resume_button = _button(box, "PAUSE_RESUME", resume_pressed, Sprites.ButtonKind.BID)
	surrender_button = _button(box, "PAUSE_SURRENDER", surrender_pressed, Sprites.ButtonKind.LIAR)
	quit_button = _button(box, "PAUSE_QUIT", quit_pressed)
	hide()


## can_surrender — игрок ещё в матче (не выбыл, матч не кончился, не обучение).
func open(can_surrender: bool) -> void:
	surrender_button.visible = can_surrender
	show()


func _button(box: VBoxContainer, key: String, emitted: Signal,
		kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := TableKit.button(key, kind)
	b.pressed.connect(func() -> void: emitted.emit())
	box.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
