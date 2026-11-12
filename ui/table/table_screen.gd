extends Control
## Игровой экран — стол (М9, DESIGN.md §6). Игрок 0 — человек, остальные — боты.
##
## Только подписывается на Events и отправляет команды MatchController; правила — в
## PlayerView / ActionRules / CheatRules. Боты ходят по таймеру (темп — TableLayout и
## Settings.bot_speed). Итог раунда ждёт «Дальше»; после выбывания — «Досмотреть ×2».
##
## М13: подсказки при первом трюке / обвинении / своём Безумии (HintPanel) и обучающий
## матч (MatchSetup.tutorial): Моряк по сценарию, TutorialDirector пускает только ту
## команду, которую ждёт шаг, TutorialCoach показывает текст шага.
##
## М17: Esc (и системная «Назад») — меню паузы (дерево на паузе): «Продолжить игру»,
## «Сдаться» (экран поражения, матч брошен), «Выйти в меню». Уведомления о достижениях.
##
## М19: стол работает с MatchSession — одиночная игра и обучение (LocalSession), сетевой
## матч на хосте (HostSession) или у гостя (ClientSession). Свой игрок — всегда место 0.
## В сети темп задаёт хост: стол каждый кадр зовёт update(), «Бросить» и «Дальше» —
## это «готов», пауза игру не останавливает, «Сдаться» и «Выйти» отдают место боту.
## Таймер хода — у портрета за TURN_WARNING_MS до конца.
##
## М21: в сети меню паузы — голос за паузу; матч встаёт, когда нажали все люди за столом
## (DESIGN.md §8б). «Шёпот Бездны» показывается у портретов: сколько у каждого соперника
## кубиков названной грани, в сообщении — у остальных и вместе со своими.
##
## М22: клики по столу (TableClicks) — всплеск по пустому месту и «живые» предметы из
## набора MatchSetup.table_props. Косметика, только у себя.
##
## М23: матч уровня кампании (MatchSetup.campaign_level) — модификаторы уровня в контроллере,
## оттенок фона, учёт в Campaign (не в ранге). На столе видно прилив, подсмотренный
## «Дурным глазом» кубик и возвращение Утопленника. После матча — «Дальше» / «К карте».

const HUMAN_ID := 0

var _setup: MatchSetup
## Матч глазами своего игрока (М19).
var _session: MatchSession
## Контроллер матча на этом устройстве (одиночная игра, обучение, хост); у гостя — null.
var _controller: MatchController
## В сети уже отправлено «готов» в этой фазе этого раунда: "фаза/раунд".
var _ready_key := ""
var _seats := {}                       # id → SeatView
var _peeked := {}                      # id → Array[int] — подсмотренные кубики соседа
## М21: итог своего «Шёпота Бездны» в этом раунде: грань (0 — не было) и счёт по игрокам.
var _whisper_face := 0
var _whisper_counts: Array[int] = []
## М21: последнее известное состояние сетевой паузы (для сообщений на столе).
var _net_paused := false
var _pause_votes_seen := 0
var _round_notes: PackedStringArray = []
var _round_title := ""
var _last_reveal: ChallengeReveal
var _spectating := false
var _defeat_shown := false

var _background: TextureRect
## М25: детали таверны уровня кампании (ребёнок фона — оттенок тот же); null — нет.
var _background_overlay: TextureRect
## М22: клики по столу и «живые» предметы.
var _clicks: TableClicks
var _seat_layer: Control
var _own: OwnHandView
var _feed: BidFeed
var _bid_caption: Label
var _bid_row: HBoxContainer
var _status_label: Label
## «Всего кубиков на столе» (М15, вместе с крупными числами у чашек).
var _total_label: Label
var _palifico_label: Label
## М23: «ПРИЛИВ: N» — грань-джокер этого раунда (кампания, «Логово»).
var _tide_label: Label
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
## М14: фон победы / поражения под панелью итога матча (виден, пока видна панель).
var _end_backdrop: TextureRect
var _timer: Timer
var _banner_timer: Timer
var _fx: TableFx
var _madness: MadnessOverlay
var _sound: TableSound
var _hint: HintPanel
var _pause: PauseMenu
var _toast: AchievementToast
var _coach: TutorialCoach
## Обучающий матч (М13); null — обычный матч.
var _director: TutorialDirector
## М19: таймер хода у портрета, сообщение о прерванном матче.
var _turn_timer: Label
var _abort_panel: ChoicePanel
## М24: реплики соперников — кто что скажет (логика) и облако у портрета.
var _barks: BarkDirector
var _bark_cloud: BarkCloud


func _ready() -> void:
	_build_ui()
	_connect_events()
	start_match(MatchSetup.take_pending())


