extends MenuScreen
## Выбор соперников (М11, DESIGN.md §5–6): портрет игрока, соперники вручную (1–5, места —
## в порядке выбора) или «случайные» (сколько), затем «За стол!» — MatchSetup.pending.
## Выбор запоминается в Settings до следующего раза.

var random_button: Button
var manual_button: Button
var count_stepper: ValueStepper
var start_button: Button
var portrait_left: TextureButton
var portrait_right: TextureButton
var cards: Array[OpponentCard] = []

var _portrait: TextureRect
var _info: Label
var _rules: Label
var _portrait_index := 0
var _random := true
var _count := MatchSetup.DEFAULT_OPPONENTS
var _picked: Array[StringName] = []


func _ready() -> void:
	_build_backdrop("SETUP_TITLE")
	_load_choice()

	var caption := TableKit.label("SETUP_PORTRAIT", TableKit.TEXT_MUTED)
	caption.position = MenuLayout.PORTRAIT_CAPTION_POS
	add_child(caption)
	var portrait_row := TableKit.hbox(3)
	portrait_row.position = MenuLayout.PORTRAIT_ROW_POS
	add_child(portrait_row)
	portrait_left = _portrait_arrow(portrait_row, false)
	var frame := Panel.new()
	frame.custom_minimum_size = TableLayout.FRAME_SIZE
	frame.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.FRAME))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_row.add_child(frame)
	_portrait = TableKit.add_portrait(frame, Sprites.portrait(Sprites.PLAYER_PORTRAITS[0]))
	portrait_right = _portrait_arrow(portrait_row, true)

	var mode_row := TableKit.hbox(4)
	mode_row.position = MenuLayout.MODE_ROW_POS
	add_child(mode_row)
	random_button = TableKit.button("SETUP_RANDOM")
	random_button.pressed.connect(_set_random.bind(true))
	mode_row.add_child(random_button)
	manual_button = TableKit.button("SETUP_MANUAL")
	manual_button.pressed.connect(_set_random.bind(false))
	mode_row.add_child(manual_button)

	count_stepper = ValueStepper.new()
	count_stepper.position = MenuLayout.COUNT_ROW_POS
	add_child(count_stepper)
	count_stepper.setup("SETUP_COUNT", 0, 24)
	count_stepper.stepped.connect(_step_count)

	_info = TableKit.label("", TableKit.TEXT)
	_info.position = MenuLayout.SETUP_INFO_POS
	_info.size.x = MenuLayout.SETUP_INFO_WIDTH
	add_child(_info)

	var cards_panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(cards_panel, MenuLayout.CARDS_PANEL_RECT)
	cards_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards_panel)
	var roster := BotRoster.all()
	var positions := MenuLayout.card_positions(roster.size())
	for i in roster.size():
		var card := OpponentCard.new()
		add_child(card)
		card.setup(roster[i])
		card.position = positions[i]
		card.pressed.connect(_toggle_card.bind(roster[i].id))
		cards.append(card)

	_rules = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	TableKit.place(_rules, MenuLayout.RULES_INFO_RECT)
	add_child(_rules)

	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	start_button = _placed_button("SETUP_START", MenuLayout.PRIMARY_RECT, start,
			Sprites.ButtonKind.BID)
	Events.locale_changed.connect(_on_locale_changed)
	refresh()


func _portrait_arrow(row: HBoxContainer, right: bool) -> TextureButton:
	var b := TableKit.arrow(right)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_step_portrait.bind(1 if right else -1))
	row.add_child(b)
	return b


## Сколько соперников можно посадить за стол.
static func max_opponents() -> int:
	return mini(MatchController.MAX_PLAYERS - 1, BotRoster.PATHS.size())


static func min_opponents() -> int:
	return MatchController.MIN_PLAYERS - 1


func player_portrait() -> StringName:
	return Sprites.PLAYER_PORTRAITS[_portrait_index]


func picked() -> Array[StringName]:
	return _picked.duplicate()


func is_random() -> bool:
	return _random


func opponent_count() -> int:
	return _count if _random else _picked.size()


func can_start() -> bool:
	return opponent_count() >= min_opponents()


## Настройка стола по текущему выбору.
func build_setup() -> MatchSetup:
	var setup := MatchSetup.from_settings()
	setup.player_portrait = player_portrait()
	setup.opponent_count = opponent_count()
	if not _random:
		setup.opponents = picked()
	return setup


func start() -> void:
	if not can_start():
		return
	MatchSetup.pending = build_setup()
	ScreenNav.go(ScreenNav.TABLE)


func info_text() -> String:
	return _info.text


func refresh() -> void:
	_portrait.texture = Sprites.portrait(player_portrait())
	Sprites.style_button(random_button,
			Sprites.ButtonKind.BID if _random else Sprites.ButtonKind.PLAIN)
	Sprites.style_button(manual_button,
			Sprites.ButtonKind.PLAIN if _random else Sprites.ButtonKind.BID)
	count_stepper.visible = _random
	count_stepper.set_value_text(str(_count))
	count_stepper.set_can_step(_count > min_opponents(), _count < max_opponents())
	var full := _picked.size() >= max_opponents()
	for card in cards:
		var order := _picked.find(card.personality.id) + 1
		card.show_state(0 if _random else order, not _random and (order > 0 or not full))
	if _random:
		_info.text = tr("SETUP_RANDOM_HINT") % (_count + 1)
	elif _picked.is_empty():
		_info.text = tr("SETUP_PICK_HINT") % max_opponents()
	else:
		_info.text = tr("SETUP_PLAYERS") % (_picked.size() + 1)
	_rules.text = tr("SETUP_RULES") % [_on_off(&"palifico"), _on_off(&"calza")]
	start_button.disabled = not can_start()


func _on_off(key: StringName) -> String:
	return tr("SETTINGS_ON" if Settings.get_value(key) else "SETTINGS_OFF")


func _on_locale_changed(_locale: String) -> void:
	refresh()


# --- Выбор ---------------------------------------------------------------------

func _step_portrait(delta: int) -> void:
	_portrait_index = posmod(_portrait_index + delta, Sprites.PLAYER_PORTRAITS.size())
	_save_choice()


func _set_random(value: bool) -> void:
	_random = value
	_save_choice()


func _step_count(delta: int) -> void:
	_count = clampi(_count + delta, min_opponents(), max_opponents())
	_save_choice()


func _toggle_card(id: StringName) -> void:
	if _random:
		return
	var i := _picked.find(id)
	if i >= 0:
		_picked.remove_at(i)
	elif _picked.size() < max_opponents():
		_picked.append(id)
	_save_choice()


func _load_choice() -> void:
	_portrait_index = maxi(Sprites.PLAYER_PORTRAITS.find(
			StringName(Settings.get_value(&"player_portrait"))), 0)
	_random = Settings.get_value(&"opponents_random")
	_count = clampi(Settings.get_value(&"opponent_count"), min_opponents(), max_opponents())
	_picked.clear()
	for id: String in Settings.get_value(&"opponents"):
		var sid := StringName(id)
		if BotRoster.by_id(sid) != null and not sid in _picked \
				and _picked.size() < max_opponents():
			_picked.append(sid)


func _save_choice() -> void:
	Settings.set_value(&"player_portrait", String(player_portrait()))
	Settings.set_value(&"opponents_random", _random)
	Settings.set_value(&"opponent_count", _count)
	var ids: Array = []
	for id in _picked:
		ids.append(String(id))
	Settings.set_value(&"opponents", ids)
	refresh()
