class_name ClientSession
extends MatchSession
## Зеркало сетевого матча у гостя (DESIGN.md §8б). Матч считает хост; сюда приходят
## только события, видимые этому игроку, и снимок его PlayerView после каждого события.
## Свой игрок — всегда место 0 (SeatFrame на хосте поворачивает номера).
##
## Жизненный цикл: CONNECTING → (связь есть, ушёл HELLO) HANDSHAKE → (WELCOME) LOBBY
## → (MATCH_START) IN_MATCH → CLOSED. Отказ хоста — сигнал rejected, обрыв — match_aborted.
##
## Команды проверяются здесь по своему PlayerView (те же правила, что у контроллера)
## и уходят хосту; хост проверяет их ещё раз. Отказ хоста — сигнал command_rejected.
## Состояние меняется только по событиям хоста.
##
## После MATCH_START разбор входящих приостанавливается до следующего update(),
## чтобы стол успел построиться и подписаться на события.

signal joined
signal rejected(reason: int, host_version: String)
signal match_began
signal command_rejected(result: int)
## Места или правила в лобби изменились (М19).
signal lobby_changed

enum State { CONNECTING, HANDSHAKE, LOBBY, IN_MATCH, CLOSED }

var state := State.CONNECTING
## Таймер хода включён хостом.
var timer_enabled := false
## Сколько входящих сообщений отброшено как недопустимые (тесты, отладка).
var dropped_messages := 0
## Лобби (М19): места в номерах хоста (бот с пустым bot_id — «случайный»), своё место
## (−1 — ещё не прислано) и правила матча хоста.
var lobby_seats: Array[SeatInfo] = []
var lobby_you := -1
var lobby_options := RuleOptions.new()

var _transport: NetTransport
var _clock: Callable
var _version: String
var _name: String
var _portrait: int
## Свой сетевой ранг для лобби (М20, RankBalance.Tier; −1 — не показывать). Задать до связи.
var rank := -1
var _started_at := 0
## Очередь входящего: ["msg", Dictionary] | ["down"].
var _inbox: Array = []
var _seats: Array[SeatInfo] = []
var _frame: SeatFrame
var _options := RuleOptions.new()
var _view: PlayerView
var _phase: int = Phase.IDLE
var _current := PerudoRules.NO_PLAYER
var _winner := PerudoRules.NO_PLAYER
## Когда (по своим часам) выйдет таймер хода; −1 — таймера нет.
var _deadline := -1
## «Готов» уже отправлен в этой фазе этого раунда.
var _ready_key := ""
## Пауза (М21): так говорит хост. На паузе таймер хода стоит на _paused_left.
var _paused := false
var _pause_votes := Vector2i.ZERO
var _paused_left := -1
## Свой голос за паузу (последний отправленный).
var _pause_sent := false


func _init(transport: NetTransport, p_name := "", p_portrait := 0, clock := Callable(),
		version := "") -> void:
	_transport = transport
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")
	_version = version if version != "" else NetProtocol.game_version()
	_name = SeatInfo.clean_name(p_name)
	_portrait = clampi(p_portrait, 0, NetBalance.PORTRAIT_COUNT - 1)
	_started_at = _now()
	_transport.peer_connected.connect(_on_connected)
	_transport.peer_disconnected.connect(_on_disconnected)
	_transport.message_received.connect(_on_received)


func _now() -> int:
	return _clock.call()


func _send(type: NetProtocol.Msg, fields := {}) -> void:
	_transport.send(NetTransport.HOST_ID, NetProtocol.make(type, fields))


func _on_disconnected(_peer: int) -> void:
	_inbox.append(["down"])


func _on_received(_peer: int, msg: Dictionary) -> void:
	_inbox.append(["msg", msg])


func _on_connected(peer: int) -> void:
	if peer == NetTransport.HOST_ID and state == State.CONNECTING:
		state = State.HANDSHAKE
		_send(NetProtocol.Msg.HELLO,
				{"ver": _version, "name": _name, "portrait": _portrait, "rank": rank})


