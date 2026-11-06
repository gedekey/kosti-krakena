extends Control
## Витрина спрайтов (М8): все нарисованные в проекте спрайты на одном экране.
##
## Страницы: кубики и чашки (с анимацией броска), UI-кит (живые кнопки, счётчики ◀ ▶,
## панели, рамки, Рассудок), иконки, заглушки портретов (обычные / Безумие), заглушка фона.

enum Page { DICE, UI, ICONS, PORTRAITS, BACKGROUND }

const PAGE_KEYS := {
	Page.DICE: "SPRITES_TAB_DICE", Page.UI: "SPRITES_TAB_UI", Page.ICONS: "SPRITES_TAB_ICONS",
	Page.PORTRAITS: "SPRITES_TAB_PORTRAITS", Page.BACKGROUND: "SPRITES_TAB_BACKGROUND",
}
const MARGIN := 6
const SEPARATION := 4
## Сколько кадров длится бросок в витрине.
const ROLL_TICKS := 8
const SANITY_SHOWN := 6
const QUANTITY_MAX := 30
const PORTRAIT_COLUMNS := 5
const ICON_COLUMNS := 4

const ACTION_BUTTONS := {
	Sprites.ButtonKind.PLAIN: "ACTION_TRICKS", Sprites.ButtonKind.BID: "ACTION_BID",
	Sprites.ButtonKind.LIAR: "ACTION_LIAR", Sprites.ButtonKind.CALZA: "ACTION_CALZA",
	Sprites.ButtonKind.ACCUSE: "ACCUSE",
}

var _pages := {}
var _tab_buttons := {}
var _content_panel: PanelContainer
var _dice_rects := {}          # DiceSet → Array[TextureRect]
var _roll_timer: Timer
var _roll_tick := 0
var _faces: Array[int] = [1, 2, 3, 4, 5, 6]
var _portrait_rects := {}      # id → TextureRect
var _mad := false
var _quantity := 3
var _face := 5
var _quantity_label: Label
var _face_rect: TextureRect


func _ready() -> void:
	_build_ui()
	_show_page(Page.DICE)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = Sprites.background()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", SEPARATION)
	root.add_child(header)
	var title := _label(header, "SPRITES_TITLE")
	title.theme_type_variation = PixelFonts.VARIATION_TITLE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for locale in Settings.SUPPORTED_LOCALES:
		var lang := _button(header, "LANG_" + locale.to_upper(), Sprites.ButtonKind.PLAIN)
		lang.pressed.connect(Settings.set_value.bind(&"locale", locale))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", SEPARATION)
	root.add_child(tabs)
	for page: Page in PAGE_KEYS:
		var b := _button(tabs, PAGE_KEYS[page], Sprites.ButtonKind.PLAIN)
		b.pressed.connect(_show_page.bind(page))
		_tab_buttons[page] = b

	_content_panel = PanelContainer.new()
	_content_panel.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content_panel)
	_pages[Page.DICE] = _build_dice_page()
	_pages[Page.UI] = _build_ui_page()
	_pages[Page.ICONS] = _build_icons_page()
	_pages[Page.PORTRAITS] = _build_portraits_page()
	_pages[Page.BACKGROUND] = Control.new()
	for page: Control in _pages.values():
		_content_panel.add_child(page)

	_roll_timer = Timer.new()
	_roll_timer.wait_time = 1.0 / Sprites.DIE_ROLL_FPS
	_roll_timer.timeout.connect(_on_roll_tick)
	add_child(_roll_timer)


func _show_page(page: Page) -> void:
	for p: Page in _pages:
		_pages[p].visible = p == page
		Sprites.style_button(_tab_buttons[p],
				Sprites.ButtonKind.CALZA if p == page else Sprites.ButtonKind.PLAIN)
	# На странице фона панель прозрачная, чтобы фон был виден целиком.
	_content_panel.self_modulate.a = 0.0 if page == Page.BACKGROUND else 1.0


# --- Кубики и чашки --------------------------------------------------------