## Начать матч (и «Реванш» — с теми же соперниками).
func start_match(setup: MatchSetup) -> void:
	_setup = setup
	_timer.stop()
	_ready_key = ""
	_spectating = false
	_defeat_shown = false
	_last_reveal = null
	_hide_popups()
	_end_panel.hide()
	_result_panel.hide()
	TableKit.clear(_messages)

	# Обучение статистику не трогает (М13).
	Stats.recording = not _setup.tutorial
	_director = null
	var first_player := PerudoRules.NO_PLAYER
	_session = null
	if _setup.session != null:
		# Сетевой матч (М19): сессию приготовило лобби.
		_session = _setup.session
		_setup.session = null
		_controller = (_session as LocalSession).controller if _session is LocalSession else null
		_session.seat_replaced.connect(_on_seat_replaced)
		_session.match_aborted.connect(_on_match_aborted)
		_session.pause_changed.connect(_on_pause_changed)
		_net_paused = false
		_pause_votes_seen = 0
		if _session.has_signal(&"command_rejected"):
			_session.connect(&"command_rejected", _on_command_rejected)
	elif _setup.tutorial:
		_controller = TutorialScript.make_controller(Rng.make_rng())
		# Режиссёр слушает контроллер раньше UI — UI видит уже новый шаг.
		_director = TutorialDirector.new(_controller)
		_director.step_changed.connect(_on_tutorial_step)
		first_player = TutorialScript.FIRST_PLAYER
	else:
		_setup.resolve_opponents(Rng.make_rng())
		var agents: Array[MatchAgent] = [HumanAgent.new()]
		for id in _setup.opponents:
			agents.append(BotAgent.new(BotRoster.by_id(id), Rng.make_rng()))
		_controller = MatchController.new(agents, _setup.rule_options(), Rng.make_rng())
		if _setup.is_campaign():
			CampaignModifiers.apply(_setup.campaign_level, _controller)
	if _session == null:
		_session = LocalSession.new(_controller)
	MatchEventBridge.connect_all(_session, Events)
	_build_seats()
	_clicks.set_props(_setup.table_props if _setup.table_props != null
			else TablePropSet.default_set())
	_setup_barks()
	_own.setup(_own_character())
	_end_panel.rematch_button.visible = not _is_net()
	_background.modulate = _setup.background_tint
	_set_background_overlay(_setup.background_overlay)
	_end_panel.set_campaign(_setup.is_campaign())
	if _director != null:
		_coach.setup(_director, _tutorial_target)
	else:
		_coach.hide()
	_begin_rank()
	_session.start_match(first_player)


## М25: детали таверны уровня кампании поверх фона.
func _set_background_overlay(texture: Texture2D) -> void:
	if texture == null:
		return
	_background_overlay = TextureRect.new()
	_background_overlay.texture = texture
	_background_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(_background_overlay)


## Учёт ранга за матч (М20, DESIGN.md §8в): обучение не считается, в сети — от 2 людей.
## М23: матч кампании — не в ранг, а в прогресс кампании.
func _begin_rank() -> void:
	if _setup.is_campaign():
		Campaign.begin(_setup.campaign_level.number)
	else:
		Campaign.skip()
	if _setup.tutorial or _setup.is_campaign():
		Ranks.skip()
	elif _is_net():
		var humans := 0
		for id in _session.player_count():
			var info := _session.seat(id)
			if info != null and info.kind != SeatInfo.Kind.BOT:
				humans += 1
		Ranks.begin_net(_session.player_count(), humans)
	else:
		var stars: Array[int] = []
		for id in _setup.opponents:
			var p := BotRoster.by_id(id)
			stars.append(p.stars if p != null else 2)
		Ranks.begin_single(_session.player_count(), stars)


func _exit_tree() -> void:
	Stats.recording = true
	_barks.unlisten()
	if _is_net():
		_session.leave()
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false


