class_name HostSession
extends LocalSession
## Сетевой матч на хосте (DESIGN.md §8б). Хост считает весь матч обычным MatchController:
## места людей — RemoteAgent, их команды приходят по сети и проверяются тем же
## контроллером. Гость командует только своим местом: место берётся по сетевому id,
## а не из сообщения.
##
## Жизненный цикл:
##   LOBBY    — гости подключаются (рукопожатие: версия, имя, портрет);
##   begin_match(план мест) → READY — гостям ушёл MATCH_START, стол строится;
##   start_match() (стол хоста готов) → IN_MATCH;
##   leave() → CLOSED (гостям — «матч прерван»).
##
## Фильтрация: каждое событие контроллера уходит каждому гостю, которому оно видно
## (NetProtocol.is_visible), вместе со снимком его PlayerView после события. Чужие
## кубики, трюки и Рассудок гостю не уходят никогда.
##
## Темп задаёт хост (update() каждый кадр, часы — инъекцией):
##   бросок — когда все живые люди «готовы» (или вышел таймер хода);
##   ход человека — таймер хода, потом автоход: минимальная ставка, иначе «Ложь!»;
##   ход бота — после паузы BOT_TURN_DELAY_MS;
##   следующий раунд — когда все готовы или прошло ROUND_READY_TIMEOUT_MS.

signal guest_joined(peer_id: int)
signal guest_left(peer_id: int)

enum State { LOBBY, READY, IN_MATCH, CLOSED }

var state := State.LOBBY
## Таймер хода (хост может выключить в лобби).
var timer_enabled := true
## Место хоста: имя и портрет.
var host_seat: SeatInfo
## Сколько входящих сообщений отброшено как недопустимые (тесты, отладка).
var dropped_messages := 0

var _transport: NetTransport
var _clock: Callable
var _version: String
## Принятые гости: peer → SeatInfo (по порядку подключения).
var _guests := {}
## Отклонённые гости: peer → когда рвать связь.
var _kick_at := {}
## Гости за столом: peer → место, peer → SeatFrame.
var _peer_seat := {}
var _frames := {}
## Кто прислал «готов» в текущей фазе (ROLL / ROUND_END): место → true.
var _ready := {}
var _phase_since := 0
var _turn_since := 0
var _bot_rng: RandomNumberGenerator


## clock — Callable без аргументов, возвращает миллисекунды (по умолчанию
## Time.get_ticks_msec). version — для тестов несовпадения версий.
func _init(transport: NetTransport, p_name := "", p_portrait := 0, clock := Callable(),
		version := "") -> void:
	super()
	_transport = transport
	_clock = clock if clock.is_valid() else Callable(Time, &"get_ticks_msec")
	_version = version if version != "" else NetProtocol.game_version()
	host_seat = SeatInfo.host(SeatInfo.clean_name(p_name),
			clampi(p_portrait, 0, NetBalance.PORTRAIT_COUNT - 1))
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_transport.message_received.connect(_on_message)


func _now() -> int:
	return _clock.call()


func is_networked() -> bool:
	return true


## Принятые в лобби гости (по порядку подключения).
func guests() -> Array[SeatInfo]:
	var out: Array[SeatInfo] = []
	for info: SeatInfo in _guests.values():
		out.append(info)
	return out


