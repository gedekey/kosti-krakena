extends GutTest
## Жульничество и Рассудок (М4): трюки, ограничения, провал, улики, обвинения, штрафы.

const Phase := MatchController.Phase
const Err := MatchController.Result
const Kind := Cheat.Kind
const Denied := CheatRules.Denied
const RiskMode := CheatState.RiskMode

const HANDS_4 := [[2, 3, 4, 5, 6], [2, 2, 3, 3, 4], [5, 5, 6, 6, 1], [4, 4, 4, 2, 6]]


## Бот, который в свой ход делает заданный трюк (и честную случайную ставку).
class CheatingBot:
	extends RandomAgent
	var turn_cheat: CheatAction
	var roll_cheat: CheatAction

	func choose_turn_cheat(_view: PlayerView) -> CheatAction:
		return turn_cheat

	func choose_roll_cheat(_view: PlayerView) -> CheatAction:
		return roll_cheat


func _humans(count: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(HumanAgent.new())
	return agents


## Матч людей: первым ходит 0, кубики заданы, риск и ложные улики отключены.
func _started(hands: Array = HANDS_4, risk := RiskMode.NEVER_FAIL, seed_value := 1) -> MatchController:
	var mc := MatchController.new(_humans(hands.size()), RuleOptions.new(),
			Rng.make_seeded(seed_value))
	mc.cheats.risk_mode = risk
	mc.cheats.false_evidence_chance = 0.0
	mc.start_match(0)
	mc.roll(hands)
	return mc


func _rolling(count := 4, risk := RiskMode.NEVER_FAIL) -> MatchController:
	var mc := MatchController.new(_humans(count), RuleOptions.new(), Rng.make_seeded(1))
	mc.cheats.risk_mode = risk
	mc.cheats.false_evidence_chance = 0.0
	mc.start_match(0)
	return mc


## Матч, где у игроков заданное число кубиков (по размерам рук).
func _started_with(hands: Array, risk := RiskMode.NEVER_FAIL) -> MatchController:
	var mc := _rolling(hands.size(), risk)
	for id in hands.size():
		mc.dice_counts[id] = hands[id].size()
	mc.roll(hands)
	return mc


func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	out.assign(values)
	return out


func _last_outcome(mc: MatchController, player_id: int) -> CheatOutcome:
	var outcomes := mc.view_for(player_id).cheat_outcomes
	return outcomes[outcomes.size() - 1] if not outcomes.is_empty() else null


# --- Каталог ---------------------------------------------------------------------

func test_catalog_costs_and_risks_match_design() -> void:
	assert_eq(CheatBalance.START_SANITY, 9)
	var expected := {
		Kind.PEEK: [1, CheatBalance.RISK_LOW],
		Kind.SLEIGHT: [1, CheatBalance.RISK_MEDIUM],
		Kind.LOADED_DIE: [2, CheatBalance.RISK_MEDIUM],
		Kind.NUDGE_CUP: [2, CheatBalance.RISK_HIGH],
		Kind.SLEEVE_DIE: [3, CheatBalance.RISK_HIGH],
		Kind.ABYSS_WHISPER: [3, CheatBalance.RISK_NONE],
	}
	for kind in Cheat.ALL:
		assert_eq(Cheat.cost(kind), expected[kind][0], Cheat.Kind.keys()[kind])
		assert_eq(Cheat.risk(kind), expected[kind][1], Cheat.Kind.keys()[kind])
	assert_almost_eq(CheatBalance.RISK_LOW, 0.10, 0.0001)
	assert_almost_eq(CheatBalance.RISK_MEDIUM, 0.20, 0.0001)
	assert_almost_eq(CheatBalance.RISK_HIGH, 0.35, 0.0001)
	assert_almost_eq(CheatBalance.FALSE_EVIDENCE_CHANCE, 0.15, 0.0001)
	assert_false(Cheat.is_cheating(Kind.ABYSS_WHISPER))
	assert_false(Cheat.leaves_evidence(Kind.ABYSS_WHISPER))
	assert_true(Cheat.is_roll_phase(Kind.LOADED_DIE))
	for kind in Cheat.ALL:
		assert_true(tr(Cheat.name_key(kind)) != "", "есть ключ локализации")


func test_neighbors_are_left_and_right_active_players() -> void:
	assert_eq(CheatRules.neighbors([5, 5, 5, 5], 0), [1, 3] as Array[int])
	assert_eq(CheatRules.neighbors([5, 0, 5, 5], 0), [2, 3] as Array[int], "выбывшие пропускаются")
	assert_eq(CheatRules.neighbors([5, 5, 0, 0], 1), [0] as Array[int], "двое — один сосед")
	assert_eq(CheatRules.previous_active_player([5, 5, 0, 5], 0), 3)


func test_whisper_count_excludes_own_dice_and_includes_sleeves() -> void:
	var hands := [[2, 2, 1], [2, 5, 1], [3, 1]]
	var sleeves := [[2], [2], [4]]
	assert_eq(CheatRules.whisper_count(0, 2, hands, sleeves, true), 4, "2,1 + рукав 2 у 1-го, 1 у 2-го")
	assert_eq(CheatRules.whisper_count(0, 2, hands, sleeves, false), 2, "Palifico: единицы не джокеры")


# --- Рассудок и ограничения ------------------------------------------------------

func test_everyone_starts_with_nine_sanity_and_only_own_is_visible() -> void:
	var mc := _started()
	for id in 4:
		assert_eq(mc.cheats.sanity[id], 9)
	var view := mc.view_for(1)
	assert_eq(view.own_sanity, 9)
	assert_eq(view.mad, [false, false, false, false] as Array[bool])
	assert_eq(view.cheat_outcomes.size(), 0)


func test_trick_spends_sanity_without_restoring() -> void:
	var mc := _started()
	watch_signals(mc)
	assert_eq(mc.submit_cheat(0, CheatAction.peek(1, 0)), Err.OK)
	assert_eq(mc.cheats.sanity[0], 8)
	assert_signal_emitted_with_parameters(mc, "sanity_changed", [0, 8, -1])
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.dudo())
	mc.next_round()
	mc.roll()
	assert_eq(mc.cheats.sanity[0], 8, "Рассудок не восполняется")


