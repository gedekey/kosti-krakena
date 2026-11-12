class_name BotCheatPlanner
extends RefCounted
## Когда и какой трюк применяет бот (М6, DESIGN.md §3). Только PlayerView и характер.
##
## Ход: с шансом cheat_chance (меньше, если у портрета бота уже есть улики) бот выбирает
## трюк по весам любимых трюков среди тех, что:
##   - по карману и не нарушают запас Рассудка (sanity_reserve);
##   - не рискованнее risk_tolerance;
##   - сейчас полезны: разведка — когда ставка спорная, «Толкнуть чашку» — перед «Ложь!»,
##     «Ловкость рук» — есть «лишний» свой кубик, рукав — не больше одного за раунд.
## Фаза броска: «Утяжелённая кость» с шансом cheat_chance × доля её веса.

var personality: BotPersonality
var _rng: RandomNumberGenerator


func _init(p_personality: BotPersonality, rng: RandomNumberGenerator) -> void:
	personality = p_personality
	_rng = rng


## Трюк в фазе броска или null.
func choose_roll_cheat(view: PlayerView) -> CheatAction:
	var kind := Cheat.Kind.LOADED_DIE
	if not _allowed(view, kind):
		return null
	var total := _total_weight()
	if total <= 0.0:
		return null
	var chance := personality.cheat_chance * personality.cheat_weight(kind) / total
	if _rng.randf() >= chance:
		return null
	# Единица-джокер подходит к любой ставке; без джокеров — случайная грань.
	var face := PerudoRules.JOKER_FACE
	if not view.round_rules.ones_wild():
		face = _rng.randi_range(1, PerudoRules.FACES)
	return CheatAction.loaded_die(face)


## Трюк в свой ход до действия или null. estimate — стол глазами бота.
func choose_turn_cheat(view: PlayerView, estimate: TableEstimate) -> CheatAction:
	if personality.cheat_chance <= 0.0 or view.cheat_window != CheatRules.CheatWindow.TURN:
		return null
	var own_evidence := view.evidence[view.player_id] if view.player_id < view.evidence.size() else 0
	var chance := personality.cheat_chance * pow(AiBalance.OWN_EVIDENCE_CAUTION, own_evidence)
	if _rng.randf() >= chance:
		return null
	var options: Array[CheatAction] = []
	var weights: Array[float] = []
	for kind in Cheat.ALL:
		if Cheat.is_roll_phase(kind) or not _allowed(view, kind):
			continue
		var action := _make(kind, view, estimate)
		if action != null:
			options.append(action)
			weights.append(personality.cheat_weight(kind))
	if options.is_empty():
		return null
	return options[_weighted_index(weights)]


# --- Внутреннее ----------------------------------------------------------------

func _allowed(view: PlayerView, kind: Cheat.Kind) -> bool:
	return personality.cheat_weight(kind) > 0.0 \
			and Cheat.risk(kind) <= personality.risk_tolerance \
			and view.can_afford_cheat(kind) \
			and view.own_sanity - Cheat.cost(kind) >= sanity_reserve(view)


## Запас Рассудка с поправкой на стартовый Рассудок матча (М23, «Скудный рассудок»):
## характер задан для обычных START_SANITY, при меньшем запас уменьшается в той же доле.
func sanity_reserve(view: PlayerView) -> int:
	if view.start_sanity >= CheatBalance.START_SANITY:
		return personality.sanity_reserve
	return roundi(personality.sanity_reserve * float(view.start_sanity)
			/ CheatBalance.START_SANITY)


## Конкретная заявка на трюк или null, если сейчас он бесполезен.
func _make(kind: Cheat.Kind, view: PlayerView, estimate: TableEstimate) -> CheatAction:
	match kind:
		Cheat.Kind.PEEK:
			return _make_peek(view, estimate)
		Cheat.Kind.SLEIGHT:
			return _make_sleight(view)
		Cheat.Kind.NUDGE_CUP:
			# Толкаем чашку того, кто поставил: его кости, скорее всего, держат ставку.
			# Перед «Ложь!»: раунд кончится раньше, чем улика кого-то насторожит.
			if view.current_bid != null and view.neighbors().has(view.current_bidder) 					and estimate.p_holds(view.current_bid) <= AiBalance.NUDGE_BELIEF_MAX:
				return CheatAction.nudge_cup(view.current_bidder)
			return null
		Cheat.Kind.SLEEVE_DIE:
			if view.sleeve_dice.size() >= AiBalance.MAX_SLEEVE_PER_ROUND:
				return null
			return CheatAction.sleeve_die()
		Cheat.Kind.ABYSS_WHISPER:
			return _make_whisper(view, estimate)
	return null


func _make_peek(view: PlayerView, estimate: TableEstimate) -> CheatAction:
	if not _doubtful(view, estimate):
		return null
	var targets := view.neighbors()
	# Сначала — тот, кто поставил: его кости объясняют ставку.
	if targets.has(view.current_bidder):
		targets.erase(view.current_bidder)
		targets.push_front(view.current_bidder)
	for target in targets:
		var hidden: Array[int] = []
		for i in view.dice_counts[target]:
			if not estimate.is_peeked(target, i):
				hidden.append(i)
		if not hidden.is_empty():
			return CheatAction.peek(target, hidden[_rng.randi_range(0, hidden.size() - 1)])
	return null


## Перебросить свой кубик, который не работает на «свою» грань.
func _make_sleight(view: PlayerView) -> CheatAction:
	var face := plan_face(view)
	var wild := view.round_rules.ones_wild()
	var tide := view.round_rules.tide()
	var useless: Array[int] = []
	for i in view.own_dice.size():
		if PerudoRules.count_face([view.own_dice[i]], face, wild, tide) == 0:
			useless.append(i)
	if useless.is_empty():
		return null
	return CheatAction.sleight(useless[_rng.randi_range(0, useless.size() - 1)])


func _make_whisper(view: PlayerView, estimate: TableEstimate) -> CheatAction:
	var face := plan_face(view)
	if estimate.knows_whisper(face):
		return null
	if view.current_bid != null and not _doubtful(view, estimate):
		return null
	return CheatAction.abyss_whisper(face)


## Разведка имеет смысл, когда есть ставка и не ясно, верить ли ей.
func _doubtful(view: PlayerView, estimate: TableEstimate) -> bool:
	if view.current_bid == null:
		return false
	var belief := estimate.p_holds(view.current_bid)
	return belief >= AiBalance.INFO_DOUBT_MIN and belief <= AiBalance.INFO_DOUBT_MAX


## Грань, на которую бот играет: грань текущей ставки или самая частая своя (не единицы).
static func plan_face(view: PlayerView) -> int:
	if view.current_bid != null:
		return view.current_bid.face
	var wild := view.round_rules.ones_wild()
	var tide := view.round_rules.tide()
	var best := 2
	var best_count := -1
	for face in range(2, PerudoRules.FACES + 1):
		var c := PerudoRules.count_face(view.own_dice, face, wild, tide)
		if c > best_count:
			best = face
			best_count = c
	return best


func _total_weight() -> float:
	var total := 0.0
	for kind in Cheat.ALL:
		total += maxf(0.0, personality.cheat_weight(kind))
	return total


func _weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1
