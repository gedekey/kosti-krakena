extends GutTest
## Безумие (М5): модель восприятия, чашка, итоги по реальным кубикам, боты в Безумии.

const Phase := MatchController.Phase
const Err := MatchController.Result
const RiskMode := CheatState.RiskMode

const HANDS_4 := [[2, 3, 4, 5, 6], [2, 2, 3, 3, 4], [5, 5, 6, 6, 1], [4, 4, 4, 2, 6]]
const TRIALS := 2000


## Бот, который запоминает, какие свои кубики видел в каждый ход, и ставит минимум.
class EyesBot:
	extends MatchAgent
	var seen: Array = []

	func choose_action(view: PlayerView) -> MatchAction:
		seen.append(view.own_dice.duplicate())
		var lowest := view.lowest_bid()
		if lowest != null:
			return MatchAction.new(MatchAction.Kind.BID, lowest)
		return MatchAction.dudo()


func _humans(count: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(HumanAgent.new())
	return agents


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


## Матч людей: первым ходит 0, кубики заданы, ложные улики отключены.
func _started(hands: Array = HANDS_4, seed_value := 1) -> MatchController:
	var mc := MatchController.new(_humans(hands.size()), RuleOptions.new(),
			Rng.make_seeded(seed_value))
	mc.cheats.risk_mode = RiskMode.NEVER_FAIL
	mc.cheats.false_evidence_chance = 0.0
	mc.start_match(0)
	mc.roll(hands)
	return mc


func _reopen(mc: MatchController, id: int) -> Array[int]:
	mc.close_cup(id)
	assert_eq(mc.open_cup(id), Err.OK)
	return mc.view_for(id).own_dice


func _changed_dice(a: Array, b: Array) -> int:
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n


# --- Модель: distort ---------------------------------------------------------------

func test_balance_matches_design() -> void:
	assert_eq(MadnessBalance.HALLUCINATION_CHANCE, 0.5)


func test_distort_zero_chance_is_truth_and_keeps_input() -> void:
	var known := _ints([1, 2, 3, 4, 5])
	var rng := Rng.make_seeded(3)
	assert_eq(Perception.distort(known, 0.0, rng), known)
	var out := Perception.distort(known, 1.0, rng)
	assert_eq(out.size(), known.size())
	assert_eq(known, _ints([1, 2, 3, 4, 5]), "вход не меняется")


func test_distort_faces_are_valid_and_uniform_when_always_lying() -> void:
	var rng := Rng.make_seeded(4)
	var counts := [0, 0, 0, 0, 0, 0, 0]
	for t in TRIALS:
		for face in Perception.distort(_ints([3, 3, 3, 3, 3]), 1.0, rng):
			assert_between(face, 1, PerudoRules.FACES)
			counts[face] += 1
	var expected := TRIALS * 5.0 / PerudoRules.FACES
	for face in range(1, PerudoRules.FACES + 1):
		assert_almost_eq(float(counts[face]), expected, expected * 0.1, "грань %d" % face)


## Каждый кубик подменяется с шансом 50%; подмена совпадает с правдой в 1/6 случаев.
func test_distort_rate_per_die() -> void:
	var rng := Rng.make_seeded(5)
	var known := _ints([1, 2, 3, 4, 5])
	var changed := 0
	for t in TRIALS:
		changed += _changed_dice(known, Perception.distort(known, 0.5, rng))
	var rate := float(changed) / (TRIALS * known.size())
	assert_almost_eq(rate, 0.5 * 5.0 / 6.0, 0.03)


# --- Модель: Perception -------------------------------------------------------------

func test_perception_truth_after_roll_then_reopen_distorts() -> void:
	var p := Perception.new(2, Rng.make_seeded(6))
	p.chance = 1.0
	var known := _ints([2, 2, 2, 2, 2])
	p.reset([known, _ints([6])])
	assert_eq(p.seen(0), known, "сразу после броска — правда")
	assert_true(p.is_cup_open(0))
	assert_true(p.lying_dice(0).is_empty())
	assert_false(p.open_cup(0, known, true), "открытую не переоткрыть")
	assert_true(p.close_cup(0))
	assert_false(p.close_cup(0))
	assert_eq(p.seen(0), known, "закрытая — по памяти")
	assert_true(p.open_cup(0, known, true))
	var seen := p.seen(0)
	var lies := p.lying_dice(0)
	assert_eq(lies.size(), _changed_dice(known, seen))
	for i in lies:
		assert_ne(seen[i], known[i])


func test_perception_sane_open_is_truth() -> void:
	var p := Perception.new(1, Rng.make_seeded(7))
	p.chance = 1.0
	var known := _ints([1, 4, 6])
	p.reset([known])
	for t in 20:
		p.close_cup(0)
		p.open_cup(0, known, false)
		assert_eq(p.seen(0), known)


func test_perception_clear_and_set_seen_die() -> void:
	var p := Perception.new(1, Rng.make_seeded(8))
	p.chance = 1.0
	p.reset([_ints([1, 1, 1])])
	p.close_cup(0)
	p.open_cup(0, _ints([1, 1, 1]), true)
	p.set_seen_die(0, 1, 5)
	assert_eq(p.seen(0)[1], 5)
	assert_false(p.lying_dice(0).has(1))
	p.clear()
	assert_true(p.seen(0).is_empty())
	assert_false(p.is_cup_open(0))


# --- Контроллер: чашка ---------------------------------------------------------------

func test_cup_commands_rules_and_signal() -> void:
	var mc := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(1))
	mc.start_match(0)
	assert_eq(mc.open_cup(0), Err.WRONG_PHASE, "до броска")
	assert_false(mc.view_for(0).cup_open)
	mc.roll()
	assert_true(mc.view_for(0).cup_open, "после броска чашка открыта")
	assert_eq(mc.open_cup(0), Err.ILLEGAL_ACTION, "уже открыта")
	watch_signals(mc)
	assert_eq(mc.close_cup(1), Err.OK, "не в свой ход — можно")
	assert_signal_emitted_with_parameters(mc, "cup_changed", [1, false])
	assert_false(mc.view_for(1).cup_open)
	assert_eq(mc.close_cup(1), Err.ILLEGAL_ACTION)
	assert_eq(mc.open_cup(1), Err.OK)
	assert_signal_emitted_with_parameters(mc, "cup_changed", [1, true])
	assert_eq(mc.open_cup(7), Err.ILLEGAL_ACTION, "нет такого игрока")


