extends Control
## Игровой экран — стол (М9, DESIGN.md §6). Игрок 0 — человек, остальные — боты.
##
## Только подписывается на Events и отправляет команды MatchController; правила — в
## PlayerView / ActionRules / CheatRules. Боты ходят по таймеру (темп — TableLayout и
## Settings.bot_speed). Итог раунда ждёт «Дальше»; после выбывания — «Досмотреть ×2».

const HUMAN_ID := 0

var _setup: MatchSetup
var _controller: MatchController
var _seats := {}                       # id → SeatView
var _peeked := {}                      # id → Array[int] — подсмотренные кубики соседа
var _round_notes: PackedStringArray = []
var _round_title := ""
var _last_reveal: ChallengeReveal
var _spectating := false
var _defeat_shown := false

var _background: TextureRect
var _seat_layer: Control
var _own: OwnHandView
var _feed: BidFeed
var _bid_caption: Label
var _bid_row: HBoxContainer
var _status_label: Label
var _palifico_label: Label
var _roll_button: Button
var _messages: VBoxContainer
var _bid_input: BidInput
var _bid_button: Button
var _liar_button: Button
var _calza_button: Button
var _accuse_button: Button
var _tricks_button: Button
var _banner: Label
var _banner_panel: PanelContainer
var _accuse_menu: ChoicePanel
var _trick_menu: TrickMenu
var _result_panel: RoundResultPanel
var _end_panel: MatchEndPanel
var _timer: Timer
var _banner_timer: Timer
var _fx: TableFx
var _madness: MadnessOverlay


func _ready() -> void:
	_build_ui()
	_connect_events()
	start_match(MatchSetup.take_pending())


## Начать матч (и «Реванш» — с теми же соперниками).
func start_match(setup: MatchSetup) -> void:
	_setup = setup
	_setup.resolve_opponents(Rng.make_rng())
	_timer.stop()
	_spectating = false
	_defeat_shown = false
	_last_reveal = null
	_hide_popups()
	_end_panel.hide()
	_result_panel.hide()
	TableKit.clear(_messages)

	var agents: Array[MatchAgent] = [HumanAgent.new()]
	for id in _setup.opponents:
		agents.append(BotAgent.new(BotRoster.by_id(id), Rng.make_rng()))
	_controller = MatchController.new(agents, _setup.rule_options(), Rng.make_rng())
	MatchEventBridge.connect_all(_controller, Events)
	_build_seats()
	_own.setup(_setup.player_portrait)
	_controller.start_match()


