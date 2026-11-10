extends GutTest
## Сетевое ядро (М18): хост и гости через транспорт в памяти. Рукопожатие, фильтрация
## секретов, команды гостя, таймер хода и автоход на инъектированных часах, темп раундов,
## обрыв связи, полный матч хост + 2 гостя.

const Phase := MatchController.Phase
const Err := MatchController.Result
const Msg := NetProtocol.Msg
const VERSION := "test/1"
const HANDS_4 := [[2, 3, 4, 5, 6], [2, 2, 3, 3, 4], [5, 5, 6, 6, 1], [4, 4, 4, 2, 6]]
const HOST_SEAT := 0
## План по умолчанию: 0 — хост, 1 — гость A, 2 — гость B, 3 — бот.
const SEAT_A := 1
const SEAT_B := 2
const SEAT_BOT := 3


class Clock:
	var t := 1000

	func now() -> int:
		return t


var clock: Clock
var hub: LoopbackTransport
var host: HostSession
var guests: Array[ClientSession] = []
var links: Array[LoopbackTransport] = []


func before_each() -> void:
	clock = Clock.new()
	hub = LoopbackTransport.make_host()
	host = HostSession.new(hub, "Хозяин", 1, clock.now, VERSION)
	guests.clear()
	links.clear()


func _join(guest_name := "Гость", portrait := 0, version := VERSION) -> ClientSession:
	var link := hub.connect_guest()
	var g := ClientSession.new(link, guest_name, portrait, clock.now, version)
	guests.append(g)
	links.append(link)
	return g


func _pump(times := 4) -> void:
	for i in times:
		host.update()
		for g in guests:
			g.update()


## Двое гостей в лобби, план: хост, A, B, бот. Матч подготовлен, но не начат.
func _prepared(timer := true, plan_bot := true) -> void:
	_join("Анна", 2)
	_join("Борис", 3)
	_pump()
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(links[0].peer_id, "", 0),
			SeatInfo.guest(links[1].peer_id, "", 0)]
	if plan_bot:
		plan.append(SeatInfo.bot(&"drowned"))
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(11), timer))
	var c := host.controller
	c.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	c.cheats.false_evidence_chance = 0.0
	c.cheats.trick_evidence_chance = 1.0
	_pump()


## Матч идёт, кубики брошены заданные, ходит first.
func _rolled(first: int, timer := true) -> void:
	_prepared(timer)
	host.start_match(first)
	host.controller.roll(HANDS_4)
	_pump()


func _a() -> ClientSession:
	return guests[0]


func _b() -> ClientSession:
	return guests[1]


## Номер места seat_id у гостя, сидящего на guest_seat (4 места).
func _local(guest_seat: int, seat_id: int) -> int:
	return posmod(seat_id - guest_seat, host.player_count())


# --- Рукопожатие ---------------------------------------------------------------

func test_handshake_accepts_guests_into_lobby() -> void:
	var a := _join("  Анна\n", 2)
	watch_signals(a)
	watch_signals(host)
	_pump()
	assert_eq(a.state, ClientSession.State.LOBBY)
	assert_signal_emitted(a, "joined")
	assert_signal_emitted(host, "guest_joined")
	assert_eq(host.guests().size(), 1)
	assert_eq(host.guests()[0].player_name, "Анна")
	assert_eq(host.guests()[0].portrait, 2)


func test_version_mismatch_is_rejected_with_reason() -> void:
	var g := _join("Старый", 0, "old/1")
	watch_signals(g)
	_pump()
	assert_signal_emitted_with_parameters(g, "rejected",
			[NetProtocol.Reject.VERSION_MISMATCH, VERSION])
	assert_eq(g.state, ClientSession.State.CLOSED)
	assert_eq(host.guests().size(), 0)


