class_name MatchAction
extends RefCounted
## Действие игрока в свой ход. Неизменяемое значение.
## М4 добавит сюда «Обвинить».

enum Kind { BID, DUDO, CALZA }

var kind: Kind
## Только для BID.
var bid: Bid


func _init(p_kind: Kind, p_bid: Bid = null) -> void:
	kind = p_kind
	bid = p_bid


static func make_bid(quantity: int, face: int) -> MatchAction:
	return MatchAction.new(Kind.BID, Bid.new(quantity, face))


static func dudo() -> MatchAction:
	return MatchAction.new(Kind.DUDO)


static func calza() -> MatchAction:
	return MatchAction.new(Kind.CALZA)


func _to_string() -> String:
	match kind:
		Kind.BID:
			return "bid %s" % bid
		Kind.DUDO:
			return "dudo"
		_:
			return "calza"
