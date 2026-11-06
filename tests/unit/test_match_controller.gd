extends GutTest
## Контроллер матча (М2): фазы, ходы, вскрытие, раунды, выбывание, победа.

const Phase := MatchController.Phase
const Err := MatchController.Result
const NO_PLAYER := PerudoRules.NO_PLAYER


func _humans(count: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(HumanAgent.new())
	return agents


func _bots(count: int, seed_value: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(RandomAgent.new(Rng.make_seeded(seed_value * 10 + i)))
	return agents


func _make(count := 3, options := RuleOptions.new(), seed_value := 1) -> MatchController:
	return MatchController.new(_humans(count), options, Rng.make_seeded(seed_value))


## Матч, где первым ходит игрок 0, кубики брошены заданными.
func _started(hands: Array, options := RuleOptions.new()) -> MatchController:
	var mc := _make(hands.size(), options)
	mc.start_match(0)
	mc.roll(hands)
	return mc


func _bid(q: int, f: int) -> MatchAction:
	return MatchAction.make_bid(q, f)


## Задать количество кубиков вне обычного хода (сценарии конца матча).
func _set_counts(mc: MatchController, counts: Array) -> void:
	for i in counts.size():
		mc.dice_counts[i] = counts[i]


# --- Старт и бросок ----------------------------------------------------------

func test_start_gives_everyone_five_dice_and_waits_for_roll() -> void:
	var mc := _make(4)
	watch_signals(mc)
	mc.start_match(2)
	assert_eq(mc.dice_counts, [5, 5, 5, 5] as Array[int])
	assert_eq(mc.phase, Phase.ROLL)
	assert_eq(mc.round_number, 1)
	assert_false(mc.round_rules.is_palifico)
	assert_signal_emitted_with_parameters(mc, "match_started", [4, 2])
	assert_signal_emitted_with_parameters(mc, "round_started", [1, 2, false])


func test_random_first_player_is_in_range_and_seeded() -> void:
	var a := _make(5, RuleOptions.new(), 42)
	var b := _make(5, RuleOptions.new(), 42)
	a.start_match()
	b.start_match()
	a.roll()
	b.roll()
	assert_between(a.current_player, 0, 4)
	assert_eq(a.current_player, b.current_player)
	assert_eq(a.hand_of(3), b.hand_of(3), "одинаковый seed — одинаковый бросок")


func test_roll_deals_dice_and_starts_turn_of_starter() -> void:
	var mc := _make(3)
	mc.start_match(1)
	watch_signals(mc)
	mc.roll()
	assert_eq(mc.phase, Phase.BIDDING)
	for id in 3:
		assert_eq(mc.hand_of(id).size(), 5)
	assert_eq(mc.current_player, 1)
	assert_signal_emitted_with_parameters(mc, "dice_rolled", [1])
	assert_signal_emitted_with_parameters(mc, "turn_started", [1])


func test_no_actions_before_roll() -> void:
	var mc := _make(2)
	mc.start_match(0)
	assert_eq(mc.submit_action(0, _bid(1, 2)), Err.WRONG_PHASE)


func test_preset_hands_are_used() -> void:
	var mc := _started([[1, 2, 3, 4, 5], [6, 6, 6, 6, 6]])
	assert_eq(mc.hand_of(0), [1, 2, 3, 4, 5] as Array[int])
	assert_eq(mc.hand_of(1), [6, 6, 6, 6, 6] as Array[int])


# --- Ставки и очередь --------------------------------------------------------

func test_bid_passes_turn_to_next_player() -> void:
	var mc := _started([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3], [4, 4, 4, 4, 4]])
	watch_signals(mc)
	assert_eq(mc.submit_action(0, _bid(2, 3)), Err.OK)
	assert_eq(mc.current_player, 1)
	assert_true(mc.current_bid.equals(Bid.new(2, 3)))
	assert_eq(mc.current_bidder, 0)
	assert_eq(mc.bid_history.size(), 1)
	assert_signal_emitted(mc, "bid_placed")
	mc.submit_action(1, _bid(3, 3))
	mc.submit_action(2, _bid(3, 4))
	assert_eq(mc.current_player, 0, "по кругу")
	assert_eq(mc.bid_history.size(), 3)


func test_wrong_player_is_rejected() -> void:
	var mc := _started([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3]])
	assert_eq(mc.submit_action(1, _bid(1, 2)), Err.NOT_YOUR_TURN)
	assert_eq(mc.current_player, 0)