func test_sixth_guest_is_rejected_as_full() -> void:
	for i in MatchController.MAX_PLAYERS - 1:
		_join("G%d" % i)
	_pump()
	var extra := _join("Лишний")
	watch_signals(extra)
	_pump()
	assert_signal_emitted_with_parameters(extra, "rejected", [NetProtocol.Reject.FULL, VERSION])
	assert_eq(host.guests().size(), MatchController.MAX_PLAYERS - 1)


func test_join_during_match_is_rejected() -> void:
	_prepared()
	host.start_match(0)
	var late := _join("Опоздал")
	watch_signals(late)
	_pump()
	assert_signal_emitted_with_parameters(late, "rejected",
			[NetProtocol.Reject.IN_PROGRESS, VERSION])


func test_rejected_guest_is_kicked_after_delay() -> void:
	# Гость, который сам не уходит после отказа: хост рвёт связь через паузу.
	var link := hub.connect_guest()
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.HELLO,
			{"ver": "old/1", "name": "Упрямый", "portrait": 0}))
	host.update()
	link.poll()
	assert_true(link.is_open())
	clock.t += NetBalance.REJECT_KICK_DELAY_MS - 1
	host.update()
	link.poll()
	assert_true(link.is_open(), "отказ ещё в пути")
	clock.t += 1
	host.update()
	link.poll()
	assert_false(link.is_open())


func test_guest_left_out_of_plan_is_rejected() -> void:
	_join("Анна")
	var spare := _join("Лишний")
	_pump()
	watch_signals(spare)
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(links[0].peer_id, "", 0)]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(1)))
	_pump()
	assert_signal_emitted_with_parameters(spare, "rejected",
			[NetProtocol.Reject.IN_PROGRESS, VERSION])


func test_bad_plans_are_refused() -> void:
	_join("Анна")
	_pump()
	var peer := links[0].peer_id
	var no_host: Array[SeatInfo] = [SeatInfo.guest(peer, "", 0), SeatInfo.bot(&"sailor")]
	var unknown_guest: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(99, "", 0)]
	var twice: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(peer, "", 0),
			SeatInfo.guest(peer, "", 0)]
	var bad_bot: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.bot(&"nobody")]
	var alone: Array[SeatInfo] = [SeatInfo.host("", 0)]
	for plan in [no_host, unknown_guest, twice, bad_bot, alone]:
		assert_false(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(1)))
	assert_eq(host.state, HostSession.State.LOBBY)


# --- Начало матча и поворот мест ------------------------------------------------

func test_match_start_gives_each_guest_own_frame() -> void:
	_prepared()
	var a := _a()
	assert_eq(a.state, ClientSession.State.IN_MATCH)
	assert_eq(a.player_count(), 4)
	assert_eq(a.seat(0).player_name, "Анна", "гость A у себя — место 0")
	assert_eq(a.seat(0).portrait, 2)
	assert_eq(a.seat(_local(SEAT_A, HOST_SEAT)).player_name, "Хозяин")
	assert_eq(a.seat(_local(SEAT_A, HOST_SEAT)).kind, SeatInfo.Kind.HOST)
	assert_eq(a.seat(_local(SEAT_A, SEAT_BOT)).bot_id, &"drowned")
	assert_eq(_b().seat(0).player_name, "Борис")
	assert_true(a.timer_enabled)


func test_events_wait_until_table_is_built() -> void:
	_join("Анна")
	_pump()
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(links[0].peer_id, "", 0)]
	host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(1))
	host.start_match(0)
	host.update()
	var a := _a()
	watch_signals(a)
	a.update()
	assert_signal_emitted(a, "match_began")
	assert_signal_not_emitted(a, "match_started", "события — со следующего update()")
	a.update()
	assert_signal_emitted_with_parameters(a, "match_started", [2, 1])
	assert_eq(a.phase, Phase.ROLL)


