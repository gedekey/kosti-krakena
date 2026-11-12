class_name HobScene
extends Control
## Сцена с Хобом между уровнями (М23, DESIGN.md §8г): портрет и 1–3 реплики в облаке,
## текст печатается по буквам. Клик (или «Дальше») — допечатать / следующая реплика,
## «Пропустить» — сразу конец. На уровне 6 Хоб сбрасывает облик — говорит Глубоководный.

signal finished

const HOB := &"hob"

var next_button: Button
var skip_button: Button
var _frame: Panel
var _portrait: TextureRect
var _name: Label
var _cloud: PanelContainer
var _tail: Polygon2D
var _text: TypedLabel
## Реплики: [ключ, говорящий].
var _lines: Array = []
var _index := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(KrakenPalette.INK, 0.8)
	dim.size = MenuLayout.SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", Sprites.panel(Sprites.PanelKind.FRAME))
	_frame.position = CampaignLayout.HOB_FRAME_POS
	_frame.size = (Sprites.PORTRAIT_SIZE + Vector2i.ONE * Sprites.FRAME_BORDER) \
			* CampaignLayout.HOB_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var back := ColorRect.new()
	back.color = TableKit.PORTRAIT_BACKING
	back.position = Vector2i.ONE * Sprites.FRAME_BORDER
	back.size = Sprites.PORTRAIT_SIZE * CampaignLayout.HOB_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(back)
	_portrait = TableKit.icon_rect(HobPortrait.texture(), CampaignLayout.HOB_SCALE)
	_portrait.position = Vector2i.ONE * Sprites.FRAME_BORDER
	_frame.add_child(_portrait)
	_name = TableKit.backed_label("CAMP_HOB", TableKit.TEXT_MAGIC, HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = CampaignLayout.HOB_NAME_POS
	_name.size = Vector2i(int(_frame.size.x), PixelFonts.BODY_SIZE + 2)
	add_child(_name)

	_tail = Polygon2D.new()
	var cloud := CampaignLayout.HOB_CLOUD_RECT
	var ty := CampaignLayout.HOB_TAIL_Y
	_tail.polygon = PackedVector2Array([Vector2(cloud.position.x + 2, ty - 8),
			Vector2(cloud.position.x + 2, ty + 8), Vector2(int(_frame.position.x + _frame.size.x) + 4, ty)])
	_tail.color = KrakenPalette.PARCHMENT
	add_child(_tail)
	_cloud = TableKit.panel(Sprites.PanelKind.PARCHMENT)
	TableKit.place(_cloud, cloud)
	_cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cloud)
	var margin := TutorialLayout.margin(CampaignLayout.HOB_CLOUD_MARGIN)
	_cloud.add_child(margin)
	_text = TypedLabel.make(KrakenPalette.INK,
			TutorialLayout.text_width(cloud.size.x, CampaignLayout.HOB_CLOUD_MARGIN))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	margin.add_child(_text)

	skip_button = TableKit.button("CAMP_SKIP")
	TableKit.place(skip_button, CampaignLayout.SCENE_SKIP_RECT)
	skip_button.pressed.connect(skip)
	add_child(skip_button)
	next_button = TableKit.button("CAMP_NEXT", Sprites.ButtonKind.BID)
	TableKit.place(next_button, CampaignLayout.SCENE_NEXT_RECT)
	next_button.pressed.connect(advance)
	add_child(next_button)
	hide()


## Сыграть реплики. lines — [[ключ, говорящий], …]; говорящий &"hob" или id персонажа.
func play(lines: Array) -> void:
	_lines = lines
	_index = 0
	if _lines.is_empty():
		finished.emit()
		return
	show()
	_show_line()


## Реплики уровня перед ним (after = false) или после победы.
static func lines_for(level: CampaignLevel, after: bool) -> Array:
	var out := []
	var keys := level.after_keys if after else level.before_keys
	for i in keys.size():
		out.append([keys[i], level.scene_speaker(after, i)])
	return out


## Клик / «Дальше»: допечатать реплику, иначе — следующая; после последней — конец.
func advance() -> void:
	if not visible:
		return
	if not _text.is_done():
		_text.finish()
		return
	_index += 1
	if _index >= _lines.size():
		_end()
	else:
		_show_line()


func skip() -> void:
	if visible:
		_end()


func is_playing() -> bool:
	return visible


func current_key() -> String:
	return _lines[_index][0] if visible and _index < _lines.size() else ""


func current_speaker() -> StringName:
	return _lines[_index][1] if visible and _index < _lines.size() else &""


func _show_line() -> void:
	var speaker: StringName = _lines[_index][1]
	if speaker == HOB:
		_portrait.texture = HobPortrait.texture()
		_name.text = "CAMP_HOB"
	else:
		_portrait.texture = Sprites.portrait(speaker)
		var p := BotRoster.by_id(speaker)
		_name.text = p.name_key if p != null else String(speaker)
	_text.type_text(tr(_lines[_index][0]))


func _end() -> void:
	_text.finish()
	hide()
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()
