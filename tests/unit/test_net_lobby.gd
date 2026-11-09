extends GutTest
## М19: лобби сетевой игры (NetLobby, сообщение LOBBY хост → гости) и поиск игр в сети
## (пакет LanBeacon, список LanBrowser, адреса рассылки).

const VERSION := "test/1"


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


func _join(guest_name := "Гость", portrait := 0) -> ClientSession:
	var link := hub.connect_guest()
	var g := ClientSession.new(link, guest_name, portrait, clock.now, VERSION)
	guests.append(g)
	links.append(link)
	return g


func _pump(times := 4) -> void:
	for i in times:
		host.update()
		for g in guests:
			g.update()


func _kinds(seats: Array[SeatInfo]) -> Array:
	var out := []
	for s in seats:
		out.append(s.kind)
	return out


# --- NetLobby ----------------------------------------------------------------------

func test_new_lobby_is_host_and_random_bots() -> void:
	var lobby := NetLobby.new(SeatInfo.host("Хозяин", 1))
	assert_eq(lobby.seat_count(), NetLobby.DEFAULT_SEATS)
	assert_eq(lobby.seats[0].kind, SeatInfo.Kind.HOST)
	for i in range(1, lobby.seat_count()):
		assert_eq(lobby.seats[i].kind, SeatInfo.Kind.BOT)
		assert_eq(lobby.seats[i].bot_id, NetLobby.RANDOM_BOT)
	assert_eq(lobby.humans(), 1)


func test_guest_takes_first_bot_seat_and_returns_it_on_leave() -> void:
	var lobby := NetLobby.new(SeatInfo.host("", 0), 3)
	assert_true(lobby.cycle_bot(1, 1))
	assert_eq(lobby.add_guest(SeatInfo.guest(7, "Анна", 2)), 1)
	assert_eq(lobby.seat_of_peer(7), 1)
	assert_eq(lobby.seat_count(), 3, "гость сел вместо бота")
	assert_true(lobby.remove_guest(7))
	assert_eq(lobby.seats[1].kind, SeatInfo.Kind.BOT)
	assert_eq(lobby.seats[1].bot_id, NetLobby.RANDOM_BOT)
	assert_false(lobby.remove_guest(7))


func test_seat_is_added_when_all_seats_are_people() -> void:
	var lobby := NetLobby.new(SeatInfo.host("", 0), 2)
	assert_eq(lobby.add_guest(SeatInfo.guest(2, "A", 0)), 1)
	assert_eq(lobby.add_guest(SeatInfo.guest(3, "B", 0)), 2)
	assert_eq(lobby.seat_count(), 3)
	for peer in range(4, 7):
		lobby.add_guest(SeatInfo.guest(peer, "G", 0))
	assert_eq(lobby.seat_count(), MatchController.MAX_PLAYERS)
	assert_eq(lobby.add_guest(SeatInfo.guest(9, "X", 0)), -1, "мест больше нет")


func test_seat_count_bounds_and_people_are_never_removed() -> void:
	var lobby := NetLobby.new(SeatInfo.host("", 0), 4)
	lobby.add_guest(SeatInfo.guest(2, "A", 0))
	lobby.add_guest(SeatInfo.guest(3, "B", 0))
	lobby.set_seat_count(2)
	assert_eq(lobby.seat_count(), 3, "людей трое — меньше трёх мест нельзя")
	assert_eq(_kinds(lobby.seats), [SeatInfo.Kind.HOST, SeatInfo.Kind.GUEST, SeatInfo.Kind.GUEST])
	lobby.set_seat_count(99)
	assert_eq(lobby.seat_count(), MatchController.MAX_PLAYERS)
	assert_false(lobby.set_seat_count(MatchController.MAX_PLAYERS))


func test_bot_choice_skips_characters_already_at_the_table() -> void:
	var lobby := NetLobby.new(SeatInfo.host("", 0), 3)
	var choices := NetLobby.bot_choices()
	assert_eq(choices[0], NetLobby.RANDOM_BOT)
	assert_true(lobby.cycle_bot(1, 1))
	assert_eq(lobby.seats[1].bot_id, choices[1])
	assert_true(lobby.cycle_bot(2, 1))
	assert_eq(lobby.seats[2].bot_id, choices[2], "первый персонаж уже за столом — следующий")
	assert_true(lobby.cycle_bot(1, -1))
	assert_eq(lobby.seats[1].bot_id, NetLobby.RANDOM_BOT)
	assert_false(lobby.cycle_bot(0, 1), "место хоста — не бот")