func test_guest_mirror_follows_host_with_rotated_ids() -> void:
	_rolled(SEAT_B)
	var a := _a()
	assert_eq(a.phase, Phase.BIDDING)
	assert_eq(a.current_player, _local(SEAT_A, SEAT_B))
	assert_eq(_b().current_player, 0)
	assert_eq(a.round_number, 1)
	assert_eq(a.total_dice(), 20)
	assert_eq(a.view_for(0).own_dice, HANDS_4[SEAT_A] as Array[int])
	assert_eq(_b().submit_action(0, MatchAction.make_bid(3, 4)), Err.OK)
	_pump()
	assert_true(host.controller.current_bid.equals(Bid.new(3, 4)))
	assert_eq(host.controller.current_player, SEAT_BOT)
	assert_eq(a.current_player, _local(SEAT_A, SEAT_BOT))
	assert_true(a.view_for(0).current_bid.equals(Bid.new(3, 4)))
	assert_eq(a.view_for(0).current_bidder, _local(SEAT_A, SEAT_B))


# --- Секреты -------------------------------------------------------------------

func test_guest_never_receives_other_hands_before_reveal() -> void:
	_rolled(SEAT_A)
	_a().submit_action(0, MatchAction.make_bid(2, 2))
	_pump()
	for entry in links[1].received_log:
		var msg: Variant = NetTransport.decode(entry[1])
		if msg["t"] != Msg.EVENT:
			continue
		var od: Array = msg["s"]["v"]["od"]
		assert_true(od.is_empty() or od == HANDS_4[SEAT_B],
				"в снимке гостя B только его кубики: %s" % [od])
		assert_ne(NetProtocol.EVENTS[msg["e"]][0], &"challenge_revealed")
	assert_null(_b().view_for(_local(SEAT_B, SEAT_A)), "чужой PlayerView недоступен")


func test_cheat_result_and_sanity_go_only_to_cheater() -> void:
	_rolled(SEAT_A)
	var a := _a()
	var b := _b()
	watch_signals(a)
	watch_signals(b)
	watch_signals(host)
	# A подглядывает к соседу справа — это B (у A он место 1).
	assert_eq(a.submit_cheat(0, CheatAction.peek(1, 0)), Err.OK)
	_pump()
	assert_signal_emitted(a, "cheat_resolved")
	var outcome: CheatOutcome = get_signal_parameters(a, "cheat_resolved")[0]
	assert_eq(outcome.player_id, 0)
	assert_eq(outcome.action.target_id, 1)
	assert_eq(outcome.peeked_face, HANDS_4[SEAT_B][0])
	assert_signal_emitted_with_parameters(a, "sanity_changed",
			[0, CheatBalance.START_SANITY - CheatBalance.COST_PEEK, -CheatBalance.COST_PEEK])
	assert_eq(a.view_for(0).cheat_outcomes.size(), 1)
	assert_eq(a.view_for(0).own_sanity, CheatBalance.START_SANITY - CheatBalance.COST_PEEK)
	for other in [b, host]:
		assert_signal_not_emitted(other, "cheat_resolved")
		assert_signal_not_emitted(other, "sanity_changed")
	assert_eq(b.view_for(0).own_sanity, CheatBalance.START_SANITY)
	assert_true(b.view_for(0).cheat_outcomes.is_empty())


func test_local_session_hides_others_secrets() -> void:
	var agents: Array[MatchAgent] = [HumanAgent.new(), HumanAgent.new()]
	var mc := MatchController.new(agents, RuleOptions.new(), Rng.make_seeded(3))
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	var session := LocalSession.new(mc, 0)
	watch_signals(session)
	session.start_match(1)
	session.roll([HANDS_4[0], HANDS_4[1]])
	mc.submit_cheat(1, CheatAction.sleeve_die())
	assert_signal_not_emitted(session, "cheat_resolved")
	assert_signal_not_emitted(session, "sanity_changed")
	assert_signal_emitted(session, "dice_rolled")
	assert_eq(session.submit_action(1, MatchAction.make_bid(2, 2)), Err.NOT_YOUR_TURN,
			"чужим местом не командуем")
	assert_null(session.view_for(1))


# --- Команды гостя -------------------------------------------------------------