# --- Построение ------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_background = TextureRect.new()
	_background.texture = Sprites.background()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	# М22: сразу над фоном — всё, что выше, забирает свои клики само.
	_clicks = TableClicks.new()
	_clicks.setup(func() -> bool: return _madness != null and _madness.is_active())
	add_child(_clicks)

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
	_status_label = TableKit.backed_label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_box.add_child(_status_label)
	_palifico_label = TableKit.label("TABLE_PALIFICO", TableKit.TEXT_MAGIC,
			HORIZONTAL_ALIGNMENT_CENTER)
	TableKit.set_backing(_palifico_label)
	TermTips.attach(_palifico_label, &"PALIFICO")
	_palifico_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_box.add_child(_palifico_label)
	_tide_label = TableKit.label("", TableKit.TEXT_MAGIC, HORIZONTAL_ALIGNMENT_CENTER)
	TableKit.set_backing(_tide_label)
	_tide_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tide_label.hide()
	status_box.add_child(_tide_label)
	_total_label = TableKit.backed_label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_total_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_box.add_child(_total_label)
	_roll_button = TableKit.button("TABLE_ROLL", Sprites.ButtonKind.BID)
	_roll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll_button.pressed.connect(_on_roll)
	_roll_button.set_meta(Sound.SILENT_META, true)    # озвучен броском
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
	_bid_button = _silent(_action_button(row1, "ACTION_BID", Sprites.ButtonKind.BID, _on_bid))
	_liar_button = _silent(_action_button(row1, "ACTION_LIAR", Sprites.ButtonKind.LIAR,
			_on_challenge.bind(MatchAction.Kind.DUDO)))
	_calza_button = _silent(_action_button(row1, "ACTION_CALZA", Sprites.ButtonKind.CALZA,
			_on_challenge.bind(MatchAction.Kind.CALZA)))
	var row2 := TableKit.hbox(4)
	controls.add_child(row2)
	_accuse_button = _action_button(row2, "ACCUSE", Sprites.ButtonKind.ACCUSE, _on_accuse)
	_accuse_button.icon = Sprites.texture(Sprites.ICON_ACCUSE)
	_tricks_button = _action_button(row2, "ACTION_TRICKS", Sprites.ButtonKind.PLAIN, _on_tricks)
	_tricks_button.icon = Sprites.trick_icon(Cheat.Kind.SLEIGHT)
	# Подсказки к терминам на кнопках (М13, доп.).
	TermTips.attach(_bid_button, &"BID")
	TermTips.attach(_liar_button, &"LIAR")
	TermTips.attach(_calza_button, &"CALZA")
	TermTips.attach(_accuse_button, &"ACCUSE")
	TermTips.attach(_tricks_button, &"TRICK")

	# Эффекты (М10): над столом, под всплывающими панелями.
	_madness = MadnessOverlay.new()
	_fx = TableFx.new()
	_fx.setup(_fx_target, _speed, self, _madness)
	add_child(_fx)
	add_child(_madness)
	# М24: облако реплики — над столом и Безумием, под всплывающими панелями.
	_bark_cloud = BarkCloud.new()
	add_child(_bark_cloud)
	_barks = BarkDirector.new(Rng.make_rng())
	_barks.bark.connect(_on_bark)
	# Звук (М12).
	_sound = TableSound.new()
	_sound.setup(_speed)
	add_child(_sound)

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
	_end_backdrop = TextureRect.new()
	_end_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_backdrop.hide()
	add_child(_end_backdrop)
	_end_panel = MatchEndPanel.new()
	_end_panel.spectate_pressed.connect(_on_spectate)
	_end_panel.rematch_pressed.connect(_on_rematch)
	_end_panel.menu_pressed.connect(_on_menu)
	add_child(_end_panel)
	_end_panel.visibility_changed.connect(_on_end_panel_visibility)
	_accuse_menu.cancelled.connect(_refresh)
	_trick_menu.cancelled.connect(_refresh)
	# М13: тренер обучения и подсказки — поверх всего.
	_coach = TutorialCoach.new()
	add_child(_coach)
	_hint = HintPanel.new()
	add_child(_hint)
	# М19: таймер хода у портрета и сообщение о прерванном сетевом матче.
	_turn_timer = TableKit.backed_label("", TableKit.TEXT_ALERT, HORIZONTAL_ALIGNMENT_CENTER)
	_turn_timer.size = TableLayout.TURN_TIMER_SIZE
	_turn_timer.hide()
	add_child(_turn_timer)
	_abort_panel = ChoicePanel.new()
	_abort_panel.show_cancel = false
	_abort_panel.picked.connect(_on_abort_picked)
	add_child(_abort_panel)
	# М17: уведомления о достижениях и пауза — поверх всего.
	_toast = AchievementToast.new()
	add_child(_toast)
	_pause = PauseMenu.new()
	_pause.resume_pressed.connect(resume)
	_pause.surrender_pressed.connect(surrender)
	_pause.quit_pressed.connect(_on_pause_quit)
	add_child(_pause)

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


## Кнопка, у которой вместо щелчка звучит само действие (ставка, «Ложь!», «Точно!»).
func _silent(b: Button) -> Button:
	b.set_meta(Sound.SILENT_META, true)
	return b


## Соперники по кругу слева направо: следующий после игрока — первый слева.
func _build_seats() -> void:
	TableKit.clear(_seat_layer)
	_seats.clear()
	_peeked.clear()
	_clear_whisper()
	var positions := TableLayout.seat_positions(_session.player_count() - 1)
	var seat_rects: Array[Rect2i] = []
	for id in range(1, _session.player_count()):
		var seat := SeatView.new()
		seat.setup(id, _character(id), _name(id))
		seat.position = positions[id - 1]
		_seat_layer.add_child(seat)
		_seats[id] = seat
		seat_rects.append(Rect2i(positions[id - 1], TableLayout.SEAT_SIZE))
	_clicks.set_blocked_rects(seat_rects)


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
	Events.player_rescued.connect(_on_player_rescued)
	Events.die_watched.connect(_on_die_watched)
	Events.phase_changed.connect(_on_phase_changed)
	Events.locale_changed.connect(_on_locale_changed)
	_barks.listen(Events)
	Settings.changed.connect(_on_setting_changed)


# --- Команды игрока ------------------------------------------------------------

func _on_roll() -> void:
	if not _tutorial_allows(TutorialStep.Command.ROLL):
		return
	_hide_popups()
	_mark_ready()
	_session.roll(_director.preset_hands() if _director != null else [])
	_refresh()


func _on_bid() -> void:
	if _bid_input.is_legal() and _tutorial_allows_bid():
		_hide_popups()
		_session.submit_action(HUMAN_ID, _bid_input.action())


func _on_challenge(kind: MatchAction.Kind) -> void:
	if _director != null and (kind != MatchAction.Kind.DUDO
			or not _director.allows(TutorialStep.Command.LIAR)):
		return
	_hide_popups()
	var action := MatchAction.dudo() if kind == MatchAction.Kind.DUDO else MatchAction.calza()
	_session.submit_action(HUMAN_ID, action)


func _on_accuse() -> void:
	if not _tutorial_allows(TutorialStep.Command.ACCUSE):
		return
	_trick_menu.hide()
	_with_hint(Stats.FLAG_HINT_ACCUSE, _open_accuse)


