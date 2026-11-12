class_name RoundRules
extends RefCounted
## Правила, действующие в конкретном раунде.

## «Прилив» не объявлен.
const NO_TIDE := 0

## Раунд Palifico: грань фиксируется первой ставкой, единицы — не джокеры.
var is_palifico: bool
## М23 (кампания, «Логово»): грань прилива — джокер вместе с единицами; NO_TIDE — нет.
## В Palifico прилива не бывает (как и единиц-джокеров).
var tide_face := NO_TIDE


func _init(p_is_palifico := false, p_tide_face := NO_TIDE) -> void:
	is_palifico = p_is_palifico
	tide_face = NO_TIDE if p_is_palifico else p_tide_face


func ones_wild() -> bool:
	return not is_palifico


## Грань прилива, если она сейчас джокер (иначе NO_TIDE).
func tide() -> int:
	return NO_TIDE if is_palifico else tide_face
