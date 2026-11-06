extends MenuScreen
## Главное меню (М11, DESIGN.md §6): «Играть» → выбор соперников, статистика, настройки,
## выход (только на ПК). «Правила» и «Обучение» добавит М13.

var play_button: Button
var stats_button: Button
var settings_button: Button
var quit_button: Button


func _ready() -> void:
	_build_backdrop("")
	var title := TableKit.title("GAME_TITLE", true)
	TableKit.place(title, MenuLayout.MAIN_TITLE_RECT)
	add_child(title)
	var subtitle := TableKit.label("MENU_SUBTITLE", TableKit.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER)
	TableKit.place(subtitle, MenuLayout.MAIN_SUBTITLE_RECT)
	add_child(subtitle)

	var box := TableKit.vbox(MenuLayout.MAIN_BUTTON_GAP)
	TableKit.place(box, MenuLayout.MAIN_BUTTONS_RECT)
	add_child(box)
	play_button = _menu_button(box, "MENU_PLAY", ScreenNav.go.bind(ScreenNav.OPPONENTS),
			Sprites.ButtonKind.BID)
	stats_button = _menu_button(box, "MENU_STATS", ScreenNav.go.bind(ScreenNav.STATS))
	settings_button = _menu_button(box, "MENU_SETTINGS", ScreenNav.go.bind(ScreenNav.SETTINGS))
	quit_button = _menu_button(box, "MENU_QUIT", ScreenNav.quit)
	quit_button.visible = ScreenNav.can_quit()


func _menu_button(box: VBoxContainer, key: String, handler: Callable,
		kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := TableKit.button(key, kind)
	b.pressed.connect(handler)
	box.add_child(b)
	return b


## Из главного меню «Назад» никуда не ведёт (на Android выход — системный).
func go_back() -> void:
	pass
