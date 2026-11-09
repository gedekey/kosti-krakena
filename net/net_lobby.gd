class_name NetLobby
extends RefCounted
## Лобби сетевой игры на хосте (М19, DESIGN.md §8б): 2–6 мест, на каждом человек или бот.
## Место 0 — хост. Гость при входе садится на первое место с ботом; если ботов нет и мест
## меньше шести — место добавляется. Гость ушёл — на его месте снова «случайный» бот.
## Бот — персонаж (BotRoster) или «случайный» (RANDOM_BOT). Перед матчем случайные
## заменяются разными персонажами, которых ещё нет за столом.
## Без нод и сети: HostSession рассылает места гостям.

const RANDOM_BOT := &""
## Мест за столом в новом лобби (как на экране выбора соперников: игрок + 3 бота).
const DEFAULT_SEATS := 4

var seats: Array[SeatInfo] = []


func _init(host_seat: SeatInfo = null, count := DEFAULT_SEATS) -> void:
	seats.append(host_seat if host_seat != null else SeatInfo.host("", 0))
	set_seat_count(count)


func seat_count() -> int:
	return seats.size()


## Сколько мест за людьми (хост + гости).
func humans() -> int:
	var n := 0
	for s in seats:
		if s.kind != SeatInfo.Kind.BOT:
			n += 1
	return n


func min_seats() -> int:
	return maxi(MatchController.MIN_PLAYERS, humans())


func max_seats() -> int:
	return MatchController.MAX_PLAYERS


## Сколько мест: лишние места ботов убираются с конца, новые — «случайные» боты.
func set_seat_count(count: int) -> bool:
	count = clampi(count, min_seats(), max_seats())
	var changed := count != seats.size()
	while seats.size() < count:
		seats.append(SeatInfo.bot(RANDOM_BOT))
	while seats.size() > count:
		seats.remove_at(_last_bot())
	return changed


func _last_bot() -> int:
	for i in range(seats.size() - 1, 0, -1):
		if seats[i].kind == SeatInfo.Kind.BOT:
			return i
	return -1


## Гость садится за стол. Номер места или −1 — мест нет.
func add_guest(info: SeatInfo) -> int:
	for i in range(1, seats.size()):
		if seats[i].kind == SeatInfo.Kind.BOT:
			seats[i] = info
			return i
	if seats.size() >= max_seats():
		return -1
	seats.append(info)
	return seats.size() - 1


## Гость ушёл — его место снова за «случайным» ботом.
func remove_guest(peer_id: int) -> bool:
	var i := seat_of_peer(peer_id)
	if i < 0:
		return false
	seats[i] = SeatInfo.bot(RANDOM_BOT)
	return true


func seat_of_peer(peer_id: int) -> int:
	for i in range(1, seats.size()):
		if seats[i].kind == SeatInfo.Kind.GUEST and seats[i].peer_id == peer_id:
			return i
	return -1


## Варианты бота: «случайный» и все персонажи.
static func bot_choices() -> Array[StringName]:
	var out: Array[StringName] = [RANDOM_BOT]
	for p in BotRoster.all():
		out.append(p.id)
	return out


## Сменить бота на месте на следующего (delta = ±1) варианта, которого нет на других
## местах («случайный» можно ставить сколько угодно).
func cycle_bot(index: int, delta: int) -> bool:
	if index <= 0 or index >= seats.size() or seats[index].kind != SeatInfo.Kind.BOT:
		return false
	var choices := bot_choices()
	var at := maxi(choices.find(seats[index].bot_id), 0)
	for step in choices.size():
		at = posmod(at + signi(delta), choices.size())
		var id := choices[at]
		if id == RANDOM_BOT or not _bot_taken(id, index):
			seats[index] = SeatInfo.bot(id)
			return true
	return false


func _bot_taken(id: StringName, except: int) -> bool:
	for i in seats.size():
		if i != except and seats[i].kind == SeatInfo.Kind.BOT and seats[i].bot_id == id:
			return true
	return false


## План мест для HostSession.begin_match: копии мест, случайные боты — разные
## персонажи, которых ещё нет за столом.
func resolve_plan(rng: RandomNumberGenerator) -> Array[SeatInfo]:
	var free: Array[StringName] = []
	for p in BotRoster.all():
		if not _bot_taken(p.id, -1):
			free.append(p.id)
	var plan: Array[SeatInfo] = []
	for s in seats:
		if s.kind == SeatInfo.Kind.BOT and s.bot_id == RANDOM_BOT:
			plan.append(SeatInfo.bot(free.pop_at(rng.randi_range(0, free.size() - 1))))
		else:
			plan.append(s.duplicate_info())
	return plan
