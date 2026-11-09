class_name LocalSession
extends MatchSession
## Матч на этом устройстве поверх MatchController: одиночная игра и основа HostSession.
## Пересылает сигналы контроллера, кроме чужих секретов (NetProtocol.is_visible),
## и пропускает команды только от своего места, пока оно за человеком.

var controller: MatchController

var _local := 0
var _seats: Array[SeatInfo] = []


func _init(p_controller: MatchController = null, local_seat := 0,
		seats: Array[SeatInfo] = []) -> void:
	if p_controller != null:
		_attach(p_controller, local_seat, seats)


func _attach(p_controller: MatchController, local_seat: int, seats: Array[SeatInfo]) -> void:
	controller = p_controller
	_local = local_seat
	_seats = seats.duplicate()
	if _seats.is_empty():
		_seats = _seats_from_agents(controller)
	for sig in controller.get_script().get_script_signal_list():
		var sig_name: StringName = sig["name"]
		controller.connect(sig_name, _forwarder(sig_name, sig["args"].size()))


## Места одиночной игры: свой — человек, остальные — боты по персонажам.
static func _seats_from_agents(c: MatchController) -> Array[SeatInfo]:
	var out: Array[SeatInfo] = []
	for id in c.player_count():
		var bot := c.agent(id) as BotAgent
		if bot != null:
			out.append(SeatInfo.bot(bot.personality.id))
		else:
			out.append(SeatInfo.host("", 0))
	return out


## Связанные методы, а не лямбды: лямбда держала бы сессию и замкнула бы цикл ссылок
## контроллер → сессия → контроллер (RefCounted не освободились бы).
func _forwarder(sig_name: StringName, argc: int) -> Callable:
	match argc:
		0:
			return _on_signal_0.bind(sig_name)
		1:
			return _on_signal_1.bind(sig_name)
		2:
			return _on_signal_2.bind(sig_name)
		3:
			return _on_signal_3.bind(sig_name)
	push_error("Unsupported signal arity: %s" % sig_name)
	return Callable()


func _on_signal_0(sig_name: StringName) -> void:
	_on_controller_event(sig_name, [])


func _on_signal_1(a: Variant, sig_name: StringName) -> void:
	_on_controller_event(sig_name, [a])


func _on_signal_2(a: Variant, b: Variant, sig_name: StringName) -> void:
	_on_controller_event(sig_name, [a, b])


func _on_signal_3(a: Variant, b: Variant, c: Variant, sig_name: StringName) -> void:
	_on_controller_event(sig_name, [a, b, c])


## Событие контроллера. HostSession дополнительно рассылает его гостям.
func _on_controller_event(sig_name: StringName, args: Array) -> void:
	_emit_visible(sig_name, args)


func _emit_visible(sig_name: StringName, args: Array) -> void:
	if NetProtocol.is_visible(sig_name, args, _local):
		callv(&"emit_signal", [sig_name] + args)


## Своё место сейчас за человеком (не отдано боту).
func _controls_local() -> bool:
	return controller != null and controller.agent(_local).is_human()


# --- Запросы -------------------------------------------------------------------

func local_player() -> int:
	return _local


func player_count() -> int:
	return 0 if controller == null else controller.player_count()


func seat(player_id: int) -> SeatInfo:
	if player_id < 0 or player_id >= _seats.size():
		return null
	return _seats[player_id]


func view_for(player_id: int) -> PlayerView:
	if controller == null or player_id != _local:
		return null
	return controller.view_for(player_id)


func is_waiting_for_human() -> bool:
	return controller != null and controller.is_waiting_for_human()


func cheat_denial(player_id: int, action: CheatAction) -> CheatRules.Denied:
	if controller == null:
		return CheatRules.Denied.WRONG_PHASE
	if player_id != _local or not _controls_local():
		return CheatRules.Denied.NOT_YOUR_TURN
	return controller.cheat_denial(player_id, action)


# --- Команды -------------------------------------------------------------------

func start_match(first_player := PerudoRules.NO_PLAYER) -> void:
	controller.start_match(first_player)


func roll(preset_hands: Array = []) -> void:
	controller.roll(preset_hands)


func submit_action(player_id: int, action: MatchAction) -> MatchController.Result:
	if controller == null:
		return Result.WRONG_PHASE
	if player_id != _local or not _controls_local():
		return Result.NOT_YOUR_TURN
	return controller.submit_action(player_id, action)


func submit_cheat(player_id: int, action: CheatAction) -> MatchController.Result:
	if controller == null:
		return Result.WRONG_PHASE
	if player_id != _local or not _controls_local():
		return Result.NOT_YOUR_TURN
	return controller.submit_cheat(player_id, action)


func open_cup(player_id: int) -> MatchController.Result:
	if controller == null:
		return Result.WRONG_PHASE
	if player_id != _local or not _controls_local():
		return Result.ILLEGAL_ACTION
	return controller.open_cup(player_id)


func close_cup(player_id: int) -> MatchController.Result:
	if controller == null:
		return Result.WRONG_PHASE
	if player_id != _local or not _controls_local():
		return Result.ILLEGAL_ACTION
	return controller.close_cup(player_id)


func next_round() -> void:
	controller.next_round()


func advance_auto() -> bool:
	return controller.advance_auto()


# --- Геттеры -------------------------------------------------------------------

func _get_phase() -> int:
	return Phase.IDLE if controller == null else controller.phase


func _get_round_number() -> int:
	return 0 if controller == null else controller.round_number


func _get_current_player() -> int:
	return PerudoRules.NO_PLAYER if controller == null else controller.current_player


func _get_winner_id() -> int:
	return PerudoRules.NO_PLAYER if controller == null else controller.winner_id


func _get_dice_counts() -> Array[int]:
	if controller == null:
		return [] as Array[int]
	return controller.dice_counts


func _get_round_rules() -> RoundRules:
	return RoundRules.new() if controller == null else controller.round_rules


func _get_options() -> RuleOptions:
	return RuleOptions.new() if controller == null else controller.options
