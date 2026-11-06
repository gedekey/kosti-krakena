class_name Bid
extends RefCounted
## Ставка: «на столе как минимум quantity кубиков с гранью face».
## Неизменяемое значение. Правила сравнения — в PerudoRules.

var quantity: int
var face: int


func _init(p_quantity: int, p_face: int) -> void:
	quantity = p_quantity
	face = p_face


func is_ones() -> bool:
	return face == PerudoRules.JOKER_FACE


## Количество ≥ 1 и грань в пределах кубика. Допустимость относительно прошлой ставки — PerudoRules.
func is_well_formed() -> bool:
	return quantity >= 1 and face >= 1 and face <= PerudoRules.FACES


func equals(other: Bid) -> bool:
	return other != null and other.quantity == quantity and other.face == face


func _to_string() -> String:
	return "%dx%d" % [quantity, face]