func test_sane_player_always_sees_truth() -> void:
	var mc := _started()
	for t in 30:
		assert_eq(_reopen(mc, 0), _ints(HANDS_4[0]))


func test_mad_player_sees_truth_right_after_roll() -> void:
	var mc := MatchController.new(_humans(4), RuleOptions.new(), Rng.make_seeded(1))
	mc.start_match(0)
	mc.debug_set_sanity(0, 0)
	mc.perception.chance = 1.0
	mc.roll(HANDS_4)
	assert_true(mc.view_for(0).is_mad())
	assert_eq(mc.view_for(0).own_dice, _ints(HANDS_4[0]))
	assert_true(mc.lying_dice(0).is_empty())


func test_mad_player_hallucinates_on_each_reopen_about_half() -> void:
	var mc := _started()
	mc.debug_set_sanity(0, 0)
	var truth := _ints(HANDS_4[0])
	var changed := 0
	var distinct := {}
	for t in TRIALS:
		var seen := _reopen(mc, 0)
		assert_eq(seen.size(), truth.size())
		assert_eq(mc.lying_dice(0).size(), _changed_dice(truth, seen))
		changed += _changed_dice(truth, seen)
		distinct[str(seen)] = true
	assert_almost_eq(float(changed) / (TRIALS * truth.size()), 0.5 * 5.0 / 6.0, 0.03)
	assert_gt(distinct.size(), 50, "искажение пересчитывается при каждом открытии")
	assert_eq(mc.hand_of(0), truth, "настоящие кубики не меняются")


