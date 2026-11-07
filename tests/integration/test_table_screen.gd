extends GutTest
## М9: игровой стол. Матч мышью (кнопками) до конца, трюки и обвинение через меню,
## чашка, вскрытие, экраны победы и поражения, «Досмотреть», «Реванш».

const Scene := preload("res://scenes/table.tscn")
const Phase := MatchController.Phase


func before_each() -> void:
	MatchSetup.pending = null
	# Подсказки при первом использовании (М13) уже показаны — меню открываются сразу.
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)


func after_each() -> void:
	Stats.clear_flags()


func _table(seed_value: int, opponents: Array[StringName] = [], count := 3) -> Control:
	Rng.set_master_seed(seed_value)
	var setup := MatchSetup.from_settings()
	setup.opponents = opponents
	setup.opponent_count = count
	MatchSetup.pending = setup
	return add_child_autofree(Scene.instantiate())


## Один шаг «как игрок мышью» или ожидание бота. human — что делать в свой ход.
func _step(screen: Control, human: Callable) -> void:
	var mc: MatchController = screen._controller
	if screen._end_panel.visible:
		if screen._end_panel.spectate_button.visible:
			screen._end_panel.spectate_button.pressed.emit()
	elif screen._result_panel.visible:
		screen._result_panel.press_continue()
	elif screen._roll_button.visible:
		screen._roll_button.pressed.emit()
	elif mc.is_waiting_for_human():
		human.call()
	else:
		screen._on_timer()


func _until_human_turn(screen: Control) -> void:
	var mc: MatchController = screen._controller
	var steps := 0
	while not mc.is_waiting_for_human() and steps < 500:
		steps += 1
		_step(screen, func() -> void: pass)


## Игрок: «Ложь!» через ход, иначе — минимальная ставка, подставленная вводом.
func _simple_human(screen: Control) -> Callable:
	var counter := [0]
	return func() -> void:
		counter[0] += 1
		if not screen._liar_button.disabled and (counter[0] % 3 == 0 or screen._bid_button.disabled):
			screen._liar_button.pressed.emit()
		else:
			assert_false(screen._bid_button.disabled, "минимальная ставка доступна")
			screen._bid_button.pressed.emit()


func _play_to_end(screen: Control, human: Callable) -> void:
	var mc: MatchController = screen._controller
	var steps := 0
	while not (mc.phase == Phase.MATCH_OVER and screen._end_panel.visible) and steps < 8000:
		steps += 1
		_step(screen, human)
	assert_eq(mc.phase, Phase.MATCH_OVER)
	assert_true(screen._end_panel.visible, "экран итога матча")


func test_full_match_with_mouse_and_end_screen() -> void:
	for seed_value in [1, 2, 3]:
		var screen := _table(seed_value)
		var mc: MatchController = screen._controller
		assert_eq(mc.player_count(), 4, "по умолчанию игрок + 3 бота")
		assert_eq(screen._seats.size(), 3)
		_play_to_end(screen, _simple_human(screen))
		var won: bool = mc.winner_id == screen.HUMAN_ID
		assert_eq(screen._end_panel.is_won(), won)
		assert_false(screen._end_panel.spectate_button.visible, "матч окончен — досматривать нечего")
		assert_true(screen._end_panel.rematch_button.visible)
		assert_true(screen._end_panel.menu_button.visible)
		screen.queue_free()


func test_seats_show_public_info_only() -> void:
	var screen := _table(4, [&"sailor", &"witch", &"deep_one"])
	_until_human_turn(screen)
	var mc: MatchController = screen._controller
	for id in range(1, 4):
		var seat: SeatView = screen._seats[id]
		assert_eq(seat._dice_label.text, "×%d" % mc.dice_counts[id])
		assert_eq(seat._evidence_box.visible, mc.cheats.evidence[id] > 0)
		assert_eq(seat._peeked_row.get_child_count(), 0, "чужие кубики не видны")
	assert_eq(screen._seats[1].position.x < screen._seats[3].position.x, true,
			"соперники по кругу слева направо")


