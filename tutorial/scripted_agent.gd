class_name ScriptedAgent
extends BotAgent
## Бот по сценарию (М13, обучающий матч): ходы берутся по порядку из списка.
## Наследует BotAgent ради характера (портрет, имя за столом); своих решений не принимает.
## Если ход из сценария сейчас недопустим или сценарий кончился — минимальная ставка
## (или «Ложь!», если ставить нечего).


## Один ход бота: трюк до действия (или null) и действие.
class Turn:
	var cheat: CheatAction
	var action: MatchAction

	func _init(p_action: MatchAction, p_cheat: CheatAction = null) -> void:
		action = p_action
		cheat = p_cheat


var _turns: Array[Turn] = []
var _current: Turn


func _init(p_personality: BotPersonality, turns: Array[Turn],
		rng: RandomNumberGenerator = RandomNumberGenerator.new()) -> void:
	super(p_personality, rng)
	_turns = turns.duplicate()


## Сколько ходов сценария ещё не сыграно.
func remaining() -> int:
	return _turns.size() + (1 if _current != null else 0)


func choose_roll_cheat(_view: PlayerView) -> CheatAction:
	return null


## Контроллер спрашивает трюк в начале каждого хода бота — здесь берём следующий ход.
func choose_turn_cheat(_view: PlayerView) -> CheatAction:
	_current = _turns.pop_front() if not _turns.is_empty() else null
	return _current.cheat if _current != null else null


func choose_action(view: PlayerView) -> MatchAction:
	var turn := _current
	_current = null
	if turn == null and not _turns.is_empty():
		turn = _turns.pop_front()
	if turn != null and view.is_legal(turn.action):
		return turn.action
	var lowest := view.lowest_bid()
	if lowest != null:
		return MatchAction.new(MatchAction.Kind.BID, lowest)
	return MatchAction.dudo()
