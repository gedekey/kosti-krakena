extends MenuScreen
## Главное меню (М11, DESIGN.md §6): «Играть» → выбор соперников, обучение, правила,
## статистика, достижения (М17), настройки, выход (только на ПК).
## М19: «Сетевая игра» → создать игру / присоединиться (локальная сеть).
## М13: при первом запуске предлагается обучающий матч (один раз; Stats-флаги).
## М20: в правом нижнем углу — одиночный ранг.

var play_button: Button
var net_button: Button
var tutorial_button: Button
var rules_button: Button
var stats_button: Button
var achievements_button: Button
var settings_button: Button
var quit_button: Button
## Предложение обучения при первом запуске.
var offer: ChoicePanel
var rank_badge: RankBadge


func _ready() -> void:
	_build_backdrop("")
	add_child(EyePlaqueEmblem.new().setup(MenuLayout.MAIN_EMBLEM_RECT))
	var title := TableKit.title("GAME_TITLE", true)
	TableKit.place(title, MenuLayout.MAIN_TITLE_RECT)
	add_child(title)
	var subtitle := TableKit.label("MENU_SUBTITLE", TableKit.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER)
	TableKit.place(subtitle, MenuLayout.MAIN_SUBTITLE_RECT)
	add_child(subtitle)
	var author := TableKit.label("MENU_AUTHOR", TableKit.TEXT_MUTED)
	TableKit.place(author, MenuLayout.MAIN_AUTHOR_RECT)
	add_child(author)
	rank_badge = RankBadge.new().setup("RANK_SINGLE")
	rank_badge.position = MenuLayout.MAIN_RANK_POS
	rank_badge.show_mode(RankTracker.Mode.SINGLE)
	add_child(rank_badge)

	var box := TableKit.vbox(MenuLayout.MAIN_BUTTON_GAP)
	TableKit.place(box, MenuLayout.MAIN_BUTTONS_RECT)
	add_child(box)
	play_button = _menu_button(box, "MENU_PLAY", ScreenNav.go.bind(ScreenNav.OPPONENTS),
			Sprites.ButtonKind.BID)
	net_button = _menu_button(box, "MENU_NETWORK", ScreenNav.go.bind(ScreenNav.NET_MENU))
	tutorial_button = _menu_button(box, "MENU_TUTORIAL", start_tutorial)
	rules_button = _menu_button(box, "MENU_RULES", ScreenNav.go.bind(ScreenNav.RULES))
	stats_button = _menu_button(box, "MENU_STATS", ScreenNav.go.bind(ScreenNav.STATS))
	achievements_button = _menu_button(box, "MENU_ACHIEVEMENTS",
			ScreenNav.go.bind(ScreenNav.ACHIEVEMENTS))
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


## Системная «Назад» (Android): закрывает предложение обучения, иначе — выход из игры
## (в project.godot quit_on_go_back = false, чтобы «Назад» на других экранах не закрывал игру).
func go_back_system() -> void:
	if offer.visible:
		offer.cancel()
	else:
		ScreenNav.quit()
