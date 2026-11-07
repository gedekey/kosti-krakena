class_name RoundResultPanel
extends PanelContainer
## Итог раунда (М9): вскрытие кубиков после «Лжи!» / «Точно!» (засчитанные кубики яркие,
## остальные притушены, кубики из рукава — отдельно) или итог разоблачения / обвинения.
## Ниже — что изменилось (кто потерял кубик…) и кнопка «Дальше».

signal continue_pressed

## Вскрытие по одному кубику (М10): пауза между кубиками и вспышка засчитанных, сек.
const REVEAL_STEP := 0.07
const REVEAL_FLASH := 0.18
## Засчитанный кубик на миг ярче (modulate > 1 — подсветка, не новый цвет).
const COUNTED_FLASH := Color(1.8, 1.8, 1.6)

## Множитель скорости анимации (стол ставит Settings.bot_speed).
var speed := 1.0
var _box: VBoxContainer
var _continue: Button
var _reveal_dice: Array[TextureRect] = []
var _reveal_tail: Array[Control] = []
var _tween: Tween


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = TableKit.vbox(3)
	add_child(_box)
	hide()


## Вскрытие. names(id) — имя игрока. notes — строки итога (потери, выбывания, Палифико).
func show_reveal(reveal: ChallengeReveal, names: Callable, notes: PackedStringArray) -> void:
	_begin()
	var dudo := reveal.kind == MatchAction.Kind.DUDO
	var key := "TABLE_REVEAL_DUDO" if dudo else "TABLE_REVEAL_CALZA"
	_box.add_child(TableKit.title(tr(key) % names.call(reveal.caller_id)))
	_box.add_child(TableKit.bid_row(reveal.bid.quantity, reveal.bid.face, TableKit.TEXT_MUTED,
			tr("TABLE_REVEAL_BID") % names.call(reveal.bidder_id)))

	var ones_wild := RoundRules.new(reveal.is_palifico).ones_wild()
	var face := reveal.bid.face
	for id in reveal.hands.size():
		var hand: Array = reveal.hands[id]
		var sleeve: Array = reveal.sleeve_dice[id] if id < reveal.sleeve_dice.size() else []
		if hand.is_empty() and sleeve.is_empty():
			continue
		var row := TableKit.hbox(2)
		var name_label := TableKit.label(names.call(id), TableKit.TEXT)
		name_label.custom_minimum_size.x = 104
		name_label.clip_text = true
		row.add_child(name_label)
		for d: int in hand:
			row.add_child(_counted_die(d, face, ones_wild))
		if not sleeve.is_empty():
			row.add_child(TableKit.icon_rect(Sprites.trick_icon(Cheat.Kind.SLEEVE_DIE)))
			for d: int in sleeve:
				row.add_child(_counted_die(d, face, ones_wild))
		for child in row.get_children():
			if child.has_meta(&"counted"):
				_reveal_dice.append(child)
		_box.add_child(row)

	var verdict: String
	if dudo:
		verdict = "TABLE_BID_HOLDS" if reveal.result.bid_holds else "TABLE_BID_FAILS"
	else:
		verdict = "TABLE_CALZA_RIGHT" if reveal.result.bid_holds else "TABLE_CALZA_WRONG"
	var total := TableKit.bid_row(reveal.result.actual_count, face, TableKit.TEXT,
			tr("TABLE_REVEAL_ACTUAL"))
	total.add_child(TableKit.label("— " + tr(verdict), TableKit.TEXT_ALERT))
	_box.add_child(total)
	_reveal_tail.append(total)
	_finish(notes)
	_animate_reveal()


## Раунд окончен без вскрытия (провал трюка, обвинение).
func show_summary(title: String, notes: PackedStringArray) -> void:
	_begin()
	_box.add_child(TableKit.title(title))
	_finish(notes)


func press_continue() -> void:
	_continue.pressed.emit()


func set_continue_text(text_key: String) -> void:
	_continue.text = text_key


func _counted_die(d: int, face: int, ones_wild: bool) -> TextureRect:
	var rect := TableKit.die_rect(d)
	var counted := PerudoRules.count_face([d], face, ones_wild) > 0
	rect.set_meta(&"counted", counted)
	if not counted:
		rect.modulate = TableKit.DIM
	return rect


## Кубики проявляются по одному, засчитанные вспыхивают; итог — последним.
func _animate_reveal() -> void:
	if _reveal_dice.is_empty() or not is_inside_tree():
		return
	var s := maxf(speed, 0.01)
	_tween = create_tween()
	for rect in _reveal_dice:
		var final := rect.modulate
		rect.modulate = Color(final, 0.0)
		_tween.tween_property(rect, "modulate", final, REVEAL_STEP / s)
		if rect.get_meta(&"counted"):
			_tween.tween_property(rect, "modulate", COUNTED_FLASH, REVEAL_FLASH * 0.3 / s)
			_tween.tween_property(rect, "modulate", final, REVEAL_FLASH * 0.7 / s)
	for c in _reveal_tail:
		c.modulate = Color(1, 1, 1, 0)
		_tween.tween_property(c, "modulate", Color.WHITE, REVEAL_STEP * 2 / s)


func is_revealing() -> bool:
	return _tween != null and _tween.is_running()


func _begin() -> void:
	if _tween != null:
		_tween.kill()
	# Если прошлое вскрытие не доиграло — всё видно сразу.
	for c in _reveal_tail:
		if is_instance_valid(c):
			c.modulate = Color.WHITE
	_reveal_dice.clear()
	_reveal_tail.clear()
	TableKit.clear(_box)


func _finish(notes: PackedStringArray) -> void:
	for line in notes:
		var l := TermLabel.make(TableKit.TEXT_MUTED, true,
				TutorialLayout.text_width(TableLayout.REVEAL_WIDTH, 0))
		l.set_term_text(line)
		_box.add_child(l)
	_continue = TableKit.button("TABLE_CONTINUE", Sprites.ButtonKind.BID)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	_box.add_child(_continue)
	custom_minimum_size = Vector2i(TableLayout.REVEAL_WIDTH, 0)
	size = Vector2i(TableLayout.REVEAL_WIDTH, 0)
	show()
	reset_size()
	position = Vector2i(TableLayout.POPUP_CENTER.x - int(size.x) / 2,
			maxi(2, TableLayout.POPUP_CENTER.y - int(size.y) / 2))