func test_own_dice_and_cup() -> void:
	var screen := _table(5)
	_until_human_turn(screen)
	var mc: MatchController = screen._controller
	var own: OwnHandView = screen._own
	assert_eq(own.shown_dice(), mc.view_for(0).own_dice, "открытая чашка — кубики видны")
	assert_true(own.is_cup_button_enabled())
	own.press_cup()
	assert_false(mc.view_for(0).cup_open)
	assert_true(own.shown_dice().is_empty(), "закрытая чашка кубики не показывает")
	own.press_cup()
	assert_true(mc.view_for(0).cup_open)
	assert_eq(own.shown_dice(), mc.hand_of(0))


func test_cup_closes_after_action_in_madness() -> void:
	var screen := _table(6)
	_until_human_turn(screen)
	var mc: MatchController = screen._controller
	mc.debug_set_sanity(0, 0)
	assert_true(screen._tricks_button.disabled, "в Безумии трюков нет")
	screen._bid_button.pressed.emit()
	if mc.phase == Phase.BIDDING:
		assert_false(mc.view_for(0).cup_open)
		assert_true(screen._own.shown_dice().is_empty())


func test_bid_input_counters_and_hint() -> void:
	var screen := _table(7)
	_until_human_turn(screen)
	var mc: MatchController = screen._controller
	var input: BidInput = screen._bid_input
	var view := mc.view_for(0)
	var lowest := view.lowest_bid()
	assert_eq([input.quantity, input.face], [lowest.quantity, lowest.face],
			"подставлена минимальная ставка")
	assert_false(screen._bid_button.disabled)
	input.shift_quantity(1)
	assert_eq(input.quantity, lowest.quantity + 1)
	assert_false(screen._bid_button.disabled)
	var before := input.face
	input.shift_face(1)
	assert_ne(input.face, before)
	assert_true(view.allowed_faces().has(input.face), "листаются только разрешённые грани")
	assert_gte(input.quantity, view.min_quantity_for_face(input.face), "количество подтянуто")
	assert_false(screen._bid_button.disabled)
	screen._bid_button.pressed.emit()
	assert_eq(mc.bid_history.back().bid.face, input.face)
	assert_eq(screen._feed.entry_count(), mc.bid_history.size(), "лента ставок")


func test_tricks_through_menu() -> void:
	var screen := _table(8)
	var mc: MatchController = screen._controller
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	var menu: TrickMenu = screen._trick_menu

	# Фаза броска: «Утяжелённая кость» через меню (трюк 3, грань 6).
	assert_eq(mc.phase, Phase.ROLL)
	assert_false(screen._tricks_button.disabled)
	screen._tricks_button.pressed.emit()
	assert_true(menu.visible)
	var list := menu.buttons()
	assert_eq(list.size(), Cheat.ALL.size())
	assert_true(list[Cheat.ALL.find(Cheat.Kind.PEEK)].disabled, "в броске — только Утяжелённая")
	list[Cheat.ALL.find(Cheat.Kind.LOADED_DIE)].pressed.emit()
	assert_eq(menu.step(), TrickMenu.Step.FACE)
	menu.buttons()[5].pressed.emit()
	assert_false(menu.visible)
	assert_eq(mc.cheats.sanity[0], CheatBalance.START_SANITY - Cheat.cost(Cheat.Kind.LOADED_DIE))
	screen._roll_button.pressed.emit()
	assert_eq(mc.hand_of(0)[MatchController.LOADED_DIE_INDEX], 6)

	# Свой ход: «Подглядеть» — сосед, кубик; итог виден у портрета.
	_until_human_turn(screen)
	screen._tricks_button.pressed.emit()
	menu.buttons()[Cheat.ALL.find(Cheat.Kind.PEEK)].pressed.emit()
	assert_eq(menu.step(), TrickMenu.Step.NEIGHBOR)
	var neighbor: int = mc.view_for(0).neighbors()[0]
	menu.buttons()[0].pressed.emit()
	assert_eq(menu.step(), TrickMenu.Step.DIE)
	menu.buttons()[0].pressed.emit()
	assert_false(menu.visible)
	assert_eq(screen._seats[neighbor]._peeked_row.get_child_count(), 1, "подсмотренный кубик")
	assert_gt(screen._messages.get_child_count(), 0, "секретный итог — в сообщениях")

	# Второй трюк за ход недоступен.
	screen._tricks_button.pressed.emit()
	for b: Button in menu.buttons():
		assert_true(b.disabled, "1 трюк за ход")
	menu.cancel()
	assert_false(menu.visible)


