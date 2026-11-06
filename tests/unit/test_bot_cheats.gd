extends GutTest
## ИИ жульничества, обвинений и Безумия (М6): знания от трюков в оценке стола,
## выбор трюков, подозрения, обвинения, поведение в Безумии, симуляция стиля.

const EPS := 0.000001
const K := Cheat.Kind
const Phase := MatchController.Phase


# --- Помощники -------------------------------------------------------------------

func _view(own: Array, counts: Array, bid: Bid = null, bidder := 1, me := 0) -> PlayerView:
	var view := PlayerView.new()
	view.player_id = me
	view.round_number = 1
	view.own_dice.assign(own)
	view.dice_counts.assign(counts)
	view.round_rules = RoundRules.new(false)
	view.options = RuleOptions.new()
	view.current_bid = bid
	if bid != null:
		view.current_bidder = bidder
		view.bid_history.append(BidEntry.new(bidder, bid))
	for i in counts.size():
		view.mad.append(false)
		view.evidence.append(0)
	view.cheat_window = CheatRules.CheatWindow.TURN
	return view


func _outcome(kind: Cheat.Kind, action: CheatAction) -> CheatOutcome:
	return CheatOutcome.new(0, action)


func _peek(view: PlayerView, target: int, die: int, face: int) -> void:
	var o := _outcome(K.PEEK, CheatAction.peek(target, die))
	o.peeked_face = face
	view.cheat_outcomes.append(o)


func _whisper(view: PlayerView, face: int, count: int) -> void:
	var o := _outcome(K.ABYSS_WHISPER, CheatAction.abyss_whisper(face))
	o.whisper_count = count
	view.cheat_outcomes.append(o)


## Характер без шума и блефа, жульничает только указанными трюками.
func _cheater(kinds: Array, changes := {}) -> BotPersonality:
	var p := BotPersonality.new()
	p.id = &"test_cheater"
	p.bluff_chance = 0.0
	p.noise = 0.0
	p.cheat_chance = 1.0
	p.risk_tolerance = 1.0
	var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for k in kinds:
		weights[k] = 1.0
	p.cheat_weights = weights
	for key in changes:
		p.set(key, changes[key])
	return p


func _planner(p: BotPersonality, seed_value := 1) -> BotCheatPlanner:
	return BotCheatPlanner.new(p, Rng.make_seeded(seed_value))


func _plan(p: BotPersonality, view: PlayerView, seed_value := 1) -> CheatAction:
	return _planner(p, seed_value).choose_turn_cheat(view, TableEstimate.new(view))


## Число аргументов сигналов, которые считают тесты.
const SIGNAL_ARGS := {"cheat_resolved": 1, "cheat_failed": 2, "accusation_made": 3,
		"madness_began": 1}


## Играть матч до конца; counters — что считать (имя сигнала → счётчик).
func _play(agents: Array[MatchAgent], seed_value: int, counters: Dictionary) -> MatchController:
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(seed_value))
	for sig in counters:
		var bump := func() -> void: counters[sig] += 1
		mc.connect(sig, bump.unbind(SIGNAL_ARGS[sig]))
	mc.start_match()
	var steps := 0
	while mc.advance_auto() and steps < 20000:
		steps += 1
	return mc


# --- Оценка стола: знания от трюков ---------------------------------------------

func test_peeked_die_is_known() -> void:
	var naive := _view([2, 3, 4, 6, 6], [5, 1])
	var peeked := _view([2, 3, 4, 6, 6], [5, 1])
	_peek(peeked, 1, 0, 5)
	assert_almost_eq(TableEstimate.new(naive).p_at_least(5, 1), 1.0 / 3.0, EPS)
	assert_eq(TableEstimate.new(peeked).p_at_least(5, 1), 1.0, "подсмотренная пятёрка")
	assert_eq(TableEstimate.new(peeked).p_at_least(5, 2), 0.0, "у соседа один кубик")


func test_peeked_non_match_lowers_belief() -> void:
	var view := _view([2, 3, 4, 6, 6], [5, 2])
	_peek(view, 1, 1, 3)
	var est := TableEstimate.new(view)
	assert_almost_eq(est.p_at_least(5, 1), 1.0 / 3.0, EPS, "один кубик неизвестен")
	assert_true(est.is_peeked(1, 1))
	assert_false(est.is_peeked(1, 0))


