extends MenuScreen
## Правила (М13, DESIGN.md §7): страницы с иллюстрациями из спрайтов игры — ставки,
## единицы, «Ложь!» и «Точно!», Палифико, трюки, улики и обвинение, Рассудок и Безумие.
## ◀ ▶ (и стрелки клавиатуры) листают страницы. Числа в текстах — из констант баланса
## и правил, таблица трюков — из Cheat (ничего не дублируется).

## Страницы по порядку: [заголовок, текст].
const PAGES := [
	["RULES_BIDS_TITLE", "RULES_BIDS_TEXT"],
	["RULES_ONES_TITLE", "RULES_ONES_TEXT"],
	["RULES_CHALLENGE_TITLE", "RULES_CHALLENGE_TEXT"],
	["RULES_PALIFICO_TITLE", "RULES_PALIFICO_TEXT"],
	["RULES_TRICKS_TITLE", "RULES_TRICKS_TEXT"],
	["RULES_EVIDENCE_TITLE", "RULES_EVIDENCE_TEXT"],
	["RULES_MADNESS_TITLE", "RULES_MADNESS_TEXT"],
]

var page := 0
var prev_button: TextureButton
var next_button: TextureButton
var _page_title: Label
var _illustration: HBoxContainer
var _text: TermLabel
var _counter: Label


func _ready() -> void:
	_build_backdrop("RULES_TITLE")
	var panel := TableKit.panel(Sprites.PanelKind.DARK)
	TableKit.place(panel, MenuLayout.RULES_PAGE_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var margin := TutorialLayout.margin(MenuLayout.RULES_PAGE_MARGIN)
	panel.add_child(margin)
	var box := TableKit.vbox(6)
	margin.add_child(box)
	_page_title = TableKit.title("")
	box.add_child(_page_title)
	_illustration = TableKit.hbox(6)
	_illustration.alignment = BoxContainer.ALIGNMENT_CENTER
	_illustration.custom_minimum_size.y = MenuLayout.RULES_ILLUSTRATION_H
	box.add_child(_illustration)
	_text = TermLabel.make(TableKit.TEXT, false, TutorialLayout.text_width(
			MenuLayout.RULES_PAGE_RECT.size.x, MenuLayout.RULES_PAGE_MARGIN))
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)

	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	var nav := TableKit.hbox(6)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	TableKit.place(nav, MenuLayout.RULES_NAV_RECT)
	add_child(nav)
	prev_button = TableKit.arrow(false)
	prev_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prev_button.pressed.connect(turn.bind(-1))
	nav.add_child(prev_button)
	_counter = TableKit.label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_counter.custom_minimum_size.x = 48
	nav.add_child(_counter)
	next_button = TableKit.arrow(true)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.pressed.connect(turn.bind(1))
	nav.add_child(next_button)

	# Как открыть подсказку к термину: на ПК — ПКМ, на телефоне — тап.
	# Поверх фона — на подложке по ширине текста, прижата вправо.
	var term_hint := TableKit.backed_label(term_hint_key(), TableKit.TEXT_MUTED)
	add_child(term_hint)
	term_hint.reset_size()
	var r := MenuLayout.RULES_TERM_HINT_RECT
	term_hint.position = Vector2i(r.end.x - int(term_hint.size.x),
			r.position.y + (r.size.y - int(term_hint.size.y)) / 2)

	Events.locale_changed.connect(_on_locale_changed)
	show_page(0)


static func term_hint_key() -> String:
	return "TERM_HINT_TOUCH" if OS.has_feature("mobile") else "TERM_HINT_MOUSE"


func page_count() -> int:
	return PAGES.size()


## Перелистнуть на step страниц (без зацикливания).
func turn(step: int) -> void:
	show_page(clampi(page + step, 0, PAGES.size() - 1))


func show_page(index: int) -> void:
	page = index
	_page_title.text = PAGES[page][0]
	_text.set_term_text(PAGES[page][1], _args(page))
	_counter.text = "%d / %d" % [page + 1, PAGES.size()]
	prev_button.disabled = page == 0
	next_button.disabled = page == PAGES.size() - 1
	TableKit.clear(_illustration)
	_illustrate(page)


func page_text() -> String:
	return _text.plain_text()


func page_label() -> TermLabel:
	return _text