func test_madness_begins_mid_round_without_changing_current_sight() -> void:
	var mc := _started()
	mc.perception.chance = 1.0
	watch_signals(mc)
	mc.debug_set_sanity(0, 0)
	assert_signal_emitted_with_parameters(mc, "madness_began", [0])
	assert_eq(mc.view_for(0).own_dice, _ints(HANDS_4[0]), "до следующего открытия — правда")
	assert_eq(mc.cheat_denial(0, CheatAction.abyss_whisper(3)), CheatRules.Denied.MAD,
			"в Безумии трюки недоступны")


func test_reveal_counts_real_dice_not_hallucinations() -> void:
	# У игрока 0 настоящие 5 шестёрок; в Безумии он видит что угодно, но вскрытие — по правде.
	var hands := [[6, 6, 6, 6, 6], [2, 2, 3, 3, 4]]
	var mc := _started(hands)
	mc.debug_set_sanity(0, 0)
	mc.perception.chance = 1.0
	_reopen(mc, 0)
	assert_eq(mc.submit_action(0, MatchAction.make_bid(5, 6)), Err.OK)
	assert_eq(mc.submit_action(1, MatchAction.dudo()), Err.OK)
	assert_eq(mc.last_reveal.result.actual_count, 5)
	assert_eq(mc.last_reveal.hands[0], [6, 6, 6, 6, 6])
	assert_eq(mc.dice_counts[1], 4, "проиграл оспоривший")


func test_madness_lasts_whole_match_and_new_round_starts_truthful() -> void:
	var mc := _started()
	mc.debug_set_sanity(0, 0)
	mc.perception.chance = 1.0
	_reopen(mc, 0)
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	mc.next_round()
	assert_true(mc.cheats.is_mad(0), "Рассудок не восполняется")
	mc.roll()
	assert_eq(mc.view_for(0).own_dice, mc.hand_of(0), "после нового броска — правда")
	var lied := false
	for t in 10:
		lied = lied or _reopen(mc, 0) != mc.hand_of(0)
	assert_true(lied)


func test_sleight_shows_new_face() -> void:
	var mc := _started()
	assert_eq(mc.submit_cheat(0, CheatAction.sleight(2)), Err.OK)
	assert_eq(mc.view_for(0).own_dice[2], mc.hand_of(0)[2])


func test_nudged_die_keeps_old_face_when_sane() -> void:
	# М4: сосед «толкнул чашку» — игрок не узнаёт результат даже при переоткрытии.
	var mc := _started([[1, 1, 1, 1, 1], [2, 2, 2, 2, 2]])
	assert_eq(mc.submit_cheat(0, CheatAction.nudge_cup(1)), Err.OK)
	assert_eq(_reopen(mc, 1), _ints([2, 2, 2, 2, 2]))


func test_hallucinations_do_not_shift_dice_rolls() -> void:
	var hands_after := []
	for reopen_count in [0, 25]:
		var mc := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(11))
		mc.start_match(0)
		mc.debug_set_sanity(0, 0)
		mc.roll()
		for t in reopen_count:
			_reopen(mc, 0)
		mc.submit_action(0, MatchAction.make_bid(1, 2))
		mc.submit_action(1, MatchAction.dudo())
		mc.next_round()
		mc.roll()
		hands_after.append([mc.hand_of(0), mc.hand_of(1), mc.hand_of(2)])
	assert_eq(hands_after[0], hands_after[1])


func test_injected_madness_rng_is_deterministic() -> void:
	var seen := []
	for i in 2:
		var mc := MatchController.new(_humans(2), RuleOptions.new(), Rng.make_seeded(1),
				Rng.make_seeded(2), Rng.make_seeded(99))
		mc.start_match(0)
		mc.debug_set_sanity(0, 0)
		mc.roll(HANDS_4.slice(0, 2))
		seen.append([_reopen(mc, 0), _reopen(mc, 0), _reopen(mc, 0)])
	assert_eq(seen[0], seen[1])


# --- Боты в Безумии ---------------------------------------------------------------------