## Рассадить и разослать гостям MATCH_START. plan: 2..6 мест, plan[0] — хост
## (SeatInfo.Kind.HOST, имя и портрет берутся из host_seat), GUEST — принятые гости
## (peer_id), BOT — персонажи BotRoster (bot_id). Гости вне плана получают отказ.
## Сам матч начнётся, когда стол хоста вызовет start_match().
func begin_match(plan: Array[SeatInfo], p_options: RuleOptions, rng: RandomNumberGenerator,
		p_timer_enabled := true) -> bool:
	if state != State.LOBBY or not _plan_ok(plan):
		return false
	var seats: Array[SeatInfo] = []
	var agents: Array[MatchAgent] = []
	for entry in plan:
		match entry.kind:
			SeatInfo.Kind.HOST:
				seats.append(host_seat.duplicate_info())
				agents.append(RemoteAgent.new(NetTransport.HOST_ID))
			SeatInfo.Kind.GUEST:
				seats.append((_guests[entry.peer_id] as SeatInfo).duplicate_info())
				agents.append(RemoteAgent.new(entry.peer_id))
			SeatInfo.Kind.BOT:
				seats.append(SeatInfo.bot(entry.bot_id))
				agents.append(BotAgent.new(BotRoster.by_id(entry.bot_id), _child_rng(rng)))
	timer_enabled = p_timer_enabled
	_bot_rng = _child_rng(rng)
	_attach(MatchController.new(agents, p_options, _child_rng(rng)), 0, seats)

	for peer: int in _guests.keys():
		var seat_id := _seat_of_peer(seats, peer)
		if seat_id < 0:
			_reject(peer, NetProtocol.Reject.IN_PROGRESS)
			continue
		_peer_seat[peer] = seat_id
		_frames[peer] = SeatFrame.new(seat_id, seats.size())
		_transport.send(peer, NetProtocol.make(NetProtocol.Msg.MATCH_START, {
			"seats": _seats_wire(_frames[peer]),
			"opt": NetCodec.encode_options(p_options),
			"timer": timer_enabled,
		}))
	_guests.clear()
	state = State.READY
	return true


func _plan_ok(plan: Array[SeatInfo]) -> bool:
	if plan.size() < MatchController.MIN_PLAYERS or plan.size() > MatchController.MAX_PLAYERS:
		return false
	if plan[0].kind != SeatInfo.Kind.HOST:
		return false
	var used := {}
	for i in range(1, plan.size()):
		var entry := plan[i]
		match entry.kind:
			SeatInfo.Kind.GUEST:
				if not _guests.has(entry.peer_id) or used.has(entry.peer_id):
					return false
				used[entry.peer_id] = true
			SeatInfo.Kind.BOT:
				if BotRoster.by_id(entry.bot_id) == null:
					return false
			_:
				return false
	return true


static func _seat_of_peer(seats: Array[SeatInfo], peer: int) -> int:
	for i in seats.size():
		if seats[i].kind == SeatInfo.Kind.GUEST and seats[i].peer_id == peer:
			return i
	return -1


func _seats_wire(frame: SeatFrame) -> Array:
	var out := []
	for local in _seats.size():
		out.append(_seats[frame.to_global(local)].to_wire())
	return out


static func _child_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var child := RandomNumberGenerator.new()
	child.seed = rng.randi()
	return child


# --- Цикл ----------------------------------------------------------------------

func update() -> void:
	if state == State.CLOSED:
		return
	_transport.poll()
	_kick_due()
	if state == State.IN_MATCH:
		_tick()


func _tick() -> void:
	var now := _now()
	match controller.phase:
		Phase.ROLL:
			var humans := _humans_in_play()
			if humans.is_empty():
				if now - _phase_since >= NetBalance.AUTO_ROLL_DELAY_MS:
					controller.roll()
			elif _all_ready(humans) or (timer_enabled
					and now - _phase_since >= NetBalance.TURN_TIME_MS):
				controller.roll()
		Phase.BIDDING:
			var cur := controller.current_player
			if controller.agent(cur).is_human():
				if timer_enabled and now - _turn_since >= NetBalance.TURN_TIME_MS:
					_auto_move(cur)
			elif now - _turn_since >= NetBalance.BOT_TURN_DELAY_MS:
				controller.play_bot_turn()
		Phase.ROUND_END:
			var humans := _humans_in_play()
			if humans.is_empty():
				if now - _phase_since >= NetBalance.AUTO_ROUND_DELAY_MS:
					controller.next_round()
			elif _all_ready(humans) or now - _phase_since >= NetBalance.ROUND_READY_TIMEOUT_MS:
				controller.next_round()


## Места живых (с кубиками) людей.
func _humans_in_play() -> Array[int]:
	var out: Array[int] = []
	for id in controller.player_count():
		if controller.agent(id).is_human() and controller.is_active(id):
			out.append(id)
	return out


func _all_ready(humans: Array[int]) -> bool:
	for id in humans:
		if not _ready.has(id):
			return false
	return true


## Время вышло: минимальная допустимая ставка, а если ставить некуда — «Ложь!».
func _auto_move(player_id: int) -> void:
	var lowest := controller.view_for(player_id).lowest_bid()
	var action := MatchAction.dudo() if lowest == null \
			else MatchAction.new(MatchAction.Kind.BID, lowest)
	if controller.submit_action(player_id, action) != Result.OK:
		push_warning("Auto move rejected for %d: %s" % [player_id, action])