func test_accusation_through_menu_ends_round_with_summary() -> void:
	var screen := _table(9)
	_until_human_turn(screen)
	var mc: MatchController = screen._controller
	screen._accuse_button.pressed.emit()
	var menu: ChoicePanel = screen._accuse_menu
	assert_true(menu.visible)
	assert_eq(menu.buttons().size(), 3)
	watch_signals(mc)
	menu.buttons()[0].pressed.emit()
	assert_signal_emitted(mc, "accusation_made")
	assert_true(screen._result_panel.visible, "итог раунда после обвинения")
	assert_true(mc.phase == Phase.ROUND_END or mc.phase == Phase.MATCH_OVER)


func test_reveal_panel_after_liar() -> void:
	var screen := _table(10)
	var mc: MatchController = screen._controller
	var steps := 0
	while mc.last_reveal == null and steps < 500:
		steps += 1
		_step(screen, func() -> void:
			if not screen._liar_button.disabled:
				screen._liar_button.pressed.emit()
			else:
				screen._bid_button.pressed.emit())
	assert_not_null(mc.last_reveal)
	assert_true(screen._result_panel.visible)
	var phase_before := mc.phase
	assert_eq(screen._auto_delay(), -1.0, "итог ждёт «Дальше», пока игрок в игре")
	if phase_before == Phase.ROUND_END and mc.is_active(0):
		screen._result_panel.press_continue()
		assert_eq(mc.phase, Phase.ROLL, "«Дальше» — следующий раунд")


func test_defeat_spectate_and_rematch() -> void:
	# Игрок только оспаривает и ставит минимум — быстро проигрывает.
	var screen := _table(11, [&"deep_one", &"scholar", &"witch"])
	var mc: MatchController = screen._controller
	var steps := 0
	while mc.is_active(0) and steps < 3000:
		steps += 1
		_step(screen, func() -> void:
			if not screen._liar_button.disabled:
				screen._liar_button.pressed.emit()
			else:
				screen._bid_button.pressed.emit())
	if mc.phase == Phase.MATCH_OVER:
		pass_test("матч кончился вместе с выбыванием")
		return
	screen._result_panel.press_continue()
	assert_true(screen._end_panel.visible, "экран поражения")
	assert_false(screen._end_panel.is_won())
	assert_true(screen._end_panel.spectate_button.visible)
	screen._end_panel.spectate_button.pressed.emit()
	assert_true(screen._spectating)
	assert_almost_eq(screen._speed(), TableLayout.SPECTATE_SPEED * float(Settings.get_value(&"bot_speed")),
			0.001, "досмотр ×2")
	steps = 0
	while mc.phase != Phase.MATCH_OVER and steps < 5000:
		steps += 1
		assert_gt(screen._auto_delay(), 0.0, "досмотр идёт сам")
		screen._on_timer()
	assert_eq(mc.phase, Phase.MATCH_OVER)
	screen._on_timer()
	assert_true(screen._end_panel.visible)
	assert_false(screen._end_panel.spectate_button.visible)

	var opponents: Array[StringName] = screen._setup.opponents.duplicate()
	screen._end_panel.rematch_button.pressed.emit()
	var mc2: MatchController = screen._controller
	assert_ne(mc2, mc, "новый матч")
	assert_eq(mc2.phase, Phase.ROLL)
	assert_false(screen._end_panel.visible)
	for id in range(1, 4):
		assert_eq((mc2.agent(id) as BotAgent).personality.id, opponents[id - 1], "те же соперники")
	assert_eq(screen._seats.size(), 3)