func test_only_one_trick_per_turn() -> void:
	var mc := _started()
	assert_eq(mc.submit_cheat(0, CheatAction.peek(1, 0)), Err.OK)
	assert_eq(mc.submit_cheat(0, CheatAction.sleight(0)), Err.ILLEGAL_ACTION)
	assert_eq(mc.cheat_denial(0, CheatAction.sleight(0)), Denied.ALREADY_USED)
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	assert_eq(mc.submit_cheat(1, CheatAction.peek(0, 0)), Err.OK, "у следующего свой ход — свой трюк")


func test_tricks_only_on_own_turn_before_action() -> void:
	var mc := _started()
	assert_eq(mc.submit_cheat(1, CheatAction.sleight(0)), Err.NOT_YOUR_TURN)
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	assert_eq(mc.submit_cheat(0, CheatAction.sleight(0)), Err.NOT_YOUR_TURN, "после действия ход ушёл")
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_eq(mc.submit_cheat(1, CheatAction.sleight(0)), Err.WRONG_PHASE)


func test_turn_tricks_are_not_allowed_in_roll_phase_and_vice_versa() -> void:
	var mc := _rolling()
	assert_eq(mc.submit_cheat(0, CheatAction.sleight(0)), Err.WRONG_PHASE)
	mc.roll()
	assert_eq(mc.submit_cheat(0, CheatAction.loaded_die(6)), Err.WRONG_PHASE)