func test_whisper_gives_exact_count() -> void:
	var view := _view([5, 5, 2, 3, 4], [5, 5, 5])
	_whisper(view, 5, 3)
	var est := TableEstimate.new(view)
	assert_true(est.knows_whisper(5))
	assert_eq(est.p_at_least(5, 5), 1.0, "2 своих + 3 у остальных")
	assert_eq(est.p_at_least(5, 6), 0.0)
	assert_eq(est.p_exactly(5, 5), 1.0)
	assert_almost_eq(est.expected_count(5), 5.0, EPS)


func test_failed_cheats_give_no_knowledge() -> void:
	var view := _view([2, 3, 4, 6, 6], [5, 1])
	_peek(view, 1, 0, 5)
	view.cheat_outcomes[0].failed = true
	assert_almost_eq(TableEstimate.new(view).p_at_least(5, 1), 1.0 / 3.0, EPS)


func test_sleeve_die_counts_as_own() -> void:
	var view := _view([2, 3], [2, 3])
	view.sleeve_dice.assign([4])
	assert_eq(TableEstimate.new(view).own_count(4), 1)


func test_distrust_of_own_dice() -> void:
	var view := _view([5, 5, 5], [3, 3])
	var sure := TableEstimate.new(view)
	var doubt := TableEstimate.new(view, 0.0, 0.5)
	assert_eq(sure.p_at_least(5, 3), 1.0)
	assert_lt(doubt.p_at_least(5, 3), 1.0, "в Безумии свои кубики могут врать")
	assert_gt(doubt.p_at_least(5, 3), sure.p_at_least(5, 6))
	assert_eq(doubt.own_count(5), 0, "увиденное — не точно")
	var same := TableEstimate.new(view, 0.0, 1.0)
	assert_almost_eq(same.p_at_least(4, 2), sure.p_at_least(4, 2), EPS)


# --- Выбор трюков ----------------------------------------------------------------

func test_default_personality_never_cheats() -> void:
	var p := BotPersonality.new()
	for s in 30:
		assert_null(_plan(p, _view([2, 3, 4, 5, 6], [5, 5, 5]), s))
		var roll_view := _view([], [5, 5, 5])
		roll_view.cheat_window = CheatRules.CheatWindow.ROLL
		assert_null(_planner(p, s).choose_roll_cheat(roll_view))


func test_peek_targets_neighbor_and_unseen_die() -> void:
	var p := _cheater([K.PEEK])
	var view := _view([2, 3, 4, 5, 6], [5, 2, 5, 2], Bid.new(5, 4), 3)
	for i in 2:
		_peek(view, 3, i, 4)
	for s in 20:
		var a := _plan(p, view, s)
		assert_not_null(a)
		assert_eq(a.kind, K.PEEK)
		assert_true(view.neighbors().has(a.target_id))
		assert_eq(a.target_id, 1, "у поставившего соседа (3) всё уже подсмотрено")
		assert_between(a.die_index, 0, 1)


func test_peek_only_on_doubtful_bid() -> void:
	var p := _cheater([K.PEEK])
	assert_null(_plan(p, _view([2, 3, 4, 5, 6], [5, 5])), "на открытии подглядывать незачем")
	assert_null(_plan(p, _view([4, 4, 4, 1, 6], [5, 5], Bid.new(3, 4))), "ставка верна наверняка")


func test_exposed_bot_prefers_to_end_round() -> void:
	# Вера в ставку ~0.44: обычно бот повышает, но после трюка улика покажется при
	# этом действии — «Ложь!» закончит раунд раньше, чем его обвинят.
	var p := _cheater([], {"dudo_threshold": 0.4})
	var view := _view([4, 2, 3, 5, 6], [5, 5, 5], Bid.new(5, 4))
	var calm := BotAgent.new(p, Rng.make_seeded(1)).choose_action(view)
	assert_ne(calm.kind, MatchAction.Kind.DUDO)
	var o := _outcome(K.SLEIGHT, CheatAction.sleight(1))
	o.new_face = 2
	view.cheat_outcomes.append(o)
	view.cheat_used = true
	assert_eq(BotAgent.new(p, Rng.make_seeded(1)).choose_action(view).kind, MatchAction.Kind.DUDO)


