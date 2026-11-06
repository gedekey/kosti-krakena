class_name PlayerView
extends RefCounted
## То, что знает конкретный игрок в момент своего хода (DESIGN.md §5: боты честны
## в информации). Чужих кубиков здесь нет — только их количество.
## Снимок: изменения контроллера после создания сюда не попадают.

var player_id: int
var round_number: int
var own_dice: Array[int] = []
var dice_counts: Array[int] = []
var current_bid: Bid
var current_bidder: int = PerudoRules.NO_PLAYER
var bid_history: Array[BidEntry] = []
var round_rules: RoundRules
var options: RuleOptions


func total_dice() -> int:
	var total := 0
	for c in dice_counts:
		total += c
	return total


func max_bid_quantity() -> int:
	return total_dice()


func min_quantity_for_face(face: int) -> int:
	return PerudoRules.min_quantity_for_face(current_bid, face, round_rules)


func lowest_bid() -> Bid:
	return ActionRules.lowest_bid(current_bid, round_rules, max_bid_quantity())


func allowed_faces() -> Array[int]:
	return ActionRules.allowed_faces(current_bid, round_rules, max_bid_quantity())


func is_legal(action: MatchAction) -> bool:
	return ActionRules.is_legal(action, current_bid, round_rules, options, max_bid_quantity())


func can_dudo() -> bool:
	return is_legal(MatchAction.dudo())


func can_calza() -> bool:
	return is_legal(MatchAction.calza())