func test_resolve_plan_gives_distinct_characters() -> void:
	var lobby := NetLobby.new(SeatInfo.host("", 0), MatchController.MAX_PLAYERS)
	lobby.cycle_bot(2, 1)
	var chosen := lobby.seats[2].bot_id
	for seed_value in 20:
		var plan := lobby.resolve_plan(Rng.make_seeded(seed_value))
		assert_eq(plan.size(), MatchController.MAX_PLAYERS)
		assert_eq(plan[2].bot_id, chosen, "выбранный персонаж остаётся")
		var seen := {}
		for i in range(1, plan.size()):
			assert_ne(plan[i].bot_id, NetLobby.RANDOM_BOT)
			assert_not_null(BotRoster.by_id(plan[i].bot_id))
			assert_false(seen.has(plan[i].bot_id), "персонажи не повторяются")
			seen[plan[i].bot_id] = true
	assert_eq(lobby.seats[1].bot_id, NetLobby.RANDOM_BOT, "лобби не меняется")


# --- Лобби по сети -----------------------------------------------------------------

func test_guests_see_lobby_seats_rules_and_their_seat() -> void:
	var options := RuleOptions.new()
	options.calza_enabled = false
	host.set_lobby_rules(options, false)
	var a := _join("Анна", 2)
	var b := _join("Борис", 3)
	watch_signals(a)
	_pump()
	assert_signal_emitted(a, "lobby_changed")
	assert_eq(a.lobby_you, 1)
	assert_eq(b.lobby_you, 2)
	assert_eq(_kinds(a.lobby_seats), [SeatInfo.Kind.HOST, SeatInfo.Kind.GUEST,
			SeatInfo.Kind.GUEST, SeatInfo.Kind.BOT])
	assert_eq(a.lobby_seats[0].player_name, "Хозяин")
	assert_eq(a.lobby_seats[2].player_name, "Борис")
	assert_eq(a.lobby_seats[2].portrait, 3)
	assert_eq(a.lobby_seats[1].peer_id, 0, "сетевые id гостям не уходят")
	assert_false(a.lobby_options.calza_enabled)
	assert_true(a.lobby_options.palifico_enabled)
	assert_false(a.timer_enabled)


func test_host_edits_reach_guests() -> void:
	var a := _join("Анна")
	_pump()
	watch_signals(host)
	host.set_seat_count(6)
	host.cycle_bot(3, 1)
	_pump()
	assert_signal_emit_count(host, "lobby_changed", 2)
	assert_eq(a.lobby_seats.size(), 6)
	assert_eq(a.lobby_seats[3].bot_id, NetLobby.bot_choices()[1])
	host.set_lobby_rules(RuleOptions.new(), true)
	_pump()
	assert_true(a.timer_enabled)


func test_guest_leaving_lobby_frees_the_seat_for_everyone() -> void:
	var a := _join("Анна")
	var b := _join("Борис")
	_pump()
	a.leave()
	_pump()
	assert_eq(host.lobby.humans(), 2)
	assert_eq(b.lobby_seats[1].kind, SeatInfo.Kind.BOT)
	assert_eq(b.lobby_you, 2)


func test_begin_lobby_match_seats_guests_and_random_bots() -> void:
	var a := _join("Анна", 2)
	_pump()
	host.set_seat_count(3)
	watch_signals(a)
	assert_true(host.begin_lobby_match(Rng.make_seeded(5)))
	_pump(1)
	assert_signal_emitted(a, "match_began")
	assert_eq(a.player_count(), 3)
	assert_eq(a.seat(0).player_name, "Анна", "гость — у себя место 0")
	assert_eq(a.seat(2).player_name, "Хозяин")
	assert_eq(a.seat(1).kind, SeatInfo.Kind.BOT)
	assert_not_null(BotRoster.by_id(a.seat(1).bot_id))
	assert_false(host.begin_lobby_match(Rng.make_seeded(5)), "второй раз нельзя")


