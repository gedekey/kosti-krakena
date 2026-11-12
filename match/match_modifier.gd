class_name MatchModifier
extends RefCounted
## Расширяемое правило матча (М23): модификаторы уровней кампании (DESIGN.md §8г) —
## «Дурной глаз», «Скудный рассудок», «Мёртвая рука», «Логово» с приливом.
## Контроллер зовёт хуки в нужные моменты; по умолчанию каждый хук ничего не меняет.
## Без нод. Случайность — только через переданный rng (отдельный от бросков кубиков).
##
## Модификаторы добавляются до start_match (MatchController.add_modifier) и применяются
## по порядку добавления.


## Сколько кубиков у игрока в начале матча.
func start_dice(_player_id: int, dice: int) -> int:
	return dice


## Предел кубиков игрока (больше не вернуть «Точно!»).
func max_dice(_player_id: int, dice: int) -> int:
	return dice


## Рассудок игрока в начале матча.
func start_sanity(_player_id: int, sanity: int) -> int:
	return sanity


## Грань прилива на новый раунд (RoundRules.NO_TIDE — нет). Не зовётся в Palifico.
## tide — то, что вернули модификаторы раньше по порядку.
func round_tide(_match: MatchController, tide: int, _rng: RandomNumberGenerator) -> int:
	return tide


## Кубики брошены (фаза ставок ещё не началась): можно что-то подсмотреть / отметить.
func after_roll(_match: MatchController, _rng: RandomNumberGenerator) -> void:
	pass


## Игрок потерял последний кубик. Больше 0 — он не выбывает и возвращается
## с этим числом кубиков.
func rescue_dice(_match: MatchController, _player_id: int) -> int:
	return 0
