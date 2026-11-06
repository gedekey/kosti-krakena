extends MenuScreen
## Главное меню (М11, DESIGN.md §6): «Играть» → выбор соперников, обучение, правила,
## статистика, настройки, выход (только на ПК).
## М13: при первом запуске предлагается обучающий матч (один раз; Stats-флаги).

var play_button: Button
var tutorial_button: Button
var rules_button: Button
var stats_button: Button
var settings_button: Button
var quit_button: Button
## Предложение обучения при первом запуске.
var offer: ChoicePanel


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
	tutorial_button = _menu_button(box, "MENU_TUTORIAL", start_tutorial)
	rules_button = _menu_button(box, "MENU_RULES", ScreenNav.go.bind(ScreenNav.RULES))
	stats_button = _menu_button(box, "MENU_STATS", ScreenNav.go.bind(ScreenNav.STATS))
	settings_button = _menu_button(box, "MENU_SETTINGS", ScreenNav.go.bind(ScreenNav.SETTINGS))
	quit_button = _menu_button(box, "MENU_QUIT", ScreenNav.quit)
	quit_button.visible = ScreenNav.can_quit()

	offer = ChoicePanel.new()
	offer.show_cancel = false
	offer.picked.connect(_on_offer_picked)
	add_child(offer)
	if should_offer_tutorial():
		_offer_tutorial()


## Обучение ещё не пройдено и не предлагалось.
static func should_offer_tutorial() -> bool:
	return not Stats.has_flag(Stats.FLAG_TUTORIAL_DONE) 			and not Stats.has_flag(Stats.FLAG_TUTORIAL_OFFERED)


static func start_tutorial() -> void:
	MatchSetup.pending = MatchSetup.for_tutorial()
	ScreenNav.go(ScreenNav.TABLE)


func _offer_tutorial() -> void:
	Stats.set_flag(Stats.FLAG_TUTORIAL_OFFERED)
	var choices: Array[ChoicePanel.Choice] = [
		ChoicePanel.Choice.new("TUT_OFFER_YES", true),
		ChoicePanel.Choice.new("TUT_OFFER_NO", false),
	]
	offer.open(tr("TUT_OFFER_TITLE"), choices, 1, tr("TUT_OFFER_FOOTER"))


func _on_offer_picked(value: Variant) -> void:
	offer.hide()
	if value == true:
		start_tutorial()


func _menu_button(box: VBoxContainer, key: String, handler: Callable,
		kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := TableKit.button(key, kind)
	b.pressed.connect(handler)
	box.add_child(b)
	return b


## Из главного меню «Назад» никуда не ведёт (на Android выход — системный);
## открыто предложение обучения — закрывает его.
func go_back() -> void:
	if offer.visible:
		offer.cancel()
