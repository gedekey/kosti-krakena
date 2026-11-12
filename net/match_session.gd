class_name MatchSession
extends RefCounted
## Матч глазами одного игрока — то, с чем работает стол (М19). Стол не знает, локальный
## матч или сетевой:
##   LocalSession  — одиночная игра поверх MatchController;
##   HostSession   — сетевой матч на хосте (считает всё сам);
##   ClientSession — зеркало матча у гостя.
##
## Сигналы — те же, что у MatchController (имена и аргументы совпадают, MatchEventBridge
## пробрасывает их в Events), но только видимые своему игроку: чужие cheat_resolved
## и sanity_changed сюда не приходят.
## Номера игроков: в сети у каждого гостя он сам — место 0 (SeatFrame).
##
## Команды — как у контроллера. В сети roll() и next_round() означают «я готов»:
## бросок и следующий раунд запускает хост, когда готовы все (или вышло время).
## advance_auto() в сети ничего не делает — темп задаёт хост; update() надо звать каждый кадр.

const Phase := MatchController.Phase
const Result := MatchController.Result

signal phase_changed(phase: int)
signal match_started(player_count: int, first_player: int)
signal round_started(round_number: int, starter_id: int, is_palifico: bool)
signal dice_rolled(round_number: int)
signal turn_started(player_id: int)
signal bid_placed(player_id: int, bid: Bid)
signal challenge_revealed(reveal: ChallengeReveal)
signal dice_count_changed(player_id: int, count: int, delta: int)
signal player_eliminated(player_id: int)
signal round_ended(next_starter_id: int, next_is_palifico: bool)
signal match_ended(winner_id: int)
signal cheat_resolved(outcome: CheatOutcome)
signal cheat_failed(player_id: int, kind: int)
signal evidence_shown(player_id: int)
signal sanity_changed(player_id: int, sanity: int, delta: int)
signal madness_began(player_id: int)
signal accusation_made(accuser_id: int, target_id: int, guilty: bool)
signal cup_changed(player_id: int, is_open: bool)
## М23 (кампания, только одиночная игра): «Мёртвая рука» и «Дурной глаз».
signal player_rescued(player_id: int, dice: int)
signal die_watched(watcher_id: int, target_id: int, die_index: int)

# --- Только в сети ---
## Место человека перешло боту (обрыв связи, «Сдаться», «Выйти»).
signal seat_replaced(player_id: int)
## Матч прерван (reason — NetProtocol.Abort): хост вышел, связь потеряна.
signal match_aborted(reason: int)
## Пауза (М21, DESIGN.md §8б): votes из voters людей за столом открыли меню паузы;
## paused — нажали все, матч стоит (таймер хода, боты, темп раундов).
signal pause_changed(paused: bool, votes: int, voters: int)

var phase: int:
	get = _get_phase
var round_number: int:
	get = _get_round_number
var current_player: int:
	get = _get_current_player
var winner_id: int:
	get = _get_winner_id
var dice_counts: Array[int]:
	get = _get_dice_counts
var round_rules: RoundRules:
	get = _get_round_rules
var options: RuleOptions:
	get = _get_options


# --- Запросы -------------------------------------------------------------------

## Свой номер места.
func local_player() -> int:
	return 0


func is_networked() -> bool:
	return false


func player_count() -> int:
	return 0


## Кто сидит на месте (имя, портрет, персонаж бота).
func seat(_player_id: int) -> SeatInfo:
	return null


func is_active(player_id: int) -> bool:
	var counts := dice_counts
	return player_id >= 0 and player_id < counts.size() and counts[player_id] > 0


func total_dice() -> int:
	var total := 0
	for c in dice_counts:
		total += c
	return total


## Что знает свой игрок. Чужой PlayerView недоступен — null.
func view_for(_player_id: int) -> PlayerView:
	return null


## Ход человека (своего или, в сети, чужого) — стол не торопит ботов.
func is_waiting_for_human() -> bool:
	return false


func is_action_legal(player_id: int, action: MatchAction) -> bool:
	var view := view_for(player_id)
	return view != null and phase == Phase.BIDDING and current_player == player_id \
			and view.is_legal(action)


## Почему трюк сейчас нельзя применить (CheatRules.Denied.OK — можно).
func cheat_denial(_player_id: int, _action: CheatAction) -> CheatRules.Denied:
	return CheatRules.Denied.WRONG_PHASE


## Сколько осталось до автохода (мс); −1 — таймера нет (одиночная игра, выключен,
## ход бота).
func turn_time_left_msec() -> int:
	return -1


## Сетевой матч стоит на паузе: её попросили все люди за столом (М21).
func is_match_paused() -> bool:
	return false


## Сколько людей за столом просят паузу и сколько их всего (М21). Вне сети — 0 и 0.
func pause_votes() -> Vector2i:
	return Vector2i.ZERO


# --- Команды -------------------------------------------------------------------

func start_match(_first_player := PerudoRules.NO_PLAYER) -> void:
	pass


func roll(_preset_hands: Array = []) -> void:
	pass


func submit_action(_player_id: int, _action: MatchAction) -> MatchController.Result:
	return Result.WRONG_PHASE


func submit_cheat(_player_id: int, _action: CheatAction) -> MatchController.Result:
	return Result.WRONG_PHASE


func open_cup(_player_id: int) -> MatchController.Result:
	return Result.WRONG_PHASE


func close_cup(_player_id: int) -> MatchController.Result:
	return Result.WRONG_PHASE


func next_round() -> void:
	pass


func advance_auto() -> bool:
	return false


## Свой голос за паузу (М21): меню паузы открыто / закрыто. Вне сети ничего не делает —
## там стол сам ставит дерево на паузу.
func request_pause(_on: bool) -> void:
	pass


## Сеть и таймеры. Звать каждый кадр (в одиночной игре ничего не делает).
func update() -> void:
	pass


## «Сдаться»: в сети место переходит боту, матч идёт дальше без своего игрока.
func surrender() -> void:
	pass


## «Выйти в меню»: место боту (гость) или конец матча для всех (хост), связь закрыта.
func leave() -> void:
	pass


# --- Геттеры свойств (переопределяют наследники) --------------------------------

func _get_phase() -> int:
	return Phase.IDLE


func _get_round_number() -> int:
	return 0


func _get_current_player() -> int:
	return PerudoRules.NO_PLAYER


func _get_winner_id() -> int:
	return PerudoRules.NO_PLAYER


func _get_dice_counts() -> Array[int]:
	return [] as Array[int]


func _get_round_rules() -> RoundRules:
	return RoundRules.new()


func _get_options() -> RuleOptions:
	return RuleOptions.new()
