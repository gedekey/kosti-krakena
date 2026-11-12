class_name TableEstimate
extends RefCounted
## Оценка стола глазами одного игрока: свои кубики известны точно, чужие — распределение.
## Строится только из PlayerView (DESIGN.md §5: боты честны в информации).
##
## «Чтение ставок» (hint_weight): если соперник в этом раунде ставил на грань,
## с вероятностью hint_weight считаем, что одна из его костей точно её показывает.
## 0 — ставки соперников игнорируются, 1 — им полностью верят.
##
## Знания от своих трюков (М6, PlayerView.cheat_outcomes и sleeve_dice):
##   - «Подглядеть»: подсмотренный кубик соседа известен точно;
##   - «Шёпот Бездны»: число кубиков грани у остальных известно точно;
##   - «Кубик в рукаве»: свой кубик из рукава считается как свой.
##
## own_trust (Безумие, М6): насколько бот верит каждому своему увиденному кубику.
## 1 — верит полностью; меньше — «увиденный кубик настоящий с шансом own_trust,
## иначе случайный» (MadnessBalance: при шансе галлюцинации h честная поправка — 1 − h).

var _own_dice: Array[int] = []
## Кубики, известные точно (рукав; при own_trust = 1 — и чашка).
var _certain_dice: Array[int] = []
var _own_trust := 1.0
var _ones_wild: bool
## М23: грань прилива (джокер вместе с единицами) или RoundRules.NO_TIDE.
var _tide: int
## Соперники с кубиками: [id, количество кубиков].
var _opponents: Array = []
## id соперника → { грань: true } — грани, на которые он ставил в этом раунде.
var _hints := {}
var _hint_weight: float
## id соперника → { индекс кубика: грань } — подсмотренные кубики.
var _peeked := {}
## грань → сколько их у остальных («Шёпот Бездны», последний ответ).
var _whispers := {}
## Кэш распределений по граням.
var _pmf_cache := {}
var _total_cache := {}


## own_dice_override — если задан, вместо view.own_dice (тесты, модели восприятия).
func _init(view: PlayerView, hint_weight := 0.0, own_trust := 1.0,
		own_dice_override: Variant = null) -> void:
	if own_dice_override == null:
		_own_dice = view.own_dice.duplicate()
	else:
		_own_dice.assign(own_dice_override)
	_own_trust = clampf(own_trust, 0.0, 1.0)
	_certain_dice.assign(view.sleeve_dice)
	if _own_trust >= 1.0:
		_certain_dice.append_array(_own_dice)
	_ones_wild = view.round_rules.ones_wild()
	_tide = view.round_rules.tide()
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
	for outcome in view.cheat_outcomes:
		if outcome.failed:
			continue
		match outcome.action.kind:
			Cheat.Kind.PEEK:
				var target := outcome.action.target_id
				if not _peeked.has(target):
					_peeked[target] = {}
				_peeked[target][outcome.action.die_index] = outcome.peeked_face
			Cheat.Kind.ABYSS_WHISPER:
				_whispers[outcome.action.face] = outcome.whisper_count


## Сколько кубиков грани у бота точно (с джокерами).
func own_count(face: int) -> int:
	return PerudoRules.count_face(_certain_dice, face, _ones_wild, _tide)


func knows_whisper(face: int) -> bool:
	return _whispers.has(face)


## Подсмотрен ли кубик соседа.
func is_peeked(player_id: int, die_index: int) -> bool:
	return _peeked.has(player_id) and _peeked[player_id].has(die_index)


## Распределение числа совпадений с гранью среди чужих кубиков.
func unknown_pmf(face: int) -> PackedFloat64Array:
	if _pmf_cache.has(face):
		return _pmf_cache[face]
	var total := PackedFloat64Array([1.0])
	if _whispers.has(face):
		total = BidMath.shift(total, _whispers[face])
	else:
		var p := BidMath.match_chance(face, _ones_wild, _tide)
		for opp in _opponents:
			total = BidMath.convolve(total, _opponent_pmf(opp[0], opp[1], face, p))
	_pmf_cache[face] = total
	return total


## P(на столе как минимум quantity кубиков грани face).
func p_at_least(face: int, quantity: int) -> float:
	return BidMath.at_least(_uncertain_pmf(face), quantity - own_count(face))


func p_exactly(face: int, quantity: int) -> float:
	return BidMath.exactly(_uncertain_pmf(face), quantity - own_count(face))


func p_holds(bid: Bid) -> float:
	return p_at_least(bid.face, bid.quantity)


func p_exact(bid: Bid) -> float:
	return p_exactly(bid.face, bid.quantity)


func expected_count(face: int) -> float:
	return own_count(face) + BidMath.expected(_uncertain_pmf(face))


# --- Внутреннее ----------------------------------------------------------------

func _opponent_pmf(id: int, count: int, face: int, p: float) -> PackedFloat64Array:
	var known: Dictionary = _peeked.get(id, {})
	var known_n := 0
	var matches := 0
	for index in known:
		if index < count:
			known_n += 1
			if PerudoRules.count_face([known[index]], face, _ones_wild, _tide) > 0:
				matches += 1
	var hidden := count - known_n
	var dist := BidMath.shift(BidMath.binomial(hidden, p), matches)
	# Подсмотренная кость уже «объясняет» ставку соперника — подсказка не нужна.
	if _hint_weight > 0.0 and hidden > 0 and matches == 0 and _is_hinted(id, face):
		var hinted := BidMath.shift(BidMath.binomial(hidden - 1, p), 1)
		dist = BidMath.mix(dist, hinted, _hint_weight)
	return dist


## Всё, что не известно точно: чужие кубики + (в Безумии) свои увиденные.
func _uncertain_pmf(face: int) -> PackedFloat64Array:
	if _own_trust >= 1.0:
		return unknown_pmf(face)
	if _total_cache.has(face):
		return _total_cache[face]
	var total := unknown_pmf(face)
	var base := BidMath.match_chance(face, _ones_wild, _tide)
	for die in _own_dice:
		var seen := 1.0 if PerudoRules.count_face([die], face, _ones_wild, _tide) > 0 else 0.0
		var p := _own_trust * seen + (1.0 - _own_trust) * base
		total = BidMath.convolve(total, BidMath.binomial(1, p))
	_total_cache[face] = total
	return total


func _is_hinted(player_id: int, face: int) -> bool:
	if not _hints.has(player_id):
		return false
	var faces: Dictionary = _hints[player_id]
	if faces.has(face) or (_ones_wild and faces.has(PerudoRules.JOKER_FACE)):
		return true
	return _tide != RoundRules.NO_TIDE and faces.has(_tide)
