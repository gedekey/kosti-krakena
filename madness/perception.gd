class_name Perception
extends RefCounted
## Восприятие своих кубиков (DESIGN.md §4) — общая модель для игрока и ботов.
## Слой «увиденных» кубиков отдельно от реальных: итоги всегда считаются по реальным,
## а PlayerView.own_dice берёт кубики отсюда.
##
## - Сразу после броска чашка открыта и игрок видит правду.
## - Каждое следующее открытие чашки: в Безумии каждый кубик с шансом chance
##   показывает случайную грань (пересчитывается при каждом открытии), без Безумия — правда.
## - Закрытая чашка: остаётся то, что игрок видел при последнем открытии.
## «Правда» — то, что игрок знает о своих кубиках (после «Толкнуть чашку» соседом
## это старая грань, М4). Без нод; RNG — инъекцией.

## Шанс галлюцинации на кубик (тесты и отладка могут подменить).
var chance := MadnessBalance.HALLUCINATION_CHANCE

var _rng: RandomNumberGenerator
## Что игрок видел при последнем открытии (по игрокам, Array[int]).
var _seen: Array = []
## Какие кубики сейчас «врут» (по игрокам, Array[bool]). Только для отладки и тестов.
var _lies: Array = []
var _cup_open: Array[bool] = []


func _init(player_count: int, rng: RandomNumberGenerator) -> void:
	_rng = rng
	for i in player_count:
		_seen.append([] as Array[int])
		_lies.append([] as Array[bool])
		_cup_open.append(false)


## Одно открытие чашки в Безумии: каждый кубик с шансом p_chance — случайная грань.
## Возвращает новый массив, known не меняется.
static func distort(known: Array[int], p_chance: float, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for face in known:
		if rng.randf() < p_chance:
			out.append(rng.randi_range(1, PerudoRules.FACES))
		else:
			out.append(face)
	return out


# --- Жизненный цикл --------------------------------------------------------------

## Начало раунда: кубиков ещё нет, чашки закрыты.
func clear() -> void:
	for id in _seen.size():
		_seen[id] = [] as Array[int]
		_lies[id] = [] as Array[bool]
		_cup_open[id] = false


## Сразу после броска: все видят правду, чашки открыты.
func reset(known_hands: Array) -> void:
	for id in _seen.size():
		var hand: Array[int] = []
		if id < known_hands.size():
			hand.assign(known_hands[id])
		_set_seen(id, hand, hand)
		_cup_open[id] = not hand.is_empty()


# --- Запросы ---------------------------------------------------------------------

func seen(player_id: int) -> Array[int]:
	var out: Array[int] = []
	out.assign(_seen[player_id])
	return out


func is_cup_open(player_id: int) -> bool:
	return _cup_open[player_id]


## Номера кубиков, которые сейчас показывают не то (ОТЛАДКА: игрок этого не знает).
func lying_dice(player_id: int) -> Array[int]:
	var out: Array[int] = []
	var lies: Array = _lies[player_id]
	for i in lies.size():
		if lies[i]:
			out.append(i)
	return out


# --- Изменения -------------------------------------------------------------------

## Открыть чашку. Уже открытая не переоткрывается (false). known — правда об игроке.
func open_cup(player_id: int, known: Array[int], mad: bool) -> bool:
	if _cup_open[player_id]:
		return false
	_cup_open[player_id] = true
	var shown := distort(known, chance, _rng) if mad else known.duplicate()
	_set_seen(player_id, shown, known)
	return true


## Закрыть чашку. Уже закрытая — false.
func close_cup(player_id: int) -> bool:
	if not _cup_open[player_id]:
		return false
	_cup_open[player_id] = false
	return true


## Игрок точно знает, что выпало на этом кубике (например, «Ловкость рук»).
func set_seen_die(player_id: int, die_index: int, face: int) -> void:
	_seen[player_id][die_index] = face
	_lies[player_id][die_index] = false


func _set_seen(player_id: int, shown: Array[int], known: Array[int]) -> void:
	_seen[player_id] = shown
	var lies: Array[bool] = []
	for i in shown.size():
		lies.append(shown[i] != known[i])
	_lies[player_id] = lies