func test_illegal_bids_are_rejected_without_state_change() -> void:
	var mc := _started([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3]])
	assert_eq(mc.submit_action(0, _bid(1, 1)), Err.ILLEGAL_ACTION, "первая ставка на единицы")
	assert_eq(mc.submit_action(0, MatchAction.dudo()), Err.ILLEGAL_ACTION, "нечего оспаривать")
	assert_eq(mc.submit_action(0, MatchAction.calza()), Err.ILLEGAL_ACTION)
	mc.submit_action(0, _bid(3, 4))
	assert_eq(mc.submit_action(1, _bid(3, 3)), Err.ILLEGAL_ACTION, "ниже предыдущей")
	assert_eq(mc.current_player, 1)
	assert_eq(mc.bid_history.size(), 1)


func test_bid_cannot_exceed_dice_on_table() -> void:
	var mc := _started([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3]])
	assert_eq(mc.submit_action(0, _bid(11, 6)), Err.ILLEGAL_ACTION)
	assert_eq(mc.submit_action(0, _bid(10, 6)), Err.OK)
	assert_true(mc.view_for(1).lowest_bid().equals(Bid.new(5, 1)), "на единицы ещё можно")
	assert_eq(mc.submit_action(1, _bid(10, 1)), Err.OK)
	assert_null(mc.view_for(0).lowest_bid(), "выше 10×1 ставить некуда")
	assert_true(mc.view_for(0).allowed_faces().is_empty())
	assert_true(mc.view_for(0).can_dudo())


func test_turn_skips_eliminated_players() -> void:
	var mc := _make(3)
	mc.start_match(0)
	_set_counts(mc, [5, 0, 5])
	mc.roll([[2, 2, 2, 2, 2], [], [3, 3, 3, 3, 3]])
	mc.submit_action(0, _bid(1, 2))
	assert_eq(mc.current_player, 2)


# --- «Ложь!» -----------------------------------------------------------------

func test_dudo_on_true_bid_costs_challenger_a_die() -> void:
	var mc := _started([[3, 3, 1, 5, 6], [3, 2, 2, 4, 4]])
	mc.submit_action(0, _bid(4, 3))  # тройки: 3 + единица = 4
	watch_signals(mc)
	assert_eq(mc.submit_action(1, MatchAction.dudo()), Err.OK)
	var reveal := mc.last_reveal
	assert_eq(reveal.kind, MatchAction.Kind.DUDO)
	assert_eq(reveal.bidder_id, 0)
	assert_eq(reveal.caller_id, 1)
	assert_eq(reveal.result.actual_count, 4)
	assert_true(reveal.result.bid_holds)
	assert_eq(mc.dice_counts, [5, 4] as Array[int])
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_signal_emitted(mc, "challenge_revealed")
	assert_signal_emitted_with_parameters(mc, "dice_count_changed", [1, 4, -1])
	assert_signal_emitted_with_parameters(mc, "round_ended", [1, false])


func test_dudo_on_false_bid_costs_bidder_a_die_and_bidder_starts() -> void:
	var mc := _started([[3, 2, 2, 5, 6], [2, 2, 4, 4, 4]])
	mc.submit_action(0, _bid(3, 3))
	mc.submit_action(1, MatchAction.dudo())
	assert_false(mc.last_reveal.result.bid_holds)
	assert_eq(mc.dice_counts, [4, 5] as Array[int])
	mc.next_round()
	assert_eq(mc.round_number, 2)
	assert_eq(mc.phase, Phase.ROLL)
	assert_null(mc.current_bid)
	assert_true(mc.bid_history.is_empty())
	mc.roll()
	assert_eq(mc.current_player, 0, "проигравший начинает")
	assert_eq(mc.hand_of(0).size(), 4)