func test_neighbor_tricks_require_a_neighbor() -> void:
	var mc := _started()
	assert_eq(mc.cheat_denial(0, CheatAction.peek(2, 0)), Denied.BAD_TARGET, "2 — не сосед 0 из 4")
	assert_eq(mc.cheat_denial(0, CheatAction.nudge_cup(0)), Denied.BAD_TARGET, "себя нельзя")
	assert_eq(mc.cheat_denial(0, CheatAction.peek(3, 0)), Denied.OK, "3 — сосед слева")
	assert_eq(mc.cheat_denial(0, CheatAction.peek(1, 5)), Denied.BAD_DIE)
	assert_eq(mc.cheat_denial(0, CheatAction.sleight(-1)), Denied.BAD_DIE)
	assert_eq(mc.cheat_denial(0, CheatAction.abyss_whisper(7)), Denied.BAD_FACE)


func test_not_enough_sanity() -> void:
	var mc := _started()
	mc.cheats.sanity[0] = 2
	assert_eq(mc.cheat_denial(0, CheatAction.sleeve_die()), Denied.NO_SANITY)
	assert_eq(mc.cheat_denial(0, CheatAction.nudge_cup(1)), Denied.OK)


func test_madness_blocks_tricks_and_begins_when_sanity_runs_out() -> void:
	var mc := _started()
	mc.cheats.sanity[0] = 3
	watch_signals(mc)
	assert_eq(mc.submit_cheat(0, CheatAction.abyss_whisper(4)), Err.OK)
	assert_eq(mc.cheats.sanity[0], 0)
	assert_signal_emitted_with_parameters(mc, "madness_began", [0])
	assert_true(mc.view_for(2).mad[0], "Безумие видно всем")
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.dudo())
	mc.next_round()
	mc.roll()
	var starter := mc.current_player
	mc.cheats.sanity[starter] = 0
	assert_eq(mc.cheat_denial(starter, CheatAction.abyss_whisper(4)), Denied.MAD)


# --- Трюки -----------------------------------------------------------------------

func test_peek_reveals_neighbor_die_only_to_cheater() -> void:
	var mc := _started()
	watch_signals(mc)
	mc.submit_cheat(0, CheatAction.peek(3, 2))
	var outcome := _last_outcome(mc, 0)
	assert_eq(outcome.peeked_face, 4)
	assert_false(outcome.failed)
	assert_signal_emitted(mc, "cheat_resolved")
	assert_eq(mc.view_for(3).cheat_outcomes.size(), 0, "сосед ничего не знает")
	assert_eq(mc.hand_of(3), [4, 4, 4, 2, 6] as Array[int], "кубики не изменились")


func test_sleight_rerolls_own_die_and_cheater_sees_it() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.sleight(4))
	var outcome := _last_outcome(mc, 0)
	assert_between(outcome.new_face, 1, 6)
	assert_eq(outcome.die_index, 4)
	assert_eq(mc.hand_of(0)[4], outcome.new_face)
	assert_eq(mc.view_for(0).own_dice[4], outcome.new_face)
	assert_eq(mc.hand_of(0).slice(0, 4), [2, 3, 4, 5] as Array[int], "остальные на месте")


func test_loaded_die_in_roll_phase_lands_on_chosen_face() -> void:
	var mc := _rolling()
	assert_eq(mc.submit_cheat(2, CheatAction.loaded_die(6)), Err.OK, "любой игрок, не только первый")
	assert_eq(mc.submit_cheat(2, CheatAction.loaded_die(5)), Err.ILLEGAL_ACTION, "одна за бросок")
	assert_eq(mc.submit_cheat(1, CheatAction.loaded_die(1)), Err.OK)
	assert_eq(mc.cheats.sanity[2], 7)
	mc.roll([[2, 2, 2, 2, 2], [3, 3, 3, 3, 3], [4, 4, 4, 4, 4], [5, 5, 5, 5, 5]])
	assert_eq(mc.hand_of(2), [6, 4, 4, 4, 4] as Array[int])
	assert_eq(mc.hand_of(1), [1, 3, 3, 3, 3] as Array[int])
	assert_eq(mc.view_for(2).own_dice[0], 6)
	assert_eq(mc.cheaters_this_round(), [2, 1] as Array[int])


func test_loaded_die_with_random_roll() -> void:
	for seed_value in 20:
		var mc := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(seed_value))
		mc.cheats.risk_mode = RiskMode.NEVER_FAIL
		mc.start_match(0)
		mc.submit_cheat(1, CheatAction.loaded_die(3))
		mc.roll()
		assert_eq(mc.hand_of(1)[MatchController.LOADED_DIE_INDEX], 3)


