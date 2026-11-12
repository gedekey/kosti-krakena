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
## Кубики в рукавах по игрокам (М4). Засчитаны в result, в hands их нет.
var sleeve_dice: Array = []
## М23: грань прилива в этом раунде (RoundRules.NO_TIDE — не было) — тоже джокер.
var tide_face := RoundRules.NO_TIDE


func _init(p_kind: MatchAction.Kind, p_bid: Bid, p_bidder_id: int, p_caller_id: int,
		p_hands: Array, p_is_palifico: bool, p_result: RevealResult,
		p_sleeve_dice: Array = [], p_tide_face := RoundRules.NO_TIDE) -> void:
	kind = p_kind
	bid = p_bid
	bidder_id = p_bidder_id
	caller_id = p_caller_id
	hands = p_hands
	is_palifico = p_is_palifico
	result = p_result
	sleeve_dice = p_sleeve_dice
	tide_face = p_tide_face
