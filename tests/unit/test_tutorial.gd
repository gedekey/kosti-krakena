extends GutTest
## М13: сценарий обучающего матча без UI — контроллер + режиссёр + Моряк по сценарию.

const Cmd := TutorialStep.Command
const Phase := MatchController.Phase
const HUMAN := TutorialScript.HUMAN_ID
const SAILOR := TutorialScript.SAILOR_ID


func _setup() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var mc := TutorialScript.make_controller(rng)
	var director := TutorialDirector.new(mc)
	mc.start_match(TutorialScript.FIRST_PLAYER)
	return [mc, director]


## Сделать то, что просит текущий шаг (как игрок), или дать походить Моряку.
func _do_step(mc: MatchController, d: TutorialDirector) -> void:
	if not d.is_ready():
		assert_true(mc.advance_auto(), "ходит Моряк")
		return
	var s := d.step()
	match s.command:
		Cmd.ROLL:
			mc.roll(d.preset_hands())
		Cmd.BID:
			assert_eq(mc.submit_action(HUMAN, MatchAction.new(MatchAction.Kind.BID, s.bid)),
					MatchController.Result.OK, "ставка %s" % s.bid)
		Cmd.LIAR:
			assert_eq(mc.submit_action(HUMAN, MatchAction.dudo()), MatchController.Result.OK)
		Cmd.TRICK:
			assert_eq(mc.submit_cheat(HUMAN, CheatAction.peek(s.target_id, 0)),
					MatchController.Result.OK)
		Cmd.ACCUSE:
			assert_eq(mc.submit_action(HUMAN, MatchAction.accuse(s.target_id)),
					MatchController.Result.OK)
		Cmd.CONTINUE:
			d.notify_continue()
			if not d.is_finished():
				mc.next_round()


func test_script_plays_from_start_to_finish() -> void:
	var r := _setup()
	var mc: MatchController = r[0]
	var d: TutorialDirector = r[1]
	var finished := [false]
	d.finished.connect(func() -> void: finished[0] = true)
	var guard := 0
	while not d.is_finished() and guard < 100:
		guard += 1
		_do_step(mc, d)
	assert_true(d.is_finished(), "обучение пройдено до конца")
	assert_true(finished[0], "сигнал finished")
	assert_eq(d.index, d.step_count() - 1)
	assert_eq(mc.round_number, 3, "три раунда")
	assert_eq(mc.dice_counts, [5, 1] as Array[int], "Моряк: −1, −1, −2 за жульничество")
	assert_true(mc.cheats.is_mad(SAILOR), "пойманный Моряк сошёл с ума")
	assert_eq(mc.cheats.sanity[HUMAN], CheatBalance.START_SANITY - Cheat.cost(Cheat.Kind.PEEK))
	assert_eq(mc.phase, Phase.ROUND_END)


func test_rounds_use_scripted_hands_and_show_what_coach_says() -> void:
	var r := _setup()
	var mc: MatchController = r[0]
	var d: TutorialDirector = r[1]
	var reveals: Array[ChallengeReveal] = []
	var evidence: Array[int] = []
	mc.challenge_revealed.connect(func(rv: ChallengeReveal) -> void: reveals.append(rv))
	mc.evidence_shown.connect(func(id: int) -> void: evidence.append(id))
	var guard := 0
	while not d.is_finished() and guard < 100:
		guard += 1
		if mc.phase == Phase.BIDDING and mc.round_number <= TutorialScript.HANDS.size():
			assert_eq(mc.hand_of(HUMAN), _hand(mc.round_number, HUMAN), "кубики по сценарию")
		_do_step(mc, d)
	assert_eq(reveals.size(), 2)
	# Раунд 1: Моряк блефовал 5 × 4 — четвёрок две.
	assert_eq([reveals[0].bid.quantity, reveals[0].bid.face], [5, 4])
	assert_eq(reveals[0].result.actual_count, 2)
	assert_false(reveals[0].result.bid_holds)
	# Раунд 2: 5 × 5 держится благодаря единицам.
	assert_eq([reveals[1].bid.quantity, reveals[1].bid.face], [5, 5])
	assert_eq(reveals[1].caller_id, SAILOR)
	assert_eq(reveals[1].result.actual_count, 6)
	assert_true(reveals[1].result.bid_holds)
	# Раунд 3: улика у игрока (подглядел) и у Моряка (рукав).
	assert_true(evidence.has(HUMAN), "свой трюк оставил улику")
	assert_true(evidence.has(SAILOR), "улика у Моряка")


