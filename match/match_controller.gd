class_name MatchController
extends RefCounted
## Контроллер матча Перудо (DESIGN.md §2): состояние, фазы, ходы, раунды, выбывание.
## Без нод и UI. RNG — инъекцией. Наружу — сигналы (MatchEventBridge пробрасывает их в Events)
## и команды: start_match / roll / submit_action / next_round / play_bot_turn.
##
## Цикл: ROLL (бросок ещё не сделан; здесь — «Утяжелённая кость»)
##   → BIDDING (ходы по кругу) → вскрытие → ROUND_END (итог виден) → следующий раунд
##   … → MATCH_OVER.
##
## Жульничество (М4, DESIGN.md §3): команда submit_cheat — трюк до своего действия
## (или в фазе броска). Провал или верное обвинение — штраф и досрочный конец раунда
## (ROUND_END без вскрытия, следующий раунд — новый бросок у всех).
## Сигналы с пометкой СЕКРЕТНО UI показывает только своему игроку.
##
## Безумие (М5, DESIGN.md §4): свои кубики игрок видит через слой восприятия Perception.
## Команды open_cup / close_cup; боты переоткрывают чашку в каждый свой ход, кроме первого
## в раунде. Вскрытие и все итоги — всегда по реальным кубикам.
## М9: в Безумии чашка закрывается сама после каждого действия игрока.

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
# --- Жульничество (М4) ---
## СЕКРЕТНО: итог успешного трюка — только для самого жулика.
signal cheat_resolved(outcome: CheatOutcome)
## Публично: трюк мгновенно провалился, жулик пойман (дальше — штраф).
signal cheat_failed(player_id: int, kind: Cheat.Kind)
## Публично: улика у портрета (истинная или ложная — не различить).
signal evidence_shown(player_id: int)
## СЕКРЕТНО: Рассудок игрока изменился (чужой Рассудок скрыт).
signal sanity_changed(player_id: int, sanity: int, delta: int)
## Публично: Рассудок кончился — Безумие до конца матча.
signal madness_began(player_id: int)
## Публично: обвинение и его исход (дальше — штраф).
signal accusation_made(accuser_id: int, target_id: int, guilty: bool)
# --- Безумие (М5) ---
## Публично: игрок открыл / закрыл свою чашку (что он увидел — только в его PlayerView).
signal cup_changed(player_id: int, is_open: bool)

## «Утяжелённая кость» ложится в чашку на это место.
const LOADED_DIE_INDEX := 0
## Соль для отдельного RNG жульничества: трюки и ложные улики не сдвигают броски кубиков.
const CHEAT_RNG_SALT := 0x4b52414b
## Соль для RNG галлюцинаций: открытия чашек не сдвигают ни броски, ни трюки.
const MADNESS_RNG_SALT := 0x4d41444e

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
## Рассудок, журнал раунда, улики, рукава. Читать можно, менять — только через команды.
var cheats: CheatState
## Восприятие своих кубиков (Безумие). Читать можно, менять — только через команды.
var perception: Perception

var _agents: Array[MatchAgent] = []
var _rng: RandomNumberGenerator
var _hands: Array = []
## Свои кубики такими, какими их видел игрок (после «Толкнуть чашку» отличаются от _hands).
var _known_hands: Array = []
var _cheat_rng: RandomNumberGenerator
## Улика от успешного трюка покажется при следующем действии игрока — так же,
## как ложная: по времени появления их не различить.
var _pending_evidence: Array[bool] = []
var _had_palifico: Array[bool] = []
var _round_starter: int = PerudoRules.NO_PLAYER
var _next_starter: int = PerudoRules.NO_PLAYER
var _next_is_palifico := false
## Сколько ходов в этом раунде уже сделал игрок (бот в первый ход видит правду после броска).
var _turns_this_round: Array[int] = []


## cheat_rng — для риска трюков, их бросков и ложных улик; madness_rng — для галлюцинаций.
## По умолчанию оба выводятся из rng.
func _init(agents: Array[MatchAgent], p_options: RuleOptions, rng: RandomNumberGenerator,
		cheat_rng: RandomNumberGenerator = null,
		madness_rng: RandomNumberGenerator = null) -> void:
	assert(agents.size() >= MIN_PLAYERS and agents.size() <= MAX_PLAYERS,
			"Players: %d..%d" % [MIN_PLAYERS, MAX_PLAYERS])
	_agents = agents.duplicate()
	options = p_options
	_rng = rng
	_cheat_rng = cheat_rng
	if _cheat_rng == null:
		_cheat_rng = RandomNumberGenerator.new()
		_cheat_rng.seed = hash([rng.seed, CHEAT_RNG_SALT])
	cheats = CheatState.new(agents.size())
	if madness_rng == null:
		madness_rng = RandomNumberGenerator.new()
		madness_rng.seed = hash([rng.seed, MADNESS_RNG_SALT])
	perception = Perception.new(agents.size(), madness_rng)
	for i in agents.size():
		_pending_evidence.append(false)
		_turns_this_round.append(0)


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


