class_name OwnHandView
extends Control
## Своя зона стола (М9): портрет, Рассудок, своя чашка (открыть / закрыть) и кубики,
## кубики в рукаве. Кубики — из PlayerView (как игрок их видит; в Безумии могут врать).
## Закрытая чашка кубики не показывает.

signal cup_pressed

var _portrait: TextureRect
var _frame: Panel
var _sanity_icon: TextureRect
var _sanity_pips: Array[TextureRect] = []
var _cup_button: TextureButton
var _cup_hint: Label
var _dice_row: HBoxContainer
var _closed_label: Label
var _sleeve_row: HBoxContainer
var _character: StringName
var _cup_open := false


func setup(character: StringName) -> void:
	_character = character
	if _frame != null:  # «Реванш»: узлы уже есть
		show_view(null, false)
		return
	TableKit.place(self, TableLayout.OWN_PANEL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var origin := TableLayout.OWN_PANEL_RECT.position

	_frame = Panel.new()
	_frame.position = TableLayout.OWN_FRAME_POS - origin
	_frame.size = TableLayout.FRAME_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_portrait = TableKit.icon_rect(Sprites.portrait(character))
	_portrait.position = Vector2i(Sprites.FRAME_BORDER, Sprites.FRAME_BORDER)
	_frame.add_child(_portrait)
	set_active(false)

	var sanity := TableKit.hbox(1)
	sanity.position = TableLayout.SANITY_POS - origin
	sanity.mouse_filter = Control.MOUSE_FILTER_PASS
	sanity.tooltip_text = "SANITY"
	add_child(sanity)
	_sanity_icon = TableKit.icon_rect(Sprites.texture(Sprites.ICON_SANITY))
	sanity.add_child(_sanity_icon)
	var pips := TableKit.hbox(TableLayout.SANITY_PIP_STEP - Sprites.SANITY_PIP_SIZE.x)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	sanity.add_child(pips)
	for i in CheatBalance.START_SANITY:
		var pip := TableKit.icon_rect(Sprites.sanity_pip(true))
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
		_sanity_pips.append(pip)

	_cup_button = TextureButton.new()
	_cup_button.position = TableLayout.CUP_POS - origin
	_cup_button.ignore_texture_size = true
	_cup_button.stretch_mode = TextureButton.STRETCH_SCALE
	_cup_button.size = Sprites.CUP_SIZE * TableLayout.OWN_SCALE
	_cup_button.focus_mode = Control.FOCUS_NONE
	_cup_button.pressed.connect(func() -> void: cup_pressed.emit())
	add_child(_cup_button)
	_cup_hint = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_cup_hint.position = TableLayout.CUP_HINT_POS - origin
	_cup_hint.size = Vector2i(52, PixelFonts.BODY_SIZE)
	add_child(_cup_hint)

	_dice_row = TableKit.hbox(TableLayout.OWN_DIE_STEP - Sprites.DIE_SIZE.x * TableLayout.OWN_SCALE)
	_dice_row.position = TableLayout.OWN_DICE_POS - origin
	add_child(_dice_row)
	_closed_label = TableKit.label("TABLE_CUP_CLOSED_HINT", TableKit.TEXT_MUTED)
	_closed_label.position = TableLayout.OWN_DICE_POS - origin + Vector2i(0, 10)
	add_child(_closed_label)

	_sleeve_row = TableKit.hbox(2)
	_sleeve_row.position = TableLayout.SLEEVE_POS - origin
	_sleeve_row.tooltip_text = "TABLE_SLEEVE_HINT"
	_sleeve_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_sleeve_row)
	show_view(null, false)


func set_active(active: bool) -> void:
	var kind := Sprites.PanelKind.FRAME_ACTIVE if active else Sprites.PanelKind.FRAME
	_frame.add_theme_stylebox_override("panel", Sprites.panel(kind))


## Обновить по своему PlayerView. cup_usable — можно ли сейчас трогать чашку.
func show_view(view: PlayerView, cup_usable: bool) -> void:
	var has_dice := view != null and not view.own_dice.is_empty()
	_cup_open = view != null and view.cup_open
	var cup_texture := Sprites.cup(TableKit.OWN_CUP, _cup_open or not has_dice)
	_cup_button.texture_normal = cup_texture
	_cup_button.disabled = not cup_usable
	_cup_button.modulate = Color.WHITE if cup_usable or _cup_open else TableKit.DIM
	_cup_hint.text = ""
	if cup_usable:
		_cup_hint.text = "TABLE_CUP_CLOSE" if _cup_open else "TABLE_CUP_OPEN"
	_cup_button.tooltip_text = _cup_hint.text

	TableKit.clear(_dice_row)
	_closed_label.visible = has_dice and not _cup_open
	if has_dice and _cup_open:
		for face in view.own_dice:
			_dice_row.add_child(TableKit.die_rect(face, TableLayout.OWN_SCALE))

	TableKit.clear(_sleeve_row)
	if view != null and not view.sleeve_dice.is_empty():
		_sleeve_row.add_child(TableKit.icon_rect(Sprites.trick_icon(Cheat.Kind.SLEEVE_DIE)))
		for face in view.sleeve_dice:
			_sleeve_row.add_child(TableKit.die_rect(face))

	var sanity := view.own_sanity if view != null else CheatBalance.START_SANITY
	var mad := view != null and view.is_mad()
	for i in _sanity_pips.size():
		_sanity_pips[i].texture = Sprites.sanity_pip(i < sanity)
	_sanity_icon.texture = Sprites.texture(Sprites.ICON_MADNESS if mad else Sprites.ICON_SANITY)
	_portrait.texture = Sprites.portrait(_character, mad)


func is_cup_button_enabled() -> bool:
	return not _cup_button.disabled


func shown_dice() -> Array[int]:
	var out: Array[int] = []
	for rect: TextureRect in _dice_row.get_children():
		for face in range(1, PerudoRules.FACES + 1):
			if rect.texture == Sprites.die(TableKit.DICE_SET, face):
				out.append(face)
	return out


func press_cup() -> void:
	_cup_button.pressed.emit()
