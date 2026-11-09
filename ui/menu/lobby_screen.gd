extends MenuScreen
## Лобби сетевой игры (М19, DESIGN.md §8б). Сессию передаёт экран «Сетевая игра»
## (NetGame.session): HostSession — создал игру, ClientSession — подключился.
##
## Хост: места 2–6 (гости садятся сами, на остальных — боты: персонаж или «случайный»),
## таймер хода вкл/выкл, свои IP-адреса и подсказка о брандмауэре, «Начать матч».
## Пока лобби открыто, хост раз в секунду объявляет игру в сети (LanBeacon).
## Гость видит то же без права менять и ждёт начала. Правила (Палифико, «Точно!») —
## из настроек хоста. «Выйти» — назад к экрану «Сетевая игра».

var host: HostSession
var client: ClientSession
var cards: Array[LobbySeatCard] = []
var count_stepper: ValueStepper
var timer_button: Button
var start_button: Button
var leave_button: Button

var _rules: TermLabel
var _waiting: Label
var _addresses: Label
var _firewall: Label
var _beacon: LanBeacon
## Сессия ушла на стол — при выходе со сцены её не закрывать.
var _handed_off := false


func _ready() -> void:
	var session := NetGame.take_session()
	host = session as HostSession
	client = session as ClientSession
	_build_backdrop("NET_LOBBY_TITLE")
	for i in MatchController.MAX_PLAYERS:
		var card := LobbySeatCard.new().setup()
		card.stepped.connect(_on_card_stepped.bind(i))
		add_child(card)
		cards.append(card)

	var box := _form_panel(MenuLayout.LOBBY_INFO_RECT, MenuLayout.LOBBY_INFO_GAP)
	var row := TableKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	count_stepper = ValueStepper.new()
	row.add_child(count_stepper)
	count_stepper.setup("NET_SEATS", 0, 24)
	count_stepper.stepped.connect(_on_count_stepped)
	timer_button = TableKit.button("")
	timer_button.pressed.connect(_toggle_timer)
	row.add_child(timer_button)
	_rules = TermLabel.make(TableKit.TEXT_MUTED, true, MenuLayout.LOBBY_INFO_RECT.size.x - 32)
	box.add_child(_rules)
	_waiting = TableKit.label("NET_WAITING_HOST", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_waiting)
	_addresses = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_addresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_addresses)
	_firewall = TableKit.label("NET_FIREWALL_HINT", TableKit.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER)
	_firewall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_firewall)

	leave_button = _placed_button("NET_LEAVE", MenuLayout.BACK_RECT, go_back)
	start_button = _placed_button("NET_START", MenuLayout.PRIMARY_RECT, start_match,
			Sprites.ButtonKind.BID)

	if host != null:
		host.lobby_changed.connect(refresh)
		host.set_lobby_rules(_host_options(), Settings.get_value(&"net_timer"))
		Settings.changed.connect(_on_setting_changed)
		_beacon = LanBeacon.new()
		_beacon.start()
	elif client != null:
		client.lobby_changed.connect(refresh)
		client.match_began.connect(_on_match_began)
		client.match_aborted.connect(_on_aborted)
		client.rejected.connect(_on_rejected)
	Events.locale_changed.connect(_on_locale_changed)
	refresh()


func is_host() -> bool:
	return host != null


func _process(_delta: float) -> void:
	if host != null:
		host.update()
		if _beacon != null:
			_beacon.set_info(host.host_seat.player_name, host.lobby.humans(),
					host.lobby.seat_count())
			_beacon.update()
	elif client != null and not _handed_off:
		client.update()


func _exit_tree() -> void:
	if _beacon != null:
		_beacon.stop()
	if not _handed_off:
		_close_session()


func _close_session() -> void:
	if host != null:
		host.leave()
	elif client != null:
		client.leave()


# --- Отображение -----------------------------------------------------------------

## Места: у хоста — из лобби, у гостя — что прислал хост.
func seats() -> Array[SeatInfo]:
	if host != null:
		return host.lobby.seats
	if client != null:
		return client.lobby_seats
	return [] as Array[SeatInfo]


func own_seat() -> int:
	if host != null:
		return 0
	return client.lobby_you if client != null else -1


