class_name ActionRules
extends RefCounted
## Допустимость действий в ход с учётом стола. Единый источник для контроллера,
## PlayerView (боты, UI-подсказки) — поверх PerudoRules.
##
## Ограничение сверху: ставка не может превышать число кубиков на столе (max_quantity).


static func is_bid_allowed(prev: Bid, bid: Bid, rules: RoundRules, max_quantity: int) -> bool:
	return PerudoRules.is_valid_bid(prev, bid, rules) and bid.quantity <= max_quantity


## actor и dice_counts нужны только для «Обвинить».
static func is_legal(action: MatchAction, prev: Bid, rules: RoundRules,
		options: RuleOptions, max_quantity: int, actor := PerudoRules.NO_PLAYER,
		dice_counts: Array = []) -> bool:
	if action == null:
		return false
	match action.kind:
		MatchAction.Kind.BID:
			return is_bid_allowed(prev, action.bid, rules, max_quantity)
		MatchAction.Kind.DUDO:
			return PerudoRules.can_call_dudo(prev)
		MatchAction.Kind.CALZA:
			return PerudoRules.can_call_calza(prev, options)
		MatchAction.Kind.ACCUSE:
			return can_accuse(actor, action.target_id, dice_counts)
	return false


## Обвинить можно любого другого игрока с кубиками — в любой момент своего хода.
static func can_accuse(actor: int, target: int, dice_counts: Array) -> bool:
	return actor != target and actor >= 0 and target >= 0 and target < dice_counts.size() 			and dice_counts[target] > 0


## Самая дешёвая допустимая ставка или null, если повышать уже некуда.
static func lowest_bid(prev: Bid, rules: RoundRules, max_quantity: int) -> Bid:
	var bid := PerudoRules.lowest_next_bid(prev, rules)
	if bid == null or bid.quantity > max_quantity:
		return null
	return bid


## Грани, на которые сейчас можно поставить (с учётом max_quantity).
static func allowed_faces(prev: Bid, rules: RoundRules, max_quantity: int) -> Array[int]:
	var faces: Array[int] = []
	for face in range(1, PerudoRules.FACES + 1):
		var q := PerudoRules.min_quantity_for_face(prev, face, rules)
		if q != PerudoRules.NOT_ALLOWED and q <= max_quantity:
			faces.append(face)
	return faces
