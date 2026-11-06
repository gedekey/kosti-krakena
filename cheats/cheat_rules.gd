class_name CheatRules
extends RefCounted
## Когда и на кого можно применить трюк (DESIGN.md §3.1). Только статические функции.
## Единый источник для контроллера, UI (что показывать в меню трюков) и ботов (М6).

## Окно для трюков в текущей фазе матча.
enum CheatWindow {
	## Трюки недоступны (итог раунда, конец матча…).
	CLOSED,
	## Фаза броска: только «Утяжелённая кость», любой игрок с кубиками.
	ROLL,
	## Ходы: остальные трюки, только текущий игрок до своего действия.
	TURN,
}

enum Denied {
	OK,
	WRONG_PHASE,
	NOT_YOUR_TURN,
	## Уже был трюк в этот ход (или «Утяжелённая кость» в этот бросок).
	ALREADY_USED,
	## Безумие: жульничество недоступно.
	MAD,
	NO_SANITY,
	## Игрок выбыл.
	OUT,
	BAD_TARGET,
	BAD_DIE,
	BAD_FACE,
}


## Почему трюк нельзя применить (Denied.OK — можно).
## hands — реальные чашки (пустые до броска), current_player — чей ход (окно TURN).
static func check(state: CheatState, player_id: int, action: CheatAction, window: CheatWindow,
		current_player: int, dice_counts: Array, hands: Array) -> Denied:
	if action == null:
		return Denied.WRONG_PHASE
	if player_id < 0 or player_id >= dice_counts.size() or dice_counts[player_id] <= 0:
		return Denied.OUT

	var kind := action.kind
	if Cheat.is_roll_phase(kind):
		if window != CheatWindow.ROLL:
			return Denied.WRONG_PHASE
		if state.used_in_roll(player_id):
			return Denied.ALREADY_USED
	else:
		if window != CheatWindow.TURN:
			return Denied.WRONG_PHASE
		if player_id != current_player:
			return Denied.NOT_YOUR_TURN
		if state.used_this_turn():
			return Denied.ALREADY_USED

	if state.is_mad(player_id):
		return Denied.MAD
	if state.sanity[player_id] < Cheat.cost(kind):
		return Denied.NO_SANITY

	match Cheat.target(kind):
		Cheat.Target.NEIGHBOR, Cheat.Target.NEIGHBOR_DIE:
			if not neighbors(dice_counts, player_id).has(action.target_id):
				return Denied.BAD_TARGET
			if Cheat.target(kind) == Cheat.Target.NEIGHBOR_DIE \
					and not _valid_die(hands, action.target_id, action.die_index):
				return Denied.BAD_DIE
		Cheat.Target.OWN_DIE:
			if not _valid_die(hands, player_id, action.die_index):
				return Denied.BAD_DIE
		Cheat.Target.FACE:
			if action.face < 1 or action.face > PerudoRules.FACES:
				return Denied.BAD_FACE
	return Denied.OK


## Соседи слева и справа среди игроков с кубиками (при двух игроках — один и тот же).
static func neighbors(dice_counts: Array, player_id: int) -> Array[int]:
	var out: Array[int] = []
	var right := PerudoRules.next_active_player(dice_counts, player_id)
	var left := previous_active_player(dice_counts, player_id)
	for id in [right, left]:
		if id != PerudoRules.NO_PLAYER and id != player_id and not out.has(id):
			out.append(id)
	return out


## Предыдущий по кругу игрок с кубиками (from_id не учитывается).
static func previous_active_player(dice_counts: Array, from_id: int) -> int:
	var n := dice_counts.size()
	for step in range(1, n + 1):
		var id := posmod(from_id - step, n)
		if id != from_id and dice_counts[id] > 0:
			return id
	return PerudoRules.NO_PLAYER


## «Шёпот Бездны»: сколько кубиков грани face у всех, кроме player_id
## (чашки и рукава остальных; единицы — по правилам раунда).
static func whisper_count(player_id: int, face: int, hands: Array, sleeves: Array,
		ones_wild: bool) -> int:
	var total := 0
	for id in hands.size():
		if id == player_id:
			continue
		total += PerudoRules.count_face(hands[id], face, ones_wild)
		if id < sleeves.size():
			total += PerudoRules.count_face(sleeves[id], face, ones_wild)
	return total


static func _valid_die(hands: Array, player_id: int, die_index: int) -> bool:
	return player_id >= 0 and player_id < hands.size() \
			and die_index >= 0 and die_index < hands[player_id].size()