func illustration() -> HBoxContainer:
	return _illustration


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		turn(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		turn(1)
	else:
		super._unhandled_input(event)


func _on_locale_changed(_locale: String) -> void:
	show_page(page)


## Числа для текста страницы — из правил и баланса.
func _args(index: int) -> Array:
	match PAGES[index][0]:
		"RULES_BIDS_TITLE":
			return [PerudoRules.START_DICE]
		"RULES_CHALLENGE_TITLE":
			return [PerudoRules.MAX_DICE]
		"RULES_TRICKS_TITLE":
			return [CheatBalance.START_SANITY]
		"RULES_EVIDENCE_TITLE":
			return [roundi(CheatBalance.TRICK_EVIDENCE_CHANCE * 100.0),
					roundi(CheatBalance.FALSE_EVIDENCE_CHANCE * 100.0),
					CheatBalance.CAUGHT_DICE_PENALTY, CheatBalance.FALSE_ACCUSATION_PENALTY]
		"RULES_MADNESS_TITLE":
			return [CheatBalance.START_SANITY, roundi(MadnessBalance.HALLUCINATION_CHANCE * 100.0)]
	return []


# --- Иллюстрации ---------------------------------------------------------------------

func _illustrate(index: int) -> void:
	var s := MenuLayout.RULES_SCALE
	match PAGES[index][0]:
		"RULES_BIDS_TITLE":
			_add(TableKit.icon_rect(Sprites.cup(TableKit.OWN_CUP, true), s))
			_add_dice([3, 3, 5, 2, 6], s)
			_add_bid(3, 3)
		"RULES_ONES_TITLE":
			for face in [1, 4, 4, 1, 6]:
				var die := TableKit.die_rect(face, s)
				if face == 6:
					die.modulate = TableKit.DIM
				_add(die)
			_add(TableKit.title("="))
			_add_bid(4, 4)
		"RULES_CHALLENGE_TITLE":
			_add(_sample_button("ACTION_LIAR", Sprites.ButtonKind.LIAR))
			_add(_sample_button("ACTION_CALZA", Sprites.ButtonKind.CALZA))
		"RULES_PALIFICO_TITLE":
			_add(TableKit.icon_rect(Sprites.cup(TableKit.OWN_CUP, true), s))
			_add(TableKit.die_rect(5, s))
			var l := TableKit.title("TABLE_PALIFICO")
			l.add_theme_color_override("font_color", TableKit.TEXT_MAGIC)
			_add(l)
		"RULES_TRICKS_TITLE":
			_add(_tricks_table())
		"RULES_EVIDENCE_TITLE":
			_add(TableKit.icon_rect(Sprites.texture(Sprites.ICON_EVIDENCE), s))
			_add(TableKit.icon_rect(Sprites.cup(TableKit.BOT_CUP, false), s))
			_add(_sample_button("ACCUSE", Sprites.ButtonKind.ACCUSE))
		"RULES_MADNESS_TITLE":
			var pips := TableKit.hbox(1)
			for i in CheatBalance.START_SANITY:
				pips.add_child(TableKit.icon_rect(Sprites.sanity_pip(i < 3), s))
			pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_add(pips)
			_add(TableKit.icon_rect(Sprites.portrait(Sprites.PLAYER_PORTRAITS[0])))
			_add(TableKit.icon_rect(Sprites.portrait(Sprites.PLAYER_PORTRAITS[0], true)))


func _add(c: Control) -> void:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_illustration.add_child(c)


func _add_dice(faces: Array, scale: int) -> void:
	for face: int in faces:
		_add(TableKit.die_rect(face, scale))


func _add_bid(quantity: int, face: int) -> void:
	_add(TableKit.title("%d ×" % quantity))
	_add(TableKit.die_rect(face, MenuLayout.RULES_SCALE))


## Кнопка как на столе — только картинка, не нажимается.
func _sample_button(key: String, kind: Sprites.ButtonKind) -> Button:
	var b := TableKit.button(key, kind)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta(Sound.SILENT_META, true)
	return b


## Все трюки: иконка, название, цена в Рассудке и риск — из Cheat.
func _tricks_table() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind in Cheat.ALL:
		var row := TableKit.hbox(3)
		row.add_child(TableKit.icon_rect(Sprites.trick_icon(kind)))
		row.add_child(TableKit.label(tr("TABLE_TRICK_OPTION") % [tr(Cheat.name_key(kind)),
				Cheat.cost(kind), roundi(Cheat.risk(kind) * 100.0)], TableKit.TEXT))
		grid.add_child(row)
	return grid
