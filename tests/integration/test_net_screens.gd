extends GutTest
## М19: экраны сетевой игры — пункт главного меню, «Сетевая игра» (создать игру,
## подключиться, отказы) и лобби хоста и гостя. Связь — LoopbackTransport.

const MainMenu := preload("res://scenes/main_menu.tscn")
const NetMenu := preload("res://scenes/net_menu.tscn")
const Lobby := preload("res://scenes/lobby.tscn")


func before_each() -> void:
	ScreenNav.history.clear()
	MatchSetup.pending = null
	NetGame.session = null
	NetGame.notice = ""
	Settings.reset_keys([&"net_name", &"net_address", &"net_timer", &"player_portrait",
			&"palifico", &"calza"])


func after_each() -> void:
	MatchSetup.pending = null
	NetGame.session = null
	NetGame.notice = ""
	Settings.reset_to_defaults()


func _screen(scene: PackedScene) -> Control:
	return add_child_autofree(scene.instantiate())


## Хост в памяти (как будто на другом устройстве).
func _remote_host(version := "") -> HostSession:
	return HostSession.new(LoopbackTransport.make_host(), "Хозяин", 1, Callable(), version)


func _hub(host: HostSession) -> LoopbackTransport:
	return host._transport


## Лобби хоста на этом устройстве + подключённый к нему гость.
func _host_lobby() -> Array:
	var hub := LoopbackTransport.make_host()
	NetGame.session = HostSession.new(hub, "Хозяин", 1)
	var lobby := _screen(Lobby)
	var guest := ClientSession.new(hub.connect_guest(), "Анна", 2)
	return [lobby, guest]


func _pump_lobby(lobby: Control, guest: ClientSession, times := 4) -> void:
	for i in times:
		lobby._process(0.0)
		guest.update()


# --- Главное меню и «Сетевая игра» ---------------------------------------------------

func test_main_menu_has_network_game() -> void:
	var menu := _screen(MainMenu)
	assert_eq(menu.net_button.text, "MENU_NETWORK")
	menu.net_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.NET_MENU)


func test_net_menu_profile_is_saved() -> void:
	var screen := _screen(NetMenu)
	screen.name_edit.text = "  Капитан\t"
	screen.name_edit.text_changed.emit(screen.name_edit.text)
	assert_eq(Settings.get_value(&"net_name"), "Капитан")
	assert_eq(NetGame.player_name(), "Капитан")
	screen.portrait_right.pressed.emit()
	assert_eq(NetGame.player_portrait(), 1)
	Settings.set_value(&"net_name", "")
	assert_eq(NetGame.player_name(), tr("NET_DEFAULT_NAME"), "без имени — «Игрок»")


func test_create_game_goes_to_lobby_with_host_session() -> void:
	Settings.set_value(&"net_name", "Капитан")
	var screen := _screen(NetMenu)
	screen.create_with(LoopbackTransport.make_host())
	assert_eq(ScreenNav.last(), ScreenNav.LOBBY)
	var host := NetGame.session as HostSession
	assert_not_null(host)
	assert_eq(host.host_seat.player_name, "Капитан")
	host.leave()


func test_bad_address_is_reported() -> void:
	var screen := _screen(NetMenu)
	screen.join_address("not an ip")
	assert_eq(screen.status_text(), tr("NET_ERR_ADDRESS"))
	assert_false(screen.is_connecting())
	assert_eq(ScreenNav.history.size(), 0)


func test_join_by_address_goes_to_lobby() -> void:
	var host := _remote_host()
	var screen := _screen(NetMenu)
	screen.join_with(_hub(host).connect_guest())
	assert_true(screen.is_connecting())
	assert_eq(screen.status_text(), tr("NET_CONNECTING"))
	assert_true(screen.create_button.disabled)
	for i in 4:
		host.update()
		screen._process(0.0)
	assert_eq(ScreenNav.last(), ScreenNav.LOBBY)
	var client := NetGame.session as ClientSession
	assert_not_null(client)
	assert_eq(client.state, ClientSession.State.LOBBY)
	assert_eq(client.lobby_you, 1, "лобби пришло вместе с приветствием")
	assert_eq(host.guests()[0].player_name, tr("NET_DEFAULT_NAME"))
	client.leave()
	host.leave()


func test_version_mismatch_shows_clear_message() -> void:
	var host := _remote_host("old/1")
	var screen := _screen(NetMenu)
	screen.join_with(_hub(host).connect_guest())
	for i in 4:
		host.update()
		screen._process(0.0)
	assert_false(screen.is_connecting())
	assert_eq(screen.status_text(), tr("NET_REJECT_VERSION") % ["old/1", NetProtocol.game_version()])
	assert_false(screen.create_button.disabled)
	assert_eq(ScreenNav.history.size(), 0)
	host.leave()


func test_found_games_are_listed_and_joinable() -> void:
	var screen := _screen(NetMenu)
	var browser: LanBrowser = screen._browser
	browser.feed("192.168.1.5", LanBeacon.make_packet("Хозяин", 2, 4))
	browser.feed("192.168.1.9", LanBeacon.make_packet("Старик", 1, 3, "old/1"))
	assert_true(screen.game_buttons[0].visible)
	assert_eq(screen.game_buttons[0].text, tr("NET_GAME_ENTRY") % ["Хозяин", 2, 4, "192.168.1.5"])
	assert_false(screen.game_buttons[0].disabled)
	assert_true(screen.game_buttons[1].disabled, "другая версия — не подключиться")
	assert_false(screen.game_buttons[2].visible)