func _build_dice_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", SEPARATION * 2)
	for dice_set: Sprites.DiceSet in Sprites.DICE_SET_IDS:
		var row := _row(page)
		var name_label := _label(row, "SPRITES_BONE" if dice_set == Sprites.DiceSet.BONE \
				else "SPRITES_OBSIDIAN")
		name_label.custom_minimum_size.x = 96
		var rects: Array[TextureRect] = []
		for face in range(1, 7):
			rects.append(_die_slot(row, Sprites.die(dice_set, face)))
		_dice_rects[dice_set] = rects
		row.add_child(VSeparator.new())
		for frame in Sprites.DIE_ROLL_FRAMES:
			_die_slot(row, Sprites.die_roll(dice_set, frame))

	_label(page, "SPRITES_CUPS")
	var cups := _row(page)
	cups.add_theme_constant_override("separation", SEPARATION * 3)
	for style: Sprites.CupStyle in Sprites.CUP_STYLE_IDS:
		for open in [false, true]:
			var slot := VBoxContainer.new()
			slot.add_theme_constant_override("separation", -2)
			slot.add_child(_texture(Sprites.cup(style, open)))
			var shadow := _texture(Sprites.cup_shadow())
			shadow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.add_child(shadow)
			cups.add_child(slot)

	var roll := _button(page, "SPRITES_ROLL", Sprites.ButtonKind.BID)
	roll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	roll.pressed.connect(roll_dice)
	return page


## Запустить анимацию броска: кадры кувыркания, потом новые грани.
func roll_dice() -> void:
	_roll_tick = 0
	_roll_timer.start()


func _on_roll_tick() -> void:
	_roll_tick += 1
	var done := _roll_tick >= ROLL_TICKS
	if done:
		_roll_timer.stop()
		for i in _faces.size():
			_faces[i] = randi_range(1, 6)
	for dice_set: Sprites.DiceSet in _dice_rects:
		var rects: Array = _dice_rects[dice_set]
		for i in rects.size():
			rects[i].texture = Sprites.die(dice_set, _faces[i]) if done \
					else Sprites.die_roll(dice_set, _roll_tick + i)


func _die_slot(parent: Node, tex: Texture2D) -> TextureRect:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", -1)
	var rect := _texture(tex)
	slot.add_child(rect)
	slot.add_child(_texture(Sprites.die_shadow()))
	parent.add_child(slot)
	return rect


# --- UI-кит ---------------------------------------------------------------

func _build_ui_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", SEPARATION)
	for disabled in [false, true]:
		var row := _row(page)
		for kind: Sprites.ButtonKind in ACTION_BUTTONS:
			_button(row, ACTION_BUTTONS[kind], kind).disabled = disabled

	var counters := _row(page)
	counters.add_theme_constant_override("separation", SEPARATION * 2)
	_quantity_label = Label.new()
	_quantity_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_label.custom_minimum_size.x = 16
	_counter(counters, _quantity_label, _change_quantity)
	_face_rect = TextureRect.new()
	_counter(counters, _face_rect, _change_face)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 1)
	pips.add_child(_texture(Sprites.texture(Sprites.ICON_SANITY)))
	for i in CheatBalance.START_SANITY:
		var pip := _texture(Sprites.sanity_pip(i < SANITY_SHOWN))
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
	counters.add_child(pips)
	_refresh_counters()

	var panels := _row(page)
	panels.add_theme_constant_override("separation", SEPARATION * 2)
	_boxed(panels, Sprites.PanelKind.PARCHMENT, _label(null, "SPRITES_PANEL_PARCHMENT",
			KrakenPalette.INK))
	_boxed(panels, Sprites.PanelKind.FIELD, _label(null, "SPRITES_PANEL_FIELD"))
	var bubble := _label(null, "", KrakenPalette.INK)
	bubble.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bubble.text = "3 × 5"
	_boxed(panels, Sprites.PanelKind.BUBBLE, bubble)
	for kind in [Sprites.PanelKind.FRAME, Sprites.PanelKind.FRAME_ACTIVE]:
		var frame := _boxed(panels, kind, _texture(Sprites.portrait(&"sailor")))
		frame.add_theme_stylebox_override("panel", _portrait_frame(kind))
	return page