# --- Построение ------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_background = TextureRect.new()
	_background.texture = Sprites.background()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_seat_layer = Control.new()
	_seat_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_seat_layer)

	_feed = BidFeed.new()
	add_child(_feed)

	var bid_panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(bid_panel, TableLayout.BID_RECT)
	bid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bid_panel)
	var bid_box := TableKit.vbox(2)
	bid_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bid_panel.add_child(bid_box)
	_bid_caption = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	bid_box.add_child(_bid_caption)
	_bid_row = TableKit.hbox(4)
	_bid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bid_box.add_child(_bid_row)

	var status_box := TableKit.vbox(2)
	TableKit.place(status_box, TableLayout.STATUS_RECT)
	add_child(status_box)
	_status_label = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(_status_label)
	_palifico_label = TableKit.label("TABLE_PALIFICO", TableKit.TEXT_MAGIC,
			HORIZONTAL_ALIGNMENT_CENTER)
	status_box.add_child(_palifico_label)
	_roll_button = TableKit.button("TABLE_ROLL", Sprites.ButtonKind.BID)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.pressed.connect(_on_roll)
	status_box.add_child(_roll_button)

	var messages_panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(messages_panel, TableLayout.MESSAGES_RECT)
	messages_panel.clip_contents = true
	messages_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(messages_panel)
	_messages = TableKit.vbox(2)
	messages_panel.add_child(_messages)

	var own_bg := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(own_bg, TableLayout.OWN_PANEL_RECT)
	own_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(own_bg)
	_own = OwnHandView.new()
	_own.cup_pressed.connect(_on_cup)
	add_child(_own)

	var controls := TableKit.vbox(4)
	TableKit.place(controls, TableLayout.CONTROLS_RECT)
	add_child(controls)
	_bid_input = BidInput.new()
	_bid_input.changed.connect(_refresh)
	controls.add_child(_bid_input)
	var row1 := TableKit.hbox(4)
	controls.add_child(row1)
	_bid_button = _action_button(row1, "ACTION_BID", Sprites.ButtonKind.BID, _on_bid)
	_liar_button = _action_button(row1, "ACTION_LIAR", Sprites.ButtonKind.LIAR,
			_on_challenge.bind(MatchAction.Kind.DUDO))
	_calza_button = _action_button(row1, "ACTION_CALZA", Sprites.ButtonKind.CALZA,
			_on_challenge.bind(MatchAction.Kind.CALZA))
	var row2 := TableKit.hbox(4)
	controls.add_child(row2)
	_accuse_button = _action_button(row2, "ACCUSE", Sprites.ButtonKind.ACCUSE, _on_accuse)
	_accuse_button.icon = Sprites.texture(Sprites.ICON_ACCUSE)
	_accuse_button.tooltip_text = "ACTION_ACCUSE_HINT"
	_tricks_button = _action_button(row2, "ACTION_TRICKS", Sprites.ButtonKind.PLAIN, _on_tricks)
	_tricks_button.icon = Sprites.trick_icon(Cheat.Kind.SLEIGHT)

	# Эффекты (М10): над столом, под всплывающими панелями.
	_madness = MadnessOverlay.new()
	_fx = TableFx.new()
	_fx.setup(_fx_target, _speed, self, _madness)
	add_child(_fx)
	add_child(_madness)

	_banner_panel = TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(_banner_panel, TableLayout.BANNER_RECT)
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.hide()
	add_child(_banner_panel)
	_banner = TableKit.title("", true)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_panel.add_child(_banner)

	_accuse_menu = ChoicePanel.new()
	_accuse_menu.picked.connect(_on_accuse_picked)
	add_child(_accuse_menu)
	_trick_menu = TrickMenu.new()
	_trick_menu.cheat_chosen.connect(_on_cheat_chosen)
	add_child(_trick_menu)
	_result_panel = RoundResultPanel.new()
	_result_panel.continue_pressed.connect(_on_continue)
	add_child(_result_panel)
	_end_panel = MatchEndPanel.new()
	_end_panel.spectate_pressed.connect(_on_spectate)
	_end_panel.rematch_pressed.connect(_on_rematch)
	_end_panel.menu_pressed.connect(_on_menu)
	add_child(_end_panel)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_banner_timer = Timer.new()
	_banner_timer.one_shot = true
	_banner_timer.timeout.connect(_banner_panel.hide)
	add_child(_banner_timer)


