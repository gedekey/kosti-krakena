class_name MatchAction
extends RefCounted
## Действие игрока в свой ход. Неизменяемое значение.
## Трюки — не действия: они идут отдельной командой до действия (CheatAction).

enum Kind { BID, DUDO, CALZA, ACCUSE }

var kind: Kind
## Только для BID.
var bid: Bid
## Только для ACCUSE: кого обвиняют.
var target_id: int = PerudoRules.NO_PLAYER


func _init(p_kind: Kind, p_bid: Bid = null, p_target_id := PerudoRules.NO_PLAYER) -> void:
	kind = p_kind
	bid = p_bid
	target_id = p_target_id


static func make_bid(quantity: int, face: int) -> MatchAction:
	return MatchAction.new(Kind.BID, Bid.new(quantity, face))


static func dudo() -> MatchAction:
	return MatchAction.new(Kind.DUDO)


static func calza() -> MatchAction:
	return MatchAction.new(Kind.CALZA)


## «Обвинить» (DESIGN.md §3.3): жульничал ли target в текущем раунде.
static func accuse(target: int) -> MatchAction:
	return MatchAction.new(Kind.ACCUSE, null, target)


func _to_string() -> String:
	match kind:
		Kind.BID:
			return "bid %s" % bid
		Kind.DUDO:
			return "dudo"
		Kind.ACCUSE:
			return "accuse %d" % target_id
		_:
			return "calza"
