class_name OpponentCard
extends Button
## Карточка персонажа-бота на экране соперников (М11): портрет в рамке, имя, ★ сложности,
## номер места, если выбран. Нажатие переключает выбор — решает экран.

const STAR := "★"

var personality: BotPersonality
var _frame: Panel
var _order: Label


func setup(p: BotPersonality) -> OpponentCard:
	personality = p
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = MenuLayout.CARD_SIZE
	size = MenuLayout.CARD_SIZE
	for slot in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(slot, StyleBoxEmpty.new())

	_frame = Panel.new()
	_frame.size = TableLayout.FRAME_SIZE
	_frame.position = Vector2i(MenuLayout.CARD_FRAME_X, 0)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var portrait := TableKit.icon_rect(Sprites.portrait(p.id))
	portrait.position = Vector2i(Sprites.FRAME_BORDER, Sprites.FRAME_BORDER)
	_frame.add_child(portrait)
	_order = TableKit.title("")
	_order.position = Vector2i(Sprites.FRAME_BORDER + 2, Sprites.FRAME_BORDER)
	_frame.add_child(_order)

	var name_label := TableKit.label(p.name_key, TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.position = Vector2i(0, MenuLayout.CARD_NAME_Y)
	name_label.size = Vector2i(MenuLayout.CARD_SIZE.x,
			MenuLayout.CARD_STARS_Y - MenuLayout.CARD_NAME_Y)
	add_child(name_label)
	var stars := TableKit.label(STAR.repeat(p.stars), TableKit.TEXT_ALERT,
			HORIZONTAL_ALIGNMENT_CENTER)
	stars.position = Vector2i(0, MenuLayout.CARD_STARS_Y)
	stars.size = Vector2i(MenuLayout.CARD_SIZE.x, MenuLayout.CARD_SIZE.y - MenuLayout.CARD_STARS_Y)
	add_child(stars)
	show_state(0, true)
	return self


## order — номер места (1…), 0 — не выбран; available — можно нажать.
func show_state(order: int, available: bool) -> void:
	var kind := Sprites.PanelKind.FRAME_ACTIVE if order > 0 else Sprites.PanelKind.FRAME
	_frame.add_theme_stylebox_override("panel", Sprites.panel(kind))
	_order.text = str(order) if order > 0 else ""
	disabled = not available
	modulate = Color.WHITE if available or order > 0 else MenuLayout.CARD_DIM


func order() -> int:
	return int(_order.text) if _order.text != "" else 0
