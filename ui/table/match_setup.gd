class_name MatchSetup
extends RefCounted
## С чем начинается матч на столе (М9): соперники, портрет игрока, опции правил.
## Экран выбора соперников (М11) заполнит MatchSetup.pending перед переходом на стол;
## без него — игрок + DEFAULT_OPPONENTS случайных разных ботов, правила из Settings.

const DEFAULT_OPPONENTS := 3

## Настройка для следующего стола (null — по умолчанию).
static var pending: MatchSetup

## id персонажей-ботов (BotPersonality.id) по порядку мест. Пусто — случайные.
var opponents: Array[StringName] = []
var opponent_count := DEFAULT_OPPONENTS
var player_portrait: StringName = Sprites.PLAYER_PORTRAITS[0]
var palifico := true
var calza := true
## Обучающий матч (М13): 1×1 против Моряка по сценарию TutorialScript, статистика не ведётся.
var tutorial := false


## Обучающий матч (М13).
static func for_tutorial() -> MatchSetup:
	var setup := MatchSetup.new()
	setup.tutorial = true
	setup.opponents = [TutorialScript.OPPONENT]
	return setup


static func from_settings() -> MatchSetup:
	var setup := MatchSetup.new()
	setup.palifico = Settings.get_value(&"palifico")
	setup.calza = Settings.get_value(&"calza")
	return setup


## Забрать настройку для стола (pending или по умолчанию).
static func take_pending() -> MatchSetup:
	var setup := pending if pending != null else from_settings()
	pending = null
	return setup


func rule_options() -> RuleOptions:
	var options := RuleOptions.new()
	options.palifico_enabled = palifico
	options.calza_enabled = calza
	return options


## Выбрать случайных соперников, если они не заданы (запоминаются — для «Реванша»).
func resolve_opponents(rng: RandomNumberGenerator) -> void:
	if not opponents.is_empty():
		return
	var roster := BotRoster.all()
	var count := clampi(opponent_count, MatchController.MIN_PLAYERS - 1,
			mini(MatchController.MAX_PLAYERS - 1, roster.size()))
	for i in count:
		var p: BotPersonality = roster.pop_at(rng.randi_range(0, roster.size() - 1))
		opponents.append(p.id)