func _mark_ready(player_id: int, p_phase: int, p_round: int) -> void:
	if p_round != controller.round_number or p_phase != controller.phase:
		return
	if p_phase == Phase.ROLL or p_phase == Phase.ROUND_END:
		_ready[player_id] = true


func turn_time_left_msec() -> int:
	if state != State.IN_MATCH or not timer_enabled:
		return -1
	match controller.phase:
		Phase.ROLL:
			return maxi(0, NetBalance.TURN_TIME_MS - (_now() - _phase_since))
		Phase.BIDDING:
			if controller.agent(controller.current_player).is_human():
				return maxi(0, NetBalance.TURN_TIME_MS - (_now() - _turn_since))
	return -1


# --- События контроллера -------------------------------------------------------

func _on_controller_event(sig_name: StringName, args: Array) -> void:
	match sig_name:
		&"phase_changed":
			_phase_since = _now()
			_ready.clear()
		&"turn_started":
			_turn_since = _now()
	# Сначала гостям: если стол хоста в обработчике пошлёт команду, порядок не собьётся.
	_broadcast_event(sig_name, args)
	_emit_visible(sig_name, args)


func _broadcast_event(sig_name: StringName, args: Array) -> void:
	var index := NetProtocol.event_index(sig_name)
	if index < 0:
		return
	var spec: String = NetProtocol.EVENTS[index][1]
	var time_left := turn_time_left_msec()
	for peer: int in _peer_seat:
		var seat_id: int = _peer_seat[peer]
		if not NetProtocol.is_visible(sig_name, args, seat_id):
			continue
		var frame: SeatFrame = _frames[peer]
		_transport.send(peer, NetProtocol.make(NetProtocol.Msg.EVENT, {
			"e": index,
			"a": NetCodec.encode_args(spec, args, frame),
			"s": NetCodec.encode_snapshot(controller.view_for(seat_id), controller.phase,
					controller.current_player, controller.winner_id, time_left, frame),
		}))


# --- Сообщения гостей ----------------------------------------------------------

func _on_message(peer: int, msg: Dictionary) -> void:
	var type := NetProtocol.type_of(msg)
	if type < 0 or _kick_at.has(peer):
		dropped_messages += 1
		return
	if type == NetProtocol.Msg.HELLO:
		_on_hello(peer, msg)
		return
	if state != State.IN_MATCH or not _peer_seat.has(peer):
		dropped_messages += 1
		return
	var seat_id: int = _peer_seat[peer]
	if type == NetProtocol.Msg.LEAVE:
		_replace_seat(seat_id)
		return
	if not controller.agent(seat_id).is_human():
		dropped_messages += 1
		return
	var frame: SeatFrame = _frames[peer]
	match type:
		NetProtocol.Msg.ACTION:
			var action := NetCodec.decode_action(msg.get("a"), frame)
			if action == null:
				dropped_messages += 1
			else:
				_reply(peer, controller.submit_action(seat_id, action))
		NetProtocol.Msg.CHEAT:
			var cheat := NetCodec.decode_cheat(msg.get("c"), frame)
			if cheat == null:
				dropped_messages += 1
			else:
				_reply(peer, controller.submit_cheat(seat_id, cheat))
		NetProtocol.Msg.CUP:
			var open: Variant = msg.get("o")
			if typeof(open) != TYPE_BOOL:
				dropped_messages += 1
			elif open:
				_reply(peer, controller.open_cup(seat_id))
			else:
				_reply(peer, controller.close_cup(seat_id))
		NetProtocol.Msg.READY:
			var ph: Variant = msg.get("ph")
			var rn: Variant = msg.get("rn")
			if typeof(ph) != TYPE_INT or typeof(rn) != TYPE_INT:
				dropped_messages += 1
			else:
				_mark_ready(seat_id, ph, rn)
		_:
			dropped_messages += 1


func _reply(peer: int, result: MatchController.Result) -> void:
	if result != Result.OK:
		_transport.send(peer, NetProtocol.make(NetProtocol.Msg.NACK, {"r": result}))