func test_reveal_keeps_snapshot_of_hands() -> void:
	var mc := _started([[3, 2, 2, 5, 6], [2, 2, 4, 4, 4]])
	mc.submit_action(0, _bid(3, 3))
	mc.submit_action(1, MatchAction.dudo())
	var hands := mc.last_reveal.hands
	mc.next_round()
	mc.roll()
	assert_eq(hands[1], [2, 2, 4, 4, 4] as Array[int])


# --- «Точно!» ----------------------------------------------------------------

func test_calza_exact_returns_a_die_up_to_max() -> void:
	var mc := _make(2)
	mc.start_match(0)
	_set_counts(mc, [5, 3])
	mc.roll([[4, 4, 1, 2, 2], [4, 6, 6]])
	mc.submit_action(0, _bid(4, 4))  # 4, 4, 1, 4 = ровно 4
	assert_eq(mc.submit_action(1, MatchAction.calza()), Err.OK)
	assert_true(mc.last_reveal.result.bid_holds)
	assert_eq(mc.dice_counts, [5, 4] as Array[int])
	assert_eq(mc.phase, Phase.ROUND_END)


func test_calza_exact_at_max_dice_changes_nothing() -> void:
	var mc := _started([[4, 4, 1, 2, 2], [4, 6, 6, 6, 6]])
	mc.submit_action(0, _bid(4, 4))
	watch_signals(mc)
	mc.submit_action(1, MatchAction.calza())
	assert_eq(mc.dice_counts, [5, 5] as Array[int])
	assert_signal_emitted_with_parameters(mc, "dice_count_changed", [1, 5, 0])


func test_calza_miss_costs_caller_a_die() -> void:
	var mc := _started([[4, 4, 1, 2, 2], [4, 6, 6, 6, 6]])
	mc.submit_action(0, _bid(3, 4))
	mc.submit_action(1, MatchAction.calza())
	assert_false(mc.last_reveal.result.bid_holds)
	assert_eq(mc.dice_counts, [5, 4] as Array[int])


func test_calza_disabled_is_illegal() -> void:
	var options := RuleOptions.new()
	options.calza_enabled = false
	var mc := _started([[4, 4, 1, 2, 2], [4, 6, 6, 6, 6]], options)
	mc.submit_action(0, _bid(3, 4))
	assert_eq(mc.submit_action(1, MatchAction.calza()), Err.ILLEGAL_ACTION)
	assert_false(mc.view_for(1).can_calza())


# --- Palifico ----------------------------------------------------------------

func _lose_last_but_one(options := RuleOptions.new()) -> MatchController:
	# У игрока 1 два кубика, он ложно оспаривает и остаётся с одним.
	var mc := _make(2, options)
	mc.start_match(0)
	_set_counts(mc, [5, 2])
	mc.roll([[3, 3, 3, 2, 2], [5, 5]])
	mc.submit_action(0, _bid(3, 3))
	mc.submit_action(1, MatchAction.dudo())
	return mc


func test_first_time_one_die_triggers_palifico_round() -> void:
	var mc := _lose_last_but_one()
	watch_signals(mc)
	assert_eq(mc.dice_counts[1], 1)
	mc.next_round()
	assert_true(mc.round_rules.is_palifico)
	assert_signal_emitted_with_parameters(mc, "round_started", [2, 1, true])
	mc.roll([[1, 1, 1, 2, 2], [4]])
	assert_eq(mc.current_player, 1, "начинает тот, у кого 1 кубик")
	assert_eq(mc.submit_action(1, _bid(1, 1)), Err.OK, "в Palifico можно начать с единиц")


func test_palifico_ones_are_not_wild() -> void:
	var mc := _lose_last_but_one()
	mc.next_round()
	mc.roll([[1, 1, 1, 2, 2], [4]])
	mc.submit_action(1, _bid(2, 4))
	assert_eq(mc.submit_action(0, _bid(3, 5)), Err.ILLEGAL_ACTION, "грань зафиксирована")
	mc.submit_action(0, MatchAction.dudo())
	assert_eq(mc.last_reveal.result.actual_count, 1, "единицы не считаются за четвёрки")
	assert_true(mc.last_reveal.is_palifico)
	assert_eq(mc.winner_id, 0, "у игрока 1 был последний кубик")


