class_name CampaignProgress
extends RefCounted
## Прогресс кампании (DESIGN.md §8г): открытые и пройденные уровни, портрет игрока,
## «без поражений» с начала кампании. Сохраняется через to_dict() / from_dict()
## (автозагрузка Campaign → user://campaign.cfg). Без нод.
##
## Уровни открываются строго по порядку: 1 открыт всегда, N — если пройден N − 1.

## Кампания начата (выбран портрет). Иначе экран кампании начинает с выбора портрета.
var started := false
## Портрет игрока по умолчанию (первый из Sprites.PLAYER_PORTRAITS; логика UI не знает).
const DEFAULT_PORTRAIT := &"player1"

## Портрет игрока (один из Sprites.PLAYER_PORTRAITS — проверяет экран).
var portrait: StringName = DEFAULT_PORTRAIT
## Вступление показано (повтор — с экрана кампании).
var intro_seen := false
## С начала этой кампании не было ни одного поражения.
var flawless := true
## Кампания хоть раз пройдена — отметка в главном меню (переживает «Начать заново»).
var ever_finished := false

var _completed := {}                  # номер уровня → true


func is_completed(level: int) -> bool:
	return _completed.has(level)


func is_unlocked(level: int) -> bool:
	if level < 1 or level > CampaignBalance.LEVEL_COUNT:
		return false
	return level == 1 or is_completed(level - 1)


func completed_count() -> int:
	return _completed.size()


## Все уровни этой кампании пройдены.
func is_finished() -> bool:
	return completed_count() >= CampaignBalance.LEVEL_COUNT


## Самый дальний открытый уровень.
func frontier() -> int:
	var level := 1
	while level < CampaignBalance.LEVEL_COUNT and is_completed(level):
		level += 1
	return level


## Новая кампания: прогресс и «без поражений» с нуля; отметка о прохождении остаётся.
func start_new(p_portrait: StringName) -> void:
	_completed.clear()
	started = true
	intro_seen = false
	flawless = true
	set_portrait(p_portrait)


func set_portrait(p_portrait: StringName) -> void:
	if p_portrait != &"":
		portrait = p_portrait


## Уровень выигран. true — впервые в этой кампании.
func record_win(level: int) -> bool:
	if not is_unlocked(level):
		return false
	var first := not is_completed(level)
	_completed[level] = true
	if is_finished():
		ever_finished = true
	return first


func record_loss() -> void:
	flawless = false


# --- Сохранение ------------------------------------------------------------------

func to_dict() -> Dictionary:
	var levels: Array[int] = []
	for level: int in _completed:
		levels.append(level)
	levels.sort()
	return {
		"started": started, "portrait": String(portrait), "intro_seen": intro_seen,
		"flawless": flawless, "ever_finished": ever_finished, "completed": levels,
	}


## Восстановить из to_dict(). Негодные значения пропускаются; уровни — только подряд с 1.
func from_dict(data: Dictionary) -> void:
	reset()
	started = _flag(data, "started", false)
	var p: Variant = data.get("portrait", "")
	if p is String or p is StringName:
		set_portrait(StringName(p))
	intro_seen = _flag(data, "intro_seen", false)
	flawless = _flag(data, "flawless", true)
	ever_finished = _flag(data, "ever_finished", false)
	var levels: Variant = data.get("completed", [])
	if levels is Array:
		var sorted: Array = levels.duplicate()
		sorted.sort()
		for level: Variant in sorted:
			if level is int and is_unlocked(level):
				_completed[level] = true


static func _flag(data: Dictionary, key: String, default: bool) -> bool:
	var v: Variant = data.get(key, default)
	return v if v is bool else default


func reset() -> void:
	_completed.clear()
	started = false
	portrait = DEFAULT_PORTRAIT
	intro_seen = false
	flawless = true
	ever_finished = false
