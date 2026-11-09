class_name MatchEndPanel
extends PanelContainer
## Экраны победы и поражения (М9, DESIGN.md §6): «Досмотреть ×2» (только если матч ещё
## идёт), «Реванш», «Меню». М20: под итогом — ранг, Слава за матч, повышение / понижение.

signal spectate_pressed
signal rematch_pressed
signal menu_pressed

var spectate_button: Button
var rematch_button: Button
var menu_button: Button
var _title: Label
var _subtitle: Label
var _portrait: TextureRect
var rank_badge: RankBadge
var rank_delta: Label
var rank_note: Label
var _rank_row: HBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := TableKit.vbox(6)
	add_child(box)
	_title = TableKit.title("", true)
	box.add_child(_title)
	_portrait = TableKit.icon_rect(Sprites.portrait(Sprites.PLAYER_PORTRAITS[0]))
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_portrait)
	_subtitle = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_subtitle)
	_rank_row = TableKit.hbox(8)
	_rank_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_rank_row)
	rank_badge = RankBadge.new().setup()
	_rank_row.add_child(rank_badge)
	rank_delta = TableKit.label("", TableKit.TEXT)
	rank_delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rank_row.add_child(rank_delta)
	rank_note = TableKit.label("", TableKit.TEXT_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(rank_note)
	var row := TableKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	spectate_button = TableKit.button("TABLE_SPECTATE")
	spectate_button.pressed.connect(func() -> void: spectate_pressed.emit())
	row.add_child(spectate_button)
	rematch_button = TableKit.button("TABLE_REMATCH", Sprites.ButtonKind.BID)
	rematch_button.pressed.connect(func() -> void: rematch_pressed.emit())
	row.add_child(rematch_button)
	menu_button = TableKit.button("TABLE_MENU")
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	row.add_child(menu_button)
	hide()


## won — победа игрока; portrait — чей портрет показать (победителя);
## can_spectate — матч продолжается без игрока.
func show_result(won: bool, portrait: Texture2D, subtitle: String, can_spectate: bool) -> void:
	_title.text = "TABLE_VICTORY" if won else "TABLE_DEFEAT"
	_title.theme_type_variation = PixelFonts.VARIATION_TITLE_GLOW if won \
			else PixelFonts.VARIATION_TITLE
	_portrait.texture = portrait
	_subtitle.text = subtitle
	spectate_button.visible = can_spectate
	_rank_row.hide()
	rank_note.hide()
	_layout()


## Ранг после матча (М20): change == null — ранг не менялся, note — пояснение почему.
func show_rank(change: RankChange, note: String) -> void:
	_rank_row.visible = change != null
	rank_note.visible = change != null and (change.promoted() or change.demoted()) or note != ""
	rank_note.text = note
	rank_note.add_theme_color_override("font_color", TableKit.TEXT_MUTED)
	if change != null:
		rank_badge.show_rank(change.tier, change.glory)
		rank_delta.text = tr("RANK_DELTA") % change.delta
		rank_delta.add_theme_color_override("font_color", TableKit.TEXT_GOOD if change.delta > 0
				else TableKit.TEXT_ALERT if change.delta < 0 else TableKit.TEXT_MUTED)
		var tier_name := tr(RankBalance.name_key(change.tier))
		if change.promoted():
			rank_note.text = tr("RANK_PROMOTED") % tier_name
			rank_note.add_theme_color_override("font_color", TableKit.TEXT_GOOD)
		elif change.demoted():
			rank_note.text = tr("RANK_DEMOTED") % tier_name
			rank_note.add_theme_color_override("font_color", TableKit.TEXT_ALERT)
	_layout()


func _layout() -> void:
	custom_minimum_size = Vector2i(TableLayout.POPUP_WIDTH, 0)
	size = Vector2i(TableLayout.POPUP_WIDTH, 0)
	show()
	reset_size()
	position = Vector2i(TableLayout.POPUP_CENTER.x - int(size.x) / 2,
			TableLayout.POPUP_CENTER.y - int(size.y) / 2)


func is_won() -> bool:
	return _title.text == "TABLE_VICTORY"