func test_peek_prefers_bidder() -> void:
	var view := _view([2, 3, 4, 5, 6], [5, 5, 5, 5], Bid.new(6, 4), 3)
	for s in 10:
		assert_eq(_plan(_cheater([K.PEEK]), view, s).target_id, 3)


func test_sleight_rerolls_die_off_plan() -> void:
	var view := _view([4, 4, 1, 2, 4], [5, 5], Bid.new(3, 4))
	for s in 10:
		var a := _plan(_cheater([K.SLEIGHT]), view, s)
		assert_eq(a.kind, K.SLEIGHT)
		assert_eq(a.die_index, 3, "единица — джокер, четвёрки на ставку; лишняя только двойка")
	var perfect := _view([4, 4, 1], [3, 5], Bid.new(3, 4))
	assert_null(_plan(_cheater([K.SLEIGHT]), perfect))


func test_nudge_only_neighbor_bidder() -> void:
	var p := _cheater([K.NUDGE_CUP])
	assert_null(_plan(p, _view([2, 3], [2, 2, 2, 2])), "нет ставки — толкать некого")
	assert_null(_plan(p, _view([2, 3], [2, 2, 2, 2], Bid.new(4, 3), 2)), "поставил не сосед")
	assert_null(_plan(p, _view([2, 3], [2, 2, 2, 2], Bid.new(2, 3), 1)), "ставке и так верится")
	var a := _plan(p, _view([2, 3], [2, 2, 2, 2], Bid.new(4, 3), 1))
	assert_eq(a.kind, K.NUDGE_CUP)
	assert_eq(a.target_id, 1)


func test_sleeve_once_per_round() -> void:
	var p := _cheater([K.SLEEVE_DIE])
	var view := _view([2, 3], [2, 2])
	assert_eq(_plan(p, view).kind, K.SLEEVE_DIE)
	view.sleeve_dice.assign([5])
	assert_null(_plan(p, view))


func test_whisper_only_on_doubtful_bid() -> void:
	var p := _cheater([K.ABYSS_WHISPER])
	var certain := _view([4, 4, 4, 4], [4, 5], Bid.new(3, 4))
	assert_null(_plan(p, certain), "ставка верна наверняка")
	var doubtful := _view([4, 2, 3, 5, 6], [5, 5], Bid.new(3, 4))
	var a := _plan(p, doubtful)
	assert_eq(a.kind, K.ABYSS_WHISPER)
	assert_eq(a.face, 4)
	_whisper(doubtful, 4, 1)
	assert_null(_plan(p, doubtful), "уже знает ответ")


func test_opening_whisper_on_own_best_face() -> void:
	var a := _plan(_cheater([K.ABYSS_WHISPER]), _view([6, 6, 2, 1, 3], [5, 5]))
	assert_eq(a.face, 6)


func test_respects_sanity_reserve_and_risk() -> void:
	var view := _view([2, 3], [2, 2])
	view.own_sanity = 4
	assert_null(_plan(_cheater([K.SLEEVE_DIE], {"sanity_reserve": 2}), view), "4 − 3 < 2")
	assert_not_null(_plan(_cheater([K.SLEEVE_DIE], {"sanity_reserve": 1}), view))
	assert_null(_plan(_cheater([K.SLEEVE_DIE], {"risk_tolerance": 0.2}), view), "риск 35%")
	view.own_sanity = 2
	assert_null(_plan(_cheater([K.SLEEVE_DIE]), view), "не по карману")


func test_no_cheats_when_mad_or_used_or_out_of_turn() -> void:
	var p := _cheater([K.PEEK, K.SLEEVE_DIE])
	var mad := _view([2, 3], [2, 2])
	mad.own_sanity = 0
	assert_null(_plan(p, mad))
	var used := _view([2, 3], [2, 2])
	used.cheat_used = true
	assert_null(_plan(p, used))
	var closed := _view([2, 3], [2, 2])
	closed.cheat_window = CheatRules.CheatWindow.CLOSED
	assert_null(_plan(p, closed))


func test_own_evidence_makes_cautious() -> void:
	var p := _cheater([K.SLEEVE_DIE], {"cheat_chance": 0.8})
	var clean := 0
	var marked := 0
	for s in 400:
		var a := _view([2, 3, 4], [3, 3, 3])
		if _plan(p, a, s) != null:
			clean += 1
		var b := _view([2, 3, 4], [3, 3, 3])
		b.evidence[0] = 2
		if _plan(p, b, s) != null:
			marked += 1
	assert_gt(clean, marked * 2, "чистых %d, с уликами %d" % [clean, marked])