func _open_accuse() -> void:
	var view := _session.view_for(HUMAN_ID)
	var choices: Array[ChoicePanel.Choice] = []
	for id in range(1, _session.player_count()):
		if _session.is_active(id):
			var ok := view.can_accuse(id) and (_director == null or _director.allows_accuse(id))
			var c := ChoicePanel.Choice.new(_name(id), id, Sprites.texture(Sprites.ICON_EVIDENCE)
					if view.evidence[id] > 0 else null, ok)
			choices.append(c)
	_accuse_menu.open(tr("TABLE_ACCUSE_TITLE"), choices, 1, tr("TABLE_ACCUSE_FOOTER")
			% [CheatBalance.CAUGHT_DICE_PENALTY, CheatBalance.FALSE_ACCUSATION_PENALTY])
	_refresh()


func _on_accuse_picked(value: Variant) -> void:
	_accuse_menu.hide()
	if _director != null and not _director.allows_accuse(int(value)):
		_refresh()
		return
	_session.submit_action(HUMAN_ID, MatchAction.accuse(int(value)))


func _on_tricks() -> void:
	if not _tutorial_allows(TutorialStep.Command.TRICK):
		return
	_accuse_menu.hide()
	_with_hint(Stats.FLAG_HINT_TRICKS, _open_tricks)


func _open_tricks() -> void:
	_trick_menu.only_kinds.clear()
	if _director != null:
		_trick_menu.only_kinds.append(_director.step().trick)
	_trick_menu.open_for(_session.view_for(HUMAN_ID), _name, _trick_denial)
	_refresh()


## Почему трюк нельзя: контроллер, а в обучении — ещё и сценарий (не тот трюк / цель).
func _trick_denial(action: CheatAction) -> CheatRules.Denied:
	var denied := _session.cheat_denial(HUMAN_ID, action)
	if denied == CheatRules.Denied.OK and _director != null:
		if not _director.allows_trick(action.kind):
			return CheatRules.Denied.WRONG_PHASE
		if action.target_id != CheatAction.NONE \
				and not _director.allows_trick_target(action.target_id):
			return CheatRules.Denied.BAD_TARGET
	return denied


func _on_cheat_chosen(action: CheatAction) -> void:
	if _trick_denial(action) != CheatRules.Denied.OK:
		_add_message(tr("TABLE_TRICK_DENIED"), TableKit.TEXT_ALERT)
		_refresh()
		return
	_session.submit_cheat(HUMAN_ID, action)
	_refresh()


func _on_cup() -> void:
	var view := _session.view_for(HUMAN_ID)
	if view == null:
		return
	if view.cup_open:
		_session.close_cup(HUMAN_ID)
	else:
		_session.open_cup(HUMAN_ID)


func _on_continue() -> void:
	_result_panel.hide()
	if _director != null:
		_director.notify_continue()
		if _director.is_finished():
			_coach.show_finish()
			_refresh()
			return
	match _session.phase:
		MatchController.Phase.MATCH_OVER:
			_show_match_end()
		MatchController.Phase.ROUND_END:
			if not _session.is_active(HUMAN_ID) and not _defeat_shown:
				_show_defeat()
			else:
				_mark_ready()
				_session.next_round()
				_refresh()


func _on_spectate() -> void:
	_end_panel.hide()
	_spectating = true
	if _session.phase == MatchController.Phase.ROUND_END:
		_session.next_round()
	_schedule()


func _on_rematch() -> void:
	start_match(_setup)


func _on_menu() -> void:
	_timer.stop()
	# Вышел посреди матча — как «Сдаться» (М20); после места ничего не меняет.
	Ranks.forfeit()
	Campaign.forfeit()
	_set_paused(false)
	if _is_net():
		_session.leave()
	# М23: из кампании — на карту (после победы там ждёт сцена с Хобом).
	ScreenNav.go(ScreenNav.CAMPAIGN if _setup != null and _setup.is_campaign()
			else ScreenNav.MAIN_MENU)


# --- Пауза (М17) -----------------------------------------------------------------

## Esc: сначала закрывает открытое меню обвинения / трюков, иначе открывает паузу.
## Открытую паузу закрывает она сама (она работает и на паузе дерева).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _pause != null and _pause.visible:
			resume()
		else:
			_on_back()


func _on_back() -> void:
	if _accuse_menu.visible:
		_accuse_menu.cancel()
	elif _trick_menu.visible:
		_trick_menu.cancel()
	else:
		open_pause()


func open_pause() -> void:
	_set_paused(true)
	_pause.open(can_surrender())
	if _is_net():
		_session.request_pause(true)
	_refresh_pause_status()


func _process(_delta: float) -> void:
	if _is_net():
		_session.update()
		_update_turn_timer()


func resume() -> void:
	_pause.hide()
	_set_paused(false)
	if _is_net():
		_session.request_pause(false)


