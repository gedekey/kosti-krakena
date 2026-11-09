class_name RankChange
extends RefCounted
## Итог матча для ранга (М20): сколько Славы, ранг и Слава до и после.

var mode := 0                 # RankTracker.Mode
var place := 0                # 1 — победа
var player_count := 0
var delta := 0                # начисленная Слава (уже с множителями)
var old_tier: RankBalance.Tier = RankBalance.Tier.WOOD
var old_glory := 0
var tier: RankBalance.Tier = RankBalance.Tier.WOOD
var glory := 0


func promoted() -> bool:
	return tier > old_tier


func demoted() -> bool:
	return tier < old_tier
