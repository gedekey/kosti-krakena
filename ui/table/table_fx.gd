class_name TableFx
extends Control
## Визуальный отклик стола на события матча (М10). Только подписывается на Events и
## показывает: покадровые эффекты (FxSprite), тряску чашек и мест, вспышки, Безумие по краям.
## Правил здесь нет; что показать — решает событие, где — место (SeatView / OwnHandView через
## fx_point / fx_node). Скорость — та же, что у ходов ботов (Settings.bot_speed, «Досмотреть ×2»).
##
## Секретное (успешные трюки) показывается только для своего игрока.

const HUMAN_ID := 0
## Больше одновременных эффектов не держим — самые старые убираются.
const MAX_EFFECTS := 24

# --- Тряска (пиксели, секунды при скорости 1) ---
const RATTLE_TIME := 0.45
const RATTLE_STEP := 0.05
const RATTLE_PX := 2
const SLAM_LIFT_PX := 4
const SLAM_TIME := 0.12
const TREMBLE_TIME := 0.6
const TREMBLE_PX := 1
const HIT_SHAKE_TIME := 0.3
const HIT_SHAKE_PX := 2
const SCREEN_SHAKE_TIME := 0.35
const SCREEN_SHAKE_PX := 3
const HOP_PX := 3
const HOP_TIME := 0.16
## Вспышка рамки (провал трюка, обвинение).
const FLASH_TIME := 0.5
const FLASH_COLOR := Color(1.0, 0.45, 0.4)
## «Шёпот Бездны» длинный — играем быстрее.
const WHISPER_SPEED := 1.6

## id → место (SeatView или OwnHandView): у обоих fx_point(part) и fx_node(part).
var _targets: Callable
var _speed: Callable
var _shake_root: Control
var _overlay: MadnessOverlay
var _layer: Node2D
var _tweens := {}        # instance id узла → [Tween, исходная позиция]


## targets(id) → место; speed() → множитель скорости; shake_root — что трясти при ударе.
func setup(targets: Callable, speed: Callable, shake_root: Control, overlay: MadnessOverlay) -> void:
	_targets = targets
	_speed = speed
	_shake_root = shake_root
	_overlay = overlay


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	TableKit.place(self, Rect2i(Vector2i.ZERO, TableLayout.SCREEN))
	_layer = Node2D.new()
	add_child(_layer)
	Events.match_started.connect(_on_match_started)
	Events.dice_rolled.connect(_on_dice_rolled)
	Events.bid_placed.connect(_on_bid_placed)
	Events.challenge_revealed.connect(_on_challenge_revealed)
	Events.dice_count_changed.connect(_on_dice_count_changed)
	Events.cheat_resolved.connect(_on_cheat_resolved)
	Events.cheat_failed.connect(_on_cheat_failed)
	Events.evidence_shown.connect(_on_evidence_shown)
	Events.madness_began.connect(_on_madness_began)
	Events.accusation_made.connect(_on_accusation_made)


# --- Публичное (и для тестов) -------------------------------------------------------

## Покадровый эффект в точке экрана.
func spawn(effect: StringName, at: Vector2, speed_mul := 1.0) -> FxSprite:
	while _layer.get_child_count() >= MAX_EFFECTS:
		var old := _layer.get_child(0)
		_layer.remove_child(old)
		old.queue_free()
	var fx := FxSprite.make(effect, at, _cur_speed() * speed_mul)
	_layer.add_child(fx)
	return fx


func active_effects() -> Array[StringName]:
	var out: Array[StringName] = []
	for fx: FxSprite in _layer.get_children():
		if not fx.is_queued_for_deletion():
			out.append(fx.effect)
	return out


func clear_effects() -> void:
	for fx in _layer.get_children():
		_layer.remove_child(fx)
		fx.queue_free()