func refresh() -> void:
	var list := seats()
	var positions := _card_positions(list.size())
	for i in cards.size():
		var card := cards[i]
		card.visible = i < list.size()
		if card.visible:
			card.position = positions[i]
			card.show_seat(list[i], i == own_seat(), is_host())
	var options := _options()
	var timer := host.timer_enabled if host != null else (client != null and client.timer_enabled)
	count_stepper.visible = is_host()
	if is_host():
		count_stepper.set_value_text(str(host.lobby.seat_count()))
		count_stepper.set_can_step(host.lobby.seat_count() > host.lobby.min_seats(),
				host.lobby.seat_count() < host.lobby.max_seats())
	timer_button.text = tr("NET_TIMER_ON") % (NetBalance.TURN_TIME_MS / 1000) if timer \
			else tr("NET_TIMER_OFF")
	timer_button.disabled = not is_host()
	_rules.set_term_text("NET_LOBBY_RULES", [_on_off(options.palifico_enabled),
			_on_off(options.calza_enabled)])
	_waiting.visible = not is_host()
	_waiting.text = "NET_WAITING_HOST" if not list.is_empty() else "NET_CONNECTING"
	_addresses.visible = is_host()
	if is_host():
		_addresses.text = _address_text()
	# Брандмауэр спрашивает разрешение только на Windows.
	_firewall.visible = is_host() and OS.get_name() == "Windows"
	start_button.visible = is_host()
	start_button.disabled = not can_start()


static func _card_positions(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in MenuLayout.card_positions(count):
		out.append(Vector2i(p.x, MenuLayout.LOBBY_CARDS_Y))
	return out


func _address_text() -> String:
	var addresses := LanBeacon.local_ipv4()
	if addresses.is_empty():
		return tr("NET_NO_ADDRESS")
	var parts: PackedStringArray = []
	for a in addresses:
		parts.append(NetGame.address_caption(a))
	return tr("NET_YOUR_ADDRESS") % " · ".join(parts)


func address_text() -> String:
	return _addresses.text


func _options() -> RuleOptions:
	if host != null:
		return host.lobby_options
	return client.lobby_options if client != null else RuleOptions.new()


func _on_off(on: bool) -> String:
	return tr("SETTINGS_ON" if on else "SETTINGS_OFF")


func _on_locale_changed(_locale: String) -> void:
	refresh()


# --- Хост --------------------------------------------------------------------------

## Правила матча — из настроек хоста.
static func _host_options() -> RuleOptions:
	var options := RuleOptions.new()
	options.palifico_enabled = Settings.get_value(&"palifico")
	options.calza_enabled = Settings.get_value(&"calza")
	return options


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key in [&"palifico", &"calza", &"net_timer"] and host != null:
		host.set_lobby_rules(_host_options(), Settings.get_value(&"net_timer"))


func _on_count_stepped(delta: int) -> void:
	if host != null:
		host.set_seat_count(host.lobby.seat_count() + delta)


func _on_card_stepped(delta: int, index: int) -> void:
	if host != null:
		host.cycle_bot(index, delta)


func _toggle_timer() -> void:
	if host != null:
		Settings.set_value(&"net_timer", not host.timer_enabled)


func can_start() -> bool:
	return host != null and host.state == HostSession.State.LOBBY \
			and host.lobby.seat_count() >= MatchController.MIN_PLAYERS


## Хост: рассадить и за стол (стол сам начнёт матч).
func start_match() -> void:
	if not can_start() or not host.begin_lobby_match(Rng.make_rng()):
		return
	_go_table(host)


# --- Гость -------------------------------------------------------------------------

func _on_match_began() -> void:
	_go_table(client)


func _go_table(session: MatchSession) -> void:
	_handed_off = true
	MatchSetup.pending = MatchSetup.for_session(session)
	ScreenNav.go(ScreenNav.TABLE)


func _on_aborted(reason: int) -> void:
	_back_to_net_menu(tr(NetText.abort_key(reason)))


func _on_rejected(reason: int, host_version: String) -> void:
	_back_to_net_menu(NetText.reject_text(reason, host_version))


func _back_to_net_menu(notice: String) -> void:
	_close_session()
	host = null
	client = null
	NetGame.notice = notice
	ScreenNav.go(ScreenNav.NET_MENU)


## «Выйти»: хост закрывает игру (гостям — «хост вышел»), гость уходит из лобби.
func go_back() -> void:
	_close_session()
	host = null
	client = null
	ScreenNav.go(ScreenNav.NET_MENU)