# --- Цикл ----------------------------------------------------------------------

func update() -> void:
	if state == State.CLOSED:
		return
	_transport.poll()
	if state == State.CONNECTING and _now() - _started_at >= NetBalance.CONNECT_TIMEOUT_MS:
		_abort(NetProtocol.Abort.CONNECTION_FAILED)
		return
	while not _inbox.is_empty() and state != State.CLOSED:
		var item: Array = _inbox.pop_front()
		if item[0] == "down":
			var connecting := state == State.CONNECTING or state == State.HANDSHAKE
			_abort(NetProtocol.Abort.CONNECTION_FAILED if connecting
					else NetProtocol.Abort.CONNECTION_LOST)
			return
		if _handle(item[1]):
			return  # MATCH_START: события — со следующего update()


## true — пришёл MATCH_START (разбор приостанавливается).
func _handle(msg: Dictionary) -> bool:
	var type := NetProtocol.type_of(msg)
	match type:
		NetProtocol.Msg.ABORT:
			var r: Variant = msg.get("r")
			if typeof(r) == TYPE_INT and r >= 0 and r < NetProtocol.Abort.size():
				_abort(r)
				return false
		NetProtocol.Msg.WELCOME:
			if state == State.HANDSHAKE:
				state = State.LOBBY
				joined.emit()
				return false
		NetProtocol.Msg.REJECT:
			var r: Variant = msg.get("r")
			var ver: Variant = msg.get("ver")
			if (state == State.HANDSHAKE or state == State.LOBBY) and typeof(r) == TYPE_INT \
					and r >= 0 and r < NetProtocol.Reject.size() and typeof(ver) == TYPE_STRING:
				_close()
				rejected.emit(r, ver)
				return false
		NetProtocol.Msg.LOBBY:
			if state == State.LOBBY and _on_lobby(msg):
				lobby_changed.emit()
				return false
		NetProtocol.Msg.MATCH_START:
			if state == State.LOBBY and _on_match_start(msg):
				state = State.IN_MATCH
				match_began.emit()
				return true
		NetProtocol.Msg.EVENT:
			if state == State.IN_MATCH and _on_event(msg):
				return false
		NetProtocol.Msg.SEAT_BOT:
			var p: Variant = msg.get("p")
			if state == State.IN_MATCH and _frame.is_seat(p):
				_seats[p].replaced = true
				seat_replaced.emit(p)
				return false
		NetProtocol.Msg.PAUSE_STATE:
			if state == State.IN_MATCH and _on_pause_state(msg):
				return false
		NetProtocol.Msg.NACK:
			var r: Variant = msg.get("r")
			if state == State.IN_MATCH and typeof(r) == TYPE_INT:
				command_rejected.emit(r)
				return false
	dropped_messages += 1
	return false


func _on_lobby(msg: Dictionary) -> bool:
	var seats := _decode_seats(msg.get("seats"))
	var options := NetCodec.decode_options(msg.get("opt"))
	var timer: Variant = msg.get("timer")
	var you: Variant = msg.get("you")
	if seats.is_empty() or options == null or typeof(timer) != TYPE_BOOL \
			or typeof(you) != TYPE_INT or you < -1 or you >= seats.size():
		return false
	lobby_seats = seats
	lobby_you = you
	lobby_options = options
	timer_enabled = timer
	return true


## Места из сети: 2..6 годных SeatInfo, иначе пусто.
static func _decode_seats(raw_seats: Variant) -> Array[SeatInfo]:
	var seats: Array[SeatInfo] = []
	if typeof(raw_seats) != TYPE_ARRAY or raw_seats.size() < MatchController.MIN_PLAYERS \
			or raw_seats.size() > MatchController.MAX_PLAYERS:
		return seats
	for raw: Variant in raw_seats:
		var info := SeatInfo.from_wire(raw)
		if info == null:
			return [] as Array[SeatInfo]
		seats.append(info)
	return seats


