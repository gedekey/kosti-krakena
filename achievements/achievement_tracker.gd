class_name AchievementTracker
extends RefCounted
## Условия достижений (DESIGN.md §8а). Чистая логика без нод: методы вызываются по
## событиям матча (их пробрасывает автозагрузка Achievements), открытые достижения и
## счётчики сохраняются через to_dict() / from_dict().
##
## Следит только за игроком HUMAN_ID. Матч, прерванный без match_ended (сдался, вышел,
## реванш), ничего «за матч» не даёт — следующий begin_match() сбрасывает его состояние.

signal unlocked(id: Achievement.Id)
## Изменилось то, что сохраняется (счётчики или открытые достижения).
signal changed

const HUMAN_ID := 0

var _unlocked := {}                 # Achievement.Id → true
var _wins := 0
var _catches := 0
var _trick_kinds := {}              # Cheat.Kind → true (успешные трюки за всё время)

# Состояние текущего матча.
var _in_match := false
var _player_count := 0
var _human_dice := PerudoRules.START_DICE
var _lost_die := false
var _cheated := false
var _mad := false


func is_unlocked(id: Achievement.Id) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


## Прогресс счётчика (для разовых — 0 или 1), не больше Achievement.goal(id).
func progress(id: Achievement.Id) -> int:
	var value := 0
	match id:
		Achievement.Id.VETERAN:
			value = _wins
		Achievement.Id.HUNTER:
			value = _catches
		Achievement.Id.TRICKSTER:
			value = _trick_kinds.size()
		_:
			value = 1 if is_unlocked(id) else 0
	return mini(value, Achievement.goal(id))


# --- События матча -------------------------------------------------------------------

func begin_match(player_count: int) -> void:
	_in_match = true
	_player_count = player_count
	_human_dice = PerudoRules.START_DICE
	_lost_die = false
	_cheated = false
	_mad = false


func dice_changed(player_id: int, count: int, delta: int) -> void:
	if player_id != HUMAN_ID:
		return
	_human_dice = count
	if delta < 0:
		_lost_die = true


## Вскрытие после «Лжи!» / «Точно!», вызванное игроком caller_id.
func challenge(kind: MatchAction.Kind, caller_id: int, result: RevealResult) -> void:
	if caller_id != HUMAN_ID:
		return
	if kind == MatchAction.Kind.DUDO and not result.bid_holds:
		_unlock(Achievement.Id.LIAR_CALL)
	elif kind == MatchAction.Kind.CALZA and result.bid_holds:
		_unlock(Achievement.Id.CALZA_HIT)


func cheat_succeeded(player_id: int, kind: Cheat.Kind) -> void:
	if player_id != HUMAN_ID:
		return
	_cheated = true
	if not _trick_kinds.has(kind):
		_trick_kinds[kind] = true
		changed.emit()
	_unlock(Achievement.Id.FIRST_TRICK)
	if kind == Cheat.Kind.ABYSS_WHISPER:
		_unlock(Achievement.Id.ABYSS_VOICE)
	if _trick_kinds.size() >= Achievement.goal(Achievement.Id.TRICKSTER):
		_unlock(Achievement.Id.TRICKSTER)


func cheat_failed(player_id: int) -> void:
	if player_id == HUMAN_ID:
		_cheated = true


func accusation(accuser_id: int, guilty: bool) -> void:
	if accuser_id != HUMAN_ID or not guilty:
		return
	_catches += 1
	changed.emit()
	_unlock(Achievement.Id.SHARP_EYE)
	if _catches >= Achievement.HUNTER_CATCHES:
		_unlock(Achievement.Id.HUNTER)


func madness(player_id: int) -> void:
	if player_id != HUMAN_ID:
		return
	_mad = true
	_unlock(Achievement.Id.INTO_ABYSS)


func match_ended(winner_id: int) -> void:
	if not _in_match:
		return
	_in_match = false
	if winner_id != HUMAN_ID:
		return
	_wins += 1
	changed.emit()
	_unlock(Achievement.Id.FIRST_WIN)
	if _wins >= Achievement.VETERAN_WINS:
		_unlock(Achievement.Id.VETERAN)
	if _player_count >= Achievement.FULL_HOUSE_PLAYERS:
		_unlock(Achievement.Id.FULL_HOUSE)
	if not _lost_die:
		_unlock(Achievement.Id.FLAWLESS)
	if _human_dice <= Achievement.LAST_DIE_DICE:
		_unlock(Achievement.Id.LAST_DIE)
	if not _cheated and _player_count >= Achievement.CLEAN_HANDS_MIN_PLAYERS:
		_unlock(Achievement.Id.CLEAN_HANDS)
	if _mad:
		_unlock(Achievement.Id.MAD_CAPTAIN)


# --- Сохранение ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var names: Array[String] = []
	for id in Achievement.ALL:
		if is_unlocked(id):
			names.append(Achievement.save_name(id))
	var kinds: Array[int] = []
	for kind: int in _trick_kinds:
		kinds.append(kind)
	kinds.sort()
	return {"unlocked": names, "wins": _wins, "catches": _catches, "trick_kinds": kinds}


## Восстановить из to_dict(). Негодные значения пропускаются.
func from_dict(data: Dictionary) -> void:
	reset()
	var names: Variant = data.get("unlocked", [])
	if names is Array:
		for name: Variant in names:
			var id := Achievement.from_save_name(str(name))
			if id >= 0:
				_unlocked[id] = true
	var wins: Variant = data.get("wins", 0)
	if wins is int and wins >= 0:
		_wins = wins
	var catches: Variant = data.get("catches", 0)
	if catches is int and catches >= 0:
		_catches = catches
	var kinds: Variant = data.get("trick_kinds", [])
	if kinds is Array:
		for kind: Variant in kinds:
			if kind is int and kind in Cheat.ALL:
				_trick_kinds[kind] = true


## Забыть всё (открытые достижения и счётчики).
func reset() -> void:
	_unlocked.clear()
	_wins = 0
	_catches = 0
	_trick_kinds.clear()
	_in_match = false


func _unlock(id: Achievement.Id) -> void:
	if is_unlocked(id):
		return
	_unlocked[id] = true
	changed.emit()
	unlocked.emit(id)
