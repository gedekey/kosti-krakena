class_name MatchAgent
extends RefCounted
## Тот, кто выбирает действие за игрока: человек (через UI) или бот.
## Бот получает только PlayerView — никакого доступа к состоянию матча.


## Человек отвечает командами из UI, контроллер у него действие не спрашивает.
func is_human() -> bool:
	return false


## Выбрать действие в свой ход. Должно вернуть допустимое действие.
func choose_action(_view: PlayerView) -> MatchAction:
	push_error("MatchAgent.choose_action is not implemented")
	return null
