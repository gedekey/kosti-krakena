extends GutTest
## М23: кампания — прогресс и открытие уровней, учёт матча, уровни-данные, модификаторы
## («Дурной глаз», «Скудный рассудок», «Мёртвая рука», «Логово» с приливом), достижения.

const Phase := MatchController.Phase
const Mod := CampaignLevel.Modifier
const HUMAN := 0


func _humans(count: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(HumanAgent.new())
	return agents


func _controller(level_number: int, seed_value := 1) -> MatchController:
	var level := CampaignLevels.get_level(level_number)
	var mc := MatchController.new(_humans(level.opponents.size() + 1), RuleOptions.new(),
			Rng.make_seeded(seed_value))
	CampaignModifiers.apply(level, mc)
	return mc


func _bid(q: int, f: int) -> MatchAction:
	return MatchAction.make_bid(q, f)


# --- Прогресс --------------------------------------------------------------------

func test_levels_open_strictly_in_order() -> void:
	var p := CampaignProgress.new()
	assert_true(p.is_unlocked(1))
	for n in range(2, CampaignBalance.LEVEL_COUNT + 1):
		assert_false(p.is_unlocked(n), "уровень %d закрыт" % n)
	assert_false(p.record_win(3), "закрытый уровень не засчитывается")
	assert_false(p.is_completed(3))
	assert_true(p.record_win(1))
	assert_true(p.is_unlocked(2))
	assert_false(p.is_unlocked(3))
	assert_false(p.record_win(1), "повтор пройденного — не впервые")
	assert_eq(p.frontier(), 2)


func test_finishing_all_levels_marks_campaign_and_restart_keeps_mark() -> void:
	var p := CampaignProgress.new()
	p.start_new(&"player3")
	for n in range(1, CampaignBalance.LEVEL_COUNT + 1):
		p.record_win(n)
	assert_true(p.is_finished())
	assert_true(p.ever_finished)
	p.record_loss()
	p.start_new(&"player2")
	assert_eq(p.completed_count(), 0)
	assert_true(p.flawless, "новая кампания — снова без поражений")
	assert_true(p.ever_finished, "отметка о прохождении остаётся")
	assert_eq(p.portrait, &"player2")
	assert_false(p.intro_seen)


func test_progress_saves_and_loads() -> void:
	var p := CampaignProgress.new()
	p.start_new(&"player5")
	p.intro_seen = true
	p.record_win(1)
	p.record_win(2)
	p.record_loss()
	var q := CampaignProgress.new()
	q.from_dict(p.to_dict())
	assert_true(q.started)
	assert_eq(q.portrait, &"player5")
	assert_true(q.intro_seen)
	assert_false(q.flawless)
	assert_true(q.is_completed(2))
	assert_true(q.is_unlocked(3))
	assert_false(q.is_unlocked(4))


func test_progress_ignores_gaps_and_junk() -> void:
	var q := CampaignProgress.new()
	q.from_dict({"completed": [1, 3, "x", 9], "portrait": 5, "started": "yes"})
	assert_true(q.is_completed(1))
	assert_false(q.is_completed(3), "без пройденного 2 уровень 3 не засчитан")
	assert_false(q.started)


# --- Учёт матча ------------------------------------------------------------------

func test_win_records_level_and_reports_clean() -> void:
	var t := CampaignTracker.new()
	watch_signals(t)
	t.begin(1)
	t.match_ended(HUMAN)
	assert_true(t.progress.is_completed(1))
	assert_eq(t.last_won, 1)
	assert_false(t.is_counting())
	assert_signal_emitted_with_parameters(t, "level_won", [1, true, true])


func test_cheating_human_is_not_clean_bots_do_not_matter() -> void:
	var t := CampaignTracker.new()
	watch_signals(t)
	t.begin(1)
	t.cheat_used(1)
	t.match_ended(HUMAN)
	assert_signal_emitted_with_parameters(t, "level_won", [1, true, true])
	t.begin(2)
	t.cheat_used(HUMAN)
	t.match_ended(HUMAN)
	assert_signal_emitted_with_parameters(t, "level_won", [2, false, true])


func test_elimination_and_forfeit_are_defeats_abort_is_not() -> void:
	var t := CampaignTracker.new()
	t.begin(1)
	t.abort()
	assert_true(t.progress.flawless)
	t.begin(1)
	t.match_ended(1)
	assert_false(t.progress.flawless, "победил соперник")
	assert_false(t.progress.is_completed(1))
	t.progress.flawless = true
	t.begin(1)
	t.player_eliminated(HUMAN)
	assert_false(t.progress.flawless, "выбыл")
	t.match_ended(1)
	t.progress.flawless = true
	t.begin(1)
	t.forfeit()
	assert_false(t.progress.flawless, "сдался")


func test_events_outside_campaign_change_nothing() -> void:
	var t := CampaignTracker.new()
	t.skip()
	t.player_eliminated(HUMAN)
	t.match_ended(1)
	t.forfeit()
	assert_true(t.progress.flawless)
	assert_eq(t.progress.completed_count(), 0)


func test_last_level_completes_campaign() -> void:
	var t := CampaignTracker.new()
	watch_signals(t)
	for n in range(1, CampaignBalance.LEVEL_COUNT):
		t.begin(n)
		t.match_ended(HUMAN)
	assert_signal_not_emitted(t, "campaign_completed")
	t.begin(CampaignBalance.LEVEL_COUNT)
	t.match_ended(HUMAN)
	assert_signal_emitted_with_parameters(t, "campaign_completed", [true])


# --- Достижения кампании ------------------------------------------------------------

func test_campaign_achievements() -> void:
	var a := AchievementTracker.new()
	a.campaign_level_won(false)
	assert_false(a.is_unlocked(Achievement.Id.CLEAN_CONSCIENCE))
	a.campaign_level_won(true)
	assert_true(a.is_unlocked(Achievement.Id.CLEAN_CONSCIENCE))
	a.campaign_completed(false)
	assert_true(a.is_unlocked(Achievement.Id.LEAVE_ISLAND))
	assert_false(a.is_unlocked(Achievement.Id.NO_RETREAT))
	a.campaign_completed(true)
	assert_true(a.is_unlocked(Achievement.Id.NO_RETREAT))
	var b := AchievementTracker.new()
	b.from_dict(a.to_dict())
	assert_true(b.is_unlocked(Achievement.Id.NO_RETREAT), "сохраняются")


func test_campaign_autoload_unlocks_achievements_through_events() -> void:
	Achievements.reset()
	Campaign.reset()
	Campaign.start_new(&"player1")
	for n in range(1, CampaignBalance.LEVEL_COUNT + 1):
		Campaign.begin(n)
		Events.match_started.emit(2, 0)
		Events.match_ended.emit(HUMAN)
	assert_true(Achievements.is_unlocked(Achievement.Id.LEAVE_ISLAND))
	assert_true(Achievements.is_unlocked(Achievement.Id.NO_RETREAT))
	assert_true(Achievements.is_unlocked(Achievement.Id.CLEAN_CONSCIENCE))
	assert_true(Campaign.progress.ever_finished)
	Achievements.reset()
	Campaign.reset()


func test_trick_in_campaign_match_is_seen_through_events() -> void:
	Campaign.reset()
	Campaign.begin(1)
	Events.cheat_failed.emit(HUMAN, Cheat.Kind.PEEK)
	watch_signals(Campaign.tracker)
	Events.match_ended.emit(HUMAN)
	assert_signal_emitted_with_parameters(Campaign.tracker, "level_won", [1, false, true])
	Campaign.reset()
	Stats.reset()
	Achievements.reset()


# --- Уровни-данные ------------------------------------------------------------------

func test_levels_match_design() -> void:
	var expected := [
		[[&"sailor"], Mod.NONE],
		[[&"ulits", &"ichthyander", &"craber"], Mod.NONE],
		[[&"witch", &"omen"], Mod.EVIL_EYE],
		[[&"occultist", &"plague_cultist", &"scholar"], Mod.SCARCE_SANITY],
		[[&"drowned", &"horror_master"], Mod.DEAD_HAND],
		[[&"deep_one"], Mod.LAIR],
	]
	var levels := CampaignLevels.all()
	assert_eq(levels.size(), CampaignBalance.LEVEL_COUNT)
	for i in levels.size():
		var lvl := levels[i]
		assert_eq(lvl.number, i + 1)
		assert_eq(lvl.opponents, Array(expected[i][0], TYPE_STRING_NAME, "", null))
		assert_eq(lvl.modifier, expected[i][1], "модификатор уровня %d" % lvl.number)
		assert_eq(lvl.bark_story, "L%d" % lvl.number)
		for id in lvl.opponents:
			assert_not_null(BotRoster.by_id(id), String(id))
		if lvl.modifier in [Mod.EVIL_EYE, Mod.DEAD_HAND, Mod.LAIR]:
			assert_gt(lvl.owner_seat(), 0, "у модификатора есть хозяин за столом")
		assert_between(lvl.before_keys.size(), 1, 3)
		assert_between(lvl.after_keys.size(), 1, 3)


func test_all_campaign_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = []
	for lvl in CampaignLevels.all():
		keys.append_array([lvl.name_key, lvl.place_key])
		keys.append_array(Array(lvl.before_keys))
		keys.append_array(Array(lvl.after_keys))
		var mk := CampaignLevel.modifier_key(lvl.modifier)
		if mk != "":
			keys.append_array([mk, mk + "_DESC"])
	for id in SlideShow.INTRO + SlideShow.FINALE:
		keys.append(SlideShow.text_key(id))
	for id in [Achievement.Id.LEAVE_ISLAND, Achievement.Id.CLEAN_CONSCIENCE,
			Achievement.Id.NO_RETREAT]:
		keys.append_array([Achievement.name_key(id), Achievement.desc_key(id)])
	var saved: String = Settings.get_value(&"locale")
	for locale in ["ru", "en"]:
		Settings.set_value(&"locale", locale)
		for key in keys:
			var text := tr(key)
			assert_true(text != "" and text != key, "%s: %s" % [locale, key])
	Settings.set_value(&"locale", saved)


func test_level_six_speaker_is_hob_until_reveal() -> void:
	var lvl := CampaignLevels.get_level(6)
	assert_eq(lvl.scene_speaker(false, 0), &"hob")
	assert_eq(lvl.scene_speaker(false, lvl.hob_reveal_from), &"deep_one")
	assert_eq(lvl.scene_speaker(true, 0), &"deep_one", "после разоблачения — Глубоководный")
	assert_eq(CampaignLevels.get_level(1).scene_speaker(true, 0), &"hob")


# --- Модификаторы -------------------------------------------------------------------

func test_no_modifiers_on_plain_levels() -> void:
	assert_eq(CampaignModifiers.build(CampaignLevels.get_level(1)).size(), 0)
	assert_eq(CampaignModifiers.build(CampaignLevels.get_level(2)).size(), 0)


func test_scarce_sanity_for_everyone() -> void:
	var mc := _controller(4)
	mc.start_match(0)
	for id in mc.player_count():
		assert_eq(mc.cheats.sanity[id], CampaignBalance.SCARCE_SANITY)
	var view := mc.view_for(0)
	assert_eq(view.start_sanity, CampaignBalance.SCARCE_SANITY)
	assert_eq(view.own_sanity, CampaignBalance.SCARCE_SANITY)
	mc.debug_set_sanity(1, CheatBalance.START_SANITY)
	assert_eq(mc.cheats.sanity[1], CampaignBalance.SCARCE_SANITY, "выше стартового не поднять")


func test_bots_scale_sanity_reserve_to_start_sanity() -> void:
	var p := BotRoster.by_id(&"scholar")
	var planner := BotCheatPlanner.new(p, Rng.make_seeded(1))
	var view := PlayerView.new()
	view.start_sanity = CheatBalance.START_SANITY
	assert_eq(planner.sanity_reserve(view), p.sanity_reserve)
	view.start_sanity = CampaignBalance.SCARCE_SANITY
	assert_eq(planner.sanity_reserve(view), roundi(p.sanity_reserve
			* float(CampaignBalance.SCARCE_SANITY) / CheatBalance.START_SANITY))
	assert_lt(planner.sanity_reserve(view), p.sanity_reserve)


func test_evil_eye_shows_one_human_die_to_witch_each_round() -> void:
	var mc := _controller(3)
	var witch := CampaignLevels.get_level(3).owner_seat()
	watch_signals(mc)
	mc.start_match(0)
	mc.roll([[2, 3, 4, 5, 6], [1, 1, 1, 1, 1], [6, 6, 6, 6, 6]])
	var marks := mc.view_for(HUMAN).watched_dice
	assert_eq(marks.size(), CampaignBalance.EVIL_EYE_DICE)
	var index := marks[0]
	var knows := mc.view_for(witch).cheat_outcomes
	assert_eq(knows.size(), 1)
	assert_eq(knows[0].action.kind, Cheat.Kind.PEEK)
	assert_eq(knows[0].action.target_id, HUMAN)
	assert_eq(knows[0].peeked_face, [2, 3, 4, 5, 6][index], "Ведьма видит настоящую грань")
	assert_signal_emitted_with_parameters(mc, "die_watched", [witch, HUMAN, index])
	assert_true(TableEstimate.new(mc.view_for(witch)).is_peeked(HUMAN, index),
			"бот учитывает подсмотренный кубик")
	assert_eq(mc.view_for(2).watched_dice.size(), 0, "у Омена меток нет")
	# Это не трюк: обвинить Ведьму в жульничестве нельзя.
	assert_false(mc.cheats.cheated_this_round(witch))
	assert_eq(mc.cheats.evidence[witch], 0)


func test_evil_eye_resets_each_round_and_stops_when_witch_is_out() -> void:
	var mc := _controller(3)
	var witch := CampaignLevels.get_level(3).owner_seat()
	mc.start_match(0)
	mc.roll()
	mc.submit_action(0, _bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	mc.next_round()
	assert_eq(mc.view_for(HUMAN).watched_dice.size(), 0, "новый раунд — метки сняты")
	mc.roll()
	assert_eq(mc.view_for(HUMAN).watched_dice.size(), 1)
	assert_eq(mc.view_for(witch).cheat_outcomes.size(), 1, "знание прошлого раунда забыто")
	mc.dice_counts[witch] = 0
	mc._finish_round(HUMAN, 0)
	mc.next_round()
	mc.roll()
	assert_eq(mc.view_for(HUMAN).watched_dice.size(), 0, "выбывшая Ведьма не смотрит")


func test_dead_hand_returns_drowned_once() -> void:
	var mc := _controller(5)
	var drowned := CampaignLevels.get_level(5).owner_seat()
	mc.start_match(0)
	watch_signals(mc)
	mc.dice_counts[drowned] = 1
	mc._finish_round(drowned, -1)
	assert_eq(mc.dice_counts[drowned], CampaignBalance.DEAD_HAND_DICE)
	assert_signal_emitted_with_parameters(mc, "player_rescued",
			[drowned, CampaignBalance.DEAD_HAND_DICE])
	assert_signal_not_emitted(mc, "player_eliminated")
	assert_eq(mc.phase, Phase.ROUND_END, "матч идёт")
	mc.next_round()
	mc._finish_round(drowned, -1)
	assert_eq(mc.dice_counts[drowned], 0, "второй раз не возвращается")
	assert_signal_emitted_with_parameters(mc, "player_eliminated", [drowned])


func test_dead_hand_only_for_drowned() -> void:
	var mc := _controller(5)
	mc.start_match(0)
	mc.dice_counts[2] = 1
	mc._finish_round(2, -1)
	assert_eq(mc.dice_counts[2], 0, "Мастер Ужаса не возвращается")


func test_lair_gives_deep_one_six_dice_and_calza_up_to_six() -> void:
	var mc := _controller(6)
	mc.start_match(0)
	assert_eq(mc.dice_counts, [5, 6] as Array[int])
	assert_eq(mc.max_dice, [5, 6] as Array[int])
	assert_eq(mc.view_for(1).own_max_dice, 6)
	# «Точно!» Глубоководного на 5 кубиках возвращает шестой.
	mc.dice_counts[1] = 5
	mc.roll([[2, 2, 3, 4, 5], [6, 6, 6, 6, 6]])
	mc.submit_action(0, _bid(2, 2))
	mc.submit_action(1, MatchAction.calza())
	assert_eq(mc.dice_counts[1], 6)
	# У игрока предел — обычный: на 5 кубиках «Точно!» ничего не возвращает.
	var hands := [[2, 2, 3, 4, 5], [6, 6, 6, 6, 6, 6]]
	var r := PerudoRules.resolve_calza(Bid.new(2, 2), 0, 5, hands, RoundRules.new(),
			mc.max_dice[0])
	assert_eq(r.dice_delta, 0)


func test_tide_starts_when_deep_one_has_three_dice_and_stays() -> void:
	var mc := _controller(6, 7)
	mc.start_match(0)
	assert_eq(mc.round_rules.tide(), RoundRules.NO_TIDE, "в начале прилива нет")
	mc.dice_counts[1] = 4
	mc._finish_round(0, 0)
	mc.next_round()
	assert_eq(mc.round_rules.tide(), RoundRules.NO_TIDE)
	mc.dice_counts[1] = CampaignBalance.TIDE_BOSS_DICE
	mc._finish_round(0, 0)
	mc.next_round()
	var seen := {}
	for i in 30:
		var tide := mc.round_rules.tide()
		assert_true(tide in CampaignBalance.TIDE_FACES, "грань прилива %d" % tide)
		seen[tide] = true
		if i == 10:
			mc.dice_counts[1] = 5  # вернул кубики — прилив не уходит
		mc._finish_round(0, 0)
		mc.next_round()
	assert_gt(seen.size(), 1, "грань меняется от раунда к раунду")


func test_no_tide_in_palifico() -> void:
	var mc := _controller(6)
	mc.start_match(0)
	mc.dice_counts[1] = 2
	mc.dice_counts[0] = 2
	mc._finish_round(0, -1)
	assert_true(mc._next_is_palifico)
	mc.next_round()
	assert_true(mc.round_rules.is_palifico)
	assert_eq(mc.round_rules.tide(), RoundRules.NO_TIDE)


# --- Прилив: подсчёт и ставки -----------------------------------------------------

func test_tide_face_counts_as_joker() -> void:
	var rules := RoundRules.new(false, 4)
	var dice := [1, 4, 4, 3, 6]
	assert_eq(PerudoRules.count_face(dice, 3, rules.ones_wild(), rules.tide()), 4,
			"тройка + единица + две четвёрки")
	assert_eq(PerudoRules.count_face(dice, 4, rules.ones_wild(), rules.tide()), 3,
			"на саму грань прилива — она и единицы")
	assert_eq(PerudoRules.count_face(dice, 1, rules.ones_wild(), rules.tide()), 1,
			"ставка на единицы — только единицы")
	var pal := RoundRules.new(true, 4)
	assert_eq(pal.tide(), RoundRules.NO_TIDE, "в Palifico прилива нет")


func test_tide_decides_liar_and_exact() -> void:
	var rules := RoundRules.new(false, 5)
	var hands := [[2, 5, 5], [1, 2, 6]]
	var dudo := PerudoRules.resolve_dudo(Bid.new(5, 2), 0, 1, hands, rules)
	assert_eq(dudo.actual_count, 5)
	assert_true(dudo.bid_holds)
	var calza := PerudoRules.resolve_calza(Bid.new(5, 2), 1, 3, hands, rules)
	assert_true(calza.bid_holds)
	var plain := PerudoRules.resolve_dudo(Bid.new(5, 2), 0, 1, hands, RoundRules.new())
	assert_false(plain.bid_holds, "без прилива — только 3")


func test_tide_does_not_change_bid_rules() -> void:
	var tide := RoundRules.new(false, 3)
	var plain := RoundRules.new()
	for prev in [null, Bid.new(4, 3), Bid.new(2, 1), Bid.new(5, 6)]:
		for face in range(1, 7):
			assert_eq(PerudoRules.min_quantity_for_face(prev, face, tide),
					PerudoRules.min_quantity_for_face(prev, face, plain), "%s → %d" % [prev, face])


func test_tide_in_controller_reveal_and_whisper() -> void:
	var mc := _controller(6)
	mc.start_match(0)
	mc.round_rules = RoundRules.new(false, 6)
	mc.roll([[2, 6, 6, 3, 4], [1, 6, 5, 5, 5, 5]])
	mc.submit_action(0, _bid(5, 2))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.last_reveal.result.actual_count, 5, "2 + шестёрки ×3 + единица")
	assert_eq(mc.last_reveal.tide_face, 6)


func test_bots_count_tide_in_estimate() -> void:
	assert_almost_eq(BidMath.match_chance(3, true, 5), 3.0 / 6.0, 1e-9)
	assert_almost_eq(BidMath.match_chance(5, true, 5), 2.0 / 6.0, 1e-9)
	assert_almost_eq(BidMath.match_chance(1, true, 5), 1.0 / 6.0, 1e-9)
	var view := PlayerView.new()
	view.player_id = 0
	view.dice_counts = [5, 6] as Array[int]
	view.own_dice = [3, 3, 4, 5, 5] as Array[int]
	view.round_rules = RoundRules.new()
	var plain := TableEstimate.new(view)
	view.round_rules = RoundRules.new(false, 5)
	var tide := TableEstimate.new(view)
	assert_eq(plain.own_count(3), 2)
	assert_eq(tide.own_count(3), 4, "свои пятёрки-прилив — тоже тройки")
	assert_gt(tide.p_at_least(3, 6), plain.p_at_least(3, 6))


func test_deep_one_bot_plays_lair_to_the_end() -> void:
	for seed_value in 3:
		var level := CampaignLevels.get_level(6)
		var rng := Rng.make_seeded(100 + seed_value)
		var agents: Array[MatchAgent] = [BotAgent.new(BotRoster.by_id(&"sailor"), rng),
				BotAgent.new(BotRoster.by_id(&"deep_one"), Rng.make_seeded(200 + seed_value))]
		var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(seed_value))
		CampaignModifiers.apply(level, mc)
		mc.start_match()
		var steps := 0
		var tide_rounds := 0
		while mc.phase != Phase.MATCH_OVER and steps < 5000:
			if mc.phase == Phase.ROLL and mc.round_rules.tide() != RoundRules.NO_TIDE:
				tide_rounds += 1
			mc.advance_auto()
			steps += 1
		assert_eq(mc.phase, Phase.MATCH_OVER, "матч доигран (seed %d)" % seed_value)
		assert_true(mc.dice_counts.max() <= CampaignBalance.LAIR_BOSS_MAX_DICE)