func test_loaded_die_in_roll_phase() -> void:
	var p := _cheater([K.LOADED_DIE])
	var view := _view([], [5, 5])
	view.cheat_window = CheatRules.CheatWindow.ROLL
	var a := _planner(p).choose_roll_cheat(view)
	assert_eq(a.kind, K.LOADED_DIE)
	assert_eq(a.face, PerudoRules.JOKER_FACE, "джокер подходит к любой ставке")
	view.round_rules = RoundRules.new(true)
	a = _planner(p).choose_roll_cheat(view)
	assert_between(a.face, 1, 6)
	view.cheat_window = CheatRules.CheatWindow.TURN
	assert_null(_planner(p).choose_roll_cheat(view), "не фаза броска")
	assert_null(_plan(p, view), "в ход «Утяжелённую кость» не предлагает")


func test_bot_cheats_through_controller() -> void:
	# Вес «Утяжелённой кости» огромный — в броске почти наверняка; в ход — только «Подглядеть».
	var p := _cheater([K.PEEK], {"cheat_weights": PackedFloat32Array([1, 0, 100000, 0, 0, 0])})
	var cheater := BotAgent.new(p, Rng.make_seeded(4))
	var agents: Array[MatchAgent] = [cheater, HumanAgent.new()]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(4))
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	watch_signals(mc)
	mc.start_match(1)
	mc.roll([[4, 2, 2, 5, 6], [3, 3, 4, 5, 6]])
	assert_eq(mc.hand_of(0)[MatchController.LOADED_DIE_INDEX], PerudoRules.JOKER_FACE)
	# 3 тройки: у бота 1 (джокер), нужно 2 из 5 чужих — спорно, бот подглядывает.
	mc.submit_action(1, MatchAction.make_bid(3, 3))
	mc.play_bot_turn()
	assert_signal_emit_count(mc, "cheat_resolved", 2, "кость в броске + подглядел в ход")
	assert_lt(mc.cheats.sanity[0], CheatBalance.START_SANITY)


# --- Подозрения и обвинения -----------------------------------------------------

func _seen(round_number: int, evidence: Array, bids_by: Array, mad := []) -> PlayerView:
	var view := _view([2, 3, 4], [3, 3, 3])
	view.round_number = round_number
	view.evidence.assign(evidence)
	for id in bids_by:
		view.bid_history.append(BidEntry.new(id, Bid.new(1, 2)))
	for id in mad:
		view.mad[id] = true
	return view


func test_belief_grows_with_evidence() -> void:
	var s0 := Suspicion.new(0.0)
	s0.observe(_seen(1, [0, 0, 0], [1, 1]))
	var s1 := Suspicion.new(0.0)
	s1.observe(_seen(1, [0, 1, 0], [1, 1]))
	var s2 := Suspicion.new(0.0)
	s2.observe(_seen(1, [0, 2, 0], [1, 1]))
	assert_lt(s0.belief(1), AiBalance.CHEAT_PRIOR, "чистые ходы снижают подозрение")
	assert_gt(s1.belief(1), s0.belief(1))
	assert_gt(s2.belief(1), s1.belief(1))


func test_no_actions_means_prior() -> void:
	var s := Suspicion.new(0.0)
	s.observe(_seen(1, [0, 0, 0], []))
	assert_almost_eq(s.belief(2), AiBalance.CHEAT_PRIOR, EPS)


func test_mad_from_round_start_is_innocent() -> void:
	var s := Suspicion.new(0.0)
	s.observe(_seen(1, [0, 2, 0], [1, 1], [1]))
	assert_eq(s.belief(1), 0.0, "в Безумии жульничать нельзя — улики ложные")


func test_memory_carries_suspicion_across_rounds() -> void:
	var forgetful := Suspicion.new(0.0)
	var keen := Suspicion.new(1.0)
	for s in [forgetful, keen]:
		s.observe(_seen(1, [0, 3, 0], [1, 1, 1]))
		s.observe(_seen(2, [0, 0, 0], []))
	assert_almost_eq(forgetful.prior_for(1), AiBalance.CHEAT_PRIOR, EPS)
	assert_gt(keen.prior_for(1), AiBalance.CHEAT_PRIOR)
	assert_gt(keen.excess_evidence(1), 0.0)
	assert_lte(keen.prior_for(1), AiBalance.PRIOR_MAX)