func test_back_cancels_connecting_then_returns_to_menu() -> void:
	var host := _remote_host()
	var screen := _screen(NetMenu)
	screen.join_with(_hub(host).connect_guest())
	screen.go_back()
	assert_false(screen.is_connecting())
	assert_eq(ScreenNav.history.size(), 0)
	screen.go_back()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)
	host.leave()


func test_notice_from_lobby_is_shown() -> void:
	NetGame.notice = "Хост вышел"
	var screen := _screen(NetMenu)
	assert_eq(screen.status_text(), "Хост вышел")


# --- Лобби --------------------------------------------------------------------------

func test_host_lobby_shows_seats_guests_and_addresses() -> void:
	var pair := _host_lobby()
	var lobby: Control = pair[0]
	var guest: ClientSession = pair[1]
	assert_true(lobby.is_host())
	assert_eq(lobby.cards[0].role_text(), "NET_ROLE_YOU_HOST")
	assert_eq(lobby.cards[1].name_text(), tr("NET_BOT_RANDOM"))
	assert_false(lobby.cards[4].visible, "по умолчанию 4 места")
	assert_true(lobby.start_button.visible)
	assert_false(lobby.start_button.disabled)
	assert_ne(lobby.address_text(), "")
	_pump_lobby(lobby, guest)
	assert_eq(lobby.cards[1].name_text(), "Анна")
	assert_eq(lobby.cards[1].role_text(), "NET_ROLE_PLAYER")
	assert_false(lobby.cards[1].left_arrow.visible, "у места человека нет выбора бота")
	assert_true(lobby.cards[2].left_arrow.visible)
	guest.leave()


func test_host_changes_seats_bots_and_timer() -> void:
	var pair := _host_lobby()
	var lobby: Control = pair[0]
	var guest: ClientSession = pair[1]
	_pump_lobby(lobby, guest)
	lobby.count_stepper.right_arrow.pressed.emit()
	assert_true(lobby.cards[4].visible)
	lobby.cards[2].right_arrow.pressed.emit()
	var first_bot := BotRoster.by_id(NetLobby.bot_choices()[1])
	assert_eq(lobby.cards[2].name_text(), tr(first_bot.name_key))
	lobby.timer_button.pressed.emit()
	assert_false(Settings.get_value(&"net_timer"))
	assert_eq(lobby.timer_button.text, tr("NET_TIMER_OFF"))
	Settings.set_value(&"calza", false)
	_pump_lobby(lobby, guest)
	assert_eq(guest.lobby_seats.size(), 5)
	assert_eq(guest.lobby_seats[2].bot_id, first_bot.id)
	assert_false(guest.timer_enabled)
	assert_false(guest.lobby_options.calza_enabled, "правила — из настроек хоста")
	guest.leave()


func test_host_starts_match_and_hands_session_to_table() -> void:
	var pair := _host_lobby()
	var lobby: Control = pair[0]
	var guest: ClientSession = pair[1]
	_pump_lobby(lobby, guest)
	watch_signals(guest)
	lobby.start_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	assert_true(MatchSetup.pending.session is HostSession)
	var host := MatchSetup.pending.session as HostSession
	assert_eq(host.state, HostSession.State.READY)
	guest.update()
	assert_signal_emitted(guest, "match_began")
	host.leave()


func test_guest_lobby_waits_and_goes_to_table_on_start() -> void:
	var host := _remote_host()
	var link := _hub(host).connect_guest()
	var client := ClientSession.new(link, "Анна", 2)
	for i in 3:
		host.update()
		client.update()
	NetGame.session = client
	var lobby := _screen(Lobby)
	assert_false(lobby.is_host())
	assert_false(lobby.start_button.visible)
	assert_true(lobby.timer_button.disabled)
	assert_eq(lobby.cards[1].role_text(), "NET_ROLE_YOU")
	assert_eq(lobby.cards[0].name_text(), "Хозяин")
	assert_false(lobby.cards[2].left_arrow.visible, "гость ботов не меняет")
	host.set_seat_count(3)
	host.update()
	lobby._process(0.0)
	assert_false(lobby.cards[3].visible)
	host.begin_lobby_match(Rng.make_seeded(3))
	host.update()
	lobby._process(0.0)
	assert_eq(ScreenNav.last(), ScreenNav.TABLE)
	assert_eq(MatchSetup.pending.session, client)
	host.leave()


func test_guest_returns_to_net_menu_when_host_leaves() -> void:
	var host := _remote_host()
	var client := ClientSession.new(_hub(host).connect_guest(), "Анна", 2)
	for i in 3:
		host.update()
		client.update()
	NetGame.session = client
	var lobby := _screen(Lobby)
	host.leave()
	lobby._process(0.0)
	assert_eq(ScreenNav.last(), ScreenNav.NET_MENU)
	assert_eq(NetGame.notice, tr("NET_ABORT_HOST_LEFT"))


func test_host_leaving_lobby_tells_guests() -> void:
	var pair := _host_lobby()
	var lobby: Control = pair[0]
	var guest: ClientSession = pair[1]
	_pump_lobby(lobby, guest)
	watch_signals(guest)
	lobby.leave_button.pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.NET_MENU)
	guest.update()
	assert_signal_emitted_with_parameters(guest, "match_aborted", [NetProtocol.Abort.HOST_LEFT])
