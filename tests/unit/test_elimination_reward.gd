extends GutTest

func _match(counts: Array, starter := 0, rescue := false) -> MatchController:
	var agents: Array[MatchAgent] = []
	for i in counts.size():
		agents.append(HumanAgent.new())
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(26))
	if rescue:
		mc.add_modifier(DeadHandModifier.new(1))
	mc.start_match(starter)
	mc.dice_counts.assign(counts)
	var hands := []
	for count in counts:
		var hand := []
		for i in count:
			hand.append(2)
		hands.append(hand)
	mc.roll(hands)
	watch_signals(mc)
	return mc

func test_bid_defender_gets_reward_before_match_ends() -> void:
	var mc := _match([3, 1])
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.dice_counts, [4, 0] as Array[int])
	assert_true(mc.elimination_reward_used[0])
	assert_eq(mc.winner_id, 0)
	assert_signal_emitted_with_parameters(mc, "elimination_reward_granted", [0, 1])

func test_successful_challenger_gets_reward() -> void:
	var mc := _match([1, 3, 3])
	mc.submit_action(0, MatchAction.make_bid(1, 6))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.dice_counts[1], 4)

func test_full_player_retains_reward_and_only_receives_it_once() -> void:
	var mc := _match([5, 1, 1, 1, 3])
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	assert_false(mc.elimination_reward_used[0])
	mc.dice_counts[0] = 3
	mc.next_round()
	mc.roll()
	mc.submit_action(2, MatchAction.accuse(0))
	assert_eq(mc.dice_counts[0], 4)
	assert_true(mc.elimination_reward_used[0])
	mc.next_round()
	mc.roll()
	mc.submit_action(3, MatchAction.accuse(0))
	assert_eq(mc.dice_counts[0], 4)
	assert_signal_emit_count(mc, "elimination_reward_granted", 1)

func test_false_accusation_rewards_target_and_limits_are_independent() -> void:
	var mc := _match([1, 3, 3])
	mc.elimination_reward_used[2] = true
	mc.submit_action(0, MatchAction.accuse(1))
	assert_eq(mc.dice_counts[1], 4)
	assert_true(mc.elimination_reward_used[1])
	var fresh := _match([3, 3, 3])
	assert_eq(fresh.elimination_reward_used, [false, false, false] as Array[bool])

func test_true_accusation_rewards_accuser() -> void:
	var mc := _match([3, 1, 3], 1)
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	mc.submit_cheat(1, CheatAction.sleeve_die())
	mc.submit_action(1, MatchAction.make_bid(1, 2))
	mc.submit_action(2, MatchAction.accuse(1))
	assert_eq(mc.dice_counts[2], 4)

func test_failed_calza_and_trick_do_not_reward() -> void:
	var mc := _match([3, 1, 3])
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.calza())
	assert_eq(mc.dice_counts[0], 3)
	assert_signal_not_emitted(mc, "elimination_reward_granted")
	var failed := _match([1, 3, 3])
	failed.cheats.risk_mode = CheatState.RiskMode.ALWAYS_FAIL
	failed.submit_cheat(0, CheatAction.sleeve_die())
	assert_signal_not_emitted(failed, "elimination_reward_granted")

func test_rescue_and_ordinary_loss_do_not_reward() -> void:
	var mc := _match([3, 1, 3], 0, true)
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	assert_true(mc.is_active(1))
	assert_false(mc.elimination_reward_used[0])
	var ordinary := _match([3, 2, 3])
	ordinary.submit_action(0, MatchAction.make_bid(1, 2))
	ordinary.submit_action(1, MatchAction.dudo())
	assert_false(ordinary.elimination_reward_used[0])

func test_tutorial_disabled_and_campaign_limit_supported() -> void:
	assert_false(TutorialScript.make_controller(Rng.make_seeded(26)).elimination_reward_enabled)
	var mc := _match([5, 1])
	mc.max_dice[0] = 6
	mc.submit_action(0, MatchAction.make_bid(1, 2))
	mc.submit_action(1, MatchAction.dudo())
	assert_eq(mc.dice_counts[0], 6)

func test_reward_event_roundtrips_with_seat_rotation() -> void:
	var frame := SeatFrame.new(1, 3)
	var encoded := NetCodec.encode_args("pp", [2, 0], frame)
	assert_eq(NetCodec.decode_args("pp", encoded, frame), [2, 0])
	assert_gte(NetProtocol.event_index(&"elimination_reward_granted"), 0)