## М21: сетевая пауза — сколько людей нажали Esc, встал ли матч.
func _on_pause_changed(paused: bool, votes: int, voters: int) -> void:
	if paused and not _net_paused:
		_add_message(tr("TABLE_MSG_PAUSED"), TableKit.TEXT_MAGIC)
	elif _net_paused and not paused:
		_add_message(tr("TABLE_MSG_UNPAUSED"), TableKit.TEXT_MAGIC)
	elif not paused and votes > _pause_votes_seen and not _pause.visible:
		_add_message(tr("TABLE_MSG_PAUSE_ASK") % [votes, voters], TableKit.TEXT_MAGIC)
	_net_paused = paused
	_pause_votes_seen = votes
	_refresh_pause_status()


func _refresh_pause_status() -> void:
	if not _is_net():
		_pause.set_status("")
		return
	var pv := _session.pause_votes()
	if _session.is_match_paused():
		_pause.set_status(tr("PAUSE_NET_ON"))
	elif pv.y > 0:
		_pause.set_status(tr("PAUSE_NET_WAIT") % [pv.x, pv.y])
	else:
		_pause.set_status(tr("PAUSE_NET_RUNNING"))


func is_paused() -> bool:
	return _pause.visible


## Сдаться можно, пока игрок в матче: не выбыл, матч не кончился, не обучение.
func can_surrender() -> bool:
	return _session != null and _director == null and not _end_panel.visible \
			and _session.phase != MatchController.Phase.MATCH_OVER \
			and _session.is_active(HUMAN_ID) and _in_control()


## Сдаться: матч брошен (победы нет, достижения «за матч» не даются), экран поражения
## с «Реваншем» и «Меню».
func surrender() -> void:
	resume()
	if not can_surrender():
		return
	_timer.stop()
	_hide_popups()
	_result_panel.hide()
	_spectating = false
	_defeat_shown = true
	Ranks.forfeit()
	Campaign.forfeit()
	if _is_net():
		# Место — боту, матч идёт дальше; победа бота за игрока не засчитывается.
		_session.surrender()
		Stats.recording = false
	_end_panel.show_result(false, Sprites.portrait(_own_character(), true),
			tr("TABLE_SURRENDERED"), _is_net())
	_show_rank()


func _on_pause_quit() -> void:
	resume()
	_on_menu()


## В сети пауза игру не останавливает (DESIGN.md §8б): меню просто поверх стола.
func _set_paused(on: bool) -> void:
	if is_inside_tree() and not (on and _is_net()):
		get_tree().paused = on


# --- Темп --------------------------------------------------------------------------

## Место игрока для эффектов: соперник — SeatView, игрок — OwnHandView; null — нет такого.
func _fx_target(player_id: int) -> Control:
	if _session == null or player_id < 0 or player_id >= _session.player_count():
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
	if _session == null or _end_panel.visible:
		return -1.0
	var human_active := _session.is_active(HUMAN_ID)
	match _session.phase:
		MatchController.Phase.BIDDING:
			# В сети ботов и чужие ходы ведёт хост.
			if not _is_net() and not _session.is_waiting_for_human():
				return TableLayout.BOT_TURN_DELAY
		MatchController.Phase.ROLL:
			if not _is_net() and not human_active:
				return TableLayout.AUTO_ROUND_DELAY * 0.5
		MatchController.Phase.ROUND_END, MatchController.Phase.MATCH_OVER:
			if _spectating and _result_panel.visible:
				return TableLayout.AUTO_ROUND_DELAY
	return -1.0


func _on_timer() -> void:
	if _auto_delay() < 0.0:
		return
	match _session.phase:
		MatchController.Phase.BIDDING, MatchController.Phase.ROLL:
			_session.advance_auto()
		_:
			_result_panel.press_continue()


# --- События матча -----------------------------------------------------------

func _on_round_started(_round_number: int, _starter_id: int, is_palifico: bool) -> void:
	_round_notes.clear()
	_round_title = ""
	_last_reveal = null
	_peeked.clear()
	_clear_whisper()
	_feed.clear_entries()
	# В сети хост начинает раунд и без «Дальше» (вышло время) — итог прошлого убираем.
	_result_panel.hide()
	for seat: SeatView in _seats.values():
		seat.hide_bubble()
		seat.set_cup_open(false)
		seat.set_peeked([])
		if not _session.is_active(seat.player_id):
			seat.set_dice_count(0)
	if is_palifico:
		_show_banner("TABLE_PALIFICO")
	var tide := _session.round_rules.tide()
	if tide != RoundRules.NO_TIDE:
		_show_banner(tr("TABLE_TIDE") % tide)
		_add_message(tr("TABLE_MSG_TIDE") % tide, TableKit.TEXT_MAGIC)
	_refresh()
	_schedule()


func _on_dice_rolled(_round_number: int) -> void:
	_refresh()


func _on_turn_started(player_id: int) -> void:
	if player_id == HUMAN_ID:
		_bid_input.reset_to_lowest(_session.view_for(HUMAN_ID))
		_preset_tutorial_bid()
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


## М23 «Мёртвая рука»: потерял последний кубик, но вернулся со дна.
func _on_player_rescued(player_id: int, dice: int) -> void:
	var text := tr("TABLE_NOTE_RESCUED") % [_name(player_id), dice]
	_round_notes.append(text)
	_add_message(text, TableKit.TEXT_MAGIC)


