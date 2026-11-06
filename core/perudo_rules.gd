class_name PerudoRules
extends RefCounted
## Правила Перудо (DESIGN.md §2): бросок, подсчёт, допустимость ставок, вскрытие.
## Только статические функции без состояния. RNG передаётся параметром.
##
## Игроки обозначаются индексами (player_id) в порядке хода по кругу.
## «Руки» (hands) — массив массивов граней, по одному на игрока.

const START_DICE := 5
const MAX_DICE := 5
const FACES := 6
## Пако — единицы, джокеры вне Palifico.
const JOKER_FACE := 1
## min_quantity_for_face: на эту грань сейчас ставить нельзя.
const NOT_ALLOWED := -1
## next_active_player / winner: такого игрока нет.
const NO_PLAYER := -1


# --- Бросок и подсчёт ---------------------------------------------------------

static func roll_dice(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var dice: Array[int] = []
	for i in count:
		dice.append(rng.randi_range(1, FACES))
	return dice


## Сколько кубиков засчитываются за грань face. Ставка на единицы считает только единицы.
static func count_face(dice: Array, face: int, ones_wild: bool) -> int:
	var total := 0
	for d in dice:
		if d == face or (ones_wild and d == JOKER_FACE):
			total += 1
	return total


static func count_on_table(hands: Array, face: int, ones_wild: bool) -> int:
	var total := 0
	for hand in hands:
		total += count_face(hand, face, ones_wild)
	return total


# --- Ставки ------------------------------------------------------------------

## Минимальное количество для ставки на грань face после prev (null — первая ставка раунда).
## NOT_ALLOWED, если на эту грань сейчас ставить нельзя.
static func min_quantity_for_face(prev: Bid, face: int, rules: RoundRules) -> int:
	if face < 1 or face > FACES:
		return NOT_ALLOWED

	if rules.is_palifico:
		if prev == null:
			return 1
		# Грань зафиксирована первой ставкой.
		return prev.quantity + 1 if face == prev.face else NOT_ALLOWED

	if prev == null:
		return NOT_ALLOWED if face == JOKER_FACE else 1

	if prev.is_ones():
		if face == JOKER_FACE:
			return prev.quantity + 1
		return prev.quantity * 2 + 1

	if face == JOKER_FACE:
		return ceili(prev.quantity / 2.0)
	return prev.quantity if face > prev.face else prev.quantity + 1


static func is_valid_bid(prev: Bid, next: Bid, rules: RoundRules) -> bool:
	if next == null or not next.is_well_formed():
		return false
	var min_q := min_quantity_for_face(prev, next.face, rules)
	return min_q != NOT_ALLOWED and next.quantity >= min_q


## Самая «дешёвая» допустимая ставка: наименьшее количество, при равенстве — меньшая грань.
## Подсказка для UI и отправная точка для ботов.
static func lowest_next_bid(prev: Bid, rules: RoundRules) -> Bid:
	var best: Bid = null
	for face in range(1, FACES + 1):
		var q := min_quantity_for_face(prev, face, rules)
		if q == NOT_ALLOWED:
			continue
		if best == null or q < best.quantity:
			best = Bid.new(q, face)
	return best


# --- Действия и вскрытие ------------------------------------------------------

static func can_call_dudo(prev: Bid) -> bool:
	return prev != null


static func can_call_calza(prev: Bid, options: RuleOptions) -> bool:
	return prev != null and options.calza_enabled


## «Ложь!»: ставка не выполнена — кубик теряет поставивший, иначе — оспоривший.
static func resolve_dudo(bid: Bid, bidder_id: int, challenger_id: int, hands: Array,
		rules: RoundRules) -> RevealResult:
	var actual := count_on_table(hands, bid.face, rules.ones_wild())
	var holds := actual >= bid.quantity
	return RevealResult.new(actual, holds, challenger_id if holds else bidder_id, -1)


## «Точно!»: ровно столько — вызвавший возвращает кубик (не больше MAX_DICE), иначе теряет.
static func resolve_calza(bid: Bid, caller_id: int, caller_dice: int, hands: Array,
		rules: RoundRules) -> RevealResult:
	var actual := count_on_table(hands, bid.face, rules.ones_wild())
	var exact := actual == bid.quantity
	var delta := -1
	if exact:
		delta = 1 if caller_dice < MAX_DICE else 0
	return RevealResult.new(actual, exact, caller_id, delta)


# --- Раунды ------------------------------------------------------------------

## Следующий раунд — Palifico, если у игрока впервые за матч остался 1 кубик.
static func triggers_palifico(dice_after: int, had_palifico_before: bool,
		options: RuleOptions) -> bool:
	return options.palifico_enabled and dice_after == 1 and not had_palifico_before


## Следующий по кругу игрок с кубиками после from_id (from_id не учитывается).
static func next_active_player(dice_counts: Array, from_id: int) -> int:
	var n := dice_counts.size()
	for step in range(1, n + 1):
		var id := (from_id + step) % n
		if id != from_id and dice_counts[id] > 0:
			return id
	return NO_PLAYER


## Начинает тот, чьё количество кубиков изменилось; если он выбыл — следующий по кругу.
static func next_round_starter(dice_counts: Array, affected_id: int) -> int:
	if dice_counts[affected_id] > 0:
		return affected_id
	return next_active_player(dice_counts, affected_id)


## Победитель, если кубики остались ровно у одного игрока.
static func winner(dice_counts: Array) -> int:
	var found := NO_PLAYER
	for id in dice_counts.size():
		if dice_counts[id] > 0:
			if found != NO_PLAYER:
				return NO_PLAYER
			found = id
	return found
