class_name MatchController
extends RefCounted
## Контроллер матча Перудо (DESIGN.md §2): состояние, фазы, ходы, раунды, выбывание.
## Без нод и UI. RNG — инъекцией. Наружу — сигналы (MatchEventBridge пробрасывает их в Events)
## и команды: start_match / roll / submit_action / next_round / play_bot_turn.
##
## Цикл: ROLL (бросок ещё не сделан; здесь М4 применит «Утяжелённую кость»)
##   → BIDDING (ходы по кругу) → вскрытие → ROUND_END (итог виден) → следующий раунд
##   … → MATCH_OVER.

enum Phase { IDLE, ROLL, BIDDING, ROUND_END, MATCH_OVER }

enum Result { OK, WRONG_PHASE, NOT_YOUR_TURN, ILLEGAL_ACTION }

const MIN_PLAYERS := 2
const MAX_PLAYERS := 6

signal phase_changed(phase: Phase)
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

var options: RuleOptions
var phase: Phase = Phase.IDLE
var round_number := 0
var round_rules := RoundRules.new()
var dice_counts: Array[int] = []
var current_player: int = PerudoRules.NO_PLAYER
var current_bid: Bid
var current_bidder: int = PerudoRules.NO_PLAYER
var bid_history: Array[BidEntry] = []
var last_reveal: ChallengeReveal
var winner_id: int = PerudoRules.NO_PLAYER

var _agents: Array[MatchAgent] = []
var _rng: RandomNumberGenerator
var _hands: Array = []
var _had_palifico: Array[bool] = []
var _round_starter: int = PerudoRules.NO_PLAYER
var _next_starter: int = PerudoRules.NO_PLAYER
var _next_is_palifico := false


func _init(agents: Array[MatchAgent], p_options: RuleOptions, rng: RandomNumberGenerator) -> void:
	assert(agents.size() >= MIN_PLAYERS and agents.size() <= MAX_PLAYERS,
			"Players: %d..%d" % [MIN_PLAYERS, MAX_PLAYERS])
	_agents = agents.duplicate()
	options = p_options
	_rng = rng


# --- Запросы -------------------------------------------------------------------

func player_count() -> int:
	return _agents.size()


func agent(player_id: int) -> MatchAgent:
	return _agents[player_id]


func is_active(player_id: int) -> bool:
	return dice_counts[player_id] > 0


func total_dice() -> int:
	var total := 0
	for c in dice_counts:
		total += c
	return total


## Кубики игрока в текущем раунде (пусто до броска). UI показывает только свои!
func hand_of(player_id: int) -> Array[int]:
	var hand: Array[int] = []
	if player_id < _hands.size():
		hand.assign(_hands[player_id])
	return hand


func is_waiting_for_human() -> bool:
	return phase == Phase.BIDDING and agent(current_player).is_human()


## Снимок того, что знает игрок: свои кубики, количества у всех, ставки раунда.
func view_for(player_id: int) -> PlayerView:
	var view := PlayerView.new()
	view.player_id = player_id
	view.round_number = round_number
	view.own_dice = hand_of(player_id)
	view.dice_counts = dice_counts.duplicate()
	view.current_bid = current_bid
	view.current_bidder = current_bidder
	view.bid_history = bid_history.duplicate()
	view.round_rules = round_rules
	view.options = options
	return view


func is_action_legal(player_id: int, action: MatchAction) -> bool:
	return _check(player_id, action) == Result.OK


# --- Команды -------------------------------------------------------------------

## Начать матч. first_player = NO_PLAYER — первый ходящий выбирается случайно.
func start_match(first_player: int = PerudoRules.NO_PLAYER) -> void:
	assert(phase == Phase.IDLE, "Match already started")
	dice_counts.clear()
	_had_palifico.clear()
	for i in player_count():
		dice_counts.append(PerudoRules.START_DICE)
		_had_palifico.append(false)
	if first_player == PerudoRules.NO_PLAYER:
		first_player = _rng.randi_range(0, player_count() - 1)
	match_started.emit(player_count(), first_player)
	_begin_round(first_player, false)


## Бросок всех чашек. preset_hands — заданные кубики (обучающий матч М13, тесты);
## размеры должны совпадать с количеством кубиков игроков.
func roll(preset_hands: Array = []) -> void:
	assert(phase == Phase.ROLL, "Roll only in ROLL phase")
	_hands.clear()
	for id in player_count():
		var hand: Array[int] = []
		if preset_hands.is_empty():
			hand = PerudoRules.roll_dice(dice_counts[id], _rng)
		else:
			assert(preset_hands[id].size() == dice_counts[id], "Preset hand size mismatch")
			hand.assign(preset_hands[id])
		_hands.append(hand)
	_set_phase(Phase.BIDDING)
	dice_rolled.emit(round_number)
	_start_turn(_round_starter)


