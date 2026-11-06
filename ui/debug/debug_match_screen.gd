extends Control
## Отладочный текстовый экран матча (М2): игрок 0 — человек, остальные — боты М3
## (случайные разные персонажи из BotRoster).
## Только подписывается на Events и отправляет команды контроллеру. Правил здесь нет.

const HUMAN_ID := 0
const DEFAULT_PLAYERS := 4
## Пауза между ходами ботов (сек) при скорости 1.0.
const BOT_DELAY := 0.6
const FONT_SIZE := 10
const BG_COLOR := Color(0.117647, 0.101961, 0.168627)

var _controller: MatchController
var _quantity := 1
var _face := 2

var _players_spin: SpinBox
var _palifico_check: CheckBox
var _calza_check: CheckBox
var _status_label: Label
var _players_label: Label
var _dice_label: Label
var _quantity_label: Label
var _face_label: Label
var _bid_button: Button
var _dudo_button: Button
var _calza_button: Button
var _roll_button: Button
var _next_button: Button
var _log: RichTextLabel
var _bot_timer: Timer


func _ready() -> void:
	_build_ui()
	_connect_events()
	_refresh()


# --- Построение интерфейса ------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme_res := Theme.new()
	theme_res.default_font_size = FONT_SIZE
	theme = theme_res

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	margin.add_child(root)

	var setup := _row(root)
	_label(setup, "DEBUG_PLAYERS")
	_players_spin = SpinBox.new()
	_players_spin.min_value = MatchController.MIN_PLAYERS
	_players_spin.max_value = MatchController.MAX_PLAYERS
	_players_spin.value = DEFAULT_PLAYERS
	setup.add_child(_players_spin)
	_palifico_check = _check(setup, "DEBUG_PALIFICO", Settings.get_value(&"palifico"))
	_calza_check = _check(setup, "DEBUG_CALZA", Settings.get_value(&"calza"))
	_button(setup, "DEBUG_NEW_MATCH", _on_new_match)

	_status_label = _label(root, "")
	_players_label = _label(root, "")
	_dice_label = _label(root, "")

	var bid_row := _row(root)
	_label(bid_row, "DEBUG_QUANTITY")
	_button(bid_row, "◀", _shift_quantity.bind(-1))
	_quantity_label = _label(bid_row, "")
	_button(bid_row, "▶", _shift_quantity.bind(1))
	_label(bid_row, "DEBUG_FACE")
	_button(bid_row, "◀", _shift_face.bind(-1))
	_face_label = _label(bid_row, "")
	_button(bid_row, "▶", _shift_face.bind(1))
	_bid_button = _button(bid_row, "DEBUG_BID", _on_bid)
	_dudo_button = _button(bid_row, "DEBUG_DUDO", _on_challenge.bind(MatchAction.dudo()))
	_calza_button = _button(bid_row, "DEBUG_CALZA_BUTTON", _on_challenge.bind(MatchAction.calza()))
	_roll_button = _button(bid_row, "DEBUG_ROLL", _on_roll)
	_next_button = _button(bid_row, "DEBUG_NEXT_ROUND", _on_next_round)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	root.add_child(_log)

	_bot_timer = Timer.new()
	_bot_timer.one_shot = true
	_bot_timer.timeout.connect(_on_bot_timer)
	add_child(_bot_timer)


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _label(parent: Node, text_key: String) -> Label:
	var label := Label.new()
	label.text = text_key
	parent.add_child(label)
	return label


