class_name RevealResult
extends RefCounted
## Итог вскрытия после «Лжи!» или «Точно!».

## Сколько на самом деле на столе кубиков нужной грани (по правилам раунда).
var actual_count: int
## «Ложь!»: ставка выполнена (кубиков ≥ заявленного). «Точно!»: кубиков ровно столько.
var bid_holds: bool
## Чьё количество кубиков меняется. Он же начинает следующий раунд (если не выбыл).
var player_id: int
## −1 — потерял кубик, +1 — вернул, 0 — угадал «Точно!», но кубиков уже максимум.
var dice_delta: int


func _init(p_actual_count: int, p_bid_holds: bool, p_player_id: int, p_dice_delta: int) -> void:
	actual_count = p_actual_count
	bid_holds = p_bid_holds
	player_id = p_player_id
	dice_delta = p_dice_delta