func test_nudge_cup_rerolls_neighbor_die_secretly() -> void:
	var changed := 0
	for seed_value in 30:
		var mc := _started(HANDS_4, RiskMode.NEVER_FAIL, seed_value)
		watch_signals(mc)
		mc.submit_cheat(0, CheatAction.nudge_cup(1))
		var real := mc.hand_of(1)
		var diffs := 0
		for i in 5:
			if real[i] != HANDS_4[1][i]:
				diffs += 1
		assert_lte(diffs, 1, "переброшен ровно один кубик")
		changed += diffs
		assert_eq(mc.view_for(1).own_dice, _ints(HANDS_4[1]), "сосед не узнаёт результат")
		var outcome := _last_outcome(mc, 0)
		assert_eq(outcome.new_face, CheatOutcome.NONE, "жулик тоже не знает")
		assert_eq(outcome.die_index, CheatOutcome.NONE)
	assert_gt(changed, 10, "кубик действительно перебрасывается")


func test_sleeve_die_counts_in_reveal_but_not_in_dice_counts() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.sleeve_die())
	var sleeve_face := _last_outcome(mc, 0).new_face
	assert_eq(mc.sleeve_of(0), [sleeve_face] as Array[int])
	assert_eq(mc.view_for(0).sleeve_dice, [sleeve_face] as Array[int])
	assert_eq(mc.dice_counts, [5, 5, 5, 5] as Array[int], "публичное число кубиков не меняется")
	assert_eq(mc.view_for(1).sleeve_dice.size(), 0)

	var face := sleeve_face if sleeve_face != PerudoRules.JOKER_FACE else 2
	var on_table := PerudoRules.count_on_table(HANDS_4, face, true)
	mc.submit_action(0, MatchAction.make_bid(on_table + 1, face))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.last_reveal.result.actual_count, on_table + 1, "кубик из рукава засчитан")
	assert_true(mc.last_reveal.result.bid_holds)
	assert_eq(mc.last_reveal.sleeve_dice[0], [sleeve_face] as Array[int])
	assert_eq(mc.last_reveal.hands[0].size(), 5, "в чашке его нет")

	mc.next_round()
	mc.roll()
	assert_eq(mc.sleeve_of(0).size(), 0, "только на этот раунд")


func test_abyss_whisper_counts_others_and_is_not_cheating() -> void:
	var mc := _started(HANDS_4, RiskMode.ALWAYS_FAIL)
	watch_signals(mc)
	assert_eq(mc.submit_cheat(0, CheatAction.abyss_whisper(4)), Err.OK)
	var outcome := _last_outcome(mc, 0)
	assert_false(outcome.failed, "риска нет")
	# Кроме своих [2,3,4,5,6]: у 1-го 4 (1 шт), у 2-го единица (1), у 3-го 4,4,4 → 5.
	assert_eq(outcome.whisper_count, 5)
	assert_eq(mc.cheats.sanity[0], 6)
	assert_eq(mc.cheaters_this_round().size(), 0, "не жульничество")
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	assert_signal_not_emitted(mc, "evidence_shown", "улик не оставляет")


# --- Мгновенный провал -----------------------------------------------------------

func test_failed_trick_is_punished_immediately() -> void:
	var mc := _started(HANDS_4, RiskMode.ALWAYS_FAIL)
	watch_signals(mc)
	assert_eq(mc.submit_cheat(0, CheatAction.peek(1, 0)), Err.OK)
	assert_signal_emitted_with_parameters(mc, "cheat_failed", [0, Kind.PEEK])
	assert_signal_not_emitted(mc, "cheat_resolved")
	assert_eq(mc.dice_counts[0], 3, "−2 кубика")
	assert_eq(mc.cheats.sanity[0], 0, "Рассудок → 0")
	assert_signal_emitted_with_parameters(mc, "madness_began", [0])
	assert_eq(mc.phase, Phase.ROUND_END, "раунд окончен досрочно")
	assert_null(mc.last_reveal, "без вскрытия")
	assert_signal_emitted_with_parameters(mc, "round_ended", [0, false])
	assert_eq(mc.view_for(0).cheat_outcomes.size(), 0, "ничего не узнал")
	mc.next_round()
	assert_eq(mc.phase, Phase.ROLL, "новый бросок у всех")


