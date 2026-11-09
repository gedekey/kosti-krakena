class_name SeatFrame
extends RefCounted
## Система отсчёта мест для одного получателя: у каждого гостя он сам — место 0,
## остальные идут по кругу в том же порядке (следующий по ходу — 1 и т.д.).
## Так стол (М19) везде рисует своего игрока снизу, как в одиночной игре.
## Хост сидит на месте 0, его система отсчёта совпадает с общей.

## Глобальный номер места получателя.
var seat: int
var count: int


func _init(p_seat: int, p_count: int) -> void:
	seat = p_seat
	count = p_count


## Тождественная система (номера уже локальные — так гость проверяет входящее).
static func identity(p_count: int) -> SeatFrame:
	return SeatFrame.new(0, p_count)


## Глобальный номер → номер у получателя. NO_PLAYER остаётся NO_PLAYER.
func to_local(id: int) -> int:
	if id == PerudoRules.NO_PLAYER:
		return id
	return posmod(id - seat, count)


## Номер у получателя → глобальный. NO_PLAYER остаётся NO_PLAYER.
func to_global(id: int) -> int:
	if id == PerudoRules.NO_PLAYER:
		return id
	return posmod(id + seat, count)


## Номер места у получателя: 0..count-1.
func is_seat(id: Variant) -> bool:
	return typeof(id) == TYPE_INT and id >= 0 and id < count


## Массив по игрокам (индекс — глобальный номер) → массив в системе получателя.
func rotate(by_player: Array) -> Array:
	var out := []
	for local in by_player.size():
		out.append(by_player[to_global(local)])
	return out
