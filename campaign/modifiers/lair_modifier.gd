class_name LairModifier
extends MatchModifier
## «Логово» (ур. 6, DESIGN.md §8г): у Глубоководного CampaignBalance.LAIR_BOSS_DICE
## кубиков (и «Точно!» возвращает до LAIR_BOSS_MAX_DICE), у игрока — обычные.
## Когда у Глубоководного остаётся TIDE_BOSS_DICE кубиков, начинается прилив: в начале
## каждого раунда одна случайная грань из TIDE_FACES — джокер вместе с единицами.
## В Palifico прилива нет (контроллер не спрашивает).

var boss_id: int
## Прилив начался (дальше не прекращается, даже если босс вернёт кубики).
var tide_started := false


func _init(p_boss_id: int) -> void:
	boss_id = p_boss_id


func start_dice(player_id: int, dice: int) -> int:
	return CampaignBalance.LAIR_BOSS_DICE if player_id == boss_id else dice


func max_dice(player_id: int, dice: int) -> int:
	return CampaignBalance.LAIR_BOSS_MAX_DICE if player_id == boss_id else dice


func round_tide(mc: MatchController, tide: int, rng: RandomNumberGenerator) -> int:
	if not tide_started and mc.dice_counts[boss_id] > 0 \
			and mc.dice_counts[boss_id] <= CampaignBalance.TIDE_BOSS_DICE:
		tide_started = true
	if not tide_started:
		return tide
	var faces := CampaignBalance.TIDE_FACES
	return faces[rng.randi_range(0, faces.size() - 1)]