func test_guest_cannot_act_out_of_turn() -> void:
	_rolled(HOST_SEAT)
	var a := _a()
	watch_signals(a)
	assert_eq(a.submit_action(0, MatchAction.make_bid(2, 2)), Err.NOT_YOUR_TURN)
	# В обход проверки гостя — хост всё равно отказывает.
	links[0].send(NetTransport.HOST_ID, NetProtocol.make(Msg.ACTION,
			{"a": NetCodec.encode_action(MatchAction.make_bid(2, 2), SeatFrame.identity(4))}))
	_pump()
	assert_signal_emitted_with_parameters(a, "command_rejected", [Err.NOT_YOUR_TURN])
	assert_null(host.controller.current_bid)
	assert_eq(host.controller.current_player, HOST_SEAT)


func test_guest_action_targets_are_mapped_back() -> void:
	_rolled(SEAT_A)
	var guilty := []
	host.accusation_made.connect(func(acc: int, target: int, g: bool) -> void:
		guilty.append([acc, target, g]))
	# A обвиняет бота: у A он место 2.
	assert_eq(_a().submit_action(0, MatchAction.accuse(_local(SEAT_A, SEAT_BOT))), Err.OK)
	_pump()
	assert_eq(guilty, [[SEAT_A, SEAT_BOT, false]])


func test_invalid_messages_are_dropped() -> void:
	_rolled(SEAT_A)
	var link := links[0]
	var before := host.dropped_messages
	link.deliver_raw(NetTransport.HOST_ID, var_to_bytes([1, 2, 3]))
	link.send(NetTransport.HOST_ID, {"t": 99})
	link.send(NetTransport.HOST_ID, {"x": 1})
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.ACTION, {"a": {"k": 0, "b": [3, 9]}}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.ACTION, {"a": "bid"}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.CHEAT, {"c": [0, 7, 0, -1]}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.CUP, {"o": 1}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.READY, {"ph": "x"}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.EVENT, {"e": 0}))
	link.send(NetTransport.HOST_ID, NetProtocol.make(Msg.HELLO,
			{"ver": VERSION, "name": "Снова", "portrait": 0}))
	_pump()
	assert_eq(host.dropped_messages - before, 9, "всё кривое отброшено (байты — транспортом)")
	assert_eq(host.controller.current_player, SEAT_A)
	assert_null(host.controller.current_bid)
	assert_eq(host.controller.phase, Phase.BIDDING)


func test_guest_cheat_denial_matches_controller() -> void:
	_rolled(SEAT_A)
	var a := _a()
	var c := host.controller
	var frame := SeatFrame.new(SEAT_A, 4)
	var cases: Array[CheatAction] = [CheatAction.peek(1, 0), CheatAction.peek(1, 7),
			CheatAction.peek(2, 0), CheatAction.sleight(4), CheatAction.sleight(5),
			CheatAction.loaded_die(3), CheatAction.nudge_cup(3), CheatAction.sleeve_die(),
			CheatAction.abyss_whisper(6), CheatAction.abyss_whisper(0)]
	for local_action in cases:
		var global_action := CheatAction.new(local_action.kind,
				frame.to_global(local_action.target_id), local_action.die_index,
				local_action.face)
		assert_eq(a.cheat_denial(0, local_action), c.cheat_denial(SEAT_A, global_action),
				str(local_action))
	# После трюка — «уже был трюк».
	a.submit_cheat(0, CheatAction.sleeve_die())
	_pump()
	assert_eq(a.cheat_denial(0, CheatAction.peek(1, 0)), CheatRules.Denied.ALREADY_USED)
	assert_eq(_b().cheat_denial(0, CheatAction.sleeve_die()), CheatRules.Denied.NOT_YOUR_TURN)


