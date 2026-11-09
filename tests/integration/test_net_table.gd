extends GutTest
## М19: стол поверх сетевой сессии. Гость играет кнопками стола (ClientSession), хост —
## в памяти на инъектированных часах (его место отдано боту: два стола в одном процессе
## делили бы шину Events). Таймер хода у портрета, пауза без остановки, «Сдаться»,
## обрыв связи. И стол хоста (HostSession) против бота.

const Scene := preload("res://scenes/table.tscn")
const Phase := MatchController.Phase
const VERSION := "test/1"


class Clock:
	var t := 1000

	func now() -> int:
		return t


var clock: Clock
var hub: LoopbackTransport
var host: HostSession
var client: ClientSession


func before_each() -> void:
	ScreenNav.history.clear()
	MatchSetup.pending = null
	for flag in HintPanel.TOPICS:
		Stats.set_flag(flag)
	clock = Clock.new()
	hub = LoopbackTransport.make_host()
	host = HostSession.new(hub, "Хозяин", 1, clock.now, VERSION)


func after_each() -> void:
	Stats.clear_flags()
	Stats.recording = true
	MatchSetup.pending = null
	if host != null:
		host.leave()


## Гость за столом: хост, гость, бот. Место хоста — боту (если host_is_bot).
func _guest_table(timer := true, host_is_bot := true) -> Control:
	client = ClientSession.new(hub.connect_guest(), "Анна", 2, clock.now, VERSION)
	for i in 3:
		host.update()
		client.update()
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0),
			SeatInfo.guest(client._transport.peer_id, "", 0), SeatInfo.bot(&"sailor")]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(21), timer))
	host.controller.cheats.false_evidence_chance = 0.0
	host.update()
	client.update()
	assert_eq(client.state, ClientSession.State.IN_MATCH)
	MatchSetup.pending = MatchSetup.for_session(client)
	var screen: Control = add_child_autofree(Scene.instantiate())
	if host_is_bot:
		host.surrender()
	host.start_match(0)
	return screen


## Кадр: время идёт, хост считает, стол забирает события.
func _tick(screen: Control, ms := 500) -> void:
	clock.t += ms
	host.update()
	screen._process(0.0)


## Шаг гостя «мышью»: итог раунда — «Дальше», бросок — «Бросить», свой ход — ставка
## или «Ложь!».
func _guest_step(screen: Control) -> void:
	if screen._end_panel.visible:
		if screen._end_panel.spectate_button.visible:
			screen._end_panel.spectate_button.pressed.emit()
	elif screen._result_panel.visible:
		screen._result_panel.press_continue()
	elif screen._roll_button.visible:
		screen._roll_button.pressed.emit()
	elif screen._my_turn():
		if not screen._liar_button.disabled and randi() % 3 == 0 or screen._bid_button.disabled:
			screen._liar_button.pressed.emit()
		else:
			screen._bid_button.pressed.emit()
	_tick(screen)


func test_guest_plays_full_match_with_table_buttons() -> void:
	seed(7)
	var screen := _guest_table()
	assert_null(screen._controller, "у гостя контроллера нет")
	assert_eq(screen._seats.size(), 2)
	_tick(screen)
	assert_eq(screen._name(2), tr("NET_NAME_REPLACED") % "Хозяин",
			"место хоста ведёт бот — так и подписано")
	assert_eq(screen._name(1), tr(BotRoster.by_id(&"sailor").name_key))
	assert_eq(screen._own_character(), Sprites.PLAYER_PORTRAITS[2], "свой портрет из лобби")
	assert_false(screen._end_panel.rematch_button.visible, "реванша в сети нет")
	var steps := 0
	while not (client.phase == Phase.MATCH_OVER and screen._end_panel.visible) and steps < 6000:
		steps += 1
		_guest_step(screen)
	assert_eq(client.phase, Phase.MATCH_OVER)
	assert_eq(host.controller.phase, Phase.MATCH_OVER)
	assert_eq(client.winner_id, SeatFrame.new(1, 3).to_local(host.controller.winner_id))
	assert_eq(screen._end_panel.is_won(), client.winner_id == 0)
	assert_eq(client.dropped_messages, 0)


func test_roll_is_ready_and_waits_for_host() -> void:
	var screen := _guest_table(true, false)
	_tick(screen)
	assert_eq(client.phase, Phase.ROLL)
	assert_true(screen._roll_button.visible)
	screen._roll_button.pressed.emit()
	assert_false(screen._roll_button.visible, "«готов» отправлен")
	assert_string_contains(screen._status_label.text, tr("NET_STATUS_WAITING"))
	_tick(screen)
	assert_eq(client.phase, Phase.ROLL, "хост ещё не готов")
	host.roll()
	_tick(screen)
	assert_ne(client.phase, Phase.ROLL)