## Настоящие кубики игрока в текущем раунде (пусто до броска). UI их НЕ показывает
## (даже свои: свои — через view_for, там восприятие); только вскрытие и отладка.
func hand_of(player_id: int) -> Array[int]:
	var hand: Array[int] = []
	if player_id < _hands.size():
		hand.assign(_hands[player_id])
	return hand


func is_waiting_for_human() -> bool:
	return phase == Phase.BIDDING and agent(current_player).is_human()


## Снимок того, что знает игрок: свои кубики (как он их видит), количества у всех, ставки.
func view_for(player_id: int) -> PlayerView:
	var view := PlayerView.new()
	view.player_id = player_id
	view.round_number = round_number
	view.dice_counts = dice_counts.duplicate()
	view.current_bid = current_bid
	view.current_bidder = current_bidder
	view.bid_history = bid_history.duplicate()
	view.round_rules = round_rules
	view.options = options
	view.own_dice = perception.seen(player_id)
	view.cup_open = perception.is_cup_open(player_id)
	view.own_sanity = cheats.sanity[player_id]
	for id in player_count():
		view.mad.append(cheats.is_mad(id))
	view.evidence = cheats.evidence.duplicate()
	view.sleeve_dice.assign(cheats.sleeve[player_id])
	view.cheat_outcomes.assign(cheats.outcomes[player_id])
	view.cheat_window = _cheat_window_for(player_id)
	match view.cheat_window:
		CheatRules.CheatWindow.ROLL:
			view.cheat_used = cheats.used_in_roll(player_id)
		CheatRules.CheatWindow.TURN:
			view.cheat_used = cheats.used_this_turn()
	return view


func is_action_legal(player_id: int, action: MatchAction) -> bool:
	return _check(player_id, action) == Result.OK


## Почему трюк сейчас нельзя применить (CheatRules.Denied.OK — можно).
func cheat_denial(player_id: int, action: CheatAction) -> CheatRules.Denied:
	var window := _cheat_window_for(player_id)
	if window == CheatRules.CheatWindow.CLOSED and phase == Phase.BIDDING:
		window = CheatRules.CheatWindow.TURN  # чужой ход: CheatRules ответит NOT_YOUR_TURN
	return CheatRules.check(cheats, player_id, action, window, current_player,
			dice_counts, _hands)


## Журнал раунда: кто жульничал (по порядку первого трюка). Для отладки и итогов раунда.
func cheaters_this_round() -> Array[int]:
	return cheats.cheaters_this_round()


## ОТЛАДКА: номера своих кубиков, которые сейчас показывают не то (игрок этого не знает).
func lying_dice(player_id: int) -> Array[int]:
	return perception.lying_dice(player_id)


## Кубики в рукаве игрока на этот раунд.
func sleeve_of(player_id: int) -> Array[int]:
	var out: Array[int] = []
	out.assign(cheats.sleeve[player_id])
	return out


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
	_ask_bots_for_roll_cheats()
	if phase != Phase.ROLL:
		return  # бот попался на «Утяжелённой кости» — раунд окончен досрочно
	_hands.clear()
	for id in player_count():
		var hand: Array[int] = []
		if preset_hands.is_empty():
			hand = PerudoRules.roll_dice(dice_counts[id], _rng)
		else:
			assert(preset_hands[id].size() == dice_counts[id], "Preset hand size mismatch")
			hand.assign(preset_hands[id])
		if cheats.loaded.has(id) and not hand.is_empty():
			hand[LOADED_DIE_INDEX] = cheats.loaded[id]
		_hands.append(hand)
	_known_hands = _hands.duplicate(true)
	perception.reset(_known_hands)
	_set_phase(Phase.BIDDING)
	dice_rolled.emit(round_number)
	_start_turn(_round_starter)


