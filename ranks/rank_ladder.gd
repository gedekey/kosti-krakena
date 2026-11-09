class_name RankLadder
extends RefCounted
## Один ранг игрока (М20, DESIGN.md §8в): ранг и Слава внутри него.
## Повышение — Слава дошла до порога (лишнее переносится), понижение — потеря на 0 Славы.

const Tier := RankBalance.Tier

var tier: RankBalance.Tier = Tier.WOOD
var glory := 0


## Слава за место (1 — победа) за столом на player_count; gain_multiplier — для прибавки.
## Потеря умножается на множитель потерь текущего ранга.
func place_glory(place: int, player_count: int, gain_multiplier := 1.0) -> int:
	return glory_for(place, player_count, tier, gain_multiplier)


static func glory_for(place: int, player_count: int, p_tier: RankBalance.Tier,
		gain_multiplier := 1.0) -> int:
	var n := maxi(player_count, 2)
	var p := clampi(place, 1, n)
	var base := RankBalance.WIN_GLORY + float(RankBalance.LAST_PLACE_GLORY
			- RankBalance.WIN_GLORY) * (p - 1) / (n - 1)
	var value := base * gain_multiplier if base > 0.0 \
			else base * RankBalance.LOSS_MULTIPLIER[p_tier]
	return roundi(value)


## Начислить Славу. Возвращает итог (ранг и Слава до и после).
func apply(delta: int) -> RankChange:
	var change := RankChange.new()
	change.delta = delta
	change.old_tier = tier
	change.old_glory = glory
	if delta >= 0:
		glory += delta
		while tier < RankBalance.TOP_TIER and glory >= RankBalance.promote_glory(tier):
			glory -= RankBalance.promote_glory(tier)
			tier = (tier + 1) as RankBalance.Tier
	elif glory == 0 and tier > Tier.WOOD:
		tier = (tier - 1) as RankBalance.Tier
		glory = roundi(RankBalance.promote_glory(tier) * RankBalance.DEMOTE_GLORY_SHARE)
	else:
		glory = maxi(glory + delta, 0)
	change.tier = tier
	change.glory = glory
	return change


func to_dict() -> Dictionary:
	return {"tier": RankBalance.SAVE_NAMES[tier], "glory": glory}


## Восстановить из to_dict(); негодное — Дерево с 0 Славы.
func from_dict(data: Dictionary) -> void:
	tier = Tier.WOOD
	glory = 0
	var index := RankBalance.SAVE_NAMES.find(str(data.get("tier", "")))
	if index < 0:
		return
	tier = index as RankBalance.Tier
	var value: Variant = data.get("glory", 0)
	if value is int and value >= 0:
		var cap := RankBalance.promote_glory(tier)
		glory = value if cap < 0 else mini(value, cap - 1)