## Действие игрока в его ход. Возвращает Result.OK или причину отказа (состояние не меняется).
func submit_action(player_id: int, action: MatchAction) -> Result:
	var err := _check(player_id, action)
	if err != Result.OK:
		return err
	if action.kind == MatchAction.Kind.BID:
		_apply_bid(player_id, action.bid)
	else:
		_apply_challenge(player_id, action.kind)
	return Result.OK


## Перейти к следующему раунду после итога.
func next_round() -> void:
	assert(phase == Phase.ROUND_END, "next_round only in ROUND_END phase")
	_begin_round(_next_starter, _next_is_palifico)


## Ход текущего бота. Если бот вернул недопустимое действие — берётся запасное.
func play_bot_turn() -> Result:
	if phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	var bot := agent(current_player)
	if bot.is_human():
		return Result.NOT_YOUR_TURN
	var action := bot.choose_action(view_for(current_player))
	if not is_action_legal(current_player, action):
		push_warning("Bot %d chose illegal action %s" % [current_player, action])
		action = _fallback_action()
	return submit_action(current_player, action)


## Один шаг автоматического хода матча (бросок, ход бота, следующий раунд).
## false — ждём человека или матч окончен.
func advance_auto() -> bool:
	match phase:
		Phase.ROLL:
			roll()
		Phase.BIDDING:
			if agent(current_player).is_human():
				return false
			play_bot_turn()
		Phase.ROUND_END:
			next_round()
		_:
			return false
	return true


# --- Внутреннее ----------------------------------------------------------------

func _check(player_id: int, action: MatchAction) -> Result:
	if phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	if player_id != current_player:
		return Result.NOT_YOUR_TURN
	if not ActionRules.is_legal(action, current_bid, round_rules, options, total_dice()):
		return Result.ILLEGAL_ACTION
	return Result.OK


func _fallback_action() -> MatchAction:
	var lowest := ActionRules.lowest_bid(current_bid, round_rules, total_dice())
	if lowest != null:
		return MatchAction.new(MatchAction.Kind.BID, lowest)
	return MatchAction.dudo()


func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


func _begin_round(starter: int, palifico: bool) -> void:
	round_number += 1
	round_rules = RoundRules.new(palifico)
	_round_starter = starter
	current_player = PerudoRules.NO_PLAYER
	current_bid = null
	current_bidder = PerudoRules.NO_PLAYER
	bid_history.clear()
	last_reveal = null
	_hands.clear()
	_set_phase(Phase.ROLL)
	round_started.emit(round_number, starter, palifico)


func _start_turn(player_id: int) -> void:
	current_player = player_id
	turn_started.emit(player_id)


func _apply_bid(player_id: int, bid: Bid) -> void:
	current_bid = bid
	current_bidder = player_id
	bid_history.append(BidEntry.new(player_id, bid))
	bid_placed.emit(player_id, bid)
	_start_turn(PerudoRules.next_active_player(dice_counts, player_id))


func _apply_challenge(caller_id: int, kind: MatchAction.Kind) -> void:
	var result: RevealResult
	if kind == MatchAction.Kind.DUDO:
		result = PerudoRules.resolve_dudo(current_bid, current_bidder, caller_id, _hands, round_rules)
	else:
		result = PerudoRules.resolve_calza(current_bid, caller_id, dice_counts[caller_id],
				_hands, round_rules)
	last_reveal = ChallengeReveal.new(kind, current_bid, current_bidder, caller_id,
			_hands.duplicate(true), round_rules.is_palifico, result)
	current_player = PerudoRules.NO_PLAYER
	challenge_revealed.emit(last_reveal)

	var affected := result.player_id
	_change_dice(affected, result.dice_delta)

	winner_id = PerudoRules.winner(dice_counts)
	if winner_id != PerudoRules.NO_PLAYER:
		_set_phase(Phase.MATCH_OVER)
		match_ended.emit(winner_id)
		return

	_next_starter = PerudoRules.next_round_starter(dice_counts, affected)
	_next_is_palifico = false
	if result.dice_delta < 0 and PerudoRules.triggers_palifico(
			dice_counts[affected], _had_palifico[affected], options):
		_had_palifico[affected] = true
		_next_is_palifico = true
	_set_phase(Phase.ROUND_END)
	round_ended.emit(_next_starter, _next_is_palifico)


## Изменить количество кубиков (М4 переиспользует для штрафа −2).
func _change_dice(player_id: int, delta: int) -> void:
	var before := dice_counts[player_id]
	dice_counts[player_id] = clampi(before + delta, 0, PerudoRules.MAX_DICE)
	var applied := dice_counts[player_id] - before
	dice_count_changed.emit(player_id, dice_counts[player_id], applied)
	if before > 0 and dice_counts[player_id] == 0:
		player_eliminated.emit(player_id)