func test_guest_cup_commands() -> void:
	_rolled(SEAT_A)
	var a := _a()
	assert_true(a.view_for(0).cup_open, "сразу после броска чашка открыта")
	assert_eq(a.open_cup(0), Err.ILLEGAL_ACTION)
	assert_eq(a.close_cup(0), Err.OK)
	_pump()
	assert_false(a.view_for(0).cup_open)
	assert_false(host.controller.view_for(SEAT_A).cup_open)


# --- Таймер хода и автоход -------------------------------------------------------

func test_turn_timer_makes_lowest_bid_for_slow_guest() -> void:
	_rolled(SEAT_A)
	assert_eq(_a().turn_time_left_msec(), NetBalance.TURN_TIME_MS)
	clock.t += NetBalance.TURN_TIME_MS - 1
	_pump()
	assert_eq(host.controller.current_player, SEAT_A)
	assert_eq(_a().turn_time_left_msec(), 1)
	clock.t += 1
	_pump()
	var expected := ActionRules.lowest_bid(null, RoundRules.new(), 20)
	assert_true(host.controller.current_bid.equals(expected), "минимальная ставка")
	assert_eq(host.controller.current_bidder, SEAT_A)
	assert_eq(host.controller.current_player, SEAT_B)


func test_turn_timer_calls_liar_when_no_bid_left() -> void:
	_rolled(HOST_SEAT)
	assert_eq(host.submit_action(HOST_SEAT, MatchAction.make_bid(20, 6)), Err.OK)
	_pump()
	assert_eq(_a().submit_action(0, MatchAction.make_bid(20, 1)), Err.OK)
	_pump()
	assert_eq(host.controller.current_player, SEAT_B)
	clock.t += NetBalance.TURN_TIME_MS
	_pump()
	assert_eq(host.controller.phase, Phase.ROUND_END)
	assert_eq(host.controller.last_reveal.kind, MatchAction.Kind.DUDO)
	assert_eq(host.controller.last_reveal.caller_id, SEAT_B)


func test_host_seat_has_timer_too() -> void:
	_rolled(HOST_SEAT)
	assert_eq(host.turn_time_left_msec(), NetBalance.TURN_TIME_MS)
	clock.t += NetBalance.TURN_TIME_MS
	_pump()
	assert_eq(host.controller.current_bidder, HOST_SEAT)


func test_disabled_timer_waits_forever() -> void:
	_rolled(SEAT_A, false)
	assert_eq(_a().turn_time_left_msec(), -1)
	clock.t += NetBalance.TURN_TIME_MS * 10
	_pump()
	assert_eq(host.controller.current_player, SEAT_A)
	assert_null(host.controller.current_bid)


func test_bot_turn_waits_for_delay() -> void:
	_rolled(SEAT_BOT)
	_pump()
	assert_eq(host.controller.current_player, SEAT_BOT)
	assert_eq(_a().turn_time_left_msec(), -1, "у бота таймера нет")
	clock.t += NetBalance.BOT_TURN_DELAY_MS
	_pump()
	assert_ne(host.controller.current_player, SEAT_BOT)


# --- Пауза (М21) ----------------------------------------------------------------

func test_pause_needs_every_human_and_freezes_turn_timer() -> void:
	_rolled(SEAT_A)
	watch_signals(_b())
	clock.t += 10_000
	host.request_pause(true)
	_a().request_pause(true)
	_pump()
	assert_false(host.is_match_paused(), "B ещё не нажал")
	assert_eq(_b().pause_votes(), Vector2i(2, 3))
	assert_signal_emitted_with_parameters(_b(), "pause_changed", [false, 2, 3])
	clock.t += 5_000
	_b().request_pause(true)
	_pump()
	assert_true(host.is_match_paused())
	assert_true(_a().is_match_paused())
	var left := NetBalance.TURN_TIME_MS - 15_000
	assert_eq(host.turn_time_left_msec(), left)
	assert_eq(_a().turn_time_left_msec(), left)
	clock.t += NetBalance.TURN_TIME_MS * 3
	_pump()
	assert_eq(host.controller.current_player, SEAT_A, "на паузе автохода нет")
	assert_null(host.controller.current_bid)
	assert_eq(_a().turn_time_left_msec(), left, "у гостя таймер стоит")
	_a().request_pause(false)
	_pump()
	assert_false(host.is_match_paused())
	assert_eq(_a().turn_time_left_msec(), left, "таймер пошёл с того же места")
	clock.t += left - 1
	_pump()
	assert_eq(host.controller.current_player, SEAT_A)
	clock.t += 1
	_pump()
	assert_eq(host.controller.current_bidder, SEAT_A, "время вышло — автоход")