## Действие игрока в его ход. Возвращает Result.OK или причину отказа (состояние не меняется).
func submit_action(player_id: int, action: MatchAction) -> Result:
	var err := _check(player_id, action)
	if err != Result.OK:
		return err
	_maybe_show_evidence(player_id)
	_turns_this_round[player_id] += 1
	match action.kind:
		MatchAction.Kind.BID:
			_apply_bid(player_id, action.bid)
		MatchAction.Kind.ACCUSE:
			_apply_accusation(player_id, action.target_id)
		_:
			_apply_challenge(player_id, action.kind)
	_close_cup_if_mad(player_id)
	return Result.OK


## Трюк (DESIGN.md §3). Тратит Рассудок, бросает риск; провал — штраф сразу.
## Итог — сигнал cheat_resolved (секретно) и PlayerView.cheat_outcomes жулика.
func submit_cheat(player_id: int, action: CheatAction) -> Result:
	match cheat_denial(player_id, action):
		CheatRules.Denied.OK:
			pass
		CheatRules.Denied.WRONG_PHASE:
			return Result.WRONG_PHASE
		CheatRules.Denied.NOT_YOUR_TURN:
			return Result.NOT_YOUR_TURN
		_:
			return Result.ILLEGAL_ACTION

	var kind := action.kind
	cheats.mark_used(player_id, kind)
	_change_sanity(player_id, -Cheat.cost(kind))
	var outcome := CheatOutcome.new(player_id, action)
	if _cheat_fails(kind):
		outcome.failed = true
		cheats.record(outcome)
		cheat_failed.emit(player_id, kind)
		_catch(player_id)
		return Result.OK

	_apply_cheat_effect(outcome)
	cheats.record(outcome)
	if Cheat.leaves_evidence(kind) and _trick_leaves_evidence():
		_pending_evidence[player_id] = true
	cheat_resolved.emit(outcome)
	return Result.OK


## Открыть свою чашку (свободно, в фазе ставок, в любой ход). В Безумии каждое открытие
## пересчитывает галлюцинации. Уже открытая — ILLEGAL_ACTION.
func open_cup(player_id: int) -> Result:
	var err := _check_cup(player_id)
	if err != Result.OK:
		return err
	var known: Array[int] = []
	known.assign(_known_hands[player_id])
	if not perception.open_cup(player_id, known, cheats.is_mad(player_id)):
		return Result.ILLEGAL_ACTION
	cup_changed.emit(player_id, true)
	return Result.OK


## Закрыть свою чашку. Уже закрытая — ILLEGAL_ACTION.
func close_cup(player_id: int) -> Result:
	var err := _check_cup(player_id)
	if err != Result.OK:
		return err
	if not perception.close_cup(player_id):
		return Result.ILLEGAL_ACTION
	cup_changed.emit(player_id, false)
	return Result.OK


## ОТЛАДКА и тесты: задать Рассудок (0 — Безумие, с обычными сигналами).
func debug_set_sanity(player_id: int, value: int) -> void:
	var target := clampi(value, 0, CheatBalance.START_SANITY)
	if target < cheats.sanity[player_id]:
		_change_sanity(player_id, target - cheats.sanity[player_id])
	elif target > cheats.sanity[player_id]:
		var delta := target - cheats.sanity[player_id]
		cheats.sanity[player_id] = target
		sanity_changed.emit(player_id, target, delta)


## Перейти к следующему раунду после итога.
func next_round() -> void:
	assert(phase == Phase.ROUND_END, "next_round only in ROUND_END phase")
	_begin_round(_next_starter, _next_is_palifico)


## Ход текущего бота. Если бот вернул недопустимое действие — берётся запасное.
func play_bot_turn() -> Result:
	if phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	var bot_id := current_player
	var bot := agent(bot_id)
	if bot.is_human():
		return Result.NOT_YOUR_TURN
	_bot_looks_at_cup(bot_id)
	var cheat := bot.choose_turn_cheat(view_for(bot_id))
	if cheat != null:
		if submit_cheat(bot_id, cheat) != Result.OK:
			push_warning("Bot %d chose illegal cheat %s" % [bot_id, cheat])
		if phase != Phase.BIDDING:
			return Result.OK  # попался — раунд окончен досрочно
	var action := bot.choose_action(view_for(bot_id))
	if not is_action_legal(bot_id, action):
		push_warning("Bot %d chose illegal action %s" % [bot_id, action])
		action = _fallback_action()
	return submit_action(bot_id, action)


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
	if not ActionRules.is_legal(action, current_bid, round_rules, options, total_dice(),
			player_id, dice_counts):
		return Result.ILLEGAL_ACTION
	return Result.OK