## Дрожание узла: случайные целые сдвиги, в конце — точно на место.
func rattle(node: CanvasItem, px: int, time: float, step := RATTLE_STEP) -> Tween:
	var tw := _restart(node)
	if tw == null:
		return null
	var origin: Vector2 = _tweens[node.get_instance_id()][1]
	var s := _cur_speed()
	var n := maxi(1, int(time / step))
	for i in n:
		var off := Vector2(randi_range(-px, px), randi_range(-px, px))
		tw.tween_property(node, "position", origin + off, step / s)
	tw.tween_property(node, "position", origin, step / s)
	return tw


## Подскок узла вверх и обратно.
func hop(node: CanvasItem, px := HOP_PX, time := HOP_TIME) -> Tween:
	var tw := _restart(node)
	if tw == null:
		return null
	var origin: Vector2 = _tweens[node.get_instance_id()][1]
	var s := _cur_speed()
	tw.tween_property(node, "position", origin - Vector2(0, px), time * 0.4 / s) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", origin, time * 0.6 / s) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


## Вспышка цветом (modulate) и возврат.
func flash(node: CanvasItem, color := FLASH_COLOR, time := FLASH_TIME) -> void:
	if node == null or not node.is_inside_tree():
		return
	if node.has_meta(&"fx_flash"):
		var old: Tween = node.get_meta(&"fx_flash")
		if old != null and old.is_valid():
			old.kill()
	var back := Color.WHITE
	node.modulate = back
	var tw := node.create_tween()
	node.set_meta(&"fx_flash", tw)
	var s := _cur_speed()
	for i in 2:
		tw.tween_property(node, "modulate", color, time * 0.25 / s)
		tw.tween_property(node, "modulate", back, time * 0.25 / s)


func shake_screen(px := SCREEN_SHAKE_PX, time := SCREEN_SHAKE_TIME) -> void:
	if _shake_root != null:
		rattle(_shake_root, px, time)


# --- События -------------------------------------------------------------------------

func _on_match_started(_count: int, _first: int) -> void:
	clear_effects()
	if _overlay != null:
		_overlay.set_active(false)


## Все трясут чашки: дрожь, удар о стол, пыль; свои кубики крутятся.
func _on_dice_rolled(_round: int) -> void:
	for target in _all_targets():
		var cup: Control = target.fx_node(&"cup")
		if cup == null or not cup.is_visible_in_tree():
			continue
		var tw := rattle(cup, RATTLE_PX, RATTLE_TIME)
		if tw == null:
			continue
		var origin: Vector2 = _tweens[cup.get_instance_id()][1]
		var s := _cur_speed()
		tw.tween_property(cup, "position", origin - Vector2(0, SLAM_LIFT_PX), SLAM_TIME * 0.5 / s)
		tw.tween_property(cup, "position", origin, SLAM_TIME * 0.5 / s) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(spawn.bind(&"slam", target.fx_point(&"cup_base"), 1.0))
		if target is OwnHandView:
			(target as OwnHandView).play_roll((RATTLE_TIME + SLAM_TIME) / s)


func _on_bid_placed(player_id: int, _bid: Bid) -> void:
	var target = _target(player_id)
	if target != null and target.fx_node(&"bubble") != null:
		hop(target.fx_node(&"bubble"))


## Вскрытие: чашки соперников подпрыгивают, открываясь.
func _on_challenge_revealed(_reveal: ChallengeReveal) -> void:
	for target in _all_targets():
		if target is SeatView:
			var cup: Control = target.fx_node(&"cup")
			if cup != null and cup.is_visible_in_tree():
				hop(cup, HOP_PX + 1)


func _on_dice_count_changed(player_id: int, _count: int, delta: int) -> void:
	var target = _target(player_id)
	if target == null or delta == 0:
		return
	if delta < 0:
		spawn(&"poof", target.fx_point(&"dice"))
		rattle(target.fx_node(&"body"), HIT_SHAKE_PX, HIT_SHAKE_TIME)
		if player_id == HUMAN_ID:
			shake_screen(HIT_SHAKE_PX)
	else:
		spawn(&"gain", target.fx_point(&"dice"))


