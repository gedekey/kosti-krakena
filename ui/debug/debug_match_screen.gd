extends Control
## Отладочный текстовый экран матча (М2): игрок 0 — человек, остальные — боты М3
## (случайные разные персонажи из BotRoster). М4: трюки, обвинение, Рассудок, улики,
## режим риска для ручной проверки и журнал «кто жульничал» в конце раунда.
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
var _cheat_option: OptionButton
var _cheat_target_option: OptionButton
var _die_spin: SpinBox
var _cheat_face_spin: SpinBox
var _cheat_button: Button
var _accuse_option: OptionButton
var _accuse_button: Button
var _risk_option: OptionButton
var _sanity_label: Label
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

	var cheat_row := _row(root)
	_label(cheat_row, "DEBUG_TRICK")
	_cheat_option = OptionButton.new()
	for kind in Cheat.ALL:
		_cheat_option.add_item(Cheat.name_key(kind), kind)
	_cheat_option.item_selected.connect(func(_i: int) -> void: _refresh())
	cheat_row.add_child(_cheat_option)
	_label(cheat_row, "DEBUG_TARGET")
	_cheat_target_option = OptionButton.new()
	_cheat_target_option.item_selected.connect(func(_i: int) -> void: _refresh())
	cheat_row.add_child(_cheat_target_option)
	_label(cheat_row, "DEBUG_DIE")
	_die_spin = _spin(cheat_row, 1, PerudoRules.MAX_DICE)
	_label(cheat_row, "DEBUG_FACE")
	_cheat_face_spin = _spin(cheat_row, 1, PerudoRules.FACES)

	var accuse_row := _row(root)
	_cheat_button = _button(accuse_row, "DEBUG_CHEAT_APPLY", _on_cheat)
	_label(accuse_row, "   ")
	_accuse_option = OptionButton.new()
	_accuse_option.item_selected.connect(func(_i: int) -> void: _refresh())
	accuse_row.add_child(_accuse_option)
	_accuse_button = _button(accuse_row, "ACCUSE", _on_accuse)
	_label(accuse_row, "DEBUG_RISK")
	_risk_option = OptionButton.new()
	for key in ["DEBUG_RISK_NORMAL", "DEBUG_RISK_NEVER", "DEBUG_RISK_ALWAYS"]:
		_risk_option.add_item(key)
	_risk_option.item_selected.connect(_on_risk_selected)
	accuse_row.add_child(_risk_option)
	_sanity_label = _label(accuse_row, "")

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


