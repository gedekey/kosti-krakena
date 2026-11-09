extends GutTest
## Сетевое ядро (М18): сериализация значений матча туда-обратно, поворот номеров мест,
## отбрасывание кривых данных.

const HANDS_4 := [[2, 3, 4, 5, 6], [2, 2, 3, 3, 4], [5, 5, 6, 6, 1], [4, 4, 4, 2, 6]]


## Через сеть: var_to_bytes → bytes_to_var.
func _wire(v: Variant) -> Variant:
	return bytes_to_var(var_to_bytes(v))


func _humans(count: int) -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = []
	for i in count:
		agents.append(HumanAgent.new())
	return agents


func _started() -> MatchController:
	var mc := MatchController.new(_humans(4), RuleOptions.new(), Rng.make_seeded(5))
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	mc.cheats.false_evidence_chance = 0.0
	mc.cheats.trick_evidence_chance = 1.0
	mc.start_match(0)
	mc.roll(HANDS_4)
	return mc


# --- SeatFrame / SeatInfo --------------------------------------------------------

func test_frame_puts_receiver_at_zero_and_keeps_order() -> void:
	var f := SeatFrame.new(2, 4)
	assert_eq(f.to_local(2), 0)
	assert_eq(f.to_local(3), 1)
	assert_eq(f.to_local(0), 2)
	assert_eq(f.to_local(1), 3)
	for id in 4:
		assert_eq(f.to_global(f.to_local(id)), id)
	assert_eq(f.to_local(PerudoRules.NO_PLAYER), PerudoRules.NO_PLAYER)
	assert_eq(f.rotate(["a", "b", "c", "d"]), ["c", "d", "a", "b"])


func test_seat_info_round_trip_without_peer_id() -> void:
	var s := SeatInfo.guest(7, "Анна", 3)
	s.replaced = true
	s.rank = RankBalance.Tier.RUBY
	var back := SeatInfo.from_wire(_wire(s.to_wire()))
	assert_eq(back.kind, SeatInfo.Kind.GUEST)
	assert_eq(back.player_name, "Анна")
	assert_eq(back.portrait, 3)
	assert_true(back.replaced)
	assert_eq(back.rank, RankBalance.Tier.RUBY, "сетевой ранг (М20)")
	assert_eq(back.peer_id, 0, "сетевой id по сети не уходит")
	assert_null(SeatInfo.from_wire([0, "x", 9, "", false, -1]), "портрет вне диапазона")
	assert_null(SeatInfo.from_wire([0, "x", 0, "", false, 6]), "ранг вне диапазона")
	assert_null(SeatInfo.from_wire([0, "x", 0, "", false]), "старый формат без ранга")
	assert_null(SeatInfo.from_wire("garbage"))


func test_clean_name_strips_control_chars_and_limits_length() -> void:
	assert_eq(SeatInfo.clean_name("  Вася\n\t "), "Вася")
	assert_eq(SeatInfo.clean_name("x".repeat(40)).length(), NetBalance.MAX_NAME_LENGTH)


# --- Bid / MatchAction / CheatAction ---------------------------------------------

func test_bid_round_trip_and_rejects() -> void:
	var b := NetCodec.decode_bid(_wire(NetCodec.encode_bid(Bid.new(7, 3))))
	assert_true(b.equals(Bid.new(7, 3)))
	assert_null(NetCodec.encode_bid(null))
	for bad in [[0, 3], [3, 7], [3], ["3", 3], [3.0, 3], null, {"q": 3}]:
		assert_null(NetCodec.decode_bid(bad), str(bad))


func test_actions_round_trip_with_rotation() -> void:
	var f := SeatFrame.new(2, 4)
	var actions := [MatchAction.make_bid(4, 5), MatchAction.dudo(), MatchAction.calza(),
			MatchAction.accuse(3)]
	for a: MatchAction in actions:
		var back := NetCodec.decode_action(_wire(NetCodec.encode_action(a, f)), f)
		assert_eq(back.kind, a.kind)
		assert_eq(back.target_id, a.target_id)
		if a.bid != null:
			assert_true(back.bid.equals(a.bid))
	assert_eq(NetCodec.encode_action(MatchAction.accuse(3), f)["p"], 1, "в системе получателя")


