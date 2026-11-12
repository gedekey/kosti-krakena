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
##
## М6: трюки (BotCheatPlanner) и обвинения (Suspicion) по характеру. Итоги своих трюков
## (подсмотренное, «Шёпот Бездны», рукав) учитываются в TableEstimate. В Безумии бот не
## жульничает и, если mad_awareness > 0, делает поправку на то, что глаза могут врать.
## Обвинение проверяется первым в каждом ходе, в том числе до первой ставки.

## Повышение рассматривается от минимального количества до минимального + столько.
const MAX_RAISE_JUMP := 2

var personality: BotPersonality
var _rng: RandomNumberGenerator
var _planner: BotCheatPlanner
var _suspicion: Suspicion
## Первый ход раунда бот видит правду после броска; номер раунда этого хода и
## размер ленты ставок на нём (по ним узнаём, что ход тот же).
var _first_turn_round := -1
var _first_turn_bids := -1


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
	_planner = BotCheatPlanner.new(personality, rng)
	_suspicion = Suspicion.new(personality.evidence_memory)


func choose_action(view: PlayerView) -> MatchAction:
	_suspicion.observe(view)
	var accused := _accusation_target(view)
	if accused != PerudoRules.NO_PLAYER:
		return MatchAction.accuse(accused)
	var estimate := estimate_for(view)
	var candidates := _candidates(view, estimate)
	if view.current_bid == null:
		return _opening(candidates)
	return _respond(view, estimate, candidates)


func choose_roll_cheat(view: PlayerView) -> CheatAction:
	return _planner.choose_roll_cheat(view)


func choose_turn_cheat(view: PlayerView) -> CheatAction:
	_suspicion.observe(view)
	return _planner.choose_turn_cheat(view, estimate_for(view))


## Стол глазами бота: с чтением ставок, знаниями от трюков и (в Безумии) недоверием
## к своим кубикам.
func estimate_for(view: PlayerView) -> TableEstimate:
	return TableEstimate.new(view, personality.bid_reading, own_trust(view))


## Насколько бот верит увиденным своим кубикам (1 — полностью).
func own_trust(view: PlayerView) -> float:
	var is_first := _is_first_turn(view)
	if not view.is_mad() or is_first:
		return 1.0
	return 1.0 - personality.mad_awareness * MadnessBalance.HALLUCINATION_CHANCE


## Вера в то, что игрок жульничал в этом раунде (для отладки и тестов).
func suspicion_of(player_id: int) -> float:
	return _suspicion.belief(player_id)


# --- Обвинения -----------------------------------------------------------------

## Кого обвинить или NO_PLAYER. Самый подозрительный, если вера не ниже порога.
func _accusation_target(view: PlayerView) -> int:
	if personality.accuse_threshold >= 1.0:
		return PerudoRules.NO_PLAYER
	var best := PerudoRules.NO_PLAYER
	var best_belief := 0.0
	for id in view.dice_counts.size():
		if id == view.player_id or not view.can_accuse(id):
			continue
		var b := _noisy(_suspicion.belief(id))
		if b >= personality.accuse_threshold and b > best_belief:
			best = id
			best_belief = b
	return best


## Покажется ли улика от своего трюка при этом действии: трюк в этот ход
## или «Утяжелённая кость» перед первым ходом раунда.
func _exposed(view: PlayerView) -> bool:
	if view.cheat_outcomes.is_empty():
		return false
	var last: CheatOutcome = view.cheat_outcomes[-1]
	if view.cheat_used and Cheat.leaves_evidence(last.action.kind):
		return true
	if _is_first_turn(view):
		for o in view.cheat_outcomes:
			if o.action.kind == Cheat.Kind.LOADED_DIE:
				return true
	return false


## Первый ход бота в раунде (кубики в нём — правда после броска).
func _is_first_turn(view: PlayerView) -> bool:
	if view.round_number != _first_turn_round:
		_first_turn_round = view.round_number
		_first_turn_bids = view.bid_history.size()
	return view.bid_history.size() == _first_turn_bids


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
	var limit := minf(personality.dudo_threshold, 1.0 - best.p)
	if _exposed(view):
		limit += AiBalance.EXPOSED_DUDO_BIAS
	if belief < limit:
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
	if view.dice_counts[view.player_id] >= view.own_max_dice:
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