func test_sleeve_die_vanishes_when_caught_later() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.sleeve_die())
	for id in 4:
		mc.submit_action(id, MatchAction.make_bid(2 + id, 3))
	mc.cheats.risk_mode = RiskMode.ALWAYS_FAIL
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	assert_eq(mc.sleeve_of(0).size(), 0)
	assert_eq(mc.dice_counts[0], 3, "рукав не смягчает штраф")


func test_failed_loaded_die_ends_round_before_roll() -> void:
	var mc := _rolling(4, RiskMode.ALWAYS_FAIL)
	mc.submit_cheat(2, CheatAction.loaded_die(6))
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_eq(mc.dice_counts[2], 3)
	mc.next_round()
	assert_eq(mc.round_rules.is_palifico, false)
	mc.roll()
	assert_eq(mc.current_player, 2, "начинает пойманный")


func test_caught_player_with_two_dice_is_eliminated_and_match_can_end() -> void:
	var mc := _started_with([[2, 3], [4, 5]], RiskMode.ALWAYS_FAIL)
	watch_signals(mc)
	mc.submit_cheat(0, CheatAction.sleight(0))
	assert_eq(mc.dice_counts[0], 0)
	assert_signal_emitted_with_parameters(mc, "player_eliminated", [0])
	assert_eq(mc.phase, Phase.MATCH_OVER)
	assert_eq(mc.winner_id, 1)


func test_penalty_down_to_one_die_triggers_palifico() -> void:
	var mc := _started_with([[2, 3, 4], [4, 5, 6, 6, 6], [1, 2, 3, 4, 5]], RiskMode.ALWAYS_FAIL)
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	assert_eq(mc.dice_counts[0], 1)
	mc.next_round()
	assert_true(mc.round_rules.is_palifico)


# --- Улики -----------------------------------------------------------------------

func test_successful_trick_leaves_evidence_at_next_action() -> void:
	var mc := _started()
	watch_signals(mc)
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	assert_signal_not_emitted(mc, "evidence_shown", "не сразу — как и ложная улика")
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	assert_signal_emit_count(mc, "evidence_shown", 1)
	assert_signal_emitted_with_parameters(mc, "evidence_shown", [0])
	assert_eq(mc.view_for(2).evidence, [1, 0, 0, 0] as Array[int], "улики видны всем")


func test_loaded_die_evidence_appears_at_first_action() -> void:
	var mc := _rolling()
	mc.submit_cheat(1, CheatAction.loaded_die(6))
	watch_signals(mc)
	mc.roll(HANDS_4)
	assert_signal_not_emitted(mc, "evidence_shown")
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.make_bid(3, 3))
	assert_signal_emitted_with_parameters(mc, "evidence_shown", [1])


func test_false_evidence_for_honest_players() -> void:
	var mc := _started()
	mc.cheats.false_evidence_chance = 1.0
	watch_signals(mc)
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.make_bid(3, 3))
	assert_signal_emit_count(mc, "evidence_shown", 2)
	assert_eq(mc.cheaters_this_round().size(), 0, "но в журнале никого")


func test_cheater_gets_exactly_one_evidence_per_trick_turn() -> void:
	var mc := _started()
	mc.cheats.false_evidence_chance = 1.0
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	watch_signals(mc)
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	assert_signal_emit_count(mc, "evidence_shown", 1)


func test_evidence_resets_each_round() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.dudo())
	mc.next_round()
	assert_eq(mc.view_for(2).evidence, [0, 0, 0, 0] as Array[int])


