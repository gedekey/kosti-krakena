class_name CheatOutcome
extends RefCounted
## Итог трюка. СЕКРЕТНО: знает только сам жулик (UI показывает его только своему игроку,
## бот видит свои итоги в PlayerView.cheat_outcomes). Публичны лишь провал и улика.

const NONE := -1

var player_id: int
var action: CheatAction
## Мгновенный провал: трюк не сработал, жулик пойман.
var failed := false
## PEEK: грань подсмотренного кубика.
var peeked_face: int = NONE
## ABYSS_WHISPER: сколько кубиков грани action.face у остальных (по правилам раунда).
var whisper_count: int = NONE
## SLEIGHT, SLEEVE_DIE: новая грань своего кубика. LOADED_DIE: заданная грань.
## NUDGE_CUP: не заполняется — результат не знает никто.
var new_face: int = NONE
## Индекс кубика, который изменился (SLEIGHT, LOADED_DIE — в своей чашке).
var die_index: int = NONE


func _init(p_player_id: int, p_action: CheatAction) -> void:
	player_id = p_player_id
	action = p_action
