class_name DeadHandModifier
extends MatchModifier
## «Мёртвая рука» (ур. 5, DESIGN.md §8г): Утопленник, потеряв последний кубик,
## CampaignBalance.DEAD_HAND_USES раз за матч «тонет» и возвращается
## с CampaignBalance.DEAD_HAND_DICE кубиками.

var owner_id: int
var uses_left := CampaignBalance.DEAD_HAND_USES


func _init(p_owner_id: int) -> void:
	owner_id = p_owner_id


func rescue_dice(_match: MatchController, player_id: int) -> int:
	if player_id != owner_id or uses_left <= 0:
		return 0
	uses_left -= 1
	return CampaignBalance.DEAD_HAND_DICE