func test_late_lobby_message_is_dropped_in_match() -> void:
	var a := _join("Анна")
	_pump()
	host.begin_lobby_match(Rng.make_seeded(1))
	_pump()
	var before := a.dropped_messages
	hub.deliver_raw(links[0].peer_id, var_to_bytes(NetProtocol.make(
			NetProtocol.Msg.LOBBY, {"seats": [], "opt": [true, true], "timer": true, "you": 0})))
	a.update()
	assert_eq(a.dropped_messages, before + 1)


func test_bad_lobby_message_is_dropped() -> void:
	var a := _join("Анна")
	_pump()
	var before := a.dropped_messages
	var good_seats := [SeatInfo.host("H", 0).to_wire(), SeatInfo.bot(&"").to_wire()]
	for bad: Dictionary in [
		{"seats": good_seats, "opt": [true, true], "timer": true, "you": 5},
		{"seats": good_seats, "opt": [true], "timer": true, "you": 1},
		{"seats": [good_seats[0]], "opt": [true, true], "timer": true, "you": 0},
		{"seats": good_seats, "opt": [true, true], "timer": 1, "you": 1},
	]:
		hub.deliver_raw(links[0].peer_id,
				var_to_bytes(NetProtocol.make(NetProtocol.Msg.LOBBY, bad)))
	a.update()
	assert_eq(a.dropped_messages, before + 4)
	assert_eq(a.lobby_you, 1, "годное лобби не испорчено")


# --- Поиск игр ---------------------------------------------------------------------

func test_beacon_packet_round_trip() -> void:
	var info: Variant = LanBeacon.read_packet(LanBeacon.make_packet("Хозяин\n", 2, 4, VERSION))
	assert_not_null(info)
	assert_eq(info["name"], "Хозяин")
	assert_eq(info["humans"], 2)
	assert_eq(info["seats"], 4)
	assert_eq(info["version"], VERSION)
	assert_eq(info["port"], NetBalance.PORT)


func test_foreign_or_broken_beacon_is_ignored() -> void:
	assert_null(LanBeacon.read_packet(var_to_bytes({"g": "other-game"})))
	assert_null(LanBeacon.read_packet(var_to_bytes({"g": 5})))
	var bad := {"g": LanBeacon.MAGIC, "ver": "x", "name": "H", "n": 5, "max": 4, "port": 1}
	assert_null(LanBeacon.read_packet(var_to_bytes(bad)), "людей больше, чем мест")
	bad["n"] = 1
	bad["max"] = 9
	assert_null(LanBeacon.read_packet(var_to_bytes(bad)))


func test_browser_lists_and_expires_games() -> void:
	var browser := LanBrowser.new(clock.now)
	watch_signals(browser)
	assert_true(browser.feed("192.168.1.5", LanBeacon.make_packet("Хозяин", 1, 4)))
	assert_false(browser.feed("192.168.1.5", LanBeacon.make_packet("Хозяин", 1, 4)),
			"то же объявление — список не меняется")
	browser.feed("26.1.2.3", LanBeacon.make_packet("Радмин", 2, 3, "old/1"))
	var games := browser.games()
	assert_eq(games.size(), 2)
	assert_eq(games[1].address, "26.1.2.3")
	assert_false(games[1].is_compatible())
	assert_true(games[0].is_compatible())
	assert_eq(games[0].host_name, "Хозяин")
	clock.t += NetBalance.GAME_LIST_TTL_MS - 100
	browser.feed("192.168.1.5", LanBeacon.make_packet("Хозяин", 2, 4))
	clock.t += 200
	browser.update()
	assert_eq(browser.games().size(), 1, "молчащая игра пропала")
	assert_eq(browser.games()[0].humans, 2)
	assert_signal_emit_count(browser, "changed", 4)


func test_broadcast_targets_cover_subnets_and_radmin() -> void:
	var targets := LanBeacon.broadcast_targets(["192.168.1.5", "26.10.20.30", "192.168.1.7"])
	assert_eq(targets, PackedStringArray(["255.255.255.255", "192.168.1.255", "26.10.20.255",
			"26.255.255.255"]))
	assert_true(LanBeacon.is_radmin("26.10.20.30"))
	assert_false(LanBeacon.is_radmin("192.168.1.5"))
	for a in LanBeacon.local_ipv4():
		assert_false(a.begins_with("127."), "без петли")
		assert_false(a.contains(":"), "только IPv4")