func test_palifico_triggers_only_once_per_player() -> void:
	var mc := _lose_last_but_one()
	mc.next_round()
	mc.roll([[2, 2, 2, 2, 2], [6]])
	mc.submit_action(1, _bid(1, 6))
	mc.submit_action(0, MatchAction.calza())  # ровно одна шестёрка, у игрока 0 уже максимум
	assert_eq(mc.dice_counts, [5, 1] as Array[int])
	mc.next_round()
	assert_false(mc.round_rules.is_palifico)
	# Пусть у игрока 1 снова 2 кубика: он падает до 1 повторно — Palifico уже был.
	_set_counts(mc, [5, 2])
	mc.roll([[3, 3, 3, 2, 2], [5, 5]])
	assert_eq(mc.current_player, 0)
	mc.submit_action(0, _bid(3, 3))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.dice_counts[1], 1)
	mc.next_round()
	assert_false(mc.round_rules.is_palifico)


func test_palifico_disabled() -> void:
	var options := RuleOptions.new()
	options.palifico_enabled = false
	var mc := _lose_last_but_one(options)
	mc.next_round()
	assert_false(mc.round_rules.is_palifico)


# --- Выбывание и победа ------------------------------------------------------

func test_elimination_and_next_starter_is_next_active() -> void:
	var mc := _make(3)
	mc.start_match(0)
	_set_counts(mc, [5, 1, 5])
	mc.roll([[2, 2, 2, 2, 2], [6], [3, 3, 3, 3, 3]])
	mc.submit_action(0, _bid(2, 6))
	watch_signals(mc)
	mc.submit_action(1, MatchAction.dudo())  # шестёрок 1 — ставка не выполнена, теряет 0
	assert_eq(mc.dice_counts, [4, 1, 5] as Array[int])
	mc.next_round()
	mc.roll([[2, 2, 2, 2], [6], [3, 3, 3, 3, 3]])
	mc.submit_action(0, _bid(1, 6))
	mc.submit_action(1, _bid(2, 5))  # пятёрок нет вообще
	mc.submit_action(2, MatchAction.dudo())
	assert_eq(mc.dice_counts, [4, 0, 5] as Array[int])
	assert_signal_emitted_with_parameters(mc, "player_eliminated", [1])
	assert_eq(mc.phase, Phase.ROUND_END)
	mc.next_round()
	mc.roll([[2, 2, 2, 2], [], [3, 3, 3, 3, 3]])
	assert_eq(mc.current_player, 2, "выбывший не начинает — следующий по кругу")


func test_last_player_standing_wins() -> void:
	var mc := _make(2)
	mc.start_match(0)
	_set_counts(mc, [3, 1])
	mc.roll([[2, 2, 2], [5]])
	mc.submit_action(0, _bid(3, 2))
	watch_signals(mc)
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.phase, Phase.MATCH_OVER)
	assert_eq(mc.winner_id, 0)
	assert_signal_emitted_with_parameters(mc, "match_ended", [0])
	assert_signal_not_emitted(mc, "round_ended")
	assert_eq(mc.submit_action(0, _bid(1, 2)), Err.WRONG_PHASE)


# --- Информация игрока -------------------------------------------------------

func test_view_contains_only_own_dice() -> void:
	var mc := _started([[1, 2, 3, 4, 5], [6, 6, 6, 6, 6], [2, 2, 2, 2, 2]])
	mc.submit_action(0, _bid(2, 3))
	var view := mc.view_for(1)
	assert_eq(view.player_id, 1)
	assert_eq(view.own_dice, [6, 6, 6, 6, 6] as Array[int])
	assert_eq(view.dice_counts, [5, 5, 5] as Array[int])
	assert_eq(view.total_dice(), 15)
	assert_true(view.current_bid.equals(Bid.new(2, 3)))
	assert_eq(view.current_bidder, 0)
	assert_eq(view.bid_history.size(), 1)
	assert_false("hands" in view, "чужих кубиков во view нет")