func _on_match_start(msg: Dictionary) -> bool:
	var seats := _decode_seats(msg.get("seats"))
	var options := NetCodec.decode_options(msg.get("opt"))
	var timer: Variant = msg.get("timer")
	if seats.is_empty() or options == null or typeof(timer) != TYPE_BOOL:
		return false
	_seats = seats
	_frame = SeatFrame.identity(seats.size())
	_options = options
	timer_enabled = timer
	return true


func _on_event(msg: Dictionary) -> bool:
	var index: Variant = msg.get("e")
	if typeof(index) != TYPE_INT or index < 0 or index >= NetProtocol.EVENTS.size():
		return false
	var sig_name: StringName = NetProtocol.EVENTS[index][0]
	var args: Variant = NetCodec.decode_args(NetProtocol.EVENTS[index][1], msg.get("a"), _frame)
	var snap: Variant = NetCodec.decode_snapshot(msg.get("s"), _frame)
	if args == null or snap == null or (snap["view"] as PlayerView).player_id != 0:
		return false
	# Защита на всякий случай: чужие секреты не показываем, даже если пришли.
	if not NetProtocol.is_visible(sig_name, args, 0):
		return false
	_view = snap["view"]
	_phase = snap["phase"]
	_current = snap["current"]
	_winner = snap["winner"]
	_deadline = -1 if snap["time_left"] < 0 else _now() + snap["time_left"]
	_paused_left = snap["time_left"]
	callv(&"emit_signal", [sig_name] + args)
	return true


func _on_pause_state(msg: Dictionary) -> bool:
	var v: Variant = msg.get("v")
	var n: Variant = msg.get("n")
	var p: Variant = msg.get("p")
	var tl: Variant = msg.get("tl")
	if typeof(v) != TYPE_INT or typeof(n) != TYPE_INT or typeof(p) != TYPE_BOOL 			or typeof(tl) != TYPE_INT or n < 0 or n > MatchController.MAX_PLAYERS 			or v < 0 or v > n or tl < -1:
		return false
	_paused = p
	_pause_votes = Vector2i(v, n)
	if _paused:
		_paused_left = tl
	else:
		_deadline = -1 if tl < 0 else _now() + tl
	pause_changed.emit(_paused, v, n)
	return true


func _abort(reason: int) -> void:
	if state == State.CLOSED:
		return
	_close()
	match_aborted.emit(reason)


func _close() -> void:
	state = State.CLOSED
	_inbox.clear()
	_transport.close()


# --- Запросы -------------------------------------------------------------------

func is_networked() -> bool:
	return true


func player_count() -> int:
	return _seats.size()


func seat(player_id: int) -> SeatInfo:
	if player_id < 0 or player_id >= _seats.size():
		return null
	return _seats[player_id]


func view_for(player_id: int) -> PlayerView:
	return _view if player_id == 0 else null


func is_waiting_for_human() -> bool:
	return _phase == Phase.BIDDING and _current >= 0 and _current < _seats.size() \
			and _seats[_current].is_human()


## Те же правила, что у контроллера (CheatRules), по своему PlayerView.
func cheat_denial(player_id: int, action: CheatAction) -> CheatRules.Denied:
	if player_id != 0 or _seats.is_empty() or not _seats[0].is_human():
		return CheatRules.Denied.NOT_YOUR_TURN
	if _view == null or state != State.IN_MATCH:
		return CheatRules.Denied.WRONG_PHASE
	var n := player_count()
	var known := CheatState.new(n)
	known.sanity[0] = _view.own_sanity
	var window := _view.cheat_window
	if _view.cheat_used:
		known.mark_used(0, Cheat.Kind.LOADED_DIE if window == CheatRules.CheatWindow.ROLL
				else Cheat.Kind.PEEK)
	if window == CheatRules.CheatWindow.CLOSED and _phase == Phase.BIDDING:
		window = CheatRules.CheatWindow.TURN  # чужой ход: ответ — NOT_YOUR_TURN
	# Настоящих чужих кубиков нет — только их количество (для проверки индекса).
	var hands := []
	for id in n:
		var hand := []
		if _phase == Phase.BIDDING:
			hand.resize(_view.dice_counts[id])
		hands.append(hand)
	return CheatRules.check(known, 0, action, window, _current, _view.dice_counts, hands)


