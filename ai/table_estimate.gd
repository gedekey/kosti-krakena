class_name TableEstimate
extends RefCounted
## Оценка стола глазами одного игрока: свои кубики известны точно, чужие — распределение.
## Строится только из PlayerView (DESIGN.md §5: боты честны в информации).
##
## «Чтение ставок» (hint_weight): если соперник в этом раунде ставил на грань,
## с вероятностью hint_weight считаем, что одна из его костей точно её показывает.
## 0 — ставки соперников игнорируются, 1 — им полностью верят.

var _own_dice: Array[int] = []
var _ones_wild: bool
## Соперники с кубиками: [id, количество кубиков].
var _opponents: Array = []
## id соперника → { грань: true } — грани, на которые он ставил в этом раунде.
var _hints := {}
var _hint_weight: float
## Кэш распределений по граням.
var _pmf_cache := {}


func _init(view: PlayerView, hint_weight := 0.0) -> void:
	_own_dice = view.own_dice.duplicate()
	_ones_wild = view.round_rules.ones_wild()
	_hint_weight = clampf(hint_weight, 0.0, 1.0)
	for id in view.dice_counts.size():
		if id != view.player_id and view.dice_counts[id] > 0:
			_opponents.append([id, view.dice_counts[id]])
	for entry in view.bid_history:
		if entry.player_id == view.player_id:
			continue
		if not _hints.has(entry.player_id):
			_hints[entry.player_id] = {}
		_hints[entry.player_id][entry.bid.face] = true


func own_count(face: int) -> int:
	return PerudoRules.count_face(_own_dice, face, _ones_wild)


## Распределение числа совпадений с гранью среди чужих кубиков.
func unknown_pmf(face: int) -> PackedFloat64Array:
	if _pmf_cache.has(face):
		return _pmf_cache[face]
	var p := BidMath.match_chance(face, _ones_wild)
	var total := PackedFloat64Array([1.0])
	for opp in _opponents:
		var dist := BidMath.binomial(opp[1], p)
		if _hint_weight > 0.0 and _is_hinted(opp[0], face):
			var hinted := BidMath.shift(BidMath.binomial(opp[1] - 1, p), 1)
			dist = BidMath.mix(dist, hinted, _hint_weight)
		total = BidMath.convolve(total, dist)
	_pmf_cache[face] = total
	return total


## P(на столе как минимум quantity кубиков грани face).
func p_at_least(face: int, quantity: int) -> float:
	return BidMath.at_least(unknown_pmf(face), quantity - own_count(face))


func p_exactly(face: int, quantity: int) -> float:
	return BidMath.exactly(unknown_pmf(face), quantity - own_count(face))


func p_holds(bid: Bid) -> float:
	return p_at_least(bid.face, bid.quantity)


func p_exact(bid: Bid) -> float:
	return p_exactly(bid.face, bid.quantity)


func expected_count(face: int) -> float:
	return own_count(face) + BidMath.expected(unknown_pmf(face))


func _is_hinted(player_id: int, face: int) -> bool:
	if not _hints.has(player_id):
		return false
	var faces: Dictionary = _hints[player_id]
	return faces.has(face) or (_ones_wild and faces.has(PerudoRules.JOKER_FACE))