## М23 «Дурной глаз»: соперник видит свой кубик игрока — метка на кубике и сообщение.
func _on_die_watched(watcher_id: int, target_id: int, die_index: int) -> void:
	if target_id != HUMAN_ID:
		return
	_add_message(tr("TABLE_MSG_EVIL_EYE") % [_name(watcher_id), die_index + 1],
			TableKit.TEXT_MAGIC)
	_refresh()


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
			text = _whisper_text(outcome)
	_add_message(text, TableKit.TEXT_MAGIC)
	_refresh()


## «Шёпот Бездны» (М21): у остальных N × грань, со своими M, по игрокам — у портретов.
func _whisper_text(outcome: CheatOutcome) -> String:
	var face := outcome.action.face
	if outcome.whisper_counts.size() != _session.player_count():
		return tr("TABLE_MSG_WHISPER") % [outcome.whisper_count, face]
	_whisper_face = face
	_whisper_counts = outcome.whisper_counts.duplicate()
	var text := tr("TABLE_MSG_WHISPER_FULL") % [outcome.whisper_count, face,
			outcome.whisper_count + _whisper_counts[HUMAN_ID]]
	if face != PerudoRules.JOKER_FACE and _session.round_rules.ones_wild():
		text += " " + tr("TABLE_MSG_WHISPER_WILD")
	var tide := _session.round_rules.tide()
	if face != PerudoRules.JOKER_FACE and tide != RoundRules.NO_TIDE and tide != face:
		text += " " + tr("TABLE_MSG_WHISPER_TIDE") % tide

	return text


func _clear_whisper() -> void:
	_whisper_face = 0
	_whisper_counts.clear()


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
		_with_hint(Stats.FLAG_HINT_MADNESS)
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
	elif _seats.has(player_id) and _session.phase == MatchController.Phase.BIDDING:
		_seats[player_id].set_cup_open(is_open)


func _on_phase_changed(_phase: int) -> void:
	if _session.phase != MatchController.Phase.BIDDING:
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


func _on_end_panel_visibility() -> void:
	_end_backdrop.visible = _end_panel.visible
	if _end_panel.visible:
		_end_backdrop.texture = Sprites.background(Sprites.Background.VICTORY
				if _end_panel.is_won() else Sprites.Background.DEFEAT)


func _show_defeat() -> void:
	_defeat_shown = true
	_end_panel.show_result(false, Sprites.portrait(_own_character(), true),
			tr("TABLE_DEFEAT_OUT"), true)
	_show_rank()


func _show_match_end() -> void:
	_timer.stop()
	var winner := _session.winner_id
	# Сдавшийся в сети не побеждает, даже если победил бот на его месте.
	var won := winner == HUMAN_ID and _in_control()
	var portrait: Texture2D
	var subtitle: String
	if won:
		portrait = Sprites.portrait(_own_character())
		subtitle = tr("TABLE_VICTORY_TEXT")
	else:
		portrait = Sprites.portrait(_character(winner))
		subtitle = tr("TABLE_DEFEAT_WINNER") % _name(winner)
	_end_panel.show_result(won, portrait, subtitle, false)
	_show_rank()


## Итог ранга под результатом матча (М20). Сетевой матч без второго человека — пояснение.
func _show_rank() -> void:
	if _setup.tutorial:
		_end_panel.show_rank(null, "")
		return
	var change := Ranks.last_change()
	_end_panel.show_rank(change, tr("RANK_NOT_COUNTED") if change == null and _is_net() else "")


# --- Отображение ---------------------------------------------------------------

func _refresh() -> void:
	if _session == null:
		return
	var view := _session.view_for(HUMAN_ID)
	if view == null:
		# Гость: первое событие от хоста ещё не пришло — команд нет.
		_roll_button.hide()
		_palifico_label.hide()
		_total_label.hide()
		return
	var phase := _session.phase
	var my_turn := _my_turn()
	var human_active := _session.is_active(HUMAN_ID)
	var in_control := _in_control()

	# М15: «Всего кубиков на столе» — от броска до конца раунда.
	var show_total := phase == MatchController.Phase.BIDDING
	for seat: SeatView in _seats.values():
		var id := seat.player_id
		seat.set_dice_count(view.dice_counts[id])
		seat.set_evidence(view.evidence[id])
		seat.set_mad(view.mad[id])
		seat.set_active(phase == MatchController.Phase.BIDDING and _session.current_player == id)
		var peeked: Array[int] = []
		peeked.assign(_peeked.get(id, []))
		seat.set_peeked(peeked)
		var whispered := _whisper_face > 0 and id < _whisper_counts.size() 				and _session.is_active(id)
		seat.set_whisper(_whisper_face if whispered else 0,
				_whisper_counts[id] if whispered else 0)
	_own.set_active(my_turn)
	if human_active and view.is_mad() and not _madness.is_active():
		_madness.set_active(true)
	_own.show_view(view if human_active else null,
			phase == MatchController.Phase.BIDDING and human_active and in_control)

	_refresh_bid(view)
	_status_label.text = _status_text()
	_total_label.visible = show_total
	if show_total:
		_total_label.text = tr("TABLE_TOTAL_DICE") % _session.total_dice()
	_palifico_label.visible = _session.round_rules.is_palifico \
			and phase != MatchController.Phase.MATCH_OVER
	var tide := _session.round_rules.tide()
	_tide_label.visible = tide != RoundRules.NO_TIDE and phase != MatchController.Phase.MATCH_OVER
	if _tide_label.visible:
		_tide_label.text = tr("TABLE_TIDE") % tide

	_roll_button.visible = phase == MatchController.Phase.ROLL and human_active and in_control \
			and not _is_ready_sent()

	_bid_input.set_view(view, my_turn)
	_bid_button.disabled = not (my_turn and _bid_input.is_legal())
	_liar_button.disabled = not (my_turn and view.can_dudo())
	_calza_button.visible = _session.options.calza_enabled
	_calza_button.disabled = not (my_turn and view.can_calza())
	_accuse_button.disabled = not (my_turn and _can_accuse_anyone(view))
	_tricks_button.disabled = not (human_active and in_control and not view.is_mad()
			and view.cheat_window != CheatRules.CheatWindow.CLOSED)
	_refresh_tutorial()


