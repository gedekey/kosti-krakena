extends GutTest
## ИИ ботов честной игры (М3): решения, характеры, честность информации, сила.

const Kind := MatchAction.Kind
const NO_PLAYER := PerudoRules.NO_PLAYER


## Предсказуемый характер без шума и блефа — для проверки решений.
func _calm(changes := {}) -> BotPersonality:
	var p := BotPersonality.new()
	p.id = &"calm"
	p.bluff_chance = 0.0
	p.noise = 0.0
	p.dudo_threshold = 0.4
	p.calza_threshold = 0.5
	p.opening_confidence = 0.6
	for key in changes:
		p.set(key, changes[key])
	return p


func _bot(p: BotPersonality, seed_value := 1) -> BotAgent:
	return BotAgent.new(p, Rng.make_seeded(seed_value))


func _view(own: Array, counts: Array, bid: Bid = null, bidder := 1,
		palifico := false, options := RuleOptions.new()) -> PlayerView:
	var view := PlayerView.new()
	view.player_id = 0
	view.own_dice.assign(own)
	view.dice_counts.assign(counts)
	view.round_rules = RoundRules.new(palifico)
	view.options = options
	view.current_bid = bid
	if bid != null:
		view.current_bidder = bidder
		view.bid_history.append(BidEntry.new(bidder, bid))
	return view


# --- Решения -------------------------------------------------------------------

func test_calls_dudo_on_nearly_impossible_bid() -> void:
	var view := _view([2, 3, 4, 6, 6], [5, 5, 5], Bid.new(13, 5))
	assert_eq(_bot(_calm()).choose_action(view).kind, Kind.DUDO)


func test_raises_when_current_bid_is_certain() -> void:
	var view := _view([5, 5, 5, 1, 1], [5, 5, 5], Bid.new(3, 5))
	var action := _bot(_calm()).choose_action(view)
	assert_eq(action.kind, Kind.BID)
	assert_true(view.is_legal(action))


func test_calls_calza_when_exact_is_likely() -> void:
	# Свои 4 пятёрки, у соперника 1 кубик: ровно 4 с шансом 4/6.
	var view := _view([5, 5, 5, 5], [4, 1], Bid.new(4, 5))
	assert_eq(_bot(_calm()).choose_action(view).kind, Kind.CALZA)


func test_no_calza_with_full_cup() -> void:
	var view := _view([5, 5, 5, 5, 2], [5, 1], Bid.new(4, 5))
	assert_ne(_bot(_calm()).choose_action(view).kind, Kind.CALZA)


func test_no_calza_when_disabled() -> void:
	var options := RuleOptions.new()
	options.calza_enabled = false
	var view := _view([5, 5, 5, 5], [4, 1], Bid.new(4, 5), 1, false, options)
	assert_ne(_bot(_calm()).choose_action(view).kind, Kind.CALZA)


func test_opening_bids_on_own_strongest_face() -> void:
	var view := _view([4, 4, 4, 1, 2], [5, 5])
	var action := _bot(_calm()).choose_action(view)
	assert_eq(action.kind, Kind.BID)
	assert_eq(action.bid.face, 4)
	assert_gte(action.bid.quantity, 4, "своих четвёрок с джокерами — 4")


func test_opening_never_on_ones_outside_palifico() -> void:
	var view := _view([1, 1, 1, 1, 1], [5, 5])
	var action := _bot(_calm()).choose_action(view)
	assert_ne(action.bid.face, PerudoRules.JOKER_FACE)
	assert_true(view.is_legal(action))


func test_palifico_keeps_fixed_face() -> void:
	var view := _view([3], [1, 4], Bid.new(2, 6), 1, true)
	var action := _bot(_calm()).choose_action(view)
	assert_true(view.is_legal(action))
	if action.kind == Kind.BID:
		assert_eq(action.bid.face, 6)


func test_dudo_when_every_raise_is_hopeless() -> void:
	var view := _view([6, 6], [2, 1], Bid.new(3, 6))
	assert_eq(_bot(_calm()).choose_action(view).kind, Kind.DUDO)


func test_same_seed_same_decision() -> void:
	var p: BotPersonality = BotRoster.by_id(&"plague_cultist")
	var view := _view([2, 3, 3, 5, 6], [5, 5, 5, 5], Bid.new(4, 3))
	for s in 20:
		var a := _bot(p, s).choose_action(view)
		var b := _bot(p, s).choose_action(view)
		assert_eq(str(a), str(b))