func _action_button(row: HBoxContainer, key: String, kind: Sprites.ButtonKind,
		handler: Callable) -> Button:
	var b := TableKit.button(key, kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(handler)
	row.add_child(b)
	return b


## Соперники по кругу слева направо: следующий после игрока — первый слева.
func _build_seats() -> void:
	TableKit.clear(_seat_layer)
	_seats.clear()
	_peeked.clear()
	var positions := TableLayout.seat_positions(_controller.player_count() - 1)
	for id in range(1, _controller.player_count()):
		var seat := SeatView.new()
		var bot := _controller.agent(id) as BotAgent
		seat.setup(id, bot.personality.id, _name(id))
		seat.position = positions[id - 1]
		_seat_layer.add_child(seat)
		_seats[id] = seat


func _connect_events() -> void:
	Events.round_started.connect(_on_round_started)
	Events.dice_rolled.connect(_on_dice_rolled)
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
	Events.cup_changed.connect(_on_cup_changed)
	Events.phase_changed.connect(_on_phase_changed)
	Events.locale_changed.connect(_on_locale_changed)


# --- Команды игрока ------------------------------------------------------------

func _on_roll() -> void:
	_hide_popups()
	_controller.roll()


func _on_bid() -> void:
	if _bid_input.is_legal():
		_hide_popups()
		_controller.submit_action(HUMAN_ID, _bid_input.action())


func _on_challenge(kind: MatchAction.Kind) -> void:
	_hide_popups()
	var action := MatchAction.dudo() if kind == MatchAction.Kind.DUDO else MatchAction.calza()
	_controller.submit_action(HUMAN_ID, action)


func _on_accuse() -> void:
	_trick_menu.hide()
	var view := _controller.view_for(HUMAN_ID)
	var choices: Array[ChoicePanel.Choice] = []
	for id in range(1, _controller.player_count()):
		if _controller.is_active(id):
			var c := ChoicePanel.Choice.new(_name(id), id, Sprites.texture(Sprites.ICON_EVIDENCE)
					if view.evidence[id] > 0 else null, view.can_accuse(id))
			choices.append(c)
	_accuse_menu.open(tr("TABLE_ACCUSE_TITLE"), choices, 1, tr("TABLE_ACCUSE_FOOTER"))


func _on_accuse_picked(value: Variant) -> void:
	_accuse_menu.hide()
	_controller.submit_action(HUMAN_ID, MatchAction.accuse(int(value)))


func _on_tricks() -> void:
	_accuse_menu.hide()
	_trick_menu.open_for(_controller.view_for(HUMAN_ID), _name,
			func(action: CheatAction) -> CheatRules.Denied:
				return _controller.cheat_denial(HUMAN_ID, action))


func _on_cheat_chosen(action: CheatAction) -> void:
	if _controller.cheat_denial(HUMAN_ID, action) != CheatRules.Denied.OK:
		_add_message(tr("TABLE_TRICK_DENIED"), TableKit.TEXT_ALERT)
		_refresh()
		return
	_controller.submit_cheat(HUMAN_ID, action)
	_refresh()


func _on_cup() -> void:
	if _controller.view_for(HUMAN_ID).cup_open:
		_controller.close_cup(HUMAN_ID)
	else:
		_controller.open_cup(HUMAN_ID)


func _on_continue() -> void:
	_result_panel.hide()
	match _controller.phase:
		MatchController.Phase.MATCH_OVER:
			_show_match_end()
		MatchController.Phase.ROUND_END:
			if not _controller.is_active(HUMAN_ID) and not _defeat_shown:
				_show_defeat()
			else:
				_controller.next_round()


func _on_spectate() -> void:
	_end_panel.hide()
	_spectating = true
	if _controller.phase == MatchController.Phase.ROUND_END:
		_controller.next_round()
	_schedule()


func _on_rematch() -> void:
	start_match(_setup)


func _on_menu() -> void:
	_timer.stop()
	ScreenNav.go(ScreenNav.MAIN_MENU)


# --- Темп --------------------------------------------------------------------------

## Место игрока для эффектов: соперник — SeatView, игрок — OwnHandView; null — нет такого.
func _fx_target(player_id: int) -> Control:
	if _controller == null or player_id < 0 or player_id >= _controller.player_count():
		return null
	return _own if player_id == HUMAN_ID else _seats.get(player_id)


func _speed() -> float:
	var speed: float = maxf(Settings.get_value(&"bot_speed"), 0.1)
	if _spectating:
		speed *= TableLayout.SPECTATE_SPEED
	return speed


## Запланировать следующий автоматический шаг (ход бота, бросок / раунд без игрока).
func _schedule() -> void:
	var delay := _auto_delay()
	if delay < 0.0:
		return
	_timer.start(delay / _speed())


## Пауза до автоматического шага или −1, если ждём игрока.
func _auto_delay() -> float:
	if _controller == null or _end_panel.visible:
		return -1.0
	var human_active := _controller.is_active(HUMAN_ID)
	match _controller.phase:
		MatchController.Phase.BIDDING:
			if not _controller.is_waiting_for_human():
				return TableLayout.BOT_TURN_DELAY
		MatchController.Phase.ROLL:
			if not human_active:
				return TableLayout.AUTO_ROUND_DELAY * 0.5
		MatchController.Phase.ROUND_END, MatchController.Phase.MATCH_OVER:
			if _spectating and _result_panel.visible:
				return TableLayout.AUTO_ROUND_DELAY
	return -1.0


func _on_timer() -> void:
	if _auto_delay() < 0.0:
		return
	match _controller.phase:
		MatchController.Phase.BIDDING, MatchController.Phase.ROLL:
			_controller.advance_auto()
		_:
			_result_panel.press_continue()


# --- События матча -----------------------------------------------------------

func _on_round_started(_round_number: int, _starter_id: int, is_palifico: bool) -> void:
	_round_notes.clear()
	_round_title = ""
	_last_reveal = null
	_peeked.clear()
	_feed.clear_entries()
	for seat: SeatView in _seats.values():
		seat.hide_bubble()
		seat.set_cup_open(false)
		seat.set_peeked([])
		if not _controller.is_active(seat.player_id):
			seat.set_dice_count(0)
	if is_palifico:
		_show_banner("TABLE_PALIFICO")
	_refresh()
	_schedule()


func _on_dice_rolled(_round_number: int) -> void:
	_refresh()


func _on_turn_started(player_id: int) -> void:
	if player_id == HUMAN_ID:
		_bid_input.reset_to_lowest(_controller.view_for(HUMAN_ID))
	_refresh()
	_schedule()


func _on_bid_placed(player_id: int, bid: Bid) -> void:
	_feed.add_entry(_name(player_id), bid.quantity, bid.face)
	if _seats.has(player_id):
		_seats[player_id].show_bubble_bid(bid.quantity, bid.face)


func _on_challenge_revealed(reveal: ChallengeReveal) -> void:
	_last_reveal = reveal
	var key := "ACTION_LIAR" if reveal.kind == MatchAction.Kind.DUDO else "ACTION_CALZA"
	if _seats.has(reveal.caller_id):
		_seats[reveal.caller_id].show_bubble_text(tr(key), TableKit.TEXT_ALERT)
	for seat: SeatView in _seats.values():
		seat.set_cup_open(true)


func _on_dice_count_changed(player_id: int, count: int, delta: int) -> void:
	if delta < 0:
		if player_id == HUMAN_ID:
			_round_notes.append(tr("TABLE_NOTE_LOST_YOU") % [-delta, count])
		else:
			_round_notes.append(tr("TABLE_NOTE_LOST") % [_name(player_id), -delta, count])
	elif delta > 0:
		if player_id == HUMAN_ID:
			_round_notes.append(tr("TABLE_NOTE_GAINED_YOU") % count)
		else:
			_round_notes.append(tr("TABLE_NOTE_GAINED") % [_name(player_id), count])
	else:
		_round_notes.append(tr("TABLE_NOTE_KEPT") % _name(player_id))
	if _seats.has(player_id):
		_seats[player_id].set_dice_count(count)


func _on_player_eliminated(player_id: int) -> void:
	_round_notes.append(_about("TABLE_NOTE_ELIMINATED", player_id))


func _on_round_ended(_next_starter: int, next_is_palifico: bool) -> void:
	if next_is_palifico:
		_round_notes.append(tr("TABLE_NOTE_PALIFICO"))
	_show_round_result()


func _on_match_ended(winner_id: int) -> void:
	_round_notes.append(tr("TABLE_NOTE_WINNER") % _name(winner_id))
	_show_round_result()


## СЕКРЕТНО: итог своего трюка видит только игрок.
func _on_cheat_resolved(outcome: CheatOutcome) -> void:
	if outcome.player_id != HUMAN_ID:
		return
	var a := outcome.action
	var text := ""
	match a.kind:
		Cheat.Kind.PEEK:
			text = tr("TABLE_MSG_PEEK") % [_name(a.target_id), a.die_index + 1, outcome.peeked_face]
			var faces: Array[int] = []
			faces.assign(_peeked.get(a.target_id, []))
			faces.append(outcome.peeked_face)
			_peeked[a.target_id] = faces
		Cheat.Kind.SLEIGHT:
			text = tr("TABLE_MSG_SLEIGHT") % [outcome.die_index + 1, outcome.new_face]
		Cheat.Kind.LOADED_DIE:
			text = tr("TABLE_MSG_LOADED") % [outcome.die_index + 1, outcome.new_face]
		Cheat.Kind.NUDGE_CUP:
			text = tr("TABLE_MSG_NUDGE") % _name(a.target_id)
		Cheat.Kind.SLEEVE_DIE:
			text = tr("TABLE_MSG_SLEEVE") % outcome.new_face
		Cheat.Kind.ABYSS_WHISPER:
			text = tr("TABLE_MSG_WHISPER") % [outcome.whisper_count, a.face]
	_add_message(text, TableKit.TEXT_MAGIC)
	_refresh()


func _on_cheat_failed(player_id: int, kind: int) -> void:
	_round_title = _about("TABLE_CAUGHT_TITLE", player_id)
	_round_notes.append(tr("TABLE_NOTE_CAUGHT_TRICK") % tr(Cheat.name_key(kind as Cheat.Kind)))
	_add_message(_round_title, TableKit.TEXT_ALERT)
	if _seats.has(player_id):
		_seats[player_id].show_bubble_text(tr("TABLE_BUBBLE_CAUGHT"), TableKit.TEXT_ALERT)


func _on_evidence_shown(player_id: int) -> void:
	_add_message(_about("TABLE_MSG_EVIDENCE", player_id), TableKit.TEXT_ALERT)
	_refresh()


func _on_sanity_changed(player_id: int, _sanity: int, _delta: int) -> void:
	if player_id == HUMAN_ID:
		_refresh()


func _on_madness_began(player_id: int) -> void:
	_add_message(_about("TABLE_MSG_MADNESS", player_id), TableKit.TEXT_MAGIC)
	if player_id == HUMAN_ID:
		_show_banner("TABLE_MADNESS_BANNER")
	_refresh()


func _on_accusation_made(accuser_id: int, target_id: int, guilty: bool) -> void:
	var key := "TABLE_ACCUSE_RIGHT" if guilty else "TABLE_ACCUSE_WRONG"
	if accuser_id == HUMAN_ID:
		_round_title = tr(key + "_BY_YOU") % _name(target_id)
	elif target_id == HUMAN_ID:
		_round_title = tr(key + "_YOU") % _name(accuser_id)
	else:
		_round_title = tr(key) % [_name(accuser_id), _name(target_id)]
	_add_message(_round_title, TableKit.TEXT_ALERT)
	if _seats.has(accuser_id):
		_seats[accuser_id].show_bubble_text(tr("TABLE_BUBBLE_ACCUSE") % _name(target_id),
				TableKit.TEXT_ALERT)


func _on_cup_changed(player_id: int, is_open: bool) -> void:
	if player_id == HUMAN_ID:
		_refresh()
	elif _seats.has(player_id) and _controller.phase == MatchController.Phase.BIDDING:
		_seats[player_id].set_cup_open(is_open)


func _on_phase_changed(_phase: int) -> void:
	if _controller.phase != MatchController.Phase.BIDDING:
		_hide_popups()
	_refresh()


func _on_locale_changed(_locale: String) -> void:
	for seat: SeatView in _seats.values():
		seat.set_display_name(_name(seat.player_id))
	_refresh()


# --- Итоги -------------------------------------------------------------------------

func _show_round_result() -> void:
	_hide_popups()
	if _last_reveal != null:
		_result_panel.speed = _speed()
		_result_panel.show_reveal(_last_reveal, _name, _round_notes)
	else:
		_result_panel.show_summary(_round_title, _round_notes)
	_refresh()
	_schedule()


func _show_defeat() -> void:
	_defeat_shown = true
	_end_panel.show_result(false, Sprites.portrait(_setup.player_portrait, true),
			tr("TABLE_DEFEAT_OUT"), true)


func _show_match_end() -> void:
	_timer.stop()
	var winner := _controller.winner_id
	var won := winner == HUMAN_ID
	var portrait: Texture2D
	var subtitle: String
	if won:
		portrait = Sprites.portrait(_setup.player_portrait)
		subtitle = tr("TABLE_VICTORY_TEXT")
	else:
		var bot := _controller.agent(winner) as BotAgent
		portrait = Sprites.portrait(bot.personality.id)
		subtitle = tr("TABLE_DEFEAT_WINNER") % _name(winner)
	_end_panel.show_result(won, portrait, subtitle, false)


# --- Отображение ---------------------------------------------------------------

func _refresh() -> void:
	if _controller == null:
		return
	var view := _controller.view_for(HUMAN_ID)
	var phase := _controller.phase
	var my_turn := _controller.is_waiting_for_human()
	var human_active := _controller.is_active(HUMAN_ID)

	for seat: SeatView in _seats.values():
		var id := seat.player_id
		seat.set_dice_count(view.dice_counts[id])
		seat.set_evidence(view.evidence[id])
		seat.set_mad(view.mad[id])
		seat.set_active(phase == MatchController.Phase.BIDDING and _controller.current_player == id)
		var peeked: Array[int] = []
		peeked.assign(_peeked.get(id, []))
		seat.set_peeked(peeked)
	_own.set_active(my_turn)
	if human_active and view.is_mad() and not _madness.is_active():
		_madness.set_active(true)
	_own.show_view(view if human_active else null,
			phase == MatchController.Phase.BIDDING and human_active)

	_refresh_bid(view)
	_status_label.text = _status_text()
	_palifico_label.visible = _controller.round_rules.is_palifico \
			and phase != MatchController.Phase.MATCH_OVER
	_roll_button.visible = phase == MatchController.Phase.ROLL and human_active

	_bid_input.set_view(view, my_turn)
	_bid_button.disabled = not (my_turn and _bid_input.is_legal())
	_liar_button.disabled = not (my_turn and view.can_dudo())
	_calza_button.visible = _controller.options.calza_enabled
	_calza_button.disabled = not (my_turn and view.can_calza())
	_accuse_button.disabled = not (my_turn and _can_accuse_anyone(view))
	_tricks_button.disabled = not (human_active and not view.is_mad()
			and view.cheat_window != CheatRules.CheatWindow.CLOSED)
	_tricks_button.tooltip_text = "TABLE_TRICKS_MAD" if view.is_mad() else ""


func _refresh_bid(view: PlayerView) -> void:
	TableKit.clear(_bid_row)
	if view.current_bid == null:
		_bid_caption.text = "TABLE_NO_BID"
		return
	_bid_caption.text = tr("TABLE_CURRENT_BID") % _name(view.current_bidder)
	var q := TableKit.title("%d ×" % view.current_bid.quantity)
	_bid_row.add_child(q)
	_bid_row.add_child(TableKit.die_rect(view.current_bid.face, TableLayout.OWN_SCALE))


func _can_accuse_anyone(view: PlayerView) -> bool:
	for id in range(1, _controller.player_count()):
		if view.can_accuse(id):
			return true
	return false


func _status_text() -> String:
	var text := tr("TABLE_ROUND") % _controller.round_number + " · "
	match _controller.phase:
		MatchController.Phase.ROLL:
			if _controller.is_active(HUMAN_ID):
				return text + tr("TABLE_STATUS_ROLL")
			return text + tr("TABLE_STATUS_ROLLING")
		MatchController.Phase.BIDDING:
			if _controller.is_waiting_for_human():
				return text + tr("TABLE_STATUS_YOUR_TURN")
			return text + tr("TABLE_STATUS_TURN") % _name(_controller.current_player)
		MatchController.Phase.ROUND_END:
			return text + tr("TABLE_STATUS_ROUND_END")
		MatchController.Phase.MATCH_OVER:
			return tr("TABLE_STATUS_MATCH_OVER")
	return ""


func _add_message(text: String, color := TableKit.TEXT) -> void:
	var l := TableKit.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TableLayout.MESSAGES_RECT.size.x - 12
	_messages.add_child(l)
	_messages.move_child(l, 0)
	while _messages.get_child_count() > TableLayout.MESSAGES_MAX:
		var old := _messages.get_child(_messages.get_child_count() - 1)
		_messages.remove_child(old)
		old.queue_free()


func _show_banner(key: String) -> void:
	_banner.text = key
	_banner_panel.show()
	_fx.hop(_banner_panel, TableFx.HOP_PX + 2, TableFx.HOP_TIME * 2)
	_banner_timer.start(TableLayout.BANNER_TIME)


func _hide_popups() -> void:
	if _accuse_menu != null:
		_accuse_menu.hide()
		_trick_menu.hide()


## Фраза о игроке: для себя — отдельный ключ <key>_YOU без имени (иначе «Вы впадает…»).
func _about(key: String, player_id: int) -> String:
	if player_id == HUMAN_ID:
		return tr(key + "_YOU")
	return tr(key) % _name(player_id)


func _name(player_id: int) -> String:
	if player_id == HUMAN_ID:
		return tr("TABLE_YOU")
	var bot := _controller.agent(player_id) as BotAgent
	return tr(bot.personality.name_key) if bot != null else str(player_id)