func _bot_match(mad: bool, seed_value: int) -> Array:
	var bot := EyesBot.new()
	var agents: Array[MatchAgent] = [HumanAgent.new(), bot]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(seed_value))
	mc.cheats.false_evidence_chance = 0.0
	mc.perception.chance = 1.0
	mc.start_match(1)
	if mad:
		mc.debug_set_sanity(1, 0)
	mc.roll([[2, 3, 4, 5, 6], [1, 2, 3, 4, 5]])
	# Бот ставит, человек тоже ставит минимум — несколько кругов.
	for t in 4:
		mc.play_bot_turn()
		var lowest := mc.view_for(0).lowest_bid()
		if lowest == null:
			break
		mc.submit_action(0, MatchAction.new(MatchAction.Kind.BID, lowest))
	return [bot.seen, mc.hand_of(1)]


func test_sane_bot_sees_truth_every_turn() -> void:
	var result := _bot_match(false, 1)
	assert_gt(result[0].size(), 1)
	for seen in result[0]:
		assert_eq(seen, result[1])


func test_mad_bot_truth_on_first_turn_then_hallucinates() -> void:
	var lied := 0
	var later := 0
	for seed_value in range(1, 21):
		var result := _bot_match(true, seed_value)
		var seen_list: Array = result[0]
		assert_eq(seen_list[0], result[1], "первый ход — правда после броска")
		for i in range(1, seen_list.size()):
			later += 1
			if seen_list[i] != result[1]:
				lied += 1
	assert_gt(later, 0)
	assert_gt(lied, later / 2, "в следующие ходы бот видит искажённые кубики")


func test_bot_reopen_emits_cup_signals() -> void:
	var bot := EyesBot.new()
	var agents: Array[MatchAgent] = [HumanAgent.new(), bot]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.start_match(1)
	mc.roll([[2, 3, 4, 5, 6], [1, 2, 3, 4, 5]])
	watch_signals(mc)
	mc.play_bot_turn()
	assert_signal_not_emitted(mc, "cup_changed", "первый ход — без переоткрытия")
	mc.submit_action(0, MatchAction.new(MatchAction.Kind.BID, mc.view_for(0).lowest_bid()))
	mc.play_bot_turn()
	assert_signal_emit_count(mc, "cup_changed", 2)


func test_full_bot_matches_with_mad_bots_stay_legal() -> void:
	for seed_value in range(1, 11):
		var agents: Array[MatchAgent] = []
		for i in 4:
			agents.append(BotAgent.new(BotRoster.all()[i], Rng.make_seeded(seed_value * 10 + i)))
		var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(seed_value))
		mc.start_match()
		for id in 4:
			mc.debug_set_sanity(id, 0)
		var steps := 0
		while mc.advance_auto() and steps < 5000:
			steps += 1
		assert_eq(mc.phase, Phase.MATCH_OVER, "seed %d" % seed_value)


func test_cup_changed_reaches_event_bus() -> void:
	var mc := _started()
	MatchEventBridge.connect_all(mc, Events)
	watch_signals(Events)
	mc.close_cup(0)
	assert_signal_emitted_with_parameters(Events, "cup_changed", [0, false])


# --- М9: автозакрытие чашки в Безумии ----------------------------------------------

func test_mad_player_cup_closes_after_action() -> void:
	var mc := _started()
	mc.debug_set_sanity(0, 0)
	assert_true(mc.view_for(0).cup_open, "после броска открыта")
	watch_signals(mc)
	assert_eq(mc.submit_action(0, MatchAction.make_bid(2, 3)), Err.OK)
	assert_signal_emitted_with_parameters(mc, "cup_changed", [0, false])
	assert_false(mc.view_for(0).cup_open, "в Безумии закрылась после ставки")
	assert_eq(mc.open_cup(0), Err.OK, "открыть можно снова")


func test_sane_player_cup_stays_open_after_action() -> void:
	var mc := _started()
	watch_signals(mc)
	assert_eq(mc.submit_action(0, MatchAction.make_bid(2, 3)), Err.OK)
	assert_signal_not_emitted(mc, "cup_changed")
	assert_true(mc.view_for(0).cup_open)


func test_mad_player_closed_cup_stays_closed_after_action() -> void:
	var mc := _started()
	mc.debug_set_sanity(0, 0)
	mc.close_cup(0)
	watch_signals(mc)
	assert_eq(mc.submit_action(0, MatchAction.make_bid(2, 3)), Err.OK)
	assert_signal_not_emitted(mc, "cup_changed")