func test_pause_stops_bots() -> void:
	_rolled(SEAT_BOT)
	for g: ClientSession in [_a(), _b()]:
		g.request_pause(true)
	host.request_pause(true)
	_pump()
	assert_true(host.is_match_paused())
	clock.t += NetBalance.BOT_TURN_DELAY_MS * 5
	_pump()
	assert_eq(host.controller.current_player, SEAT_BOT, "бот ждёт")
	host.request_pause(false)
	_pump()
	clock.t += NetBalance.BOT_TURN_DELAY_MS
	_pump()
	assert_ne(host.controller.current_player, SEAT_BOT)


func test_leaving_player_no_longer_blocks_pause() -> void:
	_rolled(SEAT_A)
	host.request_pause(true)
	_a().request_pause(true)
	_pump()
	assert_false(host.is_match_paused())
	_b().surrender()
	_pump()
	assert_true(host.is_match_paused(), "B ушёл — нажали все оставшиеся")
	assert_eq(_a().pause_votes(), Vector2i(2, 2))
	_b().request_pause(true)
	_pump()
	assert_eq(host.pause_votes(), Vector2i(2, 2), "голос ушедшего не считается")


func test_bad_pause_messages_are_dropped() -> void:
	_rolled(SEAT_A)
	var before := host.dropped_messages
	links[0].send(NetTransport.HOST_ID, NetProtocol.make(Msg.PAUSE, {"on": 1}))
	_pump()
	assert_eq(host.dropped_messages, before + 1)
	assert_eq(host.pause_votes(), Vector2i(0, 3))


func test_single_player_has_no_net_pause() -> void:
	var local := LocalSession.new(MatchController.new([HumanAgent.new(), HumanAgent.new()],
			RuleOptions.new(), Rng.make_seeded(1)))
	local.request_pause(true)
	assert_false(local.is_match_paused())
	assert_eq(local.pause_votes(), Vector2i.ZERO)


# --- Темп раундов --------------------------------------------------------------

func test_roll_waits_for_all_humans() -> void:
	_prepared(false)
	host.start_match(0)
	_pump()
	assert_eq(_a().phase, Phase.ROLL)
	host.roll()
	_a().roll()
	_pump()
	assert_eq(host.controller.phase, Phase.ROLL, "B ещё не готов")
	clock.t += NetBalance.TURN_TIME_MS * 3
	_pump()
	assert_eq(host.controller.phase, Phase.ROLL, "таймер выключен — ждём")
	_b().roll()
	_pump()
	assert_eq(host.controller.phase, Phase.BIDDING)
	assert_eq(_b().phase, Phase.BIDDING)


func test_roll_phase_times_out_with_timer() -> void:
	_prepared(true)
	host.start_match(0)
	_pump()
	clock.t += NetBalance.TURN_TIME_MS
	_pump()
	assert_eq(host.controller.phase, Phase.BIDDING)


func test_loaded_die_from_guest_in_roll_phase() -> void:
	_prepared()
	host.start_match(0)
	_pump()
	assert_eq(_a().submit_cheat(0, CheatAction.loaded_die(6)), Err.OK)
	_pump()
	assert_eq(_a().view_for(0).cheat_used, true)
	for s in [host, _a(), _b()]:
		s.roll()
	_pump()
	assert_eq(host.controller.hand_of(SEAT_A)[MatchController.LOADED_DIE_INDEX], 6)


