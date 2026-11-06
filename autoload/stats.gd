extends Node
## Статистика игрока и флаги обучения (DESIGN.md §8). Сохраняются в user://profile.cfg (М11).
##
## Счётчики ведутся сами по событиям матча (Events) для игрока HUMAN_ID:
## сыгранные матчи, победы, пойманные им жулики (верные обвинения), его ложные обвинения,
## наступления его Безумия. recording = false — не считать (обучающий матч, М13).
## Флаги — «подсказка показана», «обучение пройдено», «обучение предложено» (ставит М13).
## save_path = "" — не трогать диск (тесты, см. tests/gut_pre_run.gd).

signal changed(key: StringName, value: int)
signal flag_set(flag: StringName)

const SAVE_PATH := "user://profile.cfg"
const STATS_SECTION := "stats"
const FLAGS_SECTION := "flags"
## Игрок-человек за столом (как TableScreen.HUMAN_ID).
const HUMAN_ID := 0

const KEYS: Array[StringName] = [
	&"matches_played",
	&"matches_won",
	&"cheaters_caught",
	&"false_accusations",
	&"madness_count",
]

const FLAG_TUTORIAL_DONE := &"tutorial_done"
## Обучение уже предлагали при запуске (М13) — второй раз не навязываем.
const FLAG_TUTORIAL_OFFERED := &"tutorial_offered"
## Подсказки при первом использовании (М13).
const FLAG_HINT_TRICKS := &"hint_tricks"
const FLAG_HINT_ACCUSE := &"hint_accuse"
const FLAG_HINT_MADNESS := &"hint_madness"

var save_path := SAVE_PATH
var recording := true

var _counters: Dictionary = {}
var _flags: Dictionary = {}


func _init() -> void:
	for key in KEYS:
		_counters[key] = 0


func _ready() -> void:
	load_saved()
	listen(Events)


## Подписаться на события матча (тесты подсовывают свою шину).
func listen(events: Node) -> void:
	events.match_started.connect(_on_match_started)
	events.match_ended.connect(_on_match_ended)
	events.accusation_made.connect(_on_accusation_made)
	events.madness_began.connect(_on_madness_began)


func get_count(key: StringName) -> int:
	assert(_counters.has(key), "Unknown stat: %s" % key)
	return _counters[key]


func increment(key: StringName, amount: int = 1) -> void:
	assert(_counters.has(key), "Unknown stat: %s" % key)
	_counters[key] += amount
	changed.emit(key, _counters[key])
	save()


## Доля побед в процентах (0, если матчей не было).
func win_percent() -> int:
	var played: int = _counters[&"matches_played"]
	if played <= 0:
		return 0
	return roundi(100.0 * _counters[&"matches_won"] / played)


## Обнулить счётчики (флаги обучения остаются).
func reset() -> void:
	for key in KEYS:
		_counters[key] = 0
		changed.emit(key, 0)
	save()


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName) -> void:
	if has_flag(flag):
		return
	_flags[flag] = true
	flag_set.emit(flag)
	save()


func clear_flags() -> void:
	_flags.clear()
	save()


# --- Сохранение ------------------------------------------------------------------

func save() -> Error:
	if save_path == "":
		return OK
	var file := ConfigFile.new()
	for key in KEYS:
		file.set_value(STATS_SECTION, String(key), _counters[key])
	for flag: StringName in _flags:
		file.set_value(FLAGS_SECTION, String(flag), true)
	return file.save(save_path)


## Прочитать с диска. Негодные значения пропускаются.
func load_saved() -> void:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for key in KEYS:
		var value: Variant = file.get_value(STATS_SECTION, String(key), 0)
		if value is int and value >= 0:
			_counters[key] = value
	_flags.clear()
	if file.has_section(FLAGS_SECTION):
		for flag in file.get_section_keys(FLAGS_SECTION):
			if file.get_value(FLAGS_SECTION, flag) == true:
				_flags[StringName(flag)] = true


# --- События матча ---------------------------------------------------------------

func _on_match_started(_player_count: int, _first_player: int) -> void:
	if recording:
		increment(&"matches_played")


func _on_match_ended(winner_id: int) -> void:
	if recording and winner_id == HUMAN_ID:
		increment(&"matches_won")


func _on_accusation_made(accuser_id: int, _target_id: int, guilty: bool) -> void:
	if recording and accuser_id == HUMAN_ID:
		increment(&"cheaters_caught" if guilty else &"false_accusations")


func _on_madness_began(player_id: int) -> void:
	if recording and player_id == HUMAN_ID:
		increment(&"madness_count")