func _hand(round_number: int, id: int) -> Array[int]:
	var out: Array[int] = []
	out.assign(TutorialScript.HANDS[round_number - 1][id])
	return out


func test_director_lets_only_the_expected_command() -> void:
	var r := _setup()
	var mc: MatchController = r[0]
	var d: TutorialDirector = r[1]
	assert_eq(d.step().command, Cmd.ROLL)
	assert_true(d.allows(Cmd.ROLL))
	assert_false(d.allows(Cmd.BID))
	mc.roll(d.preset_hands())
	assert_eq(d.step().command, Cmd.BID)
	assert_true(d.is_ready(), "игрок ходит первым")
	assert_true(d.allows_bid(Bid.new(2, 3)))
	assert_false(d.allows_bid(Bid.new(3, 3)), "другая ставка не по сценарию")
	assert_false(d.allows(Cmd.LIAR))
	assert_false(d.allows_accuse(SAILOR))
	assert_eq(d.expected_bid().quantity, 2)
	# Не та ставка не двигает шаг.
	mc.submit_action(HUMAN, MatchAction.make_bid(2, 4))
	assert_eq(d.step().command, Cmd.BID)


func test_step_waits_while_sailor_moves() -> void:
	var r := _setup()
	var mc: MatchController = r[0]
	var d: TutorialDirector = r[1]
	mc.roll(d.preset_hands())
	mc.submit_action(HUMAN, MatchAction.make_bid(2, 3))
	assert_eq(d.step().command, Cmd.LIAR)
	assert_false(d.is_ready(), "ходит Моряк — шаг ждёт")
	assert_false(d.allows(Cmd.LIAR))
	mc.advance_auto()
	assert_true(d.is_ready())
	assert_eq([mc.current_bid.quantity, mc.current_bid.face], [5, 4], "блеф Моряка")


func test_trick_step_allows_only_peek_at_sailor() -> void:
	var r := _setup()
	var mc: MatchController = r[0]
	var d: TutorialDirector = r[1]
	var guard := 0
	while d.step().command != Cmd.TRICK and guard < 100:
		guard += 1
		_do_step(mc, d)
	while not d.is_ready() and guard < 200:
		guard += 1
		mc.advance_auto()
	assert_true(d.allows_trick(Cheat.Kind.PEEK))
	assert_false(d.allows_trick(Cheat.Kind.SLEEVE_DIE))
	assert_true(d.allows_trick_target(SAILOR))
	assert_false(d.allows(Cmd.BID), "сначала трюк")


func test_hands_for_rejects_mismatched_counts() -> void:
	var five: Array[int] = [5, 5]
	assert_eq(TutorialScript.hands_for(1, five).size(), 2)
	assert_eq(TutorialScript.hands_for(2, five), [], "у Моряка не 4 кубика — бросок честный")
	assert_eq(TutorialScript.hands_for(9, five), [])
	assert_eq(TutorialScript.hands_for(0, five), [])


func test_scripted_agent_falls_back_to_lowest_bid() -> void:
	var turns: Array[ScriptedAgent.Turn] = [ScriptedAgent.Turn.new(MatchAction.make_bid(1, 2))]
	var agent := ScriptedAgent.new(BotRoster.by_id(&"sailor"), turns)
	var agents: Array[MatchAgent] = [HumanAgent.new(), agent]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var mc := MatchController.new(agents, RuleOptions.new(), rng)
	mc.start_match(HUMAN)
	mc.roll()
	mc.submit_action(HUMAN, MatchAction.make_bid(3, 4))
	mc.advance_auto()   # 1 × 2 ниже 3 × 4 — недопустимо, берётся минимальная ставка
	assert_eq(mc.bid_history.size(), 2)
	assert_eq(mc.current_bidder, 1)
	assert_false(mc.current_bid.equals(Bid.new(1, 2)), "ход из сценария недопустим")
	assert_eq(agent.remaining(), 0)