func test_bot_accuses_suspicious_player() -> void:
	var p := _cheater([], {"accuse_threshold": 0.6})
	var view := _seen(1, [0, 0, 2], [1, 2, 1, 2])
	view.current_bid = Bid.new(1, 2)
	view.current_bidder = 2
	var action := BotAgent.new(p, Rng.make_seeded(1)).choose_action(view)
	assert_eq(action.kind, MatchAction.Kind.ACCUSE)
	assert_eq(action.target_id, 2)
	assert_true(view.is_legal(action))


func test_bot_does_not_accuse_below_threshold() -> void:
	var view := _seen(1, [0, 1, 0], [1, 2, 1, 2])
	view.current_bid = Bid.new(1, 2)
	view.current_bidder = 2
	var strict := BotAgent.new(_cheater([], {"accuse_threshold": 0.9}), Rng.make_seeded(1))
	assert_ne(strict.choose_action(view).kind, MatchAction.Kind.ACCUSE)
	var honest := BotAgent.new(BotPersonality.new(), Rng.make_seeded(1))
	var heavy := _seen(1, [0, 0, 3], [1, 2, 1, 2, 2])
	heavy.current_bid = Bid.new(1, 2)
	heavy.current_bidder = 2
	assert_ne(honest.choose_action(heavy).kind, MatchAction.Kind.ACCUSE, "по умолчанию не обвиняет")


func test_bot_may_accuse_before_first_bid() -> void:
	# Улика у того, кто уже действовал в раунде, до первой ставки бота нового раунда не бывает,
	# но с памятью о прошлых раундах подозрение есть и без улик.
	var p := _cheater([], {"accuse_threshold": 0.3, "evidence_memory": 1.0})
	var bot := BotAgent.new(p, Rng.make_seeded(1))
	bot.choose_action(_seen(1, [0, 4, 0], [1, 1, 1, 1]))
	var opening := _seen(2, [0, 0, 0], [])
	var action := bot.choose_action(opening)
	assert_eq(action.kind, MatchAction.Kind.ACCUSE)
	assert_eq(action.target_id, 1)


func test_whisper_knowledge_drives_decision() -> void:
	var p := _cheater([])
	var bot := BotAgent.new(p, Rng.make_seeded(1))
	# Ставка 6 пятёрок: свои 2, Шёпот сказал «у остальных 1» — точно ложь.
	var view := _view([5, 5, 2, 3, 4], [5, 5, 5], Bid.new(6, 5))
	assert_eq(bot.choose_action(view).kind, MatchAction.Kind.BID, "без Шёпота — верит")
	_whisper(view, 5, 1)
	assert_eq(bot.choose_action(view).kind, MatchAction.Kind.DUDO)


# --- Безумие ---------------------------------------------------------------------

func test_mad_bot_trusts_first_look_then_doubts() -> void:
	var bot := BotAgent.new(_cheater([], {"mad_awareness": 1.0}), Rng.make_seeded(1))
	var first := _view([5, 5, 5], [3, 3])
	first.own_sanity = 0
	assert_eq(bot.own_trust(first), 1.0, "сразу после броска — правда")
	assert_eq(bot.own_trust(first), 1.0, "тот же ход")
	var later := _view([5, 5, 5], [3, 3], Bid.new(2, 3))
	later.bid_history.push_front(BidEntry.new(0, Bid.new(1, 3)))
	later.own_sanity = 0
	assert_almost_eq(bot.own_trust(later), 1.0 - MadnessBalance.HALLUCINATION_CHANCE, EPS)
	var naive := BotAgent.new(_cheater([], {"mad_awareness": 0.0}), Rng.make_seeded(1))
	naive.own_trust(first)
	assert_eq(naive.own_trust(later), 1.0, "наивный верит глазам")


func test_sane_bot_trusts_own_dice() -> void:
	var bot := BotAgent.new(_cheater([], {"mad_awareness": 1.0}), Rng.make_seeded(1))
	bot.own_trust(_view([5], [1, 1]))
	var later := _view([5], [1, 1], Bid.new(1, 3))
	later.bid_history.push_front(BidEntry.new(0, Bid.new(1, 2)))
	assert_eq(bot.own_trust(later), 1.0)


# --- Полные матчи и симуляция ---------------------------------------------------

