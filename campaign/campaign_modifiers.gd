class_name CampaignModifiers
extends RefCounted
## Правила матча для уровня кампании: по CampaignLevel.modifier — MatchModifier'ы.
## Человек сидит на месте HUMAN_ID, соперники — по порядку CampaignLevel.opponents.

const HUMAN_ID := 0


static func build(level: CampaignLevel) -> Array[MatchModifier]:
	var out: Array[MatchModifier] = []
	var owner := level.owner_seat()
	match level.modifier:
		CampaignLevel.Modifier.EVIL_EYE:
			if owner > 0:
				out.append(EvilEyeModifier.new(owner, HUMAN_ID))
		CampaignLevel.Modifier.SCARCE_SANITY:
			out.append(ScarceSanityModifier.new())
		CampaignLevel.Modifier.DEAD_HAND:
			if owner > 0:
				out.append(DeadHandModifier.new(owner))
		CampaignLevel.Modifier.LAIR:
			if owner > 0:
				out.append(LairModifier.new(owner))
	return out


## Добавить модификаторы уровня в контроллер (до start_match).
static func apply(level: CampaignLevel, controller: MatchController) -> void:
	for m in build(level):
		controller.add_modifier(m)