func _check_cup(player_id: int) -> Result:
	if phase != Phase.BIDDING:
		return Result.WRONG_PHASE
	if player_id < 0 or player_id >= player_count() or not is_active(player_id):
		return Result.ILLEGAL_ACTION
	return Result.OK


## Бот в первый свой ход раунда видит правду после броска, в следующие — переоткрывает
## чашку (в Безумии — новые галлюцинации). Та же модель, что у игрока.
func _bot_looks_at_cup(bot_id: int) -> void:
	if _turns_this_round[bot_id] > 0:
		close_cup(bot_id)
		open_cup(bot_id)


## М9 (решение автора): в Безумии чашка сама закрывается после действия игрока —
## чтобы снова увидеть кубики, её надо открыть (с новыми галлюцинациями).
func _close_cup_if_mad(player_id: int) -> void:
	if phase == Phase.BIDDING and cheats.is_mad(player_id) \
			and perception.is_cup_open(player_id):
		close_cup(player_id)


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
	_known_hands.clear()
	perception.clear()
	cheats.begin_round()
	for i in player_count():
		_pending_evidence[i] = false
		_turns_this_round[i] = 0
	_set_phase(Phase.ROLL)
	round_started.emit(round_number, starter, palifico)


func _start_turn(player_id: int) -> void:
	current_player = player_id
	cheats.begin_turn()
	turn_started.emit(player_id)


func _apply_bid(player_id: int, bid: Bid) -> void:
	current_bid = bid
	current_bidder = player_id
	bid_history.append(BidEntry.new(player_id, bid))
	bid_placed.emit(player_id, bid)
	_start_turn(PerudoRules.next_active_player(dice_counts, player_id))


func _apply_challenge(caller_id: int, kind: MatchAction.Kind) -> void:
	var result: RevealResult
	var tally := _tally_hands()
	if kind == MatchAction.Kind.DUDO:
		result = PerudoRules.resolve_dudo(current_bid, current_bidder, caller_id, tally, round_rules)
	else:
		result = PerudoRules.resolve_calza(current_bid, caller_id, dice_counts[caller_id],
				tally, round_rules)
	last_reveal = ChallengeReveal.new(kind, current_bid, current_bidder, caller_id,
			_hands.duplicate(true), round_rules.is_palifico, result, cheats.sleeve.duplicate(true))
	current_player = PerudoRules.NO_PLAYER
	challenge_revealed.emit(last_reveal)
	_finish_round(result.player_id, result.dice_delta)


## «Обвинить»: жульничал ли target в этом раунде. Штраф и досрочный конец раунда.
func _apply_accusation(accuser_id: int, target_id: int) -> void:
	var guilty := cheats.cheated_this_round(target_id)
	current_player = PerudoRules.NO_PLAYER
	accusation_made.emit(accuser_id, target_id, guilty)
	if guilty:
		_catch(target_id)
	else:
		_finish_round(accuser_id, -CheatBalance.FALSE_ACCUSATION_PENALTY)


## Жулик пойман: −Рассудок (CheatBalance.CAUGHT_SANITY_PENALTY), рукав пуст,
## −CAUGHT_DICE_PENALTY кубиков, раунд окончен досрочно.
func _catch(player_id: int) -> void:
	cheats.sleeve[player_id] = [] as Array[int]
	_change_sanity(player_id, -CheatBalance.CAUGHT_SANITY_PENALTY)
	current_player = PerudoRules.NO_PLAYER
	_finish_round(player_id, -CheatBalance.CAUGHT_DICE_PENALTY)


## Итог раунда: изменить кубики affected, проверить победу, назначить следующий раунд.
## Начинает тот, чьи кубики изменились (если выбыл — следующий по кругу).
func _finish_round(affected: int, delta: int) -> void:
	_change_dice(affected, delta)

	winner_id = PerudoRules.winner(dice_counts)
	if winner_id != PerudoRules.NO_PLAYER:
		_set_phase(Phase.MATCH_OVER)
		match_ended.emit(winner_id)
		return

	_next_starter = PerudoRules.next_round_starter(dice_counts, affected)
	_next_is_palifico = false
	if delta < 0 and PerudoRules.triggers_palifico(
			dice_counts[affected], _had_palifico[affected], options):
		_had_palifico[affected] = true
		_next_is_palifico = true
	_set_phase(Phase.ROUND_END)
	round_ended.emit(_next_starter, _next_is_palifico)