func test_bad_actions_are_rejected() -> void:
	var f := SeatFrame.identity(4)
	for bad in [null, {}, {"k": 9}, {"k": "0"}, {"k": MatchAction.Kind.BID},
			{"k": MatchAction.Kind.BID, "b": [2, 8]}, {"k": MatchAction.Kind.ACCUSE, "p": 4},
			{"k": MatchAction.Kind.ACCUSE}, [0]]:
		assert_null(NetCodec.decode_action(bad, f), str(bad))


func test_cheat_action_round_trip_keeps_none() -> void:
	var f := SeatFrame.new(1, 3)
	for a: CheatAction in [CheatAction.peek(2, 4), CheatAction.sleight(1),
			CheatAction.loaded_die(6), CheatAction.nudge_cup(0), CheatAction.sleeve_die(),
			CheatAction.abyss_whisper(1)]:
		var back := NetCodec.decode_cheat(_wire(NetCodec.encode_cheat(a, f)), f)
		assert_eq([back.kind, back.target_id, back.die_index, back.face],
				[a.kind, a.target_id, a.die_index, a.face], str(a))
	assert_null(NetCodec.decode_cheat([9, -1, -1, -1], f))
	assert_null(NetCodec.decode_cheat([0, 3, 0, -1], f), "цель вне стола")
	assert_null(NetCodec.decode_cheat([0, 1, 0, 8], f), "грань 8")


# --- Итоги ---------------------------------------------------------------------

func test_outcome_round_trip() -> void:
	var f := SeatFrame.new(3, 4)
	var o := CheatOutcome.new(3, CheatAction.peek(0, 2))
	o.peeked_face = 5
	var back := NetCodec.decode_outcome(_wire(NetCodec.encode_outcome(o, f)), f)
	assert_eq(back.player_id, 3)
	assert_eq(back.action.target_id, 0)
	assert_eq(back.peeked_face, 5)
	assert_false(back.failed)
	assert_eq(back.whisper_count, CheatOutcome.NONE)


func test_reveal_round_trip_rotates_hands() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.sleeve_die())
	mc.submit_action(0, MatchAction.make_bid(3, 4))
	mc.submit_action(1, MatchAction.dudo())
	var reveal := mc.last_reveal
	var f := SeatFrame.new(2, 4)
	var wire: Dictionary = _wire(NetCodec.encode_reveal(reveal, f))
	assert_eq(wire["h"][0], HANDS_4[2], "у получателя его рука — первая")
	var back := NetCodec.decode_reveal(wire, f)
	assert_eq(back.hands, reveal.hands)
	assert_eq(back.sleeve_dice, reveal.sleeve_dice)
	assert_eq(back.bidder_id, 0)
	assert_eq(back.caller_id, 1)
	assert_true(back.bid.equals(reveal.bid))
	assert_eq(back.result.actual_count, reveal.result.actual_count)
	assert_eq(back.result.player_id, reveal.result.player_id)
	assert_eq(back.result.dice_delta, reveal.result.dice_delta)
	wire["h"][1] = [9]
	assert_null(NetCodec.decode_reveal(wire, f), "грань 9 в руке")


# --- PlayerView ----------------------------------------------------------------

func test_view_round_trip_with_rotation() -> void:
	var mc := _started()
	mc.submit_cheat(0, CheatAction.peek(1, 2))
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.debug_set_sanity(3, 0)
	var view := mc.view_for(0)
	var f := SeatFrame.new(0, 4)
	var back := NetCodec.decode_view(_wire(NetCodec.encode_view(view, f)), f)
	assert_eq(back.player_id, 0)
	assert_eq(back.own_dice, view.own_dice)
	assert_eq(back.dice_counts, view.dice_counts)
	assert_true(back.current_bid.equals(view.current_bid))
	assert_eq(back.current_bidder, view.current_bidder)
	assert_eq(back.bid_history.size(), 1)
	assert_eq(back.own_sanity, view.own_sanity)
	assert_eq(back.mad, view.mad)
	assert_eq(back.evidence, view.evidence)
	assert_eq(back.cheat_outcomes.size(), 1)
	assert_eq(back.cheat_outcomes[0].peeked_face, HANDS_4[1][2])
	assert_eq(back.cheat_window, view.cheat_window)
	assert_eq(back.options.calza_enabled, view.options.calza_enabled)