func test_roster_matches_finish_with_cheats_and_accusations() -> void:
	var counters := {"cheat_resolved": 0, "cheat_failed": 0, "accusation_made": 0,
			"madness_began": 0}
	var roster := BotRoster.all()
	for s in 12:
		var agents: Array[MatchAgent] = []
		for i in 4:
			agents.append(BotAgent.new(roster[(s + i) % roster.size()], Rng.make_seeded(s * 10 + i)))
		var mc := _play(agents, s, counters)
		assert_eq(mc.phase, Phase.MATCH_OVER, "матч %d завершился" % s)
	assert_gt(counters["cheat_resolved"], 0, "боты жульничают")
	assert_gt(counters["accusation_made"], 0, "боты обвиняют")
	assert_gt(counters["madness_began"], 0, "кто-то сходит с ума")


func test_cheating_bots_are_deterministic() -> void:
	var results: Array[String] = []
	for run in 2:
		var agents: Array[MatchAgent] = []
		for i in 4:
			agents.append(BotAgent.new(BotRoster.all()[i + 1], Rng.make_seeded(70 + i)))
		var counters := {"cheat_resolved": 0, "accusation_made": 0}
		var mc := _play(agents, 7, counters)
		results.append("%d %d %d %d" % [mc.winner_id, mc.round_number,
				counters["cheat_resolved"], counters["accusation_made"]])
	assert_eq(results[0], results[1])


func test_personalities_have_distinct_styles() -> void:
	var roster := BotRoster.all()
	var profiles := BotSimulation.new_profiles(roster)
	BotSimulation.tables(roster, 4, 120, Rng.make_seeded(11), RuleOptions.new(), profiles)
	var occ: BotSimulation.Profile = profiles[&"occultist"]
	var sailor: BotSimulation.Profile = profiles[&"sailor"]
	var witch: BotSimulation.Profile = profiles[&"witch"]
	var scholar: BotSimulation.Profile = profiles[&"scholar"]
	var drowned: BotSimulation.Profile = profiles[&"drowned"]
	assert_eq(_favorite(occ), K.ABYSS_WHISPER, "оккультист обожает Шёпот Бездны")
	assert_eq(_favorite(sailor), K.SLEEVE_DIE, "моряк — кубик в рукаве")
	assert_true(_favorite(witch) in [K.PEEK, K.SLEIGHT], "ведьма подглядывает и ловчит")
	assert_gt(occ.per_match(occ.went_mad), scholar.per_match(scholar.went_mad),
			"оккультист сходит с ума быстрее учёного")
	assert_gt(witch.per_match(witch.total_cheats()), scholar.per_match(scholar.total_cheats()),
			"учёный жульничает редко")
	assert_gt(scholar.per_match(scholar.accusations), sailor.per_match(sailor.accusations),
			"учёный часто обвиняет")
	assert_lt(drowned.per_match(drowned.total_cheats()), witch.per_match(witch.total_cheats()))
	assert_eq(scholar.played + occ.played + sailor.played + witch.played + drowned.played
			+ profiles[&"plague_cultist"].played + profiles[&"deep_one"].played, 480)


func test_ablation_covers_every_trick() -> void:
	var result := BotSimulation.trick_ablation(BotRoster.by_id(&"witch"), 4, 3, Rng.make_seeded(2))
	assert_eq(result.size(), Cheat.ALL.size() + 1)
	assert_true(result.has(&"honest"))
	assert_eq(result[&"honest"].total_cheats(), 0)
	for key in result:
		assert_eq(result[key].played, 4)
	var only_peek: BotSimulation.Profile = result[&"only_PEEK"]
	for k in Cheat.ALL:
		if k != K.PEEK:
			assert_eq(only_peek.cheats[k], 0)


func test_report_includes_style_and_ablation() -> void:
	var text := BotSimulation.report(BotRoster.all(), 1, 6, 3, Rng.make_seeded(1),
			RuleOptions.new(), 2)
	assert_string_contains(text, "Стиль за столом")
	assert_string_contains(text, "Абляция трюков")
	for k in Cheat.ALL:
		assert_string_contains(text, Cheat.Kind.keys()[k])


func _favorite(pr: BotSimulation.Profile) -> int:
	var best := 0
	for k in Cheat.ALL:
		if pr.cheats[k] > pr.cheats[best]:
			best = k
	return best
