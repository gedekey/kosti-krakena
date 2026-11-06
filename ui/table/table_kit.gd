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
## М15: полупрозрачная тёмная подложка под текст поверх фона таверны и под портреты
## (у портретов прозрачный фон — без подложки они сливаются со стеной).
const TEXT_BACKING := Color(KrakenPalette.INK, 0.72)
const PORTRAIT_BACKING := Color(KrakenPalette.INK, 0.8)


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


## Подпись поверх фона — на полупрозрачной подложке, чтобы не сливалась.
static func backed_label(text: String, color := TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, color, align)
	set_backing(l)
	return l


static func set_backing(l: Label) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = TEXT_BACKING
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", box)


## Крупное число кубиков на подложке (у чашки). Значение — set_count_badge().
static func count_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = TEXT_BACKING
	box.border_color = KrakenPalette.BONE
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	box.content_margin_top = 0
	badge.add_theme_stylebox_override("panel", box)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(title(""))
	badge.visible = false
	return badge


## count < 0 — спрятать.
static func set_count_badge(badge: PanelContainer, count: int) -> void:
	badge.visible = count >= 0
	if count >= 0:
		(badge.get_child(0) as Label).text = str(count)
		badge.reset_size()


static func count_badge_text(badge: PanelContainer) -> String:
	return (badge.get_child(0) as Label).text if badge.visible else ""


## Портрет в рамке: подложка и сам портрет на отступе рамки. Возвращает портрет.
static func add_portrait(frame: Control, texture: Texture2D) -> TextureRect:
	var back := ColorRect.new()
	back.color = PORTRAIT_BACKING
	back.position = Vector2i(Sprites.FRAME_BORDER, Sprites.FRAME_BORDER)
	back.size = Sprites.PORTRAIT_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	var rect := icon_rect(texture)
	rect.position = Vector2i(Sprites.FRAME_BORDER, Sprites.FRAME_BORDER)
	frame.add_child(rect)
	return rect


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
