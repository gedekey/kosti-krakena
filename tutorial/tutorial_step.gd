class_name TutorialStep
extends RefCounted
## Шаг обучающего матча (М13): что игрок должен сделать и что ему говорит подсказка.
## Неизменяемое значение; список шагов — TutorialScript.steps().

## Команда игрока, которую ждёт шаг. DONE — обучение пройдено.
enum Command { ROLL, BID, LIAR, TRICK, ACCUSE, CONTINUE, DONE }

var command: Command
## Ключ локализации текста подсказки.
var coach_key: String
## BID — какая ставка нужна.
var bid: Bid
## TRICK — какой трюк.
var trick: Cheat.Kind = Cheat.Kind.PEEK
## ACCUSE / TRICK — на кого.
var target_id := CheatAction.NONE


func _init(p_command: Command, p_coach_key: String) -> void:
	command = p_command
	coach_key = p_coach_key


static func roll(key: String) -> TutorialStep:
	return TutorialStep.new(Command.ROLL, key)


static func make_bid(key: String, quantity: int, face: int) -> TutorialStep:
	var s := TutorialStep.new(Command.BID, key)
	s.bid = Bid.new(quantity, face)
	return s


static func liar(key: String) -> TutorialStep:
	return TutorialStep.new(Command.LIAR, key)


static func trick_on(key: String, kind: Cheat.Kind, target: int) -> TutorialStep:
	var s := TutorialStep.new(Command.TRICK, key)
	s.trick = kind
	s.target_id = target
	return s


static func accuse(key: String, target: int) -> TutorialStep:
	var s := TutorialStep.new(Command.ACCUSE, key)
	s.target_id = target
	return s


static func next(key: String) -> TutorialStep:
	return TutorialStep.new(Command.CONTINUE, key)


static func done(key: String) -> TutorialStep:
	return TutorialStep.new(Command.DONE, key)
