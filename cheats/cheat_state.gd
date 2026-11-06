class_name CheatState
extends RefCounted
## Состояние жульничества в матче: Рассудок, журнал раунда, улики, кубики в рукаве,
## ограничения «1 трюк за ход / за фазу броска». Без нод; контроллер матча владеет им
## и сообщает о начале раунда и хода.

## Как бросается риск трюка. Не NORMAL — только для тестов и отладочного экрана.
enum RiskMode {
	NORMAL,
	NEVER_FAIL,
	## Проваливается любой трюк с риском > 0 («Шёпот Бездны» не проваливается никогда).
	ALWAYS_FAIL,
}

var risk_mode := RiskMode.NORMAL
## Шанс ложной улики за честный ход (тесты и отладка могут подменить).
var false_evidence_chance := CheatBalance.FALSE_EVIDENCE_CHANCE
## Шанс улики от успешного трюка (тесты и отладка могут подменить).
var trick_evidence_chance := CheatBalance.TRICK_EVIDENCE_CHANCE

## Рассудок игроков (СЕКРЕТНО: каждый знает только свой). 0 — Безумие до конца матча.
var sanity: Array[int] = []
## Журнал раунда: все трюки-жульничества (включая проваленные). Без «Шёпота Бездны».
var journal: Array[CheatOutcome] = []
## Улики за раунд по игрокам (публично; истинные и ложные неразличимы).
var evidence: Array[int] = []
## Кубики в рукаве на этот раунд по игрокам (участвуют в подсчёте).
var sleeve: Array = []
## Итоги своих успешных трюков за раунд по игрокам (то, что игрок узнал).
var outcomes: Array = []
## Заказанные «Утяжелённые кости» до броска: player_id → грань.
var loaded: Dictionary = {}

var _used_in_roll: Array[bool] = []
var _used_this_turn := false
var _honest_this_turn := true


func _init(player_count: int) -> void:
	for i in player_count:
		sanity.append(CheatBalance.START_SANITY)
		evidence.append(0)
		sleeve.append([] as Array[int])
		outcomes.append([] as Array[CheatOutcome])
		_used_in_roll.append(false)


# --- Жизненный цикл --------------------------------------------------------------

func begin_round() -> void:
	journal.clear()
	loaded.clear()
	for i in sanity.size():
		evidence[i] = 0
		sleeve[i] = [] as Array[int]
		outcomes[i] = [] as Array[CheatOutcome]
		_used_in_roll[i] = false
	begin_turn()


func begin_turn() -> void:
	_used_this_turn = false
	_honest_this_turn = true


# --- Запросы ---------------------------------------------------------------------

func is_mad(player_id: int) -> bool:
	return sanity[player_id] <= 0


func used_this_turn() -> bool:
	return _used_this_turn


## Текущий игрок не жульничал в этот ход («Шёпот Бездны» — не жульничество).
func honest_this_turn() -> bool:
	return _honest_this_turn


func used_in_roll(player_id: int) -> bool:
	return _used_in_roll[player_id]


## Жульничал ли игрок в текущем раунде — это проверяет обвинение.
func cheated_this_round(player_id: int) -> bool:
	for entry in journal:
		if entry.player_id == player_id:
			return true
	return false


## Кто жульничал в этом раунде (по порядку первого трюка).
func cheaters_this_round() -> Array[int]:
	var ids: Array[int] = []
	for entry in journal:
		if not ids.has(entry.player_id):
			ids.append(entry.player_id)
	return ids


# --- Изменения -------------------------------------------------------------------

## Потратить Рассудок. Возвращает фактическое изменение (≤ 0).
func spend(player_id: int, amount: int) -> int:
	var before := sanity[player_id]
	sanity[player_id] = maxi(0, before - amount)
	return sanity[player_id] - before


## Отметить использование трюка (до броска риска: провал тоже тратит попытку).
func mark_used(player_id: int, kind: Cheat.Kind) -> void:
	if Cheat.is_roll_phase(kind):
		_used_in_roll[player_id] = true
	else:
		_used_this_turn = true
		if Cheat.is_cheating(kind):
			_honest_this_turn = false


## Записать итог трюка: в журнал (если это жульничество) и в знания жулика (если успех).
func record(outcome: CheatOutcome) -> void:
	if Cheat.is_cheating(outcome.action.kind):
		journal.append(outcome)
	if not outcome.failed:
		outcomes[outcome.player_id].append(outcome)


func add_evidence(player_id: int) -> void:
	evidence[player_id] += 1