func test_next_round_waits_for_ready_or_timeout() -> void:
	_rolled(SEAT_A)
	_a().submit_action(0, MatchAction.make_bid(2, 2))
	_pump()
	_b().submit_action(0, MatchAction.dudo())
	_pump()
	assert_eq(_a().phase, Phase.ROUND_END)
	host.next_round()
	_a().next_round()
	_pump()
	assert_eq(host.controller.phase, Phase.ROUND_END)
	_b().next_round()
	_pump()
	assert_eq(host.controller.phase, Phase.ROLL)
	assert_eq(_a().round_number, 2)
	# Второй раунд: никто не жмёт «готов» после итога — таймаут.
	host.controller.roll()
	_pump()
	var cur := host.controller.current_player
	host.controller.submit_action(cur, MatchAction.make_bid(2, 2))
	host.controller.submit_action(host.controller.current_player, MatchAction.dudo())
	_pump()
	assert_eq(host.controller.phase, Phase.ROUND_END)
	clock.t += NetBalance.ROUND_READY_TIMEOUT_MS
	_pump()
	assert_eq(host.controller.phase, Phase.ROLL)


# --- Обрыв ---------------------------------------------------------------------

func test_disconnected_guest_is_replaced_by_bot_with_same_state() -> void:
	_rolled(SEAT_B)
	host.controller.debug_set_sanity(SEAT_A, 4)
	var b := _b()
	watch_signals(b)
	watch_signals(host)
	links[0].close()
	guests.remove_at(0)
	_pump()
	assert_true(host.seat(SEAT_A).replaced)
	assert_false(host.controller.agent(SEAT_A).is_human())
	assert_eq(host.controller.cheats.sanity[SEAT_A], 4)
	assert_eq(host.controller.dice_counts[SEAT_A], 5)
	assert_eq(host.controller.hand_of(SEAT_A), HANDS_4[SEAT_A] as Array[int])
	assert_signal_emitted_with_parameters(host, "seat_replaced", [SEAT_A])
	assert_signal_emitted_with_parameters(b, "seat_replaced", [_local(SEAT_B, SEAT_A)])
	assert_true(b.seat(_local(SEAT_B, SEAT_A)).replaced)


func test_bot_plays_for_guest_who_dropped_on_own_turn() -> void:
	_rolled(SEAT_A)
	links[0].close()
	guests.remove_at(0)
	_pump()
	assert_eq(host.controller.current_player, SEAT_A)
	clock.t += NetBalance.BOT_TURN_DELAY_MS
	_pump()
	assert_eq(host.controller.current_bidder, SEAT_A, "за отключившегося сходил бот")


func test_guest_leave_gives_seat_to_bot_and_ignores_further_commands() -> void:
	_rolled(SEAT_A)
	_a().surrender()
	_pump()
	assert_true(host.seat(SEAT_A).replaced)
	assert_eq(_a().state, ClientSession.State.IN_MATCH, "сдавшийся досматривает")
	assert_true(_a().seat(0).replaced)
	assert_eq(_a().submit_action(0, MatchAction.make_bid(2, 2)), Err.NOT_YOUR_TURN)
	clock.t += NetBalance.BOT_TURN_DELAY_MS
	_pump()
	assert_eq(host.controller.current_bidder, SEAT_A, "за A сходил бот")


func test_host_surrender_gives_host_seat_to_bot() -> void:
	_rolled(HOST_SEAT)
	host.surrender()
	assert_eq(host.submit_action(HOST_SEAT, MatchAction.make_bid(2, 2)), Err.NOT_YOUR_TURN)
	clock.t += NetBalance.BOT_TURN_DELAY_MS
	_pump()
	assert_eq(host.controller.current_bidder, HOST_SEAT)
	assert_true(_a().seat(_local(SEAT_A, HOST_SEAT)).replaced)


