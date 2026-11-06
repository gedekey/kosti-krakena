class_name ChallengeReveal
extends RefCounted
## Что открылось при «Лжи!» / «Точно!»: для ленты и анимации вскрытия.

var kind: MatchAction.Kind
var bid: Bid
var bidder_id: int
var caller_id: int
## Снимок кубиков всех игроков на момент вскрытия.
var hands: Array
var is_palifico: bool
var result: RevealResult


func _init(p_kind: MatchAction.Kind, p_bid: Bid, p_bidder_id: int, p_caller_id: int,
		p_hands: Array, p_is_palifico: bool, p_result: RevealResult) -> void:
	kind = p_kind
	bid = p_bid
	bidder_id = p_bidder_id
	caller_id = p_caller_id
	hands = p_hands
	is_palifico = p_is_palifico
	result = p_result