## Обучение (М13): пускаем только ту команду, которую ждёт шаг; тренер — по шагу.
func _refresh_tutorial() -> void:
	if _director == null:
		return
	_roll_button.disabled = not _director.allows(TutorialStep.Command.ROLL)
	_bid_button.disabled = _bid_button.disabled or not _tutorial_allows_bid()
	_liar_button.disabled = _liar_button.disabled \
			or not _director.allows(TutorialStep.Command.LIAR)
	_calza_button.disabled = true
	_accuse_button.disabled = _accuse_button.disabled \
			or not _director.allows(TutorialStep.Command.ACCUSE)
	_tricks_button.disabled = _tricks_button.disabled \
			or not _director.allows(TutorialStep.Command.TRICK)
	_coach.refresh(_accuse_menu.visible or _trick_menu.visible)


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
	for id in range(1, _session.player_count()):
		if view.can_accuse(id):
			return true
	return false


func _status_text() -> String:
	var text := tr("TABLE_ROUND") % _session.round_number + " · "
	match _session.phase:
		MatchController.Phase.ROLL:
			if _is_ready_sent():
				return text + tr("NET_STATUS_WAITING")
			if _session.is_active(HUMAN_ID) and _in_control():
				return text + tr("TABLE_STATUS_ROLL")
			return text + tr("TABLE_STATUS_ROLLING")
		MatchController.Phase.BIDDING:
			if _my_turn():
				return text + tr("TABLE_STATUS_YOUR_TURN")
			return text + tr("TABLE_STATUS_TURN") % _name(_session.current_player)
		MatchController.Phase.ROUND_END:
			if _is_ready_sent():
				return text + tr("NET_STATUS_WAITING")
			return text + tr("TABLE_STATUS_ROUND_END")
		MatchController.Phase.MATCH_OVER:
			return tr("TABLE_STATUS_MATCH_OVER")
	return ""


func _add_message(text: String, color := TableKit.TEXT) -> void:
	var l := TermLabel.make(color, false, TableLayout.MESSAGES_RECT.size.x - 12)
	l.set_term_text(text)
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


# --- Подсказки и обучение (М13) -------------------------------------------------

## Подсказка при первом использовании (в обучении — нет), затем then.
func _with_hint(flag: StringName, then: Callable = Callable()) -> void:
	if _director == null and HintPanel.wants(flag):
		_hint.open(flag, then)
	elif then.is_valid():
		then.call()


func _tutorial_allows(command: TutorialStep.Command) -> bool:
	return _director == null or _director.allows(command)


func _tutorial_allows_bid() -> bool:
	return _director == null or _director.allows_bid(_bid_input.action().bid)


## В обучении ввод ставки сразу показывает ставку, которую просит шаг.
func _preset_tutorial_bid() -> void:
	if _director == null or _director.expected_bid() == null:
		return
	var bid := _director.expected_bid()
	_bid_input.set_bid(bid.quantity, bid.face)


func _on_tutorial_step(_index: int) -> void:
	_preset_tutorial_bid()
	_refresh()


## Кнопка стола, которую подсвечивает тренер для команды шага.
func _tutorial_target(command: TutorialStep.Command) -> Control:
	match command:
		TutorialStep.Command.ROLL:
			return _roll_button
		TutorialStep.Command.BID:
			return _bid_button
		TutorialStep.Command.LIAR:
			return _liar_button
		TutorialStep.Command.TRICK:
			return _tricks_button
		TutorialStep.Command.ACCUSE:
			return _accuse_button
	return null


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
	var info := _session.seat(player_id) if _session != null else null
	if info == null:
		return str(player_id)
	if info.kind == SeatInfo.Kind.BOT:
		var bot := BotRoster.by_id(info.bot_id)
		return tr(bot.name_key) if bot != null else str(player_id)
	var person := info.player_name if info.player_name != "" \
			else tr("NET_NAMELESS") % (player_id + 1)
	# Место человека перешло боту (М19).
	return tr("NET_NAME_REPLACED") % person if info.replaced else person


# --- Места и сеть (М19) -------------------------------------------------------------

## Чей портрет на месте: персонаж бота или портрет человека.
func _character(player_id: int) -> StringName:
	if player_id == HUMAN_ID:
		return _own_character()
	var info := _session.seat(player_id)
	if info == null:
		return Sprites.PLAYER_PORTRAITS[0]
	if info.kind == SeatInfo.Kind.BOT:
		return info.bot_id
	return _human_portrait(info)


