class_name LobbySeatCard
extends Control
## Место в лобби (М19): портрет в рамке, имя, кто сидит (хост, игрок, бот, «вы»).
## У хоста под местом бота — стрелки ◀ ▶: персонаж или «случайный».
## М20: у людей в углу портрета — значок сетевого ранга.

signal stepped(delta: int)

var left_arrow: TextureButton
var right_arrow: TextureButton
var _frame: Panel
var _portrait: TextureRect
var _unknown: Label
var _name: Label
var _role: Label
var rank_icon: TextureRect


func setup() -> LobbySeatCard:
	custom_minimum_size = MenuLayout.LOBBY_CARD_SIZE
	size = MenuLayout.LOBBY_CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = Panel.new()
	_frame.size = TableLayout.FRAME_SIZE
	_frame.position = Vector2i(MenuLayout.CARD_FRAME_X, 0)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_portrait = TableKit.add_portrait(_frame, Sprites.portrait(Sprites.PLAYER_PORTRAITS[0]))
	rank_icon = TableKit.icon_rect(RankBadge.texture(RankBalance.Tier.WOOD))
	rank_icon.position = MenuLayout.LOBBY_RANK_POS
	rank_icon.hide()
	add_child(rank_icon)
	_unknown = TableKit.title("?", true)
	_unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unknown.size = TableLayout.FRAME_SIZE
	_frame.add_child(_unknown)
	_name = TableKit.label("", TableKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_name.max_lines_visible = 2
	_name.position = Vector2i(0, MenuLayout.CARD_NAME_Y)
	_name.size = Vector2i(MenuLayout.LOBBY_CARD_SIZE.x, MenuLayout.LOBBY_CARD_NAME_H)
	add_child(_name)
	_role = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_role.position = Vector2i(0, MenuLayout.LOBBY_CARD_ROLE_Y)
	_role.size = Vector2i(MenuLayout.LOBBY_CARD_SIZE.x, 12)
	add_child(_role)
	var arrows := TableKit.hbox(MenuLayout.LOBBY_CARD_SIZE.x - 2 * TouchUI.ARROW_HIT.x)
	arrows.position = Vector2i(0, MenuLayout.LOBBY_ARROWS_Y - MenuLayout.LOBBY_CARDS_Y)
	arrows.size = Vector2i(MenuLayout.LOBBY_CARD_SIZE.x, TouchUI.ARROW_HIT.y)
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(arrows)
	left_arrow = _arrow(arrows, false)
	right_arrow = _arrow(arrows, true)
	return self


func _arrow(row: HBoxContainer, right: bool) -> TextureButton:
	var b := TableKit.arrow(right)
	b.pressed.connect(func() -> void: stepped.emit(1 if right else -1))
	TouchUI.enlarge(b, TouchUI.ARROW_HIT)
	row.add_child(b)
	return b


## info — кто сидит; you — это своё место; editable — хост может сменить бота.
func show_seat(info: SeatInfo, you: bool, editable: bool) -> void:
	var random := info.kind == SeatInfo.Kind.BOT and info.bot_id == NetLobby.RANDOM_BOT
	var character: StringName = info.bot_id if info.kind == SeatInfo.Kind.BOT \
			else Sprites.PLAYER_PORTRAITS[clampi(info.portrait, 0, Sprites.PLAYER_PORTRAITS.size() - 1)]
	_portrait.visible = not random
	_unknown.visible = random
	if not random:
		_portrait.texture = Sprites.portrait(character)
	var active := you or info.kind != SeatInfo.Kind.BOT
	_frame.add_theme_stylebox_override("panel", Sprites.panel(
			Sprites.PanelKind.FRAME_ACTIVE if you else Sprites.PanelKind.FRAME))
	_name.text = name_of(info)
	_name.add_theme_color_override("font_color", TableKit.TEXT if active else TableKit.TEXT_MUTED)
	match info.kind:
		SeatInfo.Kind.HOST:
			_role.text = "NET_ROLE_YOU_HOST" if you else "NET_ROLE_HOST"
		SeatInfo.Kind.GUEST:
			_role.text = "NET_ROLE_YOU" if you else "NET_ROLE_PLAYER"
		_:
			_role.text = "NET_ROLE_BOT"
	rank_icon.visible = info.kind != SeatInfo.Kind.BOT and info.rank >= 0
	if rank_icon.visible:
		rank_icon.texture = RankBadge.texture(info.rank as RankBalance.Tier)
	left_arrow.visible = editable and info.kind == SeatInfo.Kind.BOT
	right_arrow.visible = left_arrow.visible


## Имя места: человек — как ввёл, бот — по персонажу, «случайный» — так и пишем.
static func name_of(info: SeatInfo) -> String:
	if info.kind == SeatInfo.Kind.BOT:
		if info.bot_id == NetLobby.RANDOM_BOT:
			return TranslationServer.translate("NET_BOT_RANDOM")
		var p := BotRoster.by_id(info.bot_id)
		return TranslationServer.translate(p.name_key) if p != null else String(info.bot_id)
	return info.player_name if info.player_name != "" \
			else TranslationServer.translate("NET_DEFAULT_NAME")


func name_text() -> String:
	return _name.text


func role_text() -> String:
	return _role.text
