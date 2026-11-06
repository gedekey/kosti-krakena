class_name Suspicion
extends RefCounted
## Подозрения бота (М6): насколько он верит, что соперник жульничал в текущем раунде.
## Только публичное из PlayerView: улики у портретов, число ходов соперника, Безумие.
##
## Модель — Байес по уликам раунда:
##   честный за действие показывает ложную улику с шансом CheatBalance.FALSE_EVIDENCE_CHANCE,
##   жулик — с шансом AiBalance.CHEATER_EVIDENCE_RATE.
## Априор — AiBalance.CHEAT_PRIOR, поднятый «лишними» уликами прошлых раундов
## (сверх ожидаемых ложных), которые бот помнит с весом evidence_memory за раунд.
## Кто был в Безумии с начала раунда, жульничать не мог — его улики ложные.

var _memory: float
var _round := -1
## Последнее, что бот видел в текущем раунде: улики и действия по игрокам.
var _evidence: Array[int] = []
var _actions: Array[int] = []
## Был ли игрок в Безумии, когда бот впервые увидел текущий раунд.
var _mad_at_start: Array[bool] = []
## Накопленные «лишние» улики прошлых раундов (с затуханием).
var _excess: Array[float] = []


func _init(evidence_memory: float) -> void:
	_memory = clampf(evidence_memory, 0.0, 1.0)


## Учесть то, что видно сейчас. Вызывать при каждом взгляде на стол.
func observe(view: PlayerView) -> void:
	var n := view.dice_counts.size()
	while _excess.size() < n:
		_excess.append(0.0)
		_evidence.append(0)
		_actions.append(0)
		_mad_at_start.append(false)
	if view.round_number != _round:
		_fold_round()
		_round = view.round_number
		for id in n:
			_mad_at_start[id] = id < view.mad.size() and view.mad[id]
	var actions := _count_actions(view)
	for id in n:
		if id < view.evidence.size():
			_evidence[id] = view.evidence[id]
		_actions[id] = actions[id]


## Вера в то, что игрок жульничал в текущем раунде (0..1).
func belief(player_id: int) -> float:
	if player_id < 0 or player_id >= _excess.size() or _mad_at_start[player_id]:
		return 0.0
	var prior := prior_for(player_id)
	var e := _evidence[player_id]
	var a := maxi(_actions[player_id], e)
	var l_cheater := _binomial_pmf(a, AiBalance.CHEATER_EVIDENCE_RATE, e)
	var l_honest := _binomial_pmf(a, CheatBalance.FALSE_EVIDENCE_CHANCE, e)
	var num := prior * l_cheater
	var den := num + (1.0 - prior) * l_honest
	return 0.0 if den <= 0.0 else num / den


## Априор с учётом памяти о прошлых раундах.
func prior_for(player_id: int) -> float:
	return clampf(AiBalance.CHEAT_PRIOR + AiBalance.PRIOR_PER_EXCESS_EVIDENCE * _excess[player_id],
			AiBalance.PRIOR_MIN, AiBalance.PRIOR_MAX)


## «Лишние» улики прошлых раундов (для отладки и тестов).
func excess_evidence(player_id: int) -> float:
	return _excess[player_id] if player_id < _excess.size() else 0.0


# --- Внутреннее ----------------------------------------------------------------

func _fold_round() -> void:
	if _round < 0:
		return
	for id in _excess.size():
		var expected_false := CheatBalance.FALSE_EVIDENCE_CHANCE * _actions[id]
		var excess := _evidence[id] - expected_false
		if _mad_at_start[id]:
			excess = 0.0
		_excess[id] = _excess[id] * _memory + excess * _memory
		_evidence[id] = 0
		_actions[id] = 0


## Действия игроков в раунде: улика показывается при действии, а до вскрытия
## действие — это ставка.
static func _count_actions(view: PlayerView) -> Array[int]:
	var out: Array[int] = []
	out.resize(view.dice_counts.size())
	for entry in view.bid_history:
		if entry.player_id < out.size():
			out[entry.player_id] += 1
	return out


static func _binomial_pmf(n: int, p: float, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	return BidMath.binomial(n, p)[k]
