extends GutTest
## Сетевое ядро (М18) по настоящему ENet через loopback 127.0.0.1: рукопожатие, отказ
## по версии и полный матч хост + 2 гостя. Часы игры — инъекцией (таймеры не ждём),
## сеть — настоящая.

const Phase := MatchController.Phase
const Err := MatchController.Result
## Не основной порт: тесты не мешают запущенной игре.
const TEST_PORT := NetBalance.PORT + 11
const VERSION := "enet-test/1"
const MAX_NET_WAIT_MS := 3000


class Clock:
	var t := 1000

	func now() -> int:
		return t


var clock: Clock
var host_link: ENetTransport
var host: HostSession
var guests: Array[ClientSession] = []


func before_each() -> void:
	clock = Clock.new()
	host_link = ENetTransport.host(TEST_PORT)
	assert_not_null(host_link, "порт %d свободен" % TEST_PORT)
	host = HostSession.new(host_link, "Хозяин", 0, clock.now, VERSION)
	guests.clear()


func after_each() -> void:
	for g in guests:
		g.leave()
	if host != null:
		host.leave()
	host = null
	host_link = null
	guests.clear()


func _join(guest_name: String, version := VERSION) -> ClientSession:
	var g := ClientSession.new(ENetTransport.join("127.0.0.1", TEST_PORT), guest_name, 1,
			clock.now, version)
	guests.append(g)
	return g


func _pump() -> void:
	if host != null:
		host.update()
	for g in guests:
		g.update()


## Крутить сеть, пока условие не выполнится (реальное время, не дольше MAX_NET_WAIT_MS).
func _pump_until(cond: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - start > MAX_NET_WAIT_MS:
			return false
		_pump()
		OS.delay_msec(1)
	return true


func test_handshake_over_enet() -> void:
	var a := _join("Анна")
	var b := _join("Борис")
	assert_true(_pump_until(func() -> bool: return host.guests().size() == 2))
	assert_true(_pump_until(func() -> bool:
		return a.state == ClientSession.State.LOBBY and b.state == ClientSession.State.LOBBY))


func test_version_mismatch_over_enet() -> void:
	var old := _join("Старый", "old/1")
	watch_signals(old)
	assert_true(_pump_until(func() -> bool: return old.state == ClientSession.State.CLOSED))
	assert_signal_emitted_with_parameters(old, "rejected",
			[NetProtocol.Reject.VERSION_MISMATCH, VERSION])


func test_full_match_host_and_two_guests_over_enet() -> void:
	var a := _join("Анна")
	var b := _join("Борис")
	assert_true(_pump_until(func() -> bool:
		return a.state == ClientSession.State.LOBBY and b.state == ClientSession.State.LOBBY))
	var peers: Array[int] = []
	for info in host.guests():
		peers.append(info.peer_id)
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.guest(peers[0], "", 0),
			SeatInfo.guest(peers[1], "", 0)]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(21), false))
	assert_true(_pump_until(func() -> bool:
		return a.state == ClientSession.State.IN_MATCH and b.state == ClientSession.State.IN_MATCH))
	host.start_match()

	var sessions: Array[MatchSession] = [host, a, b]
	var brains: Array[RandomAgent] = []
	for i in sessions.size():
		brains.append(RandomAgent.new(Rng.make_seeded(200 + i)))
	var start := Time.get_ticks_msec()
	while host.controller.phase != Phase.MATCH_OVER and Time.get_ticks_msec() - start < 60_000:
		for i in sessions.size():
			_drive(sessions[i], brains[i])
		_pump()
		clock.t += 100
		OS.delay_msec(1)
	assert_eq(host.controller.phase, Phase.MATCH_OVER, "матч доигран")
	var winner := host.controller.winner_id
	assert_true(_pump_until(func() -> bool:
		return a.phase == Phase.MATCH_OVER and b.phase == Phase.MATCH_OVER))
	# Гость на месте s видит победителя под номером winner − s.
	for s in [1, 2]:
		var g: ClientSession = sessions[s]
		assert_eq(g.winner_id, posmod(winner - s, 3))
		assert_eq(g.dropped_messages, 0)
	assert_eq(host.dropped_messages, 0)

	watch_signals(a)
	host.leave()
	host = null
	assert_true(_pump_until(func() -> bool: return a.state == ClientSession.State.CLOSED))
	assert_signal_emitted(a, "match_aborted")


## Человек за столом: готов к броску и раунду, в свой ход — случайное допустимое действие.
## Ход отправляется один раз: до ответа хоста снимок не меняется.
func _drive(session: MatchSession, brain: RandomAgent) -> void:
	var me := session.local_player()
	match session.phase:
		Phase.ROLL:
			session.roll()
		Phase.ROUND_END:
			session.next_round()
		Phase.BIDDING:
			if session.current_player != me or not session.seat(me).is_human():
				return
			var view := session.view_for(me)
			var key := "%d/%d" % [view.round_number, view.bid_history.size()]
			if session.get_meta(&"sent", "") == key:
				return
			session.set_meta(&"sent", key)
			assert_eq(session.submit_action(me, brain.choose_action(view)), Err.OK)
