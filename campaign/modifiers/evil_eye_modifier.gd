class_name EvilEyeModifier
extends MatchModifier
## «Дурной глаз» (ур. 3, DESIGN.md §8г): в начале каждого раунда Ведьма видит
## CampaignBalance.EVIL_EYE_DICE случайных кубиков игрока; игрок видит, какие
## (метка глаза на кубике). Ведьма без кубиков не смотрит.

var watcher_id: int
var target_id: int


func _init(p_watcher_id: int, p_target_id: int) -> void:
	watcher_id = p_watcher_id
	target_id = p_target_id


func after_roll(mc: MatchController, rng: RandomNumberGenerator) -> void:
	if not mc.is_active(watcher_id) or not mc.is_active(target_id):
		return
	var indices: Array[int] = []
	for i in mc.dice_counts[target_id]:
		indices.append(i)
	for n in mini(CampaignBalance.EVIL_EYE_DICE, indices.size()):
		var index: int = indices.pop_at(rng.randi_range(0, indices.size() - 1))
		mc.watch_die(watcher_id, target_id, index)
