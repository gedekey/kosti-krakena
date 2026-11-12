class_name CampaignLevels
extends RefCounted
## Уровни кампании по порядку (данные — campaign/levels/level_<N>.tres).

const PATH := "res://campaign/levels/level_%d.tres"


static func get_level(number: int) -> CampaignLevel:
	if number < 1 or number > CampaignBalance.LEVEL_COUNT:
		return null
	return load(PATH % number) as CampaignLevel


static func all() -> Array[CampaignLevel]:
	var out: Array[CampaignLevel] = []
	for n in range(1, CampaignBalance.LEVEL_COUNT + 1):
		out.append(get_level(n))
	return out
