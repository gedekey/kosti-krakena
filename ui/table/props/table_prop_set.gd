class_name TablePropSet
extends Resource
## Набор «живых» предметов стола (М22, DESIGN.md §6). Данные, а не код: кампания (М23)
## задаёт свой набор на уровень через MatchSetup.table_props (например, свеча культа).
##
## Места выбраны в «мёртвых» зонах стола 640×360 (и Android — раскладка та же): слева между
## лентой ставок и статусом, справа между статусом и сообщениями, на краю стола над своей
## зоной. Там нет кубиков, чашек, кнопок, портретов и панелей.

const DEFAULT_PATH := "res://ui/table/props/default_props.tres"

@export var props: Array[TablePropSlot] = []


## Обычный стол: слева свеча и кружка, справа череп и щель в досках.
static func default_set() -> TablePropSet:
	return load(DEFAULT_PATH) as TablePropSet