func _button(parent: Node, text_key: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text_key
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _check(parent: Node, text_key: String, value: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text_key
	box.button_pressed = value
	parent.add_child(box)
	return box


func _connect_events() -> void:
	Events.match_started.connect(_on_match_started)
	Events.round_started.connect(_on_round_started)
	Events.turn_started.connect(_on_turn_started)
	Events.bid_placed.connect(_on_bid_placed)
	Events.challenge_revealed.connect(_on_challenge_revealed)
	Events.dice_count_changed.connect(_on_dice_count_changed)
	Events.player_eliminated.connect(_on_player_eliminated)
	Events.round_ended.connect(_on_round_ended)
	Events.match_ended.connect(_on_match_ended)
	Events.phase_changed.connect(func(_phase: int) -> void: _refresh())
	Events.locale_changed.connect(func(_locale: String) -> void: _refresh())


# --- Команды -------------------------------------------------------------------

func _on_new_match() -> void:
	var options := RuleOptions.new()
	options.palifico_enabled = _palifico_check.button_pressed
	options.calza_enabled = _calza_check.button_pressed
	var agents: Array[MatchAgent] = [HumanAgent.new()]
	var roster := BotRoster.all()
	var pick_rng := Rng.make_rng()
	for i in int(_players_spin.value) - 1:
		var personality: BotPersonality = roster.pop_at(pick_rng.randi_range(0, roster.size() - 1))
		agents.append(BotAgent.new(personality, Rng.make_rng()))
	_log.clear()
	_bot_timer.stop()
	_controller = MatchController.new(agents, options, Rng.make_rng())
	MatchEventBridge.connect_all(_controller, Events)
	_controller.start_match()


func _on_roll() -> void:
	_controller.roll()


func _on_next_round() -> void:
	_controller.next_round()


func _on_bid() -> void:
	_controller.submit_action(HUMAN_ID, MatchAction.make_bid(_quantity, _face))


func _on_challenge(action: MatchAction) -> void:
	_controller.submit_action(HUMAN_ID, action)


func _shift_quantity(step: int) -> void:
	_quantity = clampi(_quantity + step, 1, maxi(1, _controller.total_dice() if _controller else 1))
	_refresh()


func _shift_face(step: int) -> void:
	_face = wrapi(_face + step, 1, PerudoRules.FACES + 1)
	_refresh()


## Боты ходят сами; если человек выбыл — матч досматривается целиком автоматически.
func _schedule_bots() -> void:
	if _controller == null or not _needs_auto_step():
		return
	var speed: float = Settings.get_value(&"bot_speed")
	_bot_timer.start(BOT_DELAY / maxf(speed, 0.1))


func _needs_auto_step() -> bool:
	match _controller.phase:
		MatchController.Phase.BIDDING:
			return not _controller.is_waiting_for_human()
		MatchController.Phase.ROLL, MatchController.Phase.ROUND_END:
			return not _controller.is_active(HUMAN_ID)
	return false


func _on_bot_timer() -> void:
	if _controller != null and _needs_auto_step():
		_controller.advance_auto()


# --- События -------------------------------------------------------------------

func _on_match_started(player_count: int, _first: int) -> void:
	_log_line(tr("DEBUG_LOG_MATCH_STARTED") % player_count)


func _on_round_started(round_number: int, starter_id: int, is_palifico: bool) -> void:
	var line := tr("DEBUG_LOG_ROUND") % [round_number, _name(starter_id)]
	if is_palifico:
		line += tr("DEBUG_PALIFICO_ROUND")
	_log_line("[b]%s[/b]" % line)
	_refresh()
	_schedule_bots()


func _on_turn_started(player_id: int) -> void:
	if player_id == HUMAN_ID:
		var lowest := _controller.view_for(HUMAN_ID).lowest_bid()
		if lowest != null:
			_quantity = lowest.quantity
			_face = lowest.face
	_refresh()
	_schedule_bots()


func _on_bid_placed(player_id: int, bid: Bid) -> void:
	_log_line(tr("DEBUG_LOG_BID") % [_name(player_id), bid.quantity, bid.face])


func _on_challenge_revealed(reveal: ChallengeReveal) -> void:
	var key := "DEBUG_LOG_DUDO" if reveal.kind == MatchAction.Kind.DUDO else "DEBUG_LOG_CALZA"
	_log_line(tr(key) % _name(reveal.caller_id))
	for id in reveal.hands.size():
		if not reveal.hands[id].is_empty():
			_log_line("   " + tr("DEBUG_LOG_HAND") % [_name(id), _dice_text(reveal.hands[id])])
	_log_line(tr("DEBUG_LOG_REVEAL") % [reveal.result.actual_count, reveal.bid.quantity,
			reveal.bid.face])


func _on_dice_count_changed(player_id: int, count: int, delta: int) -> void:
	var key := "DEBUG_LOG_KEPT"
	if delta < 0:
		key = "DEBUG_LOG_LOST"
	elif delta > 0:
		key = "DEBUG_LOG_GAINED"
	_log_line(tr(key) % [_name(player_id), count])


func _on_player_eliminated(player_id: int) -> void:
	_log_line(tr("DEBUG_LOG_ELIMINATED") % _name(player_id))


func _on_round_ended(_next_starter: int, next_is_palifico: bool) -> void:
	if next_is_palifico:
		_log_line(tr("DEBUG_LOG_PALIFICO"))
	_refresh()
	_schedule_bots()


func _on_match_ended(winner_id: int) -> void:
	_log_line("[b]%s[/b]" % (tr("DEBUG_LOG_WINNER") % _name(winner_id)))
	_refresh()


# --- Отображение ---------------------------------------------------------------

func _refresh() -> void:
	_quantity_label.text = str(_quantity)
	_face_label.text = str(_face)
	var has_match := _controller != null
	if not has_match:
		_status_label.text = tr("DEBUG_STATUS_IDLE")
		_players_label.text = ""
		_dice_label.text = ""
		for b in [_bid_button, _dudo_button, _calza_button, _roll_button, _next_button]:
			b.disabled = true
		return

	_status_label.text = _status_text()
	var lines: PackedStringArray = []
	for id in _controller.player_count():
		var count := _controller.dice_counts[id]
		var line := tr("DEBUG_PLAYER_LINE") % [_name(id), count]
		if count == 0:
			line += " — " + tr("DEBUG_OUT")
		if id == _controller.current_player:
			line = "▶ " + line
		lines.append(line)
	_players_label.text = "   ".join(lines)

	var view := _controller.view_for(HUMAN_ID)
	var dice_text := tr("DEBUG_YOUR_DICE") % _dice_text(view.own_dice)
	if view.current_bid != null:
		dice_text += "   " + tr("DEBUG_CURRENT_BID") % [_name(view.current_bidder),
				view.current_bid.quantity, view.current_bid.face]
	var lowest := view.lowest_bid()
	if _controller.is_waiting_for_human() and lowest != null:
		dice_text += "   " + tr("DEBUG_MIN_BID") % [lowest.quantity, lowest.face]
	_dice_label.text = dice_text

	var my_turn := _controller.is_waiting_for_human()
	var phase := _controller.phase
	_bid_button.disabled = not (my_turn and view.is_legal(MatchAction.make_bid(_quantity, _face)))
	_dudo_button.disabled = not (my_turn and view.can_dudo())
	_calza_button.disabled = not (my_turn and view.can_calza())
	_calza_button.visible = _controller.options.calza_enabled
	var human_active := _controller.is_active(HUMAN_ID)
	_roll_button.disabled = not (phase == MatchController.Phase.ROLL and human_active)
	_next_button.disabled = not (phase == MatchController.Phase.ROUND_END and human_active)


func _status_text() -> String:
	var phase_text := ""
	match _controller.phase:
		MatchController.Phase.ROLL:
			phase_text = tr("DEBUG_PHASE_ROLL")
		MatchController.Phase.BIDDING:
			phase_text = tr("DEBUG_PHASE_TURN") % _name(_controller.current_player)
		MatchController.Phase.ROUND_END:
			phase_text = tr("DEBUG_PHASE_ROUND_END")
		MatchController.Phase.MATCH_OVER:
			phase_text = tr("DEBUG_PHASE_MATCH_OVER")
	var text := tr("DEBUG_STATUS") % [_controller.round_number, phase_text]
	if _controller.round_rules.is_palifico:
		text += tr("DEBUG_PALIFICO_ROUND")
	return text


func _name(player_id: int) -> String:
	if player_id == HUMAN_ID:
		return tr("DEBUG_YOU")
	var bot: BotAgent = null
	if _controller != null:
		bot = _controller.agent(player_id) as BotAgent
	if bot != null:
		return tr(bot.personality.name_key)
	return tr("DEBUG_BOT") % player_id


func _dice_text(dice: Array) -> String:
	if dice.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for d in dice:
		parts.append(str(d))
	return " ".join(parts)


func _log_line(text: String) -> void:
	_log.append_text(text + "\n")