static func _human_portrait(info: SeatInfo) -> StringName:
	return Sprites.PLAYER_PORTRAITS[clampi(info.portrait, 0, Sprites.PLAYER_PORTRAITS.size() - 1)]


## Свой портрет: в сети — выбранный для сетевой игры, иначе — с экрана выбора соперников.
func _own_character() -> StringName:
	if _is_net():
		var info := _session.seat(HUMAN_ID)
		if info != null:
			return _human_portrait(info)
	return _setup.player_portrait


func _is_net() -> bool:
	return _session != null and _session.is_networked()


## Своё место за своим игроком (в сети после «Сдаться» его ведёт бот).
func _in_control() -> bool:
	var info := _session.seat(HUMAN_ID) if _session != null else null
	return info == null or info.is_human()


## Свой ход: ставка, «Ложь!», «Точно!», обвинение.
func _my_turn() -> bool:
	return _session.phase == MatchController.Phase.BIDDING \
			and _session.current_player == HUMAN_ID and _session.is_waiting_for_human() \
			and _in_control()


## В сети «Бросить» и «Дальше» — это «готов»: запомнить, чтобы ждать остальных.
func _mark_ready() -> void:
	if _is_net():
		_ready_key = _phase_key()


func _is_ready_sent() -> bool:
	return _is_net() and _ready_key == _phase_key()


func _phase_key() -> String:
	return "%d/%d" % [_session.phase, _session.round_number]


## Таймер хода у портрета: за TURN_WARNING_MS до автохода (DESIGN.md §8б).
func _update_turn_timer() -> void:
	var left := _session.turn_time_left_msec()
	var target: Control = null
	if left >= 0 and left <= NetBalance.TURN_WARNING_MS and not _end_panel.visible:
		match _session.phase:
			MatchController.Phase.BIDDING:
				target = _fx_target(_session.current_player)
			MatchController.Phase.ROLL:
				if _session.is_active(HUMAN_ID) and _in_control() and not _is_ready_sent():
					target = _own
	if target == null:
		_turn_timer.hide()
		return
	_turn_timer.text = str(ceili(left / 1000.0))
	var anchor: Vector2 = target.call(&"fx_point", &"portrait_base")
	_turn_timer.position = Vector2i(int(anchor.x) - TableLayout.TURN_TIMER_SIZE.x / 2,
			int(anchor.y) - TableLayout.TURN_TIMER_SIZE.y)
	_turn_timer.show()


## Что показывает таймер хода ("" — скрыт).
func turn_timer_text() -> String:
	return _turn_timer.text if _turn_timer.visible else ""


func _on_seat_replaced(player_id: int) -> void:
	_barks.set_speaker(player_id, _bark_character(player_id))
	if player_id != HUMAN_ID:
		_add_message(tr("NET_MSG_SEAT_BOT") % _name(player_id), TableKit.TEXT_MUTED)
		if _seats.has(player_id):
			_seats[player_id].set_display_name(_name(player_id))
	_refresh()


## Хост вышел или связь пропала: сообщение и выход в меню.
func _on_match_aborted(reason: int) -> void:
	_timer.stop()
	Ranks.abort()
	_hide_popups()
	_pause.hide()
	_result_panel.hide()
	_end_panel.hide()
	_turn_timer.hide()
	var choices: Array[ChoicePanel.Choice] = [ChoicePanel.Choice.new("TABLE_MENU", true)]
	_abort_panel.open(tr("NET_ABORT_TITLE"), choices, 1, tr(NetText.abort_key(reason)))


func _on_abort_picked(_value: Variant) -> void:
	_abort_panel.hide()
	_on_menu()


func is_match_aborted() -> bool:
	return _abort_panel.visible


func _on_command_rejected(_result: int) -> void:
	_add_message(tr("NET_MSG_REJECTED"), TableKit.TEXT_ALERT)
	_refresh()


# --- Реплики соперников (М24) ------------------------------------------------------

## Кто за столом говорит: боты (в сети тоже только боты), не человек и не обучение.
func _setup_barks() -> void:
	_bark_cloud.dismiss()
	var speakers: Array[StringName] = []
	for id in _session.player_count():
		speakers.append(_bark_character(id))
	_barks.set_speakers(speakers)
	_barks.lines.story = _setup.bark_story
	_barks.enabled = _barks_allowed()


func _barks_allowed() -> bool:
	return Settings.get_value(&"barks") and not _setup.tutorial


## Персонаж бота на месте или &"" — место не говорит (человек, его место у бота).
func _bark_character(player_id: int) -> StringName:
	if player_id == HUMAN_ID or _session == null:
		return &""
	var info := _session.seat(player_id)
	if info == null or info.kind != SeatInfo.Kind.BOT:
		return &""
	return info.bot_id


func _on_bark(b: BarkDirector.Bark) -> void:
	var seat: SeatView = _seats.get(b.speaker_id)
	if seat == null:
		return
	_bark_cloud.show_bark(b, seat)


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key != &"barks" or _setup == null:
		return
	_barks.enabled = _barks_allowed()
	if not _barks.enabled:
		_bark_cloud.dismiss()
		_barks.dismiss()


## Облако реплики (тесты).
func bark_cloud() -> BarkCloud:
	return _bark_cloud


func bark_director() -> BarkDirector:
	return _barks
