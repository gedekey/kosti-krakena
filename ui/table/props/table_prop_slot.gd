class_name TablePropSlot
extends Resource
## Один «живой» предмет на столе (М22): что за предмет и где стоит.

## Вид предмета: TableProp.CANDLE, MUG, SKULL, CRACK (новые виды добавляет PropArt).
@export var kind: StringName
## Точка опоры — середина нижнего края, экранные пиксели 640×360.
@export var foot := Vector2i.ZERO


static func make(p_kind: StringName, p_foot: Vector2i) -> TablePropSlot:
	var slot := TablePropSlot.new()
	slot.kind = p_kind
	slot.foot = p_foot
	return slot