func test_host_leaving_aborts_match_for_guests() -> void:
	_rolled(SEAT_A)
	watch_signals(_a())
	watch_signals(_b())
	host.leave()
	_pump()
	assert_signal_emitted_with_parameters(_a(), "match_aborted", [NetProtocol.Abort.HOST_LEFT])
	assert_signal_emitted_with_parameters(_b(), "match_aborted", [NetProtocol.Abort.HOST_LEFT])
	assert_eq(_a().state, ClientSession.State.CLOSED)


func test_lost_host_connection_aborts_match() -> void:
	_rolled(SEAT_A)
	watch_signals(_a())
	hub.close()
	_pump()
	assert_signal_emitted_with_parameters(_a(), "match_aborted",
			[NetProtocol.Abort.CONNECTION_LOST])


func test_connect_timeout_fails() -> void:
	var dead := LoopbackTransport.new()  # гость, которого никто не слышит
	var g := ClientSession.new(dead, "Одинокий", 0, clock.now, VERSION)
	watch_signals(g)
	clock.t += NetBalance.CONNECT_TIMEOUT_MS
	g.update()
	assert_signal_emitted_with_parameters(g, "match_aborted",
			[NetProtocol.Abort.CONNECTION_FAILED])


# --- Полный матч ---------------------------------------------------------------

## Человек за столом: готов к броску и раунду, в свой ход — случайное допустимое действие.
func _drive(session: MatchSession, brain: RandomAgent) -> void:
	var me := session.local_player()
	match session.phase:
		Phase.ROLL:
			session.roll()
		Phase.ROUND_END:
			session.next_round()
		Phase.BIDDING:
			if session.current_player == me and session.seat(me).is_human():
				var action := brain.choose_action(session.view_for(me))
				assert_eq(session.submit_action(me, action), Err.OK, str(action))


var _ended := {}


func _on_ended(winner: int, index: int) -> void:
	_ended[index] = winner


func test_full_match_host_and_two_guests() -> void:
	_prepared()
	host.controller.cheats.risk_mode = CheatState.RiskMode.NORMAL
	var sessions: Array[MatchSession] = [host, _a(), _b()]
	_ended.clear()
	for i in sessions.size():
		sessions[i].match_ended.connect(_on_ended.bind(i))
	var brains: Array[RandomAgent] = []
	for i in sessions.size():
		brains.append(RandomAgent.new(Rng.make_seeded(100 + i)))
	host.start_match()
	var steps := 0
	while host.controller.phase != Phase.MATCH_OVER and steps < 20000:
		for i in sessions.size():
			_drive(sessions[i], brains[i])
		_pump(1)
		clock.t += 400
		steps += 1
	_pump()
	assert_eq(host.controller.phase, Phase.MATCH_OVER, "матч доигран за %d шагов" % steps)
	var winner := host.controller.winner_id
	assert_eq(_ended.get(0), winner)
	assert_eq(_ended.get(1), _local(SEAT_A, winner))
	assert_eq(_ended.get(2), _local(SEAT_B, winner))
	assert_eq(_a().phase, Phase.MATCH_OVER)
	assert_eq(host.dropped_messages, 0)
	assert_eq(_a().dropped_messages, 0)
	assert_eq(_b().dropped_messages, 0)


# --- Контракт ------------------------------------------------------------------

func test_sessions_have_all_controller_signals() -> void:
	var names := {}
	for sig in MatchController.new([HumanAgent.new(), HumanAgent.new()] as Array[MatchAgent],
			RuleOptions.new(), Rng.make_seeded(1)).get_script().get_script_signal_list():
		names[sig["name"]] = sig["args"].size()
	for session: MatchSession in [LocalSession.new(), host,
			ClientSession.new(LoopbackTransport.new(), "", 0, clock.now, VERSION)]:
		for sig_name: StringName in names:
			assert_true(session.has_signal(sig_name), "%s: %s" % [session, sig_name])
		for sig in session.get_signal_list():
			if names.has(sig["name"]):
				assert_eq(sig["args"].size(), names[sig["name"]], str(sig["name"]))