func test_view_in_guest_frame_has_guest_at_zero() -> void:
	var mc := _started()
	mc.submit_action(0, MatchAction.make_bid(2, 3))
	mc.debug_set_sanity(3, 0)
	var f := SeatFrame.new(2, 4)
	var wire: Dictionary = _wire(NetCodec.encode_view(mc.view_for(2), f))
	assert_eq(wire["p"], 0)
	assert_eq(wire["od"], HANDS_4[2])
	assert_eq(wire["md"], [false, true, false, false], "Безумие игрока 3 — у гостя место 1")
	assert_eq(wire["bh"][0][0], 2, "ставку сделал 0 — у гостя место 2")
	# Гость разбирает в своей (тождественной) системе.
	var back := NetCodec.decode_view(wire, SeatFrame.identity(4))
	assert_eq(back.player_id, 0)
	assert_eq(back.current_bidder, 2)


func test_bad_views_are_rejected() -> void:
	var mc := _started()
	var f := SeatFrame.identity(4)
	var good := NetCodec.encode_view(mc.view_for(0), f)
	assert_not_null(NetCodec.decode_view(good, f))
	var cases := {
		"od": [1, 2, 7], "dc": [5, 5, 5], "sa": 99, "md": [true], "cw": 7, "cb": [0, 2],
		"bh": [[0, 1]], "opt": [true], "p": 4, "oc": [[0]],
	}
	for key: String in cases:
		var bad := good.duplicate(true)
		bad[key] = cases[key]
		assert_null(NetCodec.decode_view(bad, f), key)
	var missing := good.duplicate()
	missing.erase("sl")
	assert_null(NetCodec.decode_view(missing, f))


# --- События -------------------------------------------------------------------

func test_event_args_round_trip() -> void:
	var f := SeatFrame.new(1, 4)
	var o := CheatOutcome.new(1, CheatAction.abyss_whisper(4))
	o.whisper_count = 3
	var cases := [
		[&"phase_changed", [MatchController.Phase.BIDDING]],
		[&"round_started", [3, 0, true]],
		[&"bid_placed", [2, Bid.new(5, 6)]],
		[&"dice_count_changed", [3, 4, -1]],
		[&"cheat_resolved", [o]],
		[&"cheat_failed", [0, Cheat.Kind.SLEEVE_DIE]],
		[&"accusation_made", [0, 3, false]],
		[&"round_ended", [PerudoRules.NO_PLAYER, false]],
	]
	for c in cases:
		var spec: String = NetProtocol.EVENTS[NetProtocol.event_index(c[0])][1]
		var args: Variant = NetCodec.decode_args(spec, _wire(NetCodec.encode_args(spec, c[1], f)), f)
		assert_not_null(args, str(c[0]))
		assert_eq(args.size(), c[1].size())
		for i in args.size():
			if args[i] is Bid:
				assert_true(args[i].equals(c[1][i]))
			elif args[i] is CheatOutcome:
				assert_eq(args[i].whisper_count, 3)
				assert_eq(args[i].player_id, 1)
			else:
				assert_eq(args[i], c[1][i], "%s[%d]" % [c[0], i])
	assert_null(NetCodec.decode_args("p", [6], f))
	assert_null(NetCodec.decode_args("h", [9], f))
	assert_null(NetCodec.decode_args("pb", [1], f))


func test_all_controller_signals_are_net_events() -> void:
	for sig in MatchController.new(_humans(2), RuleOptions.new(), Rng.make_seeded(1)) \
			.get_script().get_script_signal_list():
		var index := NetProtocol.event_index(sig["name"])
		assert_true(index >= 0, "нет в протоколе: %s" % sig["name"])
		if index >= 0:
			assert_eq(String(NetProtocol.EVENTS[index][1]).length(), sig["args"].size(),
					str(sig["name"]))


func test_transport_drops_non_dictionaries_and_huge_packets() -> void:
	assert_null(NetTransport.decode(PackedByteArray()))
	assert_null(NetTransport.decode(var_to_bytes([1, 2])))
	assert_null(NetTransport.decode(PackedByteArray([1, 2, 3])))
	assert_engine_error("len < 4", "мусорные байты: движок пишет ошибку, пакет отброшен")
	var huge := {"t": 0, "x": "a".repeat(NetBalance.MAX_PACKET_BYTES)}
	assert_null(NetTransport.decode(var_to_bytes(huge)))
	assert_eq(NetTransport.decode(var_to_bytes({"t": 1})), {"t": 1})