## СЕКРЕТНО: свой удачный трюк.
func _on_cheat_resolved(outcome: CheatOutcome) -> void:
	if outcome.player_id != HUMAN_ID:
		return
	var own = _target(HUMAN_ID)
	if own == null:
		return
	match outcome.action.kind:
		Cheat.Kind.ABYSS_WHISPER:
			spawn(&"whisper", own.fx_point(&"hand_base"), WHISPER_SPEED)
		Cheat.Kind.NUDGE_CUP:
			spawn(&"trick", own.fx_point(&"dice"))
			var victim = _target(outcome.action.target_id)
			if victim != null and victim.fx_node(&"cup") != null:
				rattle(victim.fx_node(&"cup"), RATTLE_PX, RATTLE_TIME)
		Cheat.Kind.SLEIGHT, Cheat.Kind.LOADED_DIE:
			spawn(&"trick", own.fx_point(&"dice"))
			(own as OwnHandView).play_roll(RATTLE_TIME / _cur_speed())
		_:
			spawn(&"trick", own.fx_point(&"dice"))


## Пойман на трюке — всем видно.
func _on_cheat_failed(player_id: int, _kind: int) -> void:
	_caught(player_id)


func _on_evidence_shown(player_id: int) -> void:
	var target = _target(player_id)
	if target == null:
		return
	spawn(&"evidence", target.fx_point(&"portrait_base"))
	var cup: Control = target.fx_node(&"cup")
	if cup != null and cup.is_visible_in_tree():
		rattle(cup, TREMBLE_PX, TREMBLE_TIME, RATTLE_STEP * 0.6)


func _on_madness_began(player_id: int) -> void:
	var target = _target(player_id)
	if target != null:
		spawn(&"madness", target.fx_point(&"portrait_base"))
	if player_id == HUMAN_ID:
		if _overlay != null:
			_overlay.play_onset(_cur_speed())
		shake_screen()


func _on_accusation_made(accuser_id: int, target_id: int, guilty: bool) -> void:
	var accuser = _target(accuser_id)
	if accuser != null and accuser.fx_node(&"body") != null:
		hop(accuser.fx_node(&"body"))
	if guilty:
		_caught(target_id)
	else:
		var target = _target(target_id)
		if target != null:
			rattle(target.fx_node(&"body"), TREMBLE_PX, HIT_SHAKE_TIME)


func _caught(player_id: int) -> void:
	var target = _target(player_id)
	if target == null:
		return
	spawn(&"caught", target.fx_point(&"portrait_top"))
	flash(target.fx_node(&"frame"))
	rattle(target.fx_node(&"body"), HIT_SHAKE_PX, HIT_SHAKE_TIME)
	shake_screen()


# --- Внутреннее ----------------------------------------------------------------------

func _cur_speed() -> float:
	return maxf(_speed.call(), 0.01) if _speed.is_valid() else 1.0


func _target(player_id: int):
	return _targets.call(player_id) if _targets.is_valid() else null


func _all_targets() -> Array:
	var out := []
	if not _targets.is_valid():
		return out
	var id := 0
	while true:
		var t = _targets.call(id)
		if t == null:
			break
		out.append(t)
		id += 1
	return out


## Остановить прежнюю тряску узла (вернув его на место) и начать новую.
func _restart(node: CanvasItem) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var key := node.get_instance_id()
	if _tweens.has(key):
		var old: Tween = _tweens[key][0]
		if old.is_valid():
			old.kill()
		node.position = _tweens[key][1]
	var tw := node.create_tween()
	_tweens[key] = [tw, node.position]
	tw.finished.connect(_forget.bind(key, tw))
	return tw


func _forget(key: int, tw: Tween) -> void:
	if _tweens.has(key) and _tweens[key][0] == tw:
		_tweens.erase(key)