func _on_hello(peer: int, msg: Dictionary) -> void:
	if _guests.has(peer) or _peer_seat.has(peer):
		dropped_messages += 1
		return
	var ver: Variant = msg.get("ver")
	var raw_name: Variant = msg.get("name")
	var portrait: Variant = msg.get("portrait")
	if typeof(ver) != TYPE_STRING:
		_reject(peer, NetProtocol.Reject.BAD_HELLO)
	elif ver != _version:
		_reject(peer, NetProtocol.Reject.VERSION_MISMATCH)
	elif typeof(raw_name) != TYPE_STRING or raw_name.length() > NetBalance.MAX_NAME_LENGTH * 4 \
			or typeof(portrait) != TYPE_INT or portrait < 0 \
			or portrait >= NetBalance.PORTRAIT_COUNT:
		_reject(peer, NetProtocol.Reject.BAD_HELLO)
	elif state != State.LOBBY:
		_reject(peer, NetProtocol.Reject.IN_PROGRESS)
	elif _guests.size() >= MatchController.MAX_PLAYERS - 1:
		_reject(peer, NetProtocol.Reject.FULL)
	else:
		_guests[peer] = SeatInfo.guest(peer, SeatInfo.clean_name(raw_name), portrait)
		_transport.send(peer, NetProtocol.make(NetProtocol.Msg.WELCOME))
		guest_joined.emit(peer)


## Отказ с причиной; связь рвётся чуть позже, чтобы отказ успел дойти.
func _reject(peer: int, reason: NetProtocol.Reject) -> void:
	_transport.send(peer, NetProtocol.make(NetProtocol.Msg.REJECT, {"r": reason, "ver": _version}))
	_kick_at[peer] = _now() + NetBalance.REJECT_KICK_DELAY_MS


func _kick_due() -> void:
	var now := _now()
	for peer: int in _kick_at.keys():
		if now >= _kick_at[peer]:
			_kick_at.erase(peer)
			_transport.kick(peer)


func _on_peer_disconnected(peer: int) -> void:
	_kick_at.erase(peer)
	if _guests.has(peer):
		_guests.erase(peer)
		guest_left.emit(peer)
	if _peer_seat.has(peer):
		var seat_id: int = _peer_seat[peer]
		_peer_seat.erase(peer)
		_frames.erase(peer)
		_replace_seat(seat_id)


## Место человека — нейтральному боту (кубики и Рассудок остаются при месте).
func _replace_seat(seat_id: int) -> void:
	var agent := controller.agent(seat_id) as RemoteAgent
	if agent == null or agent.is_replaced():
		return
	agent.replace_with_bot(_child_rng(_bot_rng))
	_seats[seat_id].replaced = true
	_ready.erase(seat_id)
	if controller.phase == Phase.BIDDING and controller.current_player == seat_id:
		_turn_since = _now()
	for peer: int in _peer_seat:
		var frame: SeatFrame = _frames[peer]
		_transport.send(peer, NetProtocol.make(NetProtocol.Msg.SEAT_BOT,
				{"p": frame.to_local(seat_id)}))
	seat_replaced.emit(seat_id)


# --- Команды своего игрока -----------------------------------------------------

## Стол хоста готов — матч начинается.
func start_match(first_player := PerudoRules.NO_PLAYER) -> void:
	if state != State.READY:
		return
	state = State.IN_MATCH
	_phase_since = _now()
	controller.start_match(first_player)


## «Готов к броску».
func roll(_preset_hands: Array = []) -> void:
	if state == State.IN_MATCH and _controls_local():
		_mark_ready(_local, Phase.ROLL, controller.round_number)


## «Готов к следующему раунду».
func next_round() -> void:
	if state == State.IN_MATCH and _controls_local():
		_mark_ready(_local, Phase.ROUND_END, controller.round_number)


func advance_auto() -> bool:
	return false


func surrender() -> void:
	if state == State.IN_MATCH or state == State.READY:
		_replace_seat(_local)


## Хост уходит — матч прерван у всех.
func leave() -> void:
	if state == State.CLOSED:
		return
	var abort := NetProtocol.make(NetProtocol.Msg.ABORT, {"r": NetProtocol.Abort.HOST_LEFT})
	for peer: int in _guests:
		_transport.send(peer, abort)
	for peer: int in _peer_seat:
		_transport.send(peer, abort)
	state = State.CLOSED
	_transport.close()