## Бот видит только PlayerView: чужие кубики не влияют на решение.
func test_decision_does_not_depend_on_hidden_dice() -> void:
	var p: BotPersonality = BotRoster.by_id(&"deep_one")
	var mine := [2, 2, 5, 6, 1]
	for s in 10:
		var actions: Array[String] = []
		for others in [[[3, 3, 3, 3, 3], [4, 4, 4, 4, 4]], [[1, 1, 1, 1, 1], [2, 2, 2, 2, 2]]]:
			var agents: Array[MatchAgent] = [_bot(p, s), HumanAgent.new(), HumanAgent.new()]
			var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(s))
			mc.start_match(1)
			mc.roll([mine, others[0], others[1]])
			mc.submit_action(1, MatchAction.make_bid(3, 4))
			mc.submit_action(2, MatchAction.make_bid(4, 4))
			actions.append(str(mc.agent(0).choose_action(mc.view_for(0))))
		assert_eq(actions[0], actions[1])


## Во всех режимах правил боты делают только допустимые ходы.
func test_full_matches_only_legal_actions() -> void:
	var roster := BotRoster.all()
	var rng := Rng.make_seeded(99)
	for i in 24:
		var options := RuleOptions.new()
		options.palifico_enabled = i % 2 == 0
		options.calza_enabled = i % 3 != 0
		var agents: Array[MatchAgent] = []
		for seat in 2 + i % 5:
			agents.append(BotAgent.new(roster[(i + seat) % roster.size()], Rng.make_seeded(i * 10 + seat)))
		var mc := MatchController.new(agents, options, Rng.make_seeded(i))
		mc.start_match()
		var steps := 0
		while mc.phase != MatchController.Phase.MATCH_OVER and steps < 5000:
			steps += 1
			if mc.phase == MatchController.Phase.BIDDING:
				var id := mc.current_player
				var action := mc.agent(id).choose_action(mc.view_for(id))
				if not mc.is_action_legal(id, action):
					fail_test("Illegal action %s by %s" % [action, roster[(i + id) % roster.size()].id])
					return
				mc.submit_action(id, action)
			else:
				mc.advance_auto()
		assert_eq(mc.phase, MatchController.Phase.MATCH_OVER, "матч %d завершился" % i)


# --- Характеры -----------------------------------------------------------------

func test_roster_has_twelve_characters_from_design() -> void:
	var roster := BotRoster.all()
	assert_eq(roster.size(), 12)
	var stars := {}
	var ids := {}
	for p in roster:
		assert_not_null(p)
		ids[p.id] = true
		stars[p.id] = p.stars
		assert_ne(TranslationServer.translate(p.name_key), StringName(p.name_key),
				"есть перевод имени %s" % p.id)
	assert_eq(ids.size(), 12, "id уникальны")
	assert_eq(stars, {&"scholar": 2, &"occultist": 2, &"sailor": 1, &"witch": 2,
			&"plague_cultist": 2, &"drowned": 1, &"deep_one": 3, &"ulits": 1, &"ichthyander": 1,
			&"omen": 2, &"craber": 2, &"horror_master": 3})
	assert_eq(BotRoster.by_id(&"sailor").name_key, "BOT_SAILOR")
	assert_null(BotRoster.by_id(&"nobody"))


func test_characters_differ_in_style() -> void:
	var sailor := BotRoster.by_id(&"sailor")
	var drowned := BotRoster.by_id(&"drowned")
	var deep := BotRoster.by_id(&"deep_one")
	assert_gt(sailor.bluff_chance, drowned.bluff_chance, "моряк блефует, утопленник почти нет")
	assert_lt(deep.noise, sailor.noise, "босс считает точнее простака")
	assert_gt(deep.bid_reading, sailor.bid_reading)


# --- Сила и симуляция ----------------------------------------------------------

func test_three_stars_beat_one_star() -> void:
	var deep := BotRoster.by_id(&"deep_one")
	for weak_id in [&"sailor", &"drowned"]:
		var rate := BotSimulation.duel(deep, BotRoster.by_id(weak_id), 120, Rng.make_seeded(5))
		assert_gt(rate, 0.6, "★★★ против %s: %.0f%%" % [weak_id, rate * 100.0])


func test_tables_tally_is_consistent() -> void:
	var roster := BotRoster.all()
	var tally := BotSimulation.tables(roster, 4, 20, Rng.make_seeded(3))
	var played := 0
	var won := 0
	for id in tally:
		played += tally[id].played
		won += tally[id].won
	assert_eq(played, 80)
	assert_eq(won, 20)


func test_report_lists_every_character() -> void:
	var text := BotSimulation.report(BotRoster.all(), 2, 7, 3, Rng.make_seeded(1))
	for p in BotRoster.all():
		assert_string_contains(text, String(p.id))