func test_table_builds_for_all_player_counts_and_languages() -> void:
	var saved: String = Settings.get_value(&"locale")
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		for count in range(1, MatchController.MAX_PLAYERS):
			var screen := _table(20 + count, [], count)
			assert_eq(screen._seats.size(), count)
			for seat: SeatView in screen._seats.values():
				assert_gte(seat.position.x, 0.0)
				assert_lte(seat.position.x + TableLayout.SEAT_SIZE.x, float(TableLayout.SCREEN.x))
			screen.queue_free()
	Settings.set_value(&"locale", saved)


## Фразы о самом игроке — свои ключи, без «Вы впадает / Вы теряет».
func test_messages_about_the_player_use_second_person() -> void:
	var old_locale: String = Settings.get_value(&"locale")
	Settings.set_value(&"locale", "ru")
	var screen := _table(31)
	screen._on_madness_began(0)
	screen._on_evidence_shown(0)
	screen._on_dice_count_changed(0, 4, -1)
	screen._on_dice_count_changed(0, 5, 1)
	screen._on_player_eliminated(0)
	screen._on_accusation_made(0, 1, true)
	screen._on_accusation_made(2, 0, false)
	screen._on_cheat_failed(0, Cheat.Kind.PEEK)
	var texts: PackedStringArray = screen._round_notes.duplicate()
	for l: TermLabel in screen._messages.get_children():
		texts.append(l.plain_text())
	var all := "\n".join(texts)
	for bad in ["Вы впадает ", "Вы теряет ", "Вы возвращает ", "Вы выбывает!", "Вы обвиняет:",
			"жульничестве: Вы", "портрета: Вы", ": Вы —"]:
		assert_false(all.contains(bad), "нет «%s»" % bad)
	for good in ["Вы впадаете в Безумие", "Вы теряете 1", "Вы выбываете", "Вы обвиняете",
			"обвиняет вас", "Вы пойманы", "вашего портрета"]:
		assert_true(all.contains(good), "есть «%s»" % good)
	Settings.set_value(&"locale", old_locale)


# --- М15: крупные числа кубиков и подложки ---------------------------------------

func test_dice_count_badges_from_roll_to_round_end() -> void:
	Settings.set_value(&"show_dice_counts", true)
	var screen := _table(12, [&"sailor", &"witch", &"deep_one"])
	var mc: MatchController = screen._controller
	assert_eq(mc.phase, Phase.ROLL)
	assert_eq(screen._seats[1].count_badge_text(), "", "до броска чисел нет")
	assert_false(screen._total_label.visible)
	_until_human_turn(screen)
	for id in range(1, 4):
		assert_eq(screen._seats[id].count_badge_text(), str(mc.dice_counts[id]))
	assert_eq(screen._own.count_badge_text(), str(mc.dice_counts[0]))
	assert_true(screen._total_label.visible)
	assert_true(screen._total_label.text.contains(str(mc.total_dice())))
	var human := _simple_human(screen)
	var guard := 0
	while mc.phase == Phase.BIDDING and guard < 200:
		guard += 1
		_step(screen, human)
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_eq(screen._seats[1].count_badge_text(), "", "после конца раунда чисел нет")
	assert_eq(screen._own.count_badge_text(), "")
	assert_false(screen._total_label.visible)


func test_dice_count_badges_can_be_turned_off() -> void:
	Settings.set_value(&"show_dice_counts", false)
	var screen := _table(13)
	_until_human_turn(screen)
	assert_eq(screen._seats[1].count_badge_text(), "")
	assert_eq(screen._own.count_badge_text(), "")
	assert_false(screen._total_label.visible)
	assert_eq(screen._seats[1]._dice_label.text, "×5", "мелкий счётчик остаётся")
	Settings.reset_keys([&"show_dice_counts"])


func test_portraits_and_captions_have_backing() -> void:
	var screen := _table(14)
	var seat: SeatView = screen._seats[1]
	var back := seat._portrait.get_parent().get_child(seat._portrait.get_index() - 1)
	assert_true(back is ColorRect, "под портретом подложка")
	assert_eq((back as ColorRect).color, TableKit.PORTRAIT_BACKING)
	assert_true(seat._name_label.has_theme_stylebox_override("normal"), "имя на подложке")
	assert_true(screen._status_label.has_theme_stylebox_override("normal"), "статус на подложке")
