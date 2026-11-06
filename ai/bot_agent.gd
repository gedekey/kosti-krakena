class_name BotAgent
extends MatchAgent
## Бот честной игры (М3): вероятностная оценка стола + характер.
## Знает только PlayerView. RNG — инъекцией.
##
## Ход:
##   1. Оценить стол (TableEstimate) с поправкой на «чтение ставок» характера.
##   2. Первая ставка раунда — самая высокая, в которой бот уверен на opening_confidence.
##   3. Иначе: «Точно!», если шанс ровного попадания высок; «Ложь!», если ставке
##      верится меньше порога и меньше, чем лучшему повышению; иначе — повышение
##      (лучшее по вероятности или, с шансом блефа, случайное «терпимое»).

## Повышение рассматривается от минимального количества до минимального + столько.
const MAX_RAISE_JUMP := 2

var personality: BotPersonality
var _rng: RandomNumberGenerator


class Candidate:
	var bid: Bid
	## Вера бота в ставку (с шумом).
	var p: float

	func _init(p_bid: Bid, p_p: float) -> void:
		bid = p_bid
		p = p_p


func _init(p_personality: BotPersonality, rng: RandomNumberGenerator) -> void:
	personality = p_personality
	_rng = rng


func choose_action(view: PlayerView) -> MatchAction:
	var estimate := TableEstimate.new(view, personality.bid_reading)
	var candidates := _candidates(view, estimate)
	if view.current_bid == null:
		return _opening(candidates)
	return _respond(view, estimate, candidates)


# --- Решения -------------------------------------------------------------------

func _opening(candidates: Array[Candidate]) -> MatchAction:
	var pool: Array = candidates
	if _rng.randf() < personality.bluff_chance:
		# Блеф на открытии — ставка на случайную грань, не обязательно свою.
		var faces: Array[int] = []
		for c in candidates:
			if not faces.has(c.bid.face):
				faces.append(c.bid.face)
		var face := faces[_rng.randi_range(0, faces.size() - 1)]
		pool = candidates.filter(func(c: Candidate) -> bool: return c.bid.face == face)
	var confident := pool.filter(
			func(c: Candidate) -> bool: return c.p >= personality.opening_confidence)
	if confident.is_empty():
		return _bid_action(_most_likely(pool))
	var chosen: Candidate = confident[0]
	for c: Candidate in confident:
		if c.bid.quantity > chosen.bid.quantity \
				or (c.bid.quantity == chosen.bid.quantity and c.p > chosen.p):
			chosen = c
	return _bid_action(chosen)


func _respond(view: PlayerView, estimate: TableEstimate,
		candidates: Array[Candidate]) -> MatchAction:
	var bid := view.current_bid
	if _wants_calza(view, estimate):
		return MatchAction.calza()
	if candidates.is_empty():
		return MatchAction.dudo()
	var best := _most_likely(candidates)
	var belief := _noisy(estimate.p_holds(bid))
	if belief < minf(personality.dudo_threshold, 1.0 - best.p):
		return MatchAction.dudo()
	if _rng.randf() < personality.bluff_chance:
		var bluff := _bluff(candidates, best)
		if bluff != null:
			return _bid_action(bluff)
	return _bid_action(best)


func _wants_calza(view: PlayerView, estimate: TableEstimate) -> bool:
	if not view.can_calza():
		return false
	# С полной чашкой «Точно!» ничего не даёт — только риск.
	if view.dice_counts[view.player_id] >= PerudoRules.MAX_DICE:
		return false
	return _noisy(estimate.p_exact(view.current_bid)) >= personality.calza_threshold


## Случайная ставка из тех, во что бот ещё готов верить (кроме лучшей).
func _bluff(candidates: Array[Candidate], best: Candidate) -> Candidate:
	var pool := candidates.filter(
			func(c: Candidate) -> bool: return c != best and c.p >= personality.bluff_floor)
	if pool.is_empty():
		return null
	return pool[_rng.randi_range(0, pool.size() - 1)]


# --- Кандидаты -----------------------------------------------------------------

## Все допустимые ставки, которые бот рассматривает. На открытии — любые количества.
func _candidates(view: PlayerView, estimate: TableEstimate) -> Array[Candidate]:
	var out: Array[Candidate] = []
	var max_q := view.max_bid_quantity()
	for face in view.allowed_faces():
		var min_q := view.min_quantity_for_face(face)
		var top := max_q if view.current_bid == null else mini(max_q, min_q + MAX_RAISE_JUMP)
		for q in range(min_q, top + 1):
			out.append(Candidate.new(Bid.new(q, face), _noisy(estimate.p_at_least(face, q))))
	return out


## Самая вероятная ставка; при равенстве — первая (меньшая грань, меньшее количество).
func _most_likely(candidates: Array) -> Candidate:
	var best: Candidate = candidates[0]
	for c: Candidate in candidates:
		if c.p > best.p:
			best = c
	return best


func _noisy(p: float) -> float:
	if personality.noise <= 0.0:
		return p
	return clampf(p + _rng.randfn(0.0, personality.noise), 0.0, 1.0)


func _bid_action(c: Candidate) -> MatchAction:
	return MatchAction.new(MatchAction.Kind.BID, c.bid)