func _spin(parent: Node, min_value: int, max_value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value_changed.connect(func(_v: float) -> void: _refresh())
	parent.add_child(spin)
	return spin


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
	Events.cheat_resolved.connect(_on_cheat_resolved)
	Events.cheat_failed.connect(_on_cheat_failed)
	Events.evidence_shown.connect(_on_evidence_shown)
	Events.sanity_changed.connect(_on_sanity_changed)
	Events.madness_began.connect(_on_madness_began)
	Events.accusation_made.connect(_on_accusation_made)
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
	_controller.cheats.risk_mode = _risk_option.selected as CheatState.RiskMode
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


func _on_cheat() -> void:
	_controller.submit_cheat(HUMAN_ID, _selected_cheat())
	_refresh()


func _on_accuse() -> void:
	_controller.submit_action(HUMAN_ID, MatchAction.accuse(_accuse_option.get_selected_id()))


func _on_risk_selected(index: int) -> void:
	if _controller != null:
		_controller.cheats.risk_mode = index as CheatState.RiskMode


func _selected_kind() -> Cheat.Kind:
	return _cheat_option.get_selected_id() as Cheat.Kind


func _selected_cheat() -> CheatAction:
	var kind := _selected_kind()
	var target := _cheat_target_option.get_selected_id()
	var die := int(_die_spin.value) - 1
	var face := int(_cheat_face_spin.value)
	match kind:
		Cheat.Kind.PEEK:
			return CheatAction.peek(target, die)
		Cheat.Kind.SLEIGHT:
			return CheatAction.sleight(die)
		Cheat.Kind.LOADED_DIE:
			return CheatAction.loaded_die(face)
		Cheat.Kind.NUDGE_CUP:
			return CheatAction.nudge_cup(target)
		Cheat.Kind.SLEEVE_DIE:
			return CheatAction.sleeve_die()
	return CheatAction.abyss_whisper(face)


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
		if id < reveal.sleeve_dice.size() and not reveal.sleeve_dice[id].is_empty():
			_log_line(tr("DEBUG_LOG_SLEEVE_REVEAL") % [_name(id), _dice_text(reveal.sleeve_dice[id])])
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
	_log_cheaters()
	if next_is_palifico:
		_log_line(tr("DEBUG_LOG_PALIFICO"))
	_refresh()
	_schedule_bots()


func _on_match_ended(winner_id: int) -> void:
	_log_cheaters()
	_log_line("[b]%s[/b]" % (tr("DEBUG_LOG_WINNER") % _name(winner_id)))
	_refresh()


## Секретный итог трюка — только свой.
func _on_cheat_resolved(outcome: CheatOutcome) -> void:
	if outcome.player_id != HUMAN_ID:
		return
	var a := outcome.action
	match a.kind:
		Cheat.Kind.PEEK:
			_log_line(tr("DEBUG_LOG_PEEK") % [_name(a.target_id), a.die_index + 1, outcome.peeked_face])
		Cheat.Kind.SLEIGHT:
			_log_line(tr("DEBUG_LOG_SLEIGHT") % [outcome.die_index + 1, outcome.new_face])
		Cheat.Kind.LOADED_DIE:
			_log_line(tr("DEBUG_LOG_LOADED") % [outcome.die_index + 1, outcome.new_face])
		Cheat.Kind.NUDGE_CUP:
			_log_line(tr("DEBUG_LOG_NUDGE") % _name(a.target_id))
		Cheat.Kind.SLEEVE_DIE:
			_log_line(tr("DEBUG_LOG_SLEEVE") % outcome.new_face)
		Cheat.Kind.ABYSS_WHISPER:
			_log_line(tr("DEBUG_LOG_WHISPER") % [outcome.whisper_count, a.face])


func _on_cheat_failed(player_id: int, kind: int) -> void:
	_log_line("[b]%s[/b]" % (tr("DEBUG_LOG_CHEAT_FAILED") % [_name(player_id),
			tr(Cheat.name_key(kind as Cheat.Kind))]))


func _on_evidence_shown(player_id: int) -> void:
	_log_line(tr("DEBUG_LOG_EVIDENCE") % _name(player_id))
	_refresh()


func _on_sanity_changed(player_id: int, sanity: int, _delta: int) -> void:
	if player_id == HUMAN_ID:
		_log_line(tr("DEBUG_LOG_SANITY") % sanity)


func _on_madness_began(player_id: int) -> void:
	_log_line("[b]%s[/b]" % (tr("DEBUG_LOG_MADNESS") % _name(player_id)))


func _on_accusation_made(accuser_id: int, target_id: int, guilty: bool) -> void:
	var key := "DEBUG_LOG_ACCUSE_RIGHT" if guilty else "DEBUG_LOG_ACCUSE_WRONG"
	_log_line("[b]%s[/b]" % (tr(key) % [_name(accuser_id), _name(target_id)]))


## Журнал раунда (отладка: в настоящей игре его никто не видит).
func _log_cheaters() -> void:
	var names: PackedStringArray = []
	for id in _controller.cheaters_this_round():
		names.append(_name(id))
	var text := ", ".join(names) if not names.is_empty() else tr("DEBUG_NOBODY")
	_log_line(tr("DEBUG_LOG_CHEATERS") % text)


# --- Отображение ---------------------------------------------------------------

func _refresh() -> void:
	_quantity_label.text = str(_quantity)
	_face_label.text = str(_face)
	var has_match := _controller != null
	if not has_match:
		_status_label.text = tr("DEBUG_STATUS_IDLE")
		_players_label.text = ""
		_dice_label.text = ""
		for b in [_bid_button, _dudo_button, _calza_button, _roll_button, _next_button,
				_cheat_button, _accuse_button]:
			b.disabled = true
		_sanity_label.text = ""
		_refresh_cheat_names()
		return

	_status_label.text = _status_text()
	var lines: PackedStringArray = []
	for id in _controller.player_count():
		var count := _controller.dice_counts[id]
		var line := tr("DEBUG_PLAYER_LINE") % [_name(id), count]
		if count == 0:
			line += " — " + tr("DEBUG_OUT")
		var evidence := _controller.cheats.evidence[id]
		if evidence > 0:
			line += " · " + tr("DEBUG_EVIDENCE") % evidence
		if _controller.cheats.is_mad(id):
			line += " · " + tr("DEBUG_MAD")
		if id == _controller.current_player:
			line = "▶ " + line
		lines.append(line)
	_players_label.text = "   ".join(lines)

	var view := _controller.view_for(HUMAN_ID)
	var dice_text := tr("DEBUG_YOUR_DICE") % _dice_text(view.own_dice)
	if not view.sleeve_dice.is_empty():
		dice_text += " (" + tr("DEBUG_SLEEVE") % _dice_text(view.sleeve_dice) + ")"
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
	_refresh_cheats(view, my_turn)


func _refresh_cheats(view: PlayerView, my_turn: bool) -> void:
	_refresh_cheat_names()
	_sanity_label.text = tr("DEBUG_SANITY") % view.own_sanity
	if view.is_mad():
		_sanity_label.text += " · " + tr("DEBUG_MAD")

	var kind := _selected_kind()
	var target_kind := Cheat.target(kind)
	var targets: Array[int] = []
	if Cheat.targets_neighbor(kind):
		targets = view.neighbors()
	_fill_players(_cheat_target_option, targets)
	_cheat_target_option.disabled = targets.is_empty()

	var die_owner := HUMAN_ID
	if target_kind == Cheat.Target.NEIGHBOR_DIE:
		die_owner = _cheat_target_option.get_selected_id()
	_die_spin.editable = target_kind == Cheat.Target.OWN_DIE \
			or target_kind == Cheat.Target.NEIGHBOR_DIE
	if die_owner >= 0:
		_die_spin.max_value = maxi(1, _controller.dice_counts[die_owner])
	_cheat_face_spin.editable = target_kind == Cheat.Target.FACE
	_cheat_button.disabled = _controller.cheat_denial(HUMAN_ID, _selected_cheat()) \
			!= CheatRules.Denied.OK

	var others: Array[int] = []
	for id in _controller.player_count():
		if id != HUMAN_ID and _controller.is_active(id):
			others.append(id)
	_fill_players(_accuse_option, others)
	_accuse_button.disabled = not (my_turn and view.can_accuse(_accuse_option.get_selected_id()))


## Названия трюков с ценой и риском (переводятся при смене языка).
func _refresh_cheat_names() -> void:
	for i in _cheat_option.item_count:
		var kind := _cheat_option.get_item_id(i) as Cheat.Kind
		_cheat_option.set_item_text(i, tr("DEBUG_CHEAT_OPTION") % [tr(Cheat.name_key(kind)),
				Cheat.cost(kind), roundi(Cheat.risk(kind) * 100.0)])
	_risk_option.set_item_text(0, tr("DEBUG_RISK_NORMAL"))
	_risk_option.set_item_text(1, tr("DEBUG_RISK_NEVER"))
	_risk_option.set_item_text(2, tr("DEBUG_RISK_ALWAYS"))


## Заполнить список игроков, сохранив выбор, если он ещё доступен.
func _fill_players(option: OptionButton, ids: Array[int]) -> void:
	var keep := option.get_selected_id() if option.item_count > 0 else -1
	option.clear()
	for id in ids:
		option.add_item(_name(id), id)
	if ids.has(keep):
		option.select(option.get_item_index(keep))
	elif not ids.is_empty():
		option.select(0)


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
