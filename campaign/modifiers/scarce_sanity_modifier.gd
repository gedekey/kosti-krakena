class_name ScarceSanityModifier
extends MatchModifier
## «Скудный рассудок» (ур. 4, DESIGN.md §8г): у всех за столом
## CampaignBalance.SCARCE_SANITY Рассудка вместо обычного.


func start_sanity(_player_id: int, sanity: int) -> int:
	return mini(sanity, CampaignBalance.SCARCE_SANITY)
