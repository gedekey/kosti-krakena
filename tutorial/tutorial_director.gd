class_name TutorialDirector
extends RefCounted
## Ведёт обучающий матч по шагам (М13). Без нод и UI: слушает сигналы MatchController,
## решает, какую команду игрока сейчас пустить, и переходит к следующему шагу, когда
## игрок её выполнил. UI спрашивает allows_*() и показывает coach_key текущего шага.
##
## Шаг «готов», когда до него дошла игра: бросок — в фазе броска, действие — в ход
## игрока, «Дальше» — на итоге раунда. Пока не готов (ходит Моряк), подсказка ждёт.

signal step_changed(index: int)
signal finished

const HUMAN_ID := TutorialScript.HUMAN_ID

var index := 0
var _steps: Array[TutorialStep] = []
var _mc: MatchController


func _init(controller: MatchController, steps: Array[TutorialStep] = []) -> void:
	_mc = controller
	_steps = steps if not steps.is_empty() else TutorialScript.steps()
	_mc.dice_rolled.connect(_on_dice_rolled)
	_mc.bid_placed.connect(_on_bid_placed)
	_mc.challenge_revealed.connect(_on_challenge_revealed)
	_mc.cheat_resolved.connect(_on_cheat_resolved)
	_mc.accusation_made.connect(_on_accusation_made)


func step() -> TutorialStep:
	return _steps[mini(index, _steps.size() - 1)]


func step_count() -> int:
	return _steps.size()


func is_finished() -> bool:
	return step().command == TutorialStep.Command.DONE


## Дошла ли игра до текущего шага (иначе — ход Моряка или анимация, подсказка ждёт).
func is_ready() -> bool:
	match step().command:
		TutorialStep.Command.ROLL:
			return _mc.phase == MatchController.Phase.ROLL
		TutorialStep.Command.BID, TutorialStep.Command.LIAR, TutorialStep.Command.TRICK, \
				TutorialStep.Command.ACCUSE:
			return _mc.is_waiting_for_human() and _mc.current_player == HUMAN_ID
		TutorialStep.Command.CONTINUE:
			return _mc.phase == MatchController.Phase.ROUND_END
	return true


func allows(command: TutorialStep.Command) -> bool:
	return step().command == command and is_ready()


func allows_bid(bid: Bid) -> bool:
	return allows(TutorialStep.Command.BID) and bid != null and bid.equals(step().bid)


func allows_trick(kind: Cheat.Kind) -> bool:
	return allows(TutorialStep.Command.TRICK) and kind == step().trick


func allows_trick_target(target_id: int) -> bool:
	return allows(TutorialStep.Command.TRICK) and target_id == step().target_id


func allows_accuse(target_id: int) -> bool:
	return allows(TutorialStep.Command.ACCUSE) and target_id == step().target_id


## Ставка, которую ждёт шаг (null — шаг не про ставку).
func expected_bid() -> Bid:
	return step().bid if step().command == TutorialStep.Command.BID else null


## Кубики для броска текущего раунда ([] — по-честному).
func preset_hands() -> Array:
	return TutorialScript.hands_for(_mc.round_number, _mc.dice_counts)


## Игрок нажал «Дальше» на итоге раунда.
func notify_continue() -> void:
	if allows(TutorialStep.Command.CONTINUE):
		_advance()


func _advance() -> void:
	if is_finished():
		return
	index += 1
	step_changed.emit(index)
	if is_finished():
		finished.emit()


func _on_dice_rolled(_round_number: int) -> void:
	if step().command == TutorialStep.Command.ROLL:
		_advance()


func _on_bid_placed(player_id: int, bid: Bid) -> void:
	if player_id == HUMAN_ID and step().command == TutorialStep.Command.BID \
			and bid.equals(step().bid):
		_advance()


func _on_challenge_revealed(reveal: ChallengeReveal) -> void:
	if reveal.caller_id == HUMAN_ID and step().command == TutorialStep.Command.LIAR:
		_advance()


func _on_cheat_resolved(outcome: CheatOutcome) -> void:
	if outcome.player_id == HUMAN_ID and step().command == TutorialStep.Command.TRICK \
			and outcome.action.kind == step().trick:
		_advance()


func _on_accusation_made(accuser_id: int, _target_id: int, _guilty: bool) -> void:
	if accuser_id == HUMAN_ID and step().command == TutorialStep.Command.ACCUSE:
		_advance()
