extends MenuScreen
## Достижения (М17, DESIGN.md §8а): все 15 карточек — иконка, название, описание
## (у счётчиков — прогресс). Закрытые притушены. Сверху — «Открыто: N из 15».

var count_label: Label
## Achievement.Id → карточка (PanelContainer).
var cards := {}


func _ready() -> void:
	_build_backdrop("ACH_TITLE")
	count_label = TableKit.backed_label("", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var count_row := TableKit.hbox(0)
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	TableKit.place(count_row, MenuLayout.ACH_COUNT_RECT)
	count_row.add_child(count_label)
	add_child(count_row)
	var i := 0
	for id in Achievement.ALL:
		var card := _card(id)
		var col := i % MenuLayout.ACH_COLUMNS
		var row := i / MenuLayout.ACH_COLUMNS
		card.position = MenuLayout.ACH_GRID_POS + Vector2i(
				col * (MenuLayout.ACH_CELL_SIZE.x + MenuLayout.ACH_COL_GAP),
				row * (MenuLayout.ACH_CELL_SIZE.y + MenuLayout.ACH_ROW_GAP))
		add_child(card)
		cards[id] = card
		i += 1
	_placed_button("MENU_BACK", MenuLayout.BACK_RECT, go_back)
	Events.locale_changed.connect(func(_l: String) -> void: refresh())
	refresh()


func refresh() -> void:
	count_label.text = tr("ACH_COUNT") % [Achievements.unlocked_count(), Achievement.ALL.size()]
	for id: Achievement.Id in cards:
		var card: PanelContainer = cards[id]
		var open := Achievements.is_unlocked(id)
		var icon: TextureRect = card.get_meta(&"icon")
		icon.modulate = Color.WHITE if open else AchievementView.LOCKED_TINT
		var name_label: Label = card.get_meta(&"name")
		name_label.add_theme_color_override("font_color",
				TableKit.TEXT_GOOD if open else TableKit.TEXT_MUTED)
		var desc: TermLabel = card.get_meta(&"desc")
		desc.set_term_text(AchievementView.description(id, Achievements.progress(id)))


## Открыто ли достижение по мнению экрана (для тестов).
func is_shown_unlocked(id: Achievement.Id) -> bool:
	var icon: TextureRect = cards[id].get_meta(&"icon")
	return icon.modulate == Color.WHITE


func description_of(id: Achievement.Id) -> String:
	var desc: TermLabel = cards[id].get_meta(&"desc")
	return desc.plain_text()


func _card(id: Achievement.Id) -> PanelContainer:
	var card := TableKit.panel(Sprites.PanelKind.DARK)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = MenuLayout.ACH_CELL_SIZE
	card.size = MenuLayout.ACH_CELL_SIZE
	var margin := TutorialLayout.margin(MenuLayout.ACH_CELL_MARGIN)
	card.add_child(margin)
	var row := TableKit.hbox(MenuLayout.ACH_ICON_GAP)
	margin.add_child(row)
	var icon := TableKit.icon_rect(AchievementView.icon(id))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := TableKit.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := TableKit.label(Achievement.name_key(id))
	text.add_child(name_label)
	var width := TutorialLayout.text_width(MenuLayout.ACH_CELL_SIZE.x,
			MenuLayout.ACH_CELL_MARGIN) - Sprites.ICON_SIZE.x - MenuLayout.ACH_ICON_GAP
	var desc := TermLabel.make(TableKit.TEXT, false, width)
	text.add_child(desc)
	card.set_meta(&"icon", icon)
	card.set_meta(&"name", name_label)
	card.set_meta(&"desc", desc)
	return card
