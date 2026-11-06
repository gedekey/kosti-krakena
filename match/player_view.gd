class_name PlayerView
extends RefCounted
## То, что знает конкретный игрок в момент своего хода (DESIGN.md §5: боты честны
## в информации). Чужих кубиков здесь нет — только их количество.
## Снимок: изменения контроллера после создания сюда не попадают.

var player_id: int
var round_number: int
## Свои кубики в чашке такими, какими игрок их видел при последнем открытии чашки:
## если сосед «толкнул чашку», здесь старая грань (DESIGN.md §3.2); в Безумии часть
## кубиков может врать (DESIGN.md §4, Perception). Какие врут — не известно.
var own_dice: Array[int] = []
## Открыта ли своя чашка сейчас (закрытая — own_dice по памяти о последнем открытии).
var cup_open := false
var dice_counts: Array[int] = []
var current_bid: Bid
var current_bidder: int = PerudoRules.NO_PLAYER
var bid_history: Array[BidEntry] = []
var round_rules: RoundRules
var options: RuleOptions

# --- Жульничество (М4) ---
## Свой Рассудок. Чужой скрыт (видно только Безумие — mad).
var own_sanity: int = CheatBalance.START_SANITY
## Публично: кто в Безумии (Рассудок 0).
var mad: Array[bool] = []
## Публично: улики за раунд у каждого игрока (истинные и ложные неразличимы).
var evidence: Array[int] = []
## Свои кубики в рукаве на этот раунд (участвуют в подсчёте, на столе не видны).
var sleeve_dice: Array[int] = []
## Итоги своих успешных трюков за раунд (подсмотренные кубики, «Шёпот Бездны»…).
var cheat_outcomes: Array[CheatOutcome] = []
## Окно трюков сейчас и был ли уже трюк в этот ход / бросок.
var cheat_window: CheatRules.CheatWindow = CheatRules.CheatWindow.CLOSED
var cheat_used := false


func total_dice() -> int:
	var total := 0
	for c in dice_counts:
		total += c
	return total


func max_bid_quantity() -> int:
	return total_dice()


func min_quantity_for_face(face: int) -> int:
	return PerudoRules.min_quantity_for_face(current_bid, face, round_rules)


func lowest_bid() -> Bid:
	return ActionRules.lowest_bid(current_bid, round_rules, max_bid_quantity())


func allowed_faces() -> Array[int]:
	return ActionRules.allowed_faces(current_bid, round_rules, max_bid_quantity())


func is_legal(action: MatchAction) -> bool:
	return ActionRules.is_legal(action, current_bid, round_rules, options, max_bid_quantity(),
			player_id, dice_counts)


func can_dudo() -> bool:
	return is_legal(MatchAction.dudo())


func can_calza() -> bool:
	return is_legal(MatchAction.calza())


func can_accuse(target: int) -> bool:
	return is_legal(MatchAction.accuse(target))


func is_mad() -> bool:
	return own_sanity <= 0


## Соседи, на чьи кубики можно направить трюк.
func neighbors() -> Array[int]:
	return CheatRules.neighbors(dice_counts, player_id)


## Трюк по карману и по фазе (без проверки цели — её проверяет контроллер).
func can_afford_cheat(kind: Cheat.Kind) -> bool:
	if cheat_used or is_mad() or own_sanity < Cheat.cost(kind):
		return false
	if Cheat.is_roll_phase(kind):
		return cheat_window == CheatRules.CheatWindow.ROLL
	return cheat_window == CheatRules.CheatWindow.TURN
