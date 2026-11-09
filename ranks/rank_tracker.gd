class_name RankTracker
extends RefCounted
## Ранги игрока (М20, DESIGN.md §8в): одиночный и сетевой. Чистая логика без нод: стол
## начинает учёт (begin_match), события матча пробрасывает автозагрузка Ranks.
##
## Место игрока HUMAN_ID определяется один раз: выбыл, победил или сдался / вышел
## (forfeit — как выбывание в этот момент). Дальше события матча ранг не трогают.
## Матч, брошенный без места (обрыв связи, хост ушёл), ранг не меняет.

signal settled(change: RankChange)
## Изменилось то, что сохраняется.
signal changed

enum Mode { SINGLE, NET }

const HUMAN_ID := 0

var _ladders := {Mode.SINGLE: RankLadder.new(), Mode.NET: RankLadder.new()}

## Итог последнего засчитанного матча (null — ещё нет или матч не считается).
var last_change: RankChange

var _in_match := false
var _mode: Mode = Mode.SINGLE
var _player_count := 0
var _alive := 0
var _gain_multiplier := 1.0


func ladder(mode: Mode) -> RankLadder:
	return _ladders[mode]


func tier(mode: Mode) -> RankBalance.Tier:
	return _ladders[mode].tier


func glory(mode: Mode) -> int:
	return _ladders[mode].glory


## Матч идёт и ранг за него ещё не начислен.
func is_counting() -> bool:
	return _in_match


# --- Начало матча --------------------------------------------------------------------

## Одиночный матч: bot_stars — звёзды ботов за столом.
func begin_single(player_count: int, bot_stars: Array[int]) -> void:
	_begin(Mode.SINGLE, player_count, RankBalance.star_multiplier(bot_stars))


## Сетевой матч: humans — людей за столом в начале. Меньше NET_MIN_HUMANS — не считается.
func begin_net(player_count: int, humans: int) -> void:
	if humans < RankBalance.NET_MIN_HUMANS:
		skip()
		return
	_begin(Mode.NET, player_count, 1.0)


## Матч не на ранг (обучение, сеть без второго человека).
func skip() -> void:
	_in_match = false
	last_change = null


func _begin(mode: Mode, player_count: int, gain_multiplier: float) -> void:
	_in_match = true
	_mode = mode
	_player_count = player_count
	_alive = player_count
	_gain_multiplier = gain_multiplier
	last_change = null


# --- События матча -------------------------------------------------------------------

func player_eliminated(player_id: int) -> void:
	if not _in_match:
		return
	if player_id == HUMAN_ID:
		_settle(_alive)
	else:
		_alive = maxi(_alive - 1, 1)


func match_ended(winner_id: int) -> void:
	if not _in_match:
		return
	_settle(1 if winner_id == HUMAN_ID else _alive)


## Сдался или вышел посреди матча — худшее место среди оставшихся.
func forfeit() -> void:
	if _in_match:
		_settle(_alive)


## Матч прерван без места (обрыв связи) — ранг не меняется.
func abort() -> void:
	_in_match = false


func _settle(place: int) -> void:
	_in_match = false
	var lad: RankLadder = _ladders[_mode]
	var change := lad.apply(lad.place_glory(place, _player_count, _gain_multiplier))
	change.mode = _mode
	change.place = place
	change.player_count = _player_count
	last_change = change
	changed.emit()
	settled.emit(change)


# --- Сохранение ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"single": _ladders[Mode.SINGLE].to_dict(), "net": _ladders[Mode.NET].to_dict()}


func from_dict(data: Dictionary) -> void:
	reset()
	for key: String in ["single", "net"]:
		var value: Variant = data.get(key, {})
		if value is Dictionary:
			_ladders[Mode.SINGLE if key == "single" else Mode.NET].from_dict(value)


## Оба ранга — Дерево, 0 Славы.
func reset() -> void:
	_ladders = {Mode.SINGLE: RankLadder.new(), Mode.NET: RankLadder.new()}
	_in_match = false
	last_change = null
