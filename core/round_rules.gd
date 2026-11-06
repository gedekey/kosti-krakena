class_name RoundRules
extends RefCounted
## Правила, действующие в конкретном раунде.

## Раунд Palifico: грань фиксируется первой ставкой, единицы — не джокеры.
var is_palifico: bool


func _init(p_is_palifico := false) -> void:
	is_palifico = p_is_palifico


func ones_wild() -> bool:
	return not is_palifico
