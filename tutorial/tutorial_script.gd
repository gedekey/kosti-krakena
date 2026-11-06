class_name TutorialScript
extends RefCounted
## Сценарий обучающего матча (М13, DESIGN.md §7): 1×1 против Моряка с заданными кубиками.
## Шаги: ставка → «Ложь!» → единицы-джокеры → «Подглядеть» → улика у Моряка → «Обвинить».
##
##   Раунд 1. Игрок открывает 2 × 3, Моряк блефует 5 × 4, игрок — «Ложь!».
##            Четвёрок две — Моряк теряет кубик.
##   Раунд 2. Моряк открывает 3 × 5. У игрока две пятёрки и две единицы — ставит 5 × 5,
##            Моряк — «Ложь!». Пятёрок с единицами шесть — Моряк теряет кубик.
##   Раунд 3. Моряк открывает 2 × 6. Игрок подглядывает кубик Моряка и ставит 3 × 6.
##            Моряк прячет кубик в рукав (улика) и ставит 4 × 6. Игрок обвиняет — верно:
##            Моряк −2 кубика и Безумие.
## Трюки в обучении не проваливаются, ложных улик нет — сценарий не ломается случаем.

const HUMAN_ID := 0
const SAILOR_ID := 1
const OPPONENT := &"sailor"
const FIRST_PLAYER := HUMAN_ID

## Кубики по раундам: [игрок, Моряк]. Размеры совпадают с количеством кубиков в раунде.
const HANDS := [
	[[3, 3, 5, 2, 6], [4, 4, 2, 6, 5]],
	[[1, 1, 5, 5, 2], [5, 3, 1, 6]],
	[[6, 2, 2, 4, 3], [6, 3, 2]],
]


static func steps() -> Array[TutorialStep]:
	var s: Array[TutorialStep] = [
		TutorialStep.roll("TUT_ROLL_1"),
		TutorialStep.make_bid("TUT_BID_1", 2, 3),
		TutorialStep.liar("TUT_LIAR_1"),
		TutorialStep.next("TUT_RESULT_1"),
		TutorialStep.roll("TUT_ROLL_2"),
		TutorialStep.make_bid("TUT_ONES", 5, 5),
		TutorialStep.next("TUT_RESULT_2"),
		TutorialStep.roll("TUT_ROLL_3"),
		TutorialStep.trick_on("TUT_PEEK", Cheat.Kind.PEEK, SAILOR_ID),
		TutorialStep.make_bid("TUT_BID_3", 3, 6),
		TutorialStep.accuse("TUT_ACCUSE", SAILOR_ID),
		TutorialStep.next("TUT_RESULT_3"),
		TutorialStep.done("TUT_DONE"),
	]
	return s


## Ходы Моряка по порядку.
static func sailor_turns() -> Array[ScriptedAgent.Turn]:
	var t: Array[ScriptedAgent.Turn] = [
		ScriptedAgent.Turn.new(MatchAction.make_bid(5, 4)),
		ScriptedAgent.Turn.new(MatchAction.make_bid(3, 5)),
		ScriptedAgent.Turn.new(MatchAction.dudo()),
		ScriptedAgent.Turn.new(MatchAction.make_bid(2, 6)),
		ScriptedAgent.Turn.new(MatchAction.make_bid(4, 6), CheatAction.sleeve_die()),
	]
	return t


static func make_agents() -> Array[MatchAgent]:
	var agents: Array[MatchAgent] = [
		HumanAgent.new(),
		ScriptedAgent.new(BotRoster.by_id(OPPONENT), sailor_turns()),
	]
	return agents


## Правила обучения не зависят от настроек игрока (сценарий рассчитан на обе опции).
static func rule_options() -> RuleOptions:
	var options := RuleOptions.new()
	options.palifico_enabled = true
	options.calza_enabled = true
	return options


static func make_controller(rng: RandomNumberGenerator) -> MatchController:
	var mc := MatchController.new(make_agents(), rule_options(), rng)
	mc.cheats.risk_mode = CheatState.RiskMode.NEVER_FAIL
	mc.cheats.false_evidence_chance = 0.0
	return mc


## Кубики раунда round_number (с 1) или [] — бросок по-честному (сценарий кончился
## или количество кубиков не совпало).
static func hands_for(round_number: int, dice_counts: Array[int]) -> Array:
	if round_number < 1 or round_number > HANDS.size():
		return []
	var hands: Array = HANDS[round_number - 1]
	if hands.size() != dice_counts.size():
		return []
	for id in hands.size():
		if (hands[id] as Array).size() != dice_counts[id]:
			return []
	return hands.duplicate(true)