func test_turn_timer_shows_last_seconds_at_portrait() -> void:
	var screen := _guest_table()
	var steps := 0
	while not screen._my_turn() and steps < 200:
		steps += 1
		if screen._roll_button.visible:
			screen._roll_button.pressed.emit()
		_tick(screen)
	assert_true(screen._my_turn())
	assert_eq(screen.turn_timer_text(), "", "до последних 10 с таймера не видно")
	clock.t += NetBalance.TURN_TIME_MS - 4_500
	screen._process(0.0)
	assert_eq(screen.turn_timer_text(), "5")
	var own_base: Vector2 = screen._own.fx_point(&"portrait_base")
	assert_lt(absf(screen._turn_timer.position.x + TableLayout.TURN_TIMER_SIZE.x / 2.0
			- own_base.x), 1.0, "таймер — у своего портрета")
	_tick(screen, 5_000)
	_tick(screen)
	assert_false(screen._my_turn(), "время вышло — автоход")


func test_pause_does_not_stop_network_game_and_surrender_gives_seat_to_bot() -> void:
	var screen := _guest_table()
	_tick(screen)
	screen.open_pause()
	assert_true(screen.is_paused())
	assert_false(get_tree().paused, "в сети пауза игру не останавливает")
	assert_true(screen._pause.surrender_button.visible)
	screen._pause.surrender_button.pressed.emit()
	assert_false(screen.is_paused())
	assert_true(screen._end_panel.visible)
	assert_false(screen._end_panel.is_won())
	assert_true(screen._end_panel.spectate_button.visible, "матч идёт — можно досмотреть")
	assert_false(Stats.recording, "сдавшемуся победа бота не засчитывается")
	_tick(screen)
	assert_true(host.lobby != null and host.seat(1).replaced, "место гостя у хоста — бот")
	assert_false(client.seat(0).is_human())
	screen._end_panel.spectate_button.pressed.emit()
	var steps := 0
	while client.phase != Phase.MATCH_OVER and steps < 4000:
		steps += 1
		_guest_step(screen)
	assert_eq(client.phase, Phase.MATCH_OVER, "бот доиграл за гостя")


func test_host_leaving_shows_message_and_menu() -> void:
	var screen := _guest_table()
	_tick(screen)
	host.leave()
	host = null
	screen._process(0.0)
	assert_true(screen.is_match_aborted())
	assert_eq(screen._abort_panel.footer_text(), tr("NET_ABORT_HOST_LEFT"))
	screen._abort_panel.buttons()[0].pressed.emit()
	assert_eq(ScreenNav.last(), ScreenNav.MAIN_MENU)


func test_other_guest_leaving_is_announced() -> void:
	var other := ClientSession.new(hub.connect_guest(), "Борис", 3, clock.now, VERSION)
	client = ClientSession.new(hub.connect_guest(), "Анна", 2, clock.now, VERSION)
	for i in 3:
		host.update()
		other.update()
		client.update()
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0),
			SeatInfo.guest(other._transport.peer_id, "", 0),
			SeatInfo.guest(client._transport.peer_id, "", 0)]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(4), false))
	host.update()
	client.update()
	MatchSetup.pending = MatchSetup.for_session(client)
	var screen: Control = add_child_autofree(Scene.instantiate())
	host.start_match(0)
	_tick(screen)
	# У Анны (у хоста место 2) по кругу: 1 — хост, 2 — Борис.
	assert_eq(screen._name(2), "Борис")
	other.leave()
	_tick(screen)
	_tick(screen)
	assert_eq(screen._name(2), tr("NET_NAME_REPLACED") % "Борис")
	assert_eq(screen._seats[2]._name_label.text, tr("NET_NAME_REPLACED") % "Борис")


func test_host_table_plays_against_bot() -> void:
	var plan: Array[SeatInfo] = [SeatInfo.host("", 0), SeatInfo.bot(&"witch")]
	assert_true(host.begin_match(plan, RuleOptions.new(), Rng.make_seeded(8), true))
	MatchSetup.pending = MatchSetup.for_session(host)
	var screen: Control = add_child_autofree(Scene.instantiate())
	assert_eq(screen._controller, host.controller)
	assert_eq(host.state, HostSession.State.IN_MATCH, "стол хоста сам начал матч")
	assert_eq(screen._own_character(), Sprites.PLAYER_PORTRAITS[1])
	var steps := 0
	while not (host.phase == Phase.MATCH_OVER and screen._end_panel.visible) and steps < 6000:
		steps += 1
		if screen._end_panel.visible:
			if screen._end_panel.spectate_button.visible:
				screen._end_panel.spectate_button.pressed.emit()
		elif screen._result_panel.visible:
			screen._result_panel.press_continue()
		elif screen._roll_button.visible:
			screen._roll_button.pressed.emit()
		elif screen._my_turn():
			if screen._bid_button.disabled:
				screen._liar_button.pressed.emit()
			else:
				screen._bid_button.pressed.emit()
		clock.t += 700
		screen._process(0.0)
	assert_eq(host.phase, Phase.MATCH_OVER)
	assert_true(screen._end_panel.visible)
