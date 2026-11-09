extends MenuScreen
## «Сетевая игра» (М19, DESIGN.md §8б): имя и портрет, «Создать игру» (хост → лобби),
## список игр в локальной сети (находятся сами) и подключение по IP.
## Подключение идёт в фоне: «Подключение…», затем лобби или причина отказа.

var name_edit: LineEdit
var address_edit: LineEdit
var create_button: Button
var join_button: Button
var portrait_left: TextureButton
var portrait_right: TextureButton
## Кнопки найденных игр (по одной на игру, до NET_GAMES_MAX).
var game_buttons: Array[Button] = []

var _portrait: TextureRect
var _games_box: VBoxContainer
var _games_hint: Label
var _status: Label
var _browser: LanBrowser
## Идёт подключение (ждём WELCOME или отказ).
var _client: ClientSession


func _ready() -> void:
	_build_backdrop("NET_TITLE")
	_build_profile()
	_build_join()
	_status = TableKit.backed_label("", TableKit.TEXT_ALERT, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TableKit.place(_status, MenuLayout.NET_STATUS_RECT)
	_status.visible = false
	add_child(_status)
	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)

	_browser = LanBrowser.new()
	_browser.changed.connect(_refresh_games)
	if not _browser.start():
		_games_hint.text = "NET_SEARCH_UNAVAILABLE"
	var notice := NetGame.take_notice()
	if notice != "":
		show_status(notice)
	_refresh_games()