func _counter(parent: Node, value: Control, change: Callable) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for right in [false, true]:
		var arrow := TextureButton.new()
		Sprites.style_arrow(arrow, right)
		arrow.pressed.connect(change.bind(1 if right else -1))
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(arrow)
		if not right:
			var field := PanelContainer.new()
			field.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.FIELD))
			field.add_child(value)
			box.add_child(field)
	parent.add_child(box)


func _change_quantity(delta: int) -> void:
	_quantity = clampi(_quantity + delta, 1, QUANTITY_MAX)
	_refresh_counters()


func _change_face(delta: int) -> void:
	_face = wrapi(_face + delta, 1, 7)
	_refresh_counters()


func _refresh_counters() -> void:
	_quantity_label.text = str(_quantity)
	_face_rect.texture = Sprites.die(Sprites.DiceSet.BONE, _face)


func _boxed(parent: Node, kind: Sprites.PanelKind, content: Control) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Sprites.panel(kind))
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(content)
	parent.add_child(box)
	return box


## Рамка портрета: край рамки (4 px) вплотную к портрету.
func _portrait_frame(kind: Sprites.PanelKind) -> StyleBoxTexture:
	var box := Sprites.panel(kind)
	box.set_content_margin_all(Sprites.FRAME_BORDER)
	return box


# --- Иконки ---------------------------------------------------------------

func _build_icons_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = ICON_COLUMNS
	grid.add_theme_constant_override("h_separation", SEPARATION * 3)
	grid.add_theme_constant_override("v_separation", SEPARATION)
	var items: Array = []
	for kind: Cheat.Kind in Cheat.ALL:
		items.append([Sprites.trick_icon(kind), Cheat.name_key(kind)])
	items.append_array([
		[Sprites.texture(Sprites.ICON_SANITY), "SANITY"],
		[Sprites.texture(Sprites.ICON_EVIDENCE), "SPRITES_ICON_EVIDENCE"],
		[Sprites.texture(Sprites.ICON_MADNESS), "SPRITES_ICON_MADNESS"],
		[Sprites.texture(Sprites.ICON_DICE), "SPRITES_ICON_DICE"],
		[Sprites.texture(Sprites.ICON_ACCUSE), "ACCUSE"],
	])
	for item in items:
		var row := _row(grid)
		row.add_child(_texture(item[0]))
		_label(row, item[1])
	return grid


# --- Портреты -------------------------------------------------------------

func _build_portraits_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", SEPARATION)
	var toggle := _button(page, "SPRITES_MADNESS_TOGGLE", Sprites.ButtonKind.LIAR)
	toggle.toggle_mode = true
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toggle.toggled.connect(set_madness)
	var grid := GridContainer.new()
	grid.columns = PORTRAIT_COLUMNS
	grid.add_theme_constant_override("h_separation", SEPARATION)
	grid.add_theme_constant_override("v_separation", SEPARATION)
	page.add_child(grid)
	for id in Sprites.portrait_characters():
		var rect := _texture(Sprites.portrait(id))
		_portrait_rects[id] = rect
		var frame := _boxed(grid, Sprites.PanelKind.FRAME, rect)
		frame.add_theme_stylebox_override("panel", _portrait_frame(Sprites.PanelKind.FRAME))
	_label(page, "SPRITES_PLACEHOLDER_NOTE", KrakenPalette.BONE)
	return page


func set_madness(mad: bool) -> void:
	_mad = mad
	for id: StringName in _portrait_rects:
		_portrait_rects[id].texture = Sprites.portrait(id, mad)


# --- Помощники ------------------------------------------------------------

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	parent.add_child(row)
	return row


func _label(parent: Node, key: String, color: Color = KrakenPalette.PARCHMENT) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if parent != null:
		parent.add_child(label)
	return label


func _button(parent: Node, key: String, kind: Sprites.ButtonKind) -> Button:
	var button := Button.new()
	button.text = key
	Sprites.style_button(button, kind)
	parent.add_child(button)
	return button


func _texture(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	return rect