## Изменить количество кубиков (исход вскрытия и штрафы за жульничество).
func _change_dice(player_id: int, delta: int) -> void:
	var before := dice_counts[player_id]
	dice_counts[player_id] = clampi(before + delta, 0, PerudoRules.MAX_DICE)
	var applied := dice_counts[player_id] - before
	dice_count_changed.emit(player_id, dice_counts[player_id], applied)
	if before > 0 and dice_counts[player_id] == 0:
		player_eliminated.emit(player_id)


# --- Жульничество ----------------------------------------------------------------

func _cheat_window_for(player_id: int) -> CheatRules.CheatWindow:
	match phase:
		Phase.ROLL:
			return CheatRules.CheatWindow.ROLL
		Phase.BIDDING:
			if player_id == current_player:
				return CheatRules.CheatWindow.TURN
	return CheatRules.CheatWindow.CLOSED


func _ask_bots_for_roll_cheats() -> void:
	for id in player_count():
		if phase != Phase.ROLL:
			return
		if not is_active(id) or agent(id).is_human():
			continue
		var cheat := agent(id).choose_roll_cheat(view_for(id))
		if cheat != null and submit_cheat(id, cheat) != Result.OK:
			push_warning("Bot %d chose illegal roll cheat %s" % [id, cheat])


func _apply_cheat_effect(outcome: CheatOutcome) -> void:
	var p := outcome.player_id
	var a := outcome.action
	match a.kind:
		Cheat.Kind.PEEK:
			outcome.peeked_face = _hands[a.target_id][a.die_index]
		Cheat.Kind.SLEIGHT:
			var face := _roll_one()
			_hands[p][a.die_index] = face
			_known_hands[p][a.die_index] = face
			perception.set_seen_die(p, a.die_index, face)
			outcome.new_face = face
			outcome.die_index = a.die_index
		Cheat.Kind.LOADED_DIE:
			cheats.loaded[p] = a.face
			outcome.new_face = a.face
			outcome.die_index = LOADED_DIE_INDEX
		Cheat.Kind.NUDGE_CUP:
			# Ни жулик, ни сосед не узнают ни какой кубик, ни что выпало.
			var hand: Array = _hands[a.target_id]
			hand[_cheat_rng.randi_range(0, hand.size() - 1)] = _roll_one()
		Cheat.Kind.SLEEVE_DIE:
			var face := _roll_one()
			cheats.sleeve[p].append(face)
			outcome.new_face = face
		Cheat.Kind.ABYSS_WHISPER:
			outcome.whisper_counts = CheatRules.whisper_counts(a.face, _hands, cheats.sleeve,
					round_rules.ones_wild())
			outcome.whisper_count = CheatRules.whisper_count(p, a.face, _hands, cheats.sleeve,
					round_rules.ones_wild())


func _cheat_fails(kind: Cheat.Kind) -> bool:
	var risk := Cheat.risk(kind)
	match cheats.risk_mode:
		CheatState.RiskMode.NEVER_FAIL:
			return false
		CheatState.RiskMode.ALWAYS_FAIL:
			return risk > 0.0
	return _cheat_rng.randf() < risk


func _roll_one() -> int:
	return _cheat_rng.randi_range(1, PerudoRules.FACES)


## Чашки + рукава: по ним считается итог вскрытия.
func _tally_hands() -> Array:
	var tally := []
	for id in _hands.size():
		var hand: Array = _hands[id].duplicate()
		hand.append_array(cheats.sleeve[id])
		tally.append(hand)
	return tally


## Оставит ли успешный трюк улику. При шансе 1 RNG не трогаем (детерминизм прежних сидов).
func _trick_leaves_evidence() -> bool:
	if cheats.trick_evidence_chance >= 1.0:
		return true
	return _cheat_rng.randf() < cheats.trick_evidence_chance


## При действии игрока: улика от его трюка (отложенная) или, если он честен в этот ход,
## ложная улика с шансом cheats.false_evidence_chance.
func _maybe_show_evidence(player_id: int) -> void:
	var show := _pending_evidence[player_id]
	_pending_evidence[player_id] = false
	if not show and cheats.honest_this_turn():
		show = _cheat_rng.randf() < cheats.false_evidence_chance
	if show:
		cheats.add_evidence(player_id)
		evidence_shown.emit(player_id)


func _change_sanity(player_id: int, delta: int) -> void:
	var before := cheats.sanity[player_id]
	cheats.spend(player_id, -delta)
	var applied := cheats.sanity[player_id] - before
	if applied == 0:
		return
	sanity_changed.emit(player_id, cheats.sanity[player_id], applied)
	if before > 0 and cheats.is_mad(player_id):
		madness_began.emit(player_id)
