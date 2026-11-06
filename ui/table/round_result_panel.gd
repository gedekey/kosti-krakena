class_name RoundResultPanel
extends PanelContainer
## Итог раунда (М9): вскрытие кубиков после «Лжи!» / «Точно!» (засчитанные кубики яркие,
## остальные притушены, кубики из рукава — отдельно) или итог разоблачения / обвинения.
## Ниже — что изменилось (кто потерял кубик…) и кнопка «Дальше».

signal continue_pressed

var _box: VBoxContainer
var _continue: Button


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
	_finish(notes)


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
	if PerudoRules.count_face([d], face, ones_wild) == 0:
		rect.modulate = TableKit.DIM
	return rect


func _begin() -> void:
	TableKit.clear(_box)


func _finish(notes: PackedStringArray) -> void:
	for line in notes:
		var l := TableKit.label(line, TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