func _build_profile() -> void:
	var box := _form_panel(MenuLayout.NET_LEFT_RECT, 6)
	box.add_child(TableKit.label("NET_NAME", TableKit.TEXT_MUTED))
	name_edit = _line_edit("NET_NAME_PLACEHOLDER", NetBalance.MAX_NAME_LENGTH)
	name_edit.text = SeatInfo.clean_name(String(Settings.get_value(&"net_name")))
	name_edit.text_changed.connect(_on_name_changed)
	box.add_child(name_edit)

	box.add_child(TableKit.label("SETUP_PORTRAIT", TableKit.TEXT_MUTED))
	var row := TableKit.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	portrait_left = _portrait_arrow(row, false)
	var frame := Panel.new()
	frame.custom_minimum_size = TableLayout.FRAME_SIZE
	frame.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.FRAME))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	_portrait = TableKit.add_portrait(frame, Sprites.portrait(Sprites.PLAYER_PORTRAITS[0]))
	portrait_right = _portrait_arrow(row, true)

	create_button = TableKit.button("NET_CREATE", Sprites.ButtonKind.BID)
	create_button.pressed.connect(create_game)
	box.add_child(create_button)
	var hint := TableKit.label("NET_CREATE_HINT", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_refresh_portrait()


func _build_join() -> void:
	var box := _form_panel(MenuLayout.NET_RIGHT_RECT, 4)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(TableKit.title("NET_JOIN"))
	box.add_child(TableKit.label("NET_GAMES", TableKit.TEXT_MUTED))
	_games_box = TableKit.vbox(3)
	box.add_child(_games_box)
	_games_hint = TableKit.label("NET_SEARCHING", TableKit.TEXT_MUTED)
	_games_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_games_hint.custom_minimum_size.x = MenuLayout.NET_GAME_BUTTON_WIDTH
	box.add_child(_games_hint)
	for i in MenuLayout.NET_GAMES_MAX:
		var b := TableKit.button("")
		b.custom_minimum_size.x = MenuLayout.NET_GAME_BUTTON_WIDTH
		b.clip_text = true
		b.pressed.connect(_on_game_pressed.bind(i))
		b.hide()
		_games_box.add_child(b)
		game_buttons.append(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	box.add_child(TableKit.label("NET_ADDRESS", TableKit.TEXT_MUTED))
	var row := TableKit.hbox(4)
	box.add_child(row)
	address_edit = _line_edit("NET_ADDRESS_PLACEHOLDER", 64)
	address_edit.text = String(Settings.get_value(&"net_address"))
	address_edit.text_submitted.connect(func(_t: String) -> void: join_address(address_edit.text))
	row.add_child(address_edit)
	join_button = TableKit.button("NET_CONNECT", Sprites.ButtonKind.BID)
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(func() -> void: join_address(address_edit.text))
	row.add_child(join_button)


## Поле ввода в стиле UI-кита.
static func _line_edit(placeholder: String, max_length: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.max_length = max_length
	e.custom_minimum_size = MenuLayout.NET_FIELD_SIZE
	e.add_theme_stylebox_override("normal", Sprites.panel(Sprites.PanelKind.FIELD))
	e.add_theme_stylebox_override("focus", Sprites.panel(Sprites.PanelKind.FIELD))
	e.add_theme_color_override("font_color", TableKit.TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(TableKit.TEXT_MUTED, 0.6))
	e.add_theme_color_override("caret_color", TableKit.TEXT)
	e.select_all_on_focus = false
	return e


func _portrait_arrow(row: HBoxContainer, right: bool) -> TextureButton:
	var b := TableKit.arrow(right)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_step_portrait.bind(1 if right else -1))
	row.add_child(b)
	TouchUI.enlarge(b, TouchUI.ARROW_HIT)
	return b


func _process(_delta: float) -> void:
	_browser.update()
	if _client != null:
		_client.update()


func _exit_tree() -> void:
	_browser.stop()
	if _client != null:
		_client.leave()  # подключение брошено (переход в лобби забирает сессию раньше)


# --- Профиль -------------------------------------------------------------------

func _on_name_changed(text: String) -> void:
	Settings.set_value(&"net_name", SeatInfo.clean_name(text))


func _step_portrait(delta: int) -> void:
	var index := posmod(NetGame.player_portrait() + delta, Sprites.PLAYER_PORTRAITS.size())
	Settings.set_value(&"player_portrait", String(Sprites.PLAYER_PORTRAITS[index]))
	_refresh_portrait()


func _refresh_portrait() -> void:
	_portrait.texture = Sprites.portrait(Sprites.PLAYER_PORTRAITS[NetGame.player_portrait()])


# --- Создать игру --------------------------------------------------------------

func create_game() -> void:
	if is_connecting():
		return
	var transport := ENetTransport.host()
	if transport == null:
		show_status(tr("NET_ERR_PORT_BUSY") % NetBalance.PORT)
		return
	create_with(transport)


## Хост поверх готового транспорта (тесты — LoopbackTransport) → лобби.
func create_with(transport: NetTransport) -> void:
	NetGame.session = HostSession.new(transport, NetGame.player_name(), NetGame.player_portrait())
	ScreenNav.go(ScreenNav.LOBBY)


# --- Присоединиться ------------------------------------------------------------

func _refresh_games() -> void:
	var games := _browser.games()
	for i in game_buttons.size():
		var b := game_buttons[i]
		b.visible = i < games.size()
		if not b.visible:
			continue
		var g := games[i]
		var host_name := g.host_name if g.host_name != "" else tr("NET_DEFAULT_NAME")
		if g.is_compatible():
			b.text = tr("NET_GAME_ENTRY") % [host_name, g.humans, g.seats, g.address]
		else:
			b.text = tr("NET_GAME_OLD") % [host_name, g.address]
		b.disabled = not g.is_compatible() or is_connecting()
	if _browser.is_listening():
		_games_hint.text = "NET_SEARCHING" if games.is_empty() else ""
	_games_hint.visible = _games_hint.text != ""


func _on_game_pressed(index: int) -> void:
	var games := _browser.games()
	if index < games.size():
		address_edit.text = games[index].address
		join_address(games[index].address, games[index].port)


func join_address(address: String, port := NetBalance.PORT) -> void:
	if is_connecting():
		return
	address = address.strip_edges()
	if not address.is_valid_ip_address():
		show_status(tr("NET_ERR_ADDRESS"))
		return
	Settings.set_value(&"net_address", address)
	var transport := ENetTransport.join(address, port)
	if transport == null:
		show_status(tr("NET_ERR_ADDRESS"))
		return
	join_with(transport)


## Подключиться через готовый транспорт (тесты — LoopbackTransport).
func join_with(transport: NetTransport) -> void:
	_client = ClientSession.new(transport, NetGame.player_name(), NetGame.player_portrait())
	_client.joined.connect(_on_joined)
	_client.rejected.connect(_on_rejected)
	_client.match_aborted.connect(_on_join_failed)
	show_status(tr("NET_CONNECTING"), TableKit.TEXT)
	_set_busy(true)


func is_connecting() -> bool:
	return _client != null


func _on_joined() -> void:
	NetGame.session = _client
	_client = null
	ScreenNav.go(ScreenNav.LOBBY)


func _on_rejected(reason: int, host_version: String) -> void:
	_client = null
	_set_busy(false)
	show_status(NetText.reject_text(reason, host_version))


func _on_join_failed(reason: int) -> void:
	_client = null
	_set_busy(false)
	show_status(tr(NetText.abort_key(reason)))


func _set_busy(busy: bool) -> void:
	create_button.disabled = busy
	join_button.disabled = busy
	_refresh_games()


func show_status(text: String, color := TableKit.TEXT_ALERT) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_status.visible = text != ""


func status_text() -> String:
	return _status.text if _status.visible else ""


## «Назад»: подключение — отменить, иначе — в главное меню.
func go_back() -> void:
	if _client != null:
		var c := _client
		_client = null
		c.leave()
		_set_busy(false)
		show_status("")
		return
	ScreenNav.go(ScreenNav.MAIN_MENU)
