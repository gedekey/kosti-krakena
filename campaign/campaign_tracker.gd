class_name CampaignTracker
extends RefCounted
## Учёт матча кампании (DESIGN.md §8г): победа открывает следующий уровень, поражение
## снимает «без поражений». Без нод: методы зовёт автозагрузка Campaign по событиям матча.
##
## Поражение — выбывание игрока, победа другого, «Сдаться» или выход в меню посреди матча
## (forfeit). Матч, прерванный без итога (abort, закрытие игры), ничего не меняет.
## «Чистая совесть» — уровень пройден без трюков (даже пойманных).

## Уровень выигран; clean — без трюков; first — впервые в этой кампании.
signal level_won(level: int, clean: bool, first: bool)
signal level_lost(level: int)
## Пройден последний уровень; flawless — без единого поражения с начала кампании.
signal campaign_completed(flawless: bool)
## Изменилось то, что сохраняется.
signal changed

const HUMAN_ID := 0
const NO_LEVEL := 0

var progress := CampaignProgress.new()
## Итог последнего матча кампании: номер уровня, если он выигран (иначе NO_LEVEL).
var last_won := NO_LEVEL

var _level := NO_LEVEL
var _cheated := false


## Начать учёт матча на уровне (стол кампании).
func begin(level: int) -> void:
	_level = level
	_cheated = false
	last_won = NO_LEVEL


## Матч не кампании (или обучение) — ничего не учитывать.
func skip() -> void:
	_level = NO_LEVEL


func is_counting() -> bool:
	return _level != NO_LEVEL


func level() -> int:
	return _level


func cheat_used(player_id: int) -> void:
	if player_id == HUMAN_ID:
		_cheated = true


func player_eliminated(player_id: int) -> void:
	if player_id == HUMAN_ID and is_counting():
		_lose()


func match_ended(winner_id: int) -> void:
	if not is_counting():
		return
	if winner_id != HUMAN_ID:
		_lose()
		return
	var level := _level
	_level = NO_LEVEL
	var first := progress.record_win(level)
	last_won = level
	changed.emit()
	level_won.emit(level, not _cheated, first)
	if level == CampaignBalance.LEVEL_COUNT:
		campaign_completed.emit(progress.flawless)


## «Сдаться» или выход посреди матча — поражение.
func forfeit() -> void:
	if is_counting():
		_lose()


## Матч прерван без итога — без последствий.
func abort() -> void:
	_level = NO_LEVEL


func _lose() -> void:
	var level := _level
	_level = NO_LEVEL
	progress.record_loss()
	changed.emit()
	level_lost.emit(level)
