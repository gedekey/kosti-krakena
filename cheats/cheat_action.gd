class_name CheatAction
extends RefCounted
## Заявка на трюк. Неизменяемое значение. Какие поля нужны — Cheat.target(kind).

const NONE := -1

var kind: Cheat.Kind
## Сосед-цель (PEEK, NUDGE_CUP).
var target_id: int = NONE
## Индекс кубика: в чашке соседа (PEEK) или своей (SLEIGHT).
var die_index: int = NONE
## Грань (LOADED_DIE, ABYSS_WHISPER).
var face: int = NONE


func _init(p_kind: Cheat.Kind, p_target_id := NONE, p_die_index := NONE, p_face := NONE) -> void:
	kind = p_kind
	target_id = p_target_id
	die_index = p_die_index
	face = p_face


static func peek(target: int, die: int) -> CheatAction:
	return CheatAction.new(Cheat.Kind.PEEK, target, die)


static func sleight(die: int) -> CheatAction:
	return CheatAction.new(Cheat.Kind.SLEIGHT, NONE, die)


static func loaded_die(p_face: int) -> CheatAction:
	return CheatAction.new(Cheat.Kind.LOADED_DIE, NONE, NONE, p_face)


static func nudge_cup(target: int) -> CheatAction:
	return CheatAction.new(Cheat.Kind.NUDGE_CUP, target)


static func sleeve_die() -> CheatAction:
	return CheatAction.new(Cheat.Kind.SLEEVE_DIE)


static func abyss_whisper(p_face: int) -> CheatAction:
	return CheatAction.new(Cheat.Kind.ABYSS_WHISPER, NONE, NONE, p_face)


func _to_string() -> String:
	return "%s(target=%d die=%d face=%d)" % [Cheat.Kind.keys()[kind], target_id, die_index, face]