func test_view_is_snapshot() -> void:
	var mc := _started([[1, 2, 3, 4, 5], [6, 6, 6, 6, 6]])
	var view := mc.view_for(1)
	mc.submit_action(0, _bid(2, 3))
	assert_null(view.current_bid)
	assert_true(view.bid_history.is_empty())


# --- Боты и полный матч ------------------------------------------------------

func test_human_turn_blocks_auto_advance() -> void:
	var agents: Array[MatchAgent] = [HumanAgent.new(), RandomAgent.new(Rng.make_seeded(5))]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(5))
	mc.start_match(0)
	assert_true(mc.advance_auto(), "бросок")
	assert_true(mc.is_waiting_for_human())
	assert_false(mc.advance_auto())
	assert_eq(mc.play_bot_turn(), Err.NOT_YOUR_TURN)
	mc.submit_action(0, _bid(1, 2))
	assert_true(mc.advance_auto(), "ход бота")
	if mc.phase == Phase.BIDDING:
		assert_eq(mc.current_bidder, 1, "бот поднял ставку")
		assert_true(mc.is_waiting_for_human())
	else:
		assert_eq(mc.last_reveal.caller_id, 1, "бот оспорил")


func test_bot_with_illegal_choice_gets_fallback() -> void:
	var agents: Array[MatchAgent] = [_IllegalBot.new(), _IllegalBot.new()]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.start_match(0)
	mc.roll()
	assert_eq(mc.play_bot_turn(), Err.OK)
	assert_true(mc.current_bid.equals(Bid.new(1, 2)), "самая дешёвая ставка")


func test_full_bot_matches_finish_with_winner() -> void:
	for seed_value in range(1, 31):
		var count := 2 + seed_value % 5
		var mc := MatchController.new(_bots(count, seed_value), RuleOptions.new(),
				Rng.make_seeded(seed_value))
		mc.start_match()
		var steps := 0
		while mc.advance_auto():
			steps += 1
			assert_lt(steps, 5000, "матч должен закончиться")
			if steps >= 5000:
				return
		assert_eq(mc.phase, Phase.MATCH_OVER)
		assert_ne(mc.winner_id, NO_PLAYER)
		assert_gt(mc.dice_counts[mc.winner_id], 0)
		assert_eq(mc.total_dice(), mc.dice_counts[mc.winner_id], "у остальных кубиков нет")


func test_random_agent_always_chooses_legal_actions() -> void:
	var rng := Rng.make_seeded(77)
	var bot := RandomAgent.new(Rng.make_seeded(78))
	for i in 500:
		var view := PlayerView.new()
		view.dice_counts = [rng.randi_range(1, 5), rng.randi_range(1, 5)] as Array[int]
		view.round_rules = RoundRules.new(rng.randf() < 0.3)
		view.options = RuleOptions.new()
		if rng.randf() < 0.8:
			view.current_bid = Bid.new(rng.randi_range(1, view.total_dice()), rng.randi_range(1, 6))
		var action := bot.choose_action(view)
		assert_true(view.is_legal(action), "%s после %s" % [action, view.current_bid])


# --- Шина событий ------------------------------------------------------------

func test_bridge_forwards_signals_to_events() -> void:
	var mc := _make(2)
	MatchEventBridge.connect_all(mc, Events)
	watch_signals(Events)
	mc.start_match(1)
	mc.roll([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3]])
	mc.submit_action(1, _bid(2, 3))
	assert_signal_emitted_with_parameters(Events, "match_started", [2, 1])
	assert_signal_emitted_with_parameters(Events, "round_started", [1, 1, false])
	assert_signal_emitted_with_parameters(Events, "phase_changed", [Phase.BIDDING])
	assert_signal_emitted_with_parameters(Events, "turn_started", [0])
	assert_signal_emitted(Events, "bid_placed")


class _IllegalBot:
	extends MatchAgent

	func choose_action(_view: PlayerView) -> MatchAction:
		return MatchAction.make_bid(99, 9)
