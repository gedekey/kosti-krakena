extends Node
## Статистика игрока (DESIGN.md §8).
##
## Сейчас — только счётчики в памяти. Сохранение в user:// и экран статистики — модуль 11.

signal changed(key: StringName, value: int)

const KEYS: Array[StringName] = [
	&"matches_played",
	&"matches_won",
	&"cheaters_caught",
	&"false_accusations",
	&"madness_count",
]

var _counters: Dictionary = {}


func _init() -> void:
	reset()


func get_count(key: StringName) -> int:
	assert(_counters.has(key), "Unknown stat: %s" % key)
	return _counters[key]


func increment(key: StringName, amount: int = 1) -> void:
	assert(_counters.has(key), "Unknown stat: %s" % key)
	_counters[key] += amount
	changed.emit(key, _counters[key])


func reset() -> void:
	for key in KEYS:
		_counters[key] = 0
