extends Node
## Достижения игрока (DESIGN.md §8а). Условия — в AchievementTracker; здесь — подписка на
## события матча (Events) и сохранение в user://achievements.cfg.
##
## Пока Stats.recording = false (обучающий матч) — события не учитываются.
## save_path = "" — не трогать диск (тесты, см. tests/gut_pre_run.gd).

signal unlocked(id: Achievement.Id)

const SAVE_PATH := "user://achievements.cfg"
const SECTION := "achievements"

var save_path := SAVE_PATH
var tracker := AchievementTracker.new()


func _ready() -> void:
	tracker.unlocked.connect(func(id: Achievement.Id) -> void: unlocked.emit(id))
	tracker.changed.connect(save)
	load_saved()
	listen(Events)


## Подписаться на события матча (тесты подсовывают свою шину).
func listen(events: Node) -> void:
	events.match_started.connect(func(count: int, _first: int) -> void:
		if _recording():
			tracker.begin_match(count))
	events.dice_count_changed.connect(func(id: int, count: int, delta: int) -> void:
		if _recording():
			tracker.dice_changed(id, count, delta))
	events.challenge_revealed.connect(func(reveal: ChallengeReveal) -> void:
		if _recording():
			tracker.challenge(reveal.kind, reveal.caller_id, reveal.result))
	events.cheat_resolved.connect(func(outcome: CheatOutcome) -> void:
		if _recording():
			tracker.cheat_succeeded(outcome.player_id, outcome.action.kind))
	events.cheat_failed.connect(func(id: int, _kind: int) -> void:
		if _recording():
			tracker.cheat_failed(id))
	events.accusation_made.connect(func(accuser: int, _target: int, guilty: bool) -> void:
		if _recording():
			tracker.accusation(accuser, guilty))
	events.madness_began.connect(func(id: int) -> void:
		if _recording():
			tracker.madness(id))
	events.match_ended.connect(func(winner: int) -> void:
		if _recording():
			tracker.match_ended(winner))


func is_unlocked(id: Achievement.Id) -> bool:
	return tracker.is_unlocked(id)


func unlocked_count() -> int:
	return tracker.unlocked_count()


func progress(id: Achievement.Id) -> int:
	return tracker.progress(id)


## Забыть все достижения (тесты).
func reset() -> void:
	tracker.reset()
	save()


func _recording() -> bool:
	return Stats.recording


# --- Сохранение ------------------------------------------------------------------

func save() -> Error:
	if save_path == "":
		return OK
	var file := ConfigFile.new()
	var data := tracker.to_dict()
	for key: String in data:
		file.set_value(SECTION, key, data[key])
	return file.save(save_path)


func load_saved() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK or not file.has_section(SECTION):
		return
	var data := {}
	for key in file.get_section_keys(SECTION):
		data[key] = file.get_value(SECTION, key)
	tracker.from_dict(data)
