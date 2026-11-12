class_name PortraitPicker
extends PanelContainer
## Выбор портрета игрока для кампании (М23): ◀ портрет ▶ и «Готово».

signal picked(portrait: StringName)

var ok_button: Button
var _portrait: TextureRect
var _index := 0


func _ready() -> void:
	add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.DARK))
	mouse_filter = Control.MOUSE_FILTER_STOP
	TableKit.place(self, CampaignLayout.PICKER_RECT)
	var margin := TutorialLayout.margin(MenuLayout.FORM_MARGIN)
	add_child(margin)
	var box := TableKit.vbox(8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	box.add_child(TableKit.title("CAMP_PICK_PORTRAIT"))
	var row := TableKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var left := TableKit.arrow(false)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.pressed.connect(step.bind(-1))
	row.add_child(left)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.FRAME))
	frame.custom_minimum_size = TableLayout.FRAME_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	_portrait = TableKit.add_portrait(frame, Sprites.portrait(Sprites.PLAYER_PORTRAITS[0]))
	var right := TableKit.arrow(true)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.pressed.connect(step.bind(1))
	row.add_child(right)
	var hint := TableKit.label("CAMP_PICK_HINT", TableKit.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = TutorialLayout.text_width(CampaignLayout.PICKER_RECT.size.x,
			MenuLayout.FORM_MARGIN)
	box.add_child(hint)
	ok_button = TableKit.button("CAMP_PICK_OK", Sprites.ButtonKind.BID)
	ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_button.pressed.connect(func() -> void:
		hide()
		picked.emit(portrait()))
	box.add_child(ok_button)
	hide()


func open(current: StringName) -> void:
	_index = maxi(0, Sprites.PLAYER_PORTRAITS.find(current))
	_refresh()
	show()


func step(delta: int) -> void:
	_index = posmod(_index + delta, Sprites.PLAYER_PORTRAITS.size())
	_refresh()


func portrait() -> StringName:
	return Sprites.PLAYER_PORTRAITS[_index]


func _refresh() -> void:
	_portrait.texture = Sprites.portrait(portrait())