func test_false_evidence_rate_is_about_fifteen_percent() -> void:
	var n := {"actions": 0, "evidence": 0}
	for i in 60:
		var agents: Array[MatchAgent] = []
		for j in 4:
			agents.append(RandomAgent.new(Rng.make_seeded(i * 10 + j)))
		var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(i))
		mc.bid_placed.connect(func(_p: int, _b: Bid) -> void: n.actions += 1)
		mc.challenge_revealed.connect(func(_r: ChallengeReveal) -> void: n.actions += 1)
		mc.evidence_shown.connect(func(_p: int) -> void: n.evidence += 1)
		mc.start_match()
		while mc.advance_auto():
			pass
	assert_gt(n.actions, 2000)
	assert_almost_eq(float(n.evidence) / n.actions, CheatBalance.FALSE_EVIDENCE_CHANCE, 0.02)


func test_risk_rates_match_constants() -> void:
	var tries := 1500
	var cases := [
		[CheatAction.peek(1, 0), CheatBalance.RISK_LOW],
		[CheatAction.sleight(0), CheatBalance.RISK_MEDIUM],
		[CheatAction.nudge_cup(1), CheatBalance.RISK_HIGH],
		[CheatAction.sleeve_die(), CheatBalance.RISK_HIGH],
	]
	for c in cases:
		var fails := 0
		for i in tries:
			var mc := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(i))
			mc.start_match(0)
			mc.roll([[1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5]])
			mc.submit_cheat(0, c[0])
			if mc.phase == Phase.ROUND_END:
				fails += 1
		assert_almost_eq(float(fails) / tries, c[1], 0.035, str(c[0]))


func test_cheats_do_not_shift_dice_rolls() -> void:
	var a := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(77))
	var b := MatchController.new(_humans(3), RuleOptions.new(), Rng.make_seeded(77))
	b.cheats.false_evidence_chance = 1.0
	b.cheats.risk_mode = RiskMode.NEVER_FAIL
	for mc in [a, b]:
		mc.start_match(0)
		mc.roll()
	b.submit_cheat(0, CheatAction.abyss_whisper(3))
	for mc in [a, b]:
		mc.submit_action(0, MatchAction.make_bid(1, 2))
		mc.submit_action(1, MatchAction.make_bid(1, 3))
		mc.submit_action(2, MatchAction.make_bid(1, 4))
		mc.submit_action(0, MatchAction.dudo())
		mc.next_round()
		mc.roll()
	for id in 3:
		assert_eq(a.hand_of(id), b.hand_of(id))


# --- Обвинение -------------------------------------------------------------------

func test_correct_accusation_punishes_cheater() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.sleeve_die())
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.make_bid(3, 3))
	watch_signals(mc)
	assert_eq(mc.submit_action(2, MatchAction.accuse(0)), Err.OK, "обвинять можно не только соседа")
	assert_signal_emitted_with_parameters(mc, "accusation_made", [2, 0, true])
	assert_eq(mc.dice_counts, [3, 5, 5, 5] as Array[int])
	assert_eq(mc.cheats.sanity[0], 0)
	assert_eq(mc.sleeve_of(0).size(), 0, "кубик из рукава исчезает")
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_null(mc.last_reveal)
	assert_signal_emitted_with_parameters(mc, "round_ended", [0, false])


func test_false_accusation_costs_accuser_one_die() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.abyss_whisper(3))
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	watch_signals(mc)
	mc.submit_action(1, MatchAction.accuse(0))
	assert_signal_emitted_with_parameters(mc, "accusation_made", [1, 0, false])
	assert_eq(mc.dice_counts, [5, 4, 5, 5] as Array[int], "«Шёпот Бездны» — не жульничество")
	assert_eq(mc.cheats.sanity[1], 9)
	assert_eq(mc.phase, Phase.ROUND_END)
	assert_signal_emitted_with_parameters(mc, "round_ended", [1, false])