func turn_time_left_msec() -> int:
	if _paused:
		return _paused_left
	return -1 if _deadline < 0 else maxi(0, _deadline - _now())


func is_match_paused() -> bool:
	return _paused


func pause_votes() -> Vector2i:
	return _pause_votes


## Своё меню паузы открыто / закрыто — голос хосту.
func request_pause(on: bool) -> void:
	if state != State.IN_MATCH or on == _pause_sent:
		return
	_pause_sent = on
	_send(NetProtocol.Msg.PAUSE, {"on": on})


# --- Команды -------------------------------------------------------------------

func submit_action(player_id: int, action: MatchAction) -> MatchController.Result:
	if state != State.IN_MATCH or _phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	if player_id != 0 or _current != 0 or not _seats[0].is_human():
		return Result.NOT_YOUR_TURN
	if not _view.is_legal(action):
		return Result.ILLEGAL_ACTION
	_send(NetProtocol.Msg.ACTION, {"a": NetCodec.encode_action(action, _frame)})
	return Result.OK


func submit_cheat(player_id: int, action: CheatAction) -> MatchController.Result:
	match cheat_denial(player_id, action):
		CheatRules.Denied.OK:
			pass
		CheatRules.Denied.WRONG_PHASE:
			return Result.WRONG_PHASE
		CheatRules.Denied.NOT_YOUR_TURN:
			return Result.NOT_YOUR_TURN
		_:
			return Result.ILLEGAL_ACTION
	_send(NetProtocol.Msg.CHEAT, {"c": NetCodec.encode_cheat(action, _frame)})
	return Result.OK


func open_cup(player_id: int) -> MatchController.Result:
	return _cup(player_id, true)


func close_cup(player_id: int) -> MatchController.Result:
	return _cup(player_id, false)


func _cup(player_id: int, open: bool) -> MatchController.Result:
	if state != State.IN_MATCH or _phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	if player_id != 0 or not _seats[0].is_human() or not is_active(0) \
			or _view.cup_open == open:
		return Result.ILLEGAL_ACTION
	_send(NetProtocol.Msg.CUP, {"o": open})
	return Result.OK


## «Готов к броску».
func roll(_preset_hands: Array = []) -> void:
	if _phase == Phase.ROLL:
		_send_ready()


## «Готов к следующему раунду».
func next_round() -> void:
	if _phase == Phase.ROUND_END:
		_send_ready()


func _send_ready() -> void:
	if state != State.IN_MATCH or not _seats[0].is_human():
		return
	var key := "%d/%d" % [_phase, round_number]
	if key == _ready_key:
		return
	_ready_key = key
	_send(NetProtocol.Msg.READY, {"ph": _phase, "rn": round_number})


## «Сдаться»: место — боту, матч досматривается.
func surrender() -> void:
	if state == State.IN_MATCH:
		_send(NetProtocol.Msg.LEAVE)


## «Выйти в меню»: место — боту, связь закрыта.
func leave() -> void:
	if state == State.CLOSED:
		return
	if state == State.IN_MATCH:
		_send(NetProtocol.Msg.LEAVE)
	_close()


# --- Геттеры -------------------------------------------------------------------

func _get_phase() -> int:
	return _phase


func _get_round_number() -> int:
	return 0 if _view == null else _view.round_number


func _get_current_player() -> int:
	return _current


func _get_winner_id() -> int:
	return _winner


func _get_dice_counts() -> Array[int]:
	if _view != null:
		return _view.dice_counts
	var counts: Array[int] = []
	for i in _seats.size():
		counts.append(PerudoRules.START_DICE)
	return counts


func _get_round_rules() -> RoundRules:
	return RoundRules.new() if _view == null else _view.round_rules


func _get_options() -> RuleOptions:
	return _options
