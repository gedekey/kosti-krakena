class_name MenuScreen
extends Control
## Основа экранов меню (М11): фон таверны с затемнением, заголовок, «Назад» по Esc
## и по системной кнопке «Назад» (Android). Музыка меню (М12).


func _enter_tree() -> void:
	Sound.play_music(SoundCatalog.MUSIC_MENU)


func _build_backdrop(title_key: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = Sprites.background(Sprites.Background.MENU)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = MenuLayout.BACKDROP_DIM
	dim.size = MenuLayout.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	if title_key != "":
		var title := TableKit.title(title_key, true)
		TableKit.place(title, MenuLayout.TITLE_RECT)
		add_child(title)


func _placed_button(key: String, rect: Rect2i, handler: Callable,
		kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := TableKit.button(key, kind)
	TableKit.place(b, rect)
	b.pressed.connect(handler)
	add_child(b)
	return b


## Тёмная панель с полями и вертикальным списком внутри; возвращает список.
func _form_panel(rect: Rect2i, separation: int) -> VBoxContainer:
	var panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(panel, rect)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, MenuLayout.FORM_MARGIN)
	panel.add_child(margin)
	var box := TableKit.vbox(separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	return box


## «Назад». По умолчанию — в главное меню.
func go_back() -> void:
	ScreenNav.go(ScreenNav.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
