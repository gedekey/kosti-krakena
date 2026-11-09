extends Node
## Ранги игрока (DESIGN.md §8в, М20). Логика — RankTracker; здесь — подписка на события
## матча (Events) и сохранение в user://ranks.cfg. Учёт матча начинает стол (begin_*).
##
## save_path = "" — не трогать диск (тесты, см. tests/gut_pre_run.gd).

signal settled(change: RankChange)

const SAVE_PATH := "user://ranks.cfg"
const SECTION := "ranks"
const Mode := RankTracker.Mode

var save_path := SAVE_PATH
var tracker := RankTracker.new()


func _ready() -> void:
	tracker.changed.connect(save)
	tracker.settled.connect(func(change: RankChange) -> void: settled.emit(change))
	load_saved()
	listen(Events)


## Подписаться на события матча (тесты подсовывают свою шину).
func listen(events: Node) -> void:
	events.player_eliminated.connect(tracker.player_eliminated)
	events.match_ended.connect(tracker.match_ended)


func begin_single(player_count: int, bot_stars: Array[int]) -> void:
	tracker.begin_single(player_count, bot_stars)


func begin_net(player_count: int, humans: int) -> void:
	tracker.begin_net(player_count, humans)


func skip() -> void:
	tracker.skip()


func forfeit() -> void:
	tracker.forfeit()


func abort() -> void:
	tracker.abort()


func is_counting() -> bool:
	return tracker.is_counting()


func tier(mode: Mode) -> RankBalance.Tier:
	return tracker.tier(mode)


func glory(mode: Mode) -> int:
	return tracker.glory(mode)


func last_change() -> RankChange:
	return tracker.last_change


## Забыть оба ранга (тесты).
func reset() -> void:
	tracker.reset()
	save()


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