func test_accusation_checks_whole_round_but_only_current_round() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.submit_action(1, MatchAction.make_bid(3, 3))
	mc.submit_action(2, MatchAction.make_bid(4, 3))
	mc.submit_action(3, MatchAction.make_bid(5, 3))
	mc.submit_action(0, MatchAction.make_bid(6, 3))
	mc.submit_action(1, MatchAction.accuse(0))
	assert_eq(mc.dice_counts[0], 3, "трюк был в прошлом ходу этого раунда — найден")

	mc.next_round()
	mc.roll()
	var accuser := mc.current_player
	assert_eq(accuser, 0)
	mc.submit_action(0, MatchAction.accuse(1))
	assert_eq(mc.dice_counts[0], 2, "прошлые раунды не в счёт")


func test_accusation_can_be_made_before_any_bid() -> void:
	var mc := _started()
	assert_true(mc.view_for(0).can_accuse(2))
	assert_eq(mc.submit_action(0, MatchAction.accuse(2)), Err.OK)
	assert_eq(mc.dice_counts[0], 4)


func test_cannot_accuse_self_or_eliminated() -> void:
	var mc := _started()
	mc.dice_counts[2] = 0
	assert_eq(mc.submit_action(0, MatchAction.accuse(0)), Err.ILLEGAL_ACTION)
	assert_eq(mc.submit_action(0, MatchAction.accuse(2)), Err.ILLEGAL_ACTION)
	assert_eq(mc.submit_action(0, MatchAction.accuse(9)), Err.ILLEGAL_ACTION)
	assert_eq(mc.submit_action(1, MatchAction.accuse(0)), Err.NOT_YOUR_TURN)


func test_correct_accusation_against_loaded_die_from_roll_phase() -> void:
	var mc := _rolling()
	mc.submit_cheat(3, CheatAction.loaded_die(2))
	mc.roll(HANDS_4)
	mc.submit_action(0, MatchAction.accuse(3))
	assert_eq(mc.dice_counts[3], 3)


# --- Боты: точки для М6 ----------------------------------------------------------

func test_bot_turn_cheat_is_applied_before_its_action() -> void:
	var bot := CheatingBot.new(Rng.make_seeded(5))
	bot.turn_cheat = CheatAction.abyss_whisper(5)
	var agents: Array[MatchAgent] = [bot, HumanAgent.new()]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.start_match(0)
	mc.roll()
	watch_signals(mc)
	assert_eq(mc.play_bot_turn(), Err.OK)
	assert_signal_emitted(mc, "cheat_resolved")
	assert_eq(mc.cheats.sanity[0], 6)
	assert_eq(mc.current_player, 1, "после трюка бот сделал ход")


func test_bot_roll_cheat_is_applied_in_roll() -> void:
	var bot := CheatingBot.new(Rng.make_seeded(5))
	bot.roll_cheat = CheatAction.loaded_die(6)
	var agents: Array[MatchAgent] = [HumanAgent.new(), bot]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.cheats.risk_mode = RiskMode.NEVER_FAIL
	mc.start_match(0)
	mc.roll()
	assert_eq(mc.hand_of(1)[0], 6)
	assert_eq(mc.cheaters_this_round(), [1] as Array[int])


func test_caught_bot_does_not_act() -> void:
	var bot := CheatingBot.new(Rng.make_seeded(5))
	bot.turn_cheat = CheatAction.sleight(0)
	var agents: Array[MatchAgent] = [bot, HumanAgent.new(), HumanAgent.new()]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.cheats.risk_mode = RiskMode.ALWAYS_FAIL
	mc.start_match(0)
	mc.roll()
	watch_signals(mc)
	mc.play_bot_turn()
	assert_signal_not_emitted(mc, "bid_placed")
	assert_eq(mc.phase, Phase.ROUND_END)


func test_cheat_signals_reach_events_bus() -> void:
	var mc := _started()
	MatchEventBridge.connect_all(mc, Events)
	watch_signals(Events)
	mc.submit_cheat(0, CheatAction.peek(1, 0))
	mc.submit_action(0, MatchAction.accuse(1))
	assert_signal_emitted(Events, "cheat_resolved")
	assert_signal_emitted(Events, "sanity_changed")
	assert_signal_emitted(Events, "evidence_shown")
	assert_signal_emitted_with_parameters(Events, "accusation_made", [0, 1, false])
