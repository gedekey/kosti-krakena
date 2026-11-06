class_name TableKit
extends RefCounted
## Мелкие помощники вёрстки стола (М9): спрайты кубиков, подписи, кнопки UI-кита.
## Правил здесь нет.

const DICE_SET := Sprites.DiceSet.BONE
const OWN_CUP := Sprites.CupStyle.WOOD
const BOT_CUP := Sprites.CupStyle.BRINE
## Кубики, которые не засчитаны во вскрытии, — притушены.
const DIM := Color(1, 1, 1, 0.35)
const TEXT := KrakenPalette.PARCHMENT
const TEXT_MUTED := KrakenPalette.BONE
const TEXT_ALERT := KrakenPalette.EMBER
const TEXT_MAGIC := KrakenPalette.LILAC
const TEXT_GOOD := KrakenPalette.LIME


static func die_rect(face: int, scale := 1) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Sprites.die(DICE_SET, face)
	_fix_size(rect, Sprites.DIE_SIZE * scale)
	return rect


static func icon_rect(texture: Texture2D, scale := 1) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	_fix_size(rect, Vector2i(texture.get_size()) * scale)
	return rect


static func set_die(rect: TextureRect, face: int) -> void:
	rect.texture = Sprites.die(DICE_SET, face)


static func label(text: String, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, glow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = PixelFonts.VARIATION_TITLE_GLOW if glow else PixelFonts.VARIATION_TITLE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, kind := Sprites.ButtonKind.PLAIN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	Sprites.style_button(b, kind)
	return b


static func arrow(right: bool) -> TextureButton:
	var b := TextureButton.new()
	Sprites.style_arrow(b, right)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func hbox(separation := 2) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func vbox(separation := 2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func panel(kind := Sprites.PanelKind.DARK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Sprites.panel(kind))
	return p


## Строка «N × [кубик]» (ставка).
static func bid_row(quantity: int, face: int, color := TEXT, prefix := "") -> HBoxContainer:
	var row := hbox(2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(label("%s%d ×" % [prefix, quantity], color))
	row.add_child(die_rect(face))
	return row


static func place(control: Control, rect: Rect2i) -> void:
	control.position = rect.position
	control.size = rect.size


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _fix_size(rect: TextureRect, size: Vector2i) -> void:
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = size
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
