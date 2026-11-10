class_name SeatView
extends Control
## Место соперника за столом (М9): портрет в рамке (активная — его ход), имя, число кубиков,
## улики раунда, признак Безумия, чашка, реплика с последним действием и подсмотренные
## своим трюком кубики. М21: итог своего «Шёпота Бездны» — сколько у этого соперника
## кубиков названной грани. Только показывает то, что ему передали.

var player_id: int
var _character: StringName
var _frame: Panel
var _portrait: TextureRect
var _name_label: Label
var _dice_label: Label
var _evidence_box: HBoxContainer
var _evidence_label: Label
var _madness_icon: TextureRect
var _cup: TextureRect
var _bubble: PanelContainer
var _bubble_row: HBoxContainer
var _peeked_row: HBoxContainer
var _whisper_box: PanelContainer
var _whisper_die: TextureRect
var _whisper_label: Label
var _mad := false


func setup(id: int, character: StringName, display_name: String) -> void:
	player_id = id
	_character = character
	size = TableLayout.SEAT_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_frame = Panel.new()
	_frame.size = TableLayout.FRAME_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_portrait = TableKit.add_portrait(_frame, Sprites.portrait(character))
	_peeked_row = TableKit.hbox(1)
	_peeked_row.position = Vector2i(Sprites.FRAME_BORDER + 1, TableLayout.FRAME_SIZE.y - 22)
	_frame.add_child(_peeked_row)

	var info := TableKit.vbox(2)
	info.position = Vector2i(TableLayout.SEAT_INFO_X, 0)
	add_child(info)
	var dice_box := TableKit.hbox(2)
	dice_box.add_child(TableKit.icon_rect(Sprites.texture(Sprites.ICON_DICE)))
	_dice_label = TableKit.label("")
	dice_box.add_child(_dice_label)
	info.add_child(dice_box)
	_evidence_box = TableKit.hbox(2)
	_evidence_box.add_child(TableKit.icon_rect(Sprites.texture(Sprites.ICON_EVIDENCE)))
	_evidence_label = TableKit.label("", TableKit.TEXT_ALERT)
	_evidence_box.add_child(_evidence_label)
	TermTips.attach(_evidence_box, &"EVIDENCE")
	info.add_child(_evidence_box)
	_madness_icon = TableKit.icon_rect(Sprites.texture(Sprites.ICON_MADNESS))
	info.add_child(_madness_icon)
	TermTips.attach(_madness_icon, &"MADNESS")
	# М21: «Шёпот Бездны» — [грань] ×N у этого соперника.
	# Своё место — слева от чашки, над именем: столбец справа от портрета может быть занят.
	_whisper_box = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = TableKit.TEXT_BACKING
	backing.set_content_margin_all(1)
	_whisper_box.add_theme_stylebox_override("panel", backing)
	_whisper_box.position = TableLayout.SEAT_WHISPER_POS
	var row := TableKit.hbox(1)
	_whisper_box.add_child(row)
	_whisper_die = TableKit.die_rect(1)
	row.add_child(_whisper_die)
	_whisper_label = TableKit.label("", TableKit.TEXT_MAGIC)
	row.add_child(_whisper_label)
	TermTips.attach(_whisper_box, &"ABYSS_WHISPER")
	add_child(_whisper_box)
	_whisper_box.visible = false

	_cup = TableKit.icon_rect(Sprites.cup(TableKit.BOT_CUP, false))
	_cup.position = Vector2i(TableLayout.SEAT_SIZE.x - Sprites.CUP_SIZE.x - 2,
			TableLayout.SEAT_NAME_Y - Sprites.CUP_SIZE.y - 1)
	add_child(_cup)

	_name_label = TableKit.backed_label(display_name, TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_name_label)
	_layout_name()

	_bubble = TableKit.panel(Sprites.PanelKind.BUBBLE)
	_bubble.position = Vector2i(0, TableLayout.SEAT_BUBBLE_Y)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	_bubble_row = TableKit.hbox(2)
	_bubble.add_child(_bubble_row)
	_bubble.visible = false
	set_active(false)


func set_display_name(text: String) -> void:
	_name_label.text = text
	_layout_name()


## Имя по центру места, подложка — по ширине текста (длинное — обрезается).
func _layout_name() -> void:
	_name_label.clip_text = false
	_name_label.reset_size()
	var width := mini(int(_name_label.size.x), TableLayout.SEAT_SIZE.x)
	_name_label.clip_text = width >= TableLayout.SEAT_SIZE.x
	_name_label.size = Vector2i(width, int(_name_label.size.y))
	_name_label.position = Vector2i((TableLayout.SEAT_SIZE.x - width) / 2, TableLayout.SEAT_NAME_Y)


func set_active(active: bool) -> void:
	var kind := Sprites.PanelKind.FRAME_ACTIVE if active else Sprites.PanelKind.FRAME
	_frame.add_theme_stylebox_override("panel", Sprites.panel(kind))


func set_dice_count(count: int) -> void:
	_dice_label.text = "×%d" % count
	modulate = Color.WHITE if count > 0 else TableKit.DIM
	if count == 0:
		_cup.visible = false
		show_bubble_text(tr("TABLE_OUT"), TableKit.TEXT_MUTED)


func set_evidence(count: int) -> void:
	_evidence_box.visible = count > 0
	_evidence_label.text = "×%d" % count


func set_mad(mad: bool) -> void:
	_mad = mad
	_madness_icon.visible = mad
	_portrait.texture = Sprites.portrait(_character, mad)
	PortraitFx.apply(_portrait, mad, player_id * 0.7)


func set_cup_open(open: bool) -> void:
	_cup.texture = Sprites.cup(TableKit.BOT_CUP, open)


## Реплика-ставка: «N × [кубик]».
func show_bubble_bid(quantity: int, face: int) -> void:
	TableKit.clear(_bubble_row)
	_bubble_row.add_child(TableKit.label("%d ×" % quantity, KrakenPalette.INK))
	_bubble_row.add_child(TableKit.die_rect(face))
	_show_bubble()


func show_bubble_text(text: String, color := KrakenPalette.INK) -> void:
	TableKit.clear(_bubble_row)
	_bubble_row.add_child(TableKit.label(text, color))
	_show_bubble()


func hide_bubble() -> void:
	_bubble.visible = false


func bubble_text() -> String:
	var parts: PackedStringArray = []
	for child in _bubble_row.get_children():
		if child is Label:
			parts.append((child as Label).text)
	return " ".join(parts)


## Подсмотренные своим трюком кубики соседа (на этот раунд).
func set_peeked(faces: Array[int]) -> void:
	TableKit.clear(_peeked_row)
	for face in faces:
		_peeked_row.add_child(TableKit.die_rect(face))


## Итог своего «Шёпота Бездны» (на этот раунд): у соперника count кубиков грани face.
## face ≤ 0 — убрать.
func set_whisper(face: int, count: int) -> void:
	_whisper_box.visible = face > 0
	if face > 0:
		_whisper_die.texture = Sprites.die(TableKit.DICE_SET, face)
		_whisper_label.text = "×%d" % count


func whisper_text() -> String:
	return _whisper_label.text if _whisper_box.visible else ""


# --- Точки и узлы для эффектов (М10) ---

## Точка привязки эффекта в координатах экрана. part: portrait_base (низ портрета),
## portrait_top (под восклицание над портретом), dice (счётчик кубиков), cup_base (низ чашки).
func fx_point(part: StringName) -> Vector2:
	var p := Vector2.ZERO
	match part:
		&"portrait_base":
			p = Vector2(TableLayout.FRAME_SIZE.x / 2, TableLayout.FRAME_SIZE.y - 4)
		&"portrait_top":
			p = Vector2(TableLayout.FRAME_SIZE.x / 2, TableLayout.FX_EXCLAIM_Y)
		&"dice":
			p = Vector2(TableLayout.SEAT_INFO_X + 12, TableLayout.FX_SEAT_DICE_Y)
		&"cup_base", &"hand_base":
			p = _cup.position + Vector2(Sprites.CUP_SIZE.x / 2, Sprites.CUP_SIZE.y)
	return global_position + p


## Узел для тряски / вспышки: body (всё место), frame, cup, bubble.
func fx_node(part: StringName) -> Control:
	match part:
		&"body":
			return self
		&"frame":
			return _frame
		&"cup":
			return _cup
		&"bubble":
			return _bubble
	return null


func is_portrait_wobbling() -> bool:
	return PortraitFx.is_applied(_portrait)


func _show_bubble() -> void:
	_bubble.visible = true
	_bubble.reset_size()
	_bubble.position.x = maxi(0, (TableLayout.SEAT_SIZE.x - int(_bubble.size.x)) / 2)
