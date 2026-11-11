class_name Sprites
extends RefCounted
## Доступ к нарисованным в проекте спрайтам (М8).
##
## Атласы собирает tools/build_sprites.gd (рисует SpritePainter):
##   ui/sprites/atlas_main.png       — кубики, чашки, UI-кит, иконки;
##   ui/sprites/atlas_portraits.png  — портреты 64×64;
##   ui/sprites/background_*.png      — фоны 640×360 (таверна, меню, победа, поражение).
## Портреты и фоны берутся из assets/generated/ (М14, GeneratedArt), без них — заглушки М8.
## Регионы — в сгенерированном ui/sprites/sprite_regions.gd.
##
## Атласы грузятся лениво (load, не preload): генератор сам использует перечисления
## отсюда и должен работать, даже когда атласов ещё нет.

enum DiceSet { BONE, OBSIDIAN }
## Чашки: дерево с глазом, морская (зелёные щупальца), бездна (фиолетовые щупальца).
enum CupStyle { WOOD, BRINE, ABYSS }
enum ButtonKind { PLAIN, BID, LIAR, CALZA, ACCUSE }
enum ButtonState { NORMAL, HOVER, PRESSED, DISABLED }
## Девятисрезные панели и рамки.
enum PanelKind { DARK, PARCHMENT, FRAME, FRAME_ACTIVE, BUBBLE, FIELD }
## Фоны: стол таверны, главное меню (и все экраны меню), победа, поражение.
enum Background { TAVERN, MENU, VICTORY, DEFEAT }

const MAIN_ATLAS_PATH := "res://ui/sprites/atlas_main.png"
const PORTRAIT_ATLAS_PATH := "res://ui/sprites/atlas_portraits.png"
const BACKGROUND_PATH := "res://ui/sprites/background_tavern.png"
const BACKGROUND_PATHS := {
	Background.TAVERN: BACKGROUND_PATH,
	Background.MENU: "res://ui/sprites/background_menu.png",
	Background.VICTORY: "res://ui/sprites/background_victory.png",
	Background.DEFEAT: "res://ui/sprites/background_defeat.png",
}
const REGIONS_PATH := "res://ui/sprites/sprite_regions.gd"

const DIE_SIZE := Vector2i(16, 16)
const DIE_ROLL_FRAMES := 4
## Скорость анимации броска, кадров в секунду.
const DIE_ROLL_FPS := 12.0
const CUP_SIZE := Vector2i(20, 24)
const ICON_SIZE := Vector2i(16, 16)
const SANITY_PIP_SIZE := Vector2i(6, 6)
const ARROW_SIZE := Vector2i(9, 12)
const PORTRAIT_SIZE := Vector2i(64, 64)
const BACKGROUND_SIZE := Vector2i(640, 360)
## Видимая толщина рамки (FRAME / FRAME_ACTIVE): столько отступа нужно, чтобы рамка
## легла вплотную к портрету. Угловые пластины чуть заходят на портрет — так задумано.
const FRAME_BORDER := 4

## Портреты игрока на выбор (DESIGN.md §5). Ботов — по BotPersonality.id.
const PLAYER_PORTRAITS: Array[StringName] = [&"player1", &"player2", &"player3", &"player4",
		&"player5", &"player6"]

const DICE_SET_IDS := {DiceSet.BONE: "bone", DiceSet.OBSIDIAN: "obsidian"}
const CUP_STYLE_IDS := {CupStyle.WOOD: "wood", CupStyle.BRINE: "brine", CupStyle.ABYSS: "abyss"}
const BUTTON_KIND_IDS := {
	ButtonKind.PLAIN: "plain", ButtonKind.BID: "bid", ButtonKind.LIAR: "liar",
	ButtonKind.CALZA: "calza", ButtonKind.ACCUSE: "accuse",
}
const BUTTON_STATE_IDS := {
	ButtonState.NORMAL: "normal", ButtonState.HOVER: "hover",
	ButtonState.PRESSED: "pressed", ButtonState.DISABLED: "disabled",
}
const PANEL_IDS := {
	PanelKind.DARK: &"panel_dark", PanelKind.PARCHMENT: &"panel_parchment", PanelKind.FRAME: &"frame",
	PanelKind.FRAME_ACTIVE: &"frame_active", PanelKind.BUBBLE: &"bubble", PanelKind.FIELD: &"field",
}
const TRICK_ICONS := {
	Cheat.Kind.PEEK: &"icon_peek", Cheat.Kind.SLEIGHT: &"icon_sleight",
	Cheat.Kind.LOADED_DIE: &"icon_loaded_die", Cheat.Kind.NUDGE_CUP: &"icon_nudge_cup",
	Cheat.Kind.SLEEVE_DIE: &"icon_sleeve_die", Cheat.Kind.ABYSS_WHISPER: &"icon_abyss_whisper",
}
const ICON_SANITY := &"icon_sanity"
const ICON_EVIDENCE := &"icon_evidence"
const ICON_MADNESS := &"icon_madness"
const ICON_DICE := &"icon_dice"
const ICON_ACCUSE := &"icon_accuse"

## Цвет текста на кнопке по виду (обычный, неактивный).
const BUTTON_TEXT := {
	ButtonKind.PLAIN: KrakenPalette.PARCHMENT, ButtonKind.BID: KrakenPalette.INK,
	ButtonKind.LIAR: KrakenPalette.PARCHMENT, ButtonKind.CALZA: KrakenPalette.INK,
	ButtonKind.ACCUSE: KrakenPalette.PARCHMENT,
}
const BUTTON_TEXT_DISABLED := KrakenPalette.WOOD
## Поля вокруг текста кнопки (слева, сверху, справа, снизу). Нажатая — текст на 1 px ниже.
const BUTTON_CONTENT := [6, 3, 6, 4]
const BUTTON_CONTENT_PRESSED := [6, 4, 6, 3]

static var _textures := {}
static var _regions: Dictionary = {}


# --- Имена спрайтов (общие для генератора и игры) -------------------------

static func die_name(dice_set: DiceSet, face: int) -> StringName:
	return StringName("die_%s_%d" % [DICE_SET_IDS[dice_set], face])


static func die_roll_name(dice_set: DiceSet, frame: int) -> StringName:
	return StringName("die_%s_roll_%d" % [DICE_SET_IDS[dice_set], frame])


static func cup_name(style: CupStyle, open: bool) -> StringName:
	return StringName("cup_%s_%s" % [CUP_STYLE_IDS[style], "open" if open else "closed"])


static func button_name(kind: ButtonKind, state: ButtonState) -> StringName:
	return StringName("button_%s_%s" % [BUTTON_KIND_IDS[kind], BUTTON_STATE_IDS[state]])


static func arrow_name(right: bool, state: ButtonState) -> StringName:
	return StringName("arrow_%s_%s" % ["right" if right else "left", BUTTON_STATE_IDS[state]])


static func portrait_name(character: StringName, mad: bool) -> StringName:
	return StringName("%s_%s" % [character, "mad" if mad else "normal"])


## Все персонажи с портретами: боты в порядке BotRoster, потом варианты игрока.
static func portrait_characters() -> Array[StringName]:
	var out: Array[StringName] = []
	for path in BotRoster.PATHS:
		out.append(StringName(path.get_file().get_basename()))
	out.append_array(PLAYER_PORTRAITS)
	return out


# --- Текстуры ------------------------------------------------------------

static func has(name: StringName) -> bool:
	return _main_regions().has(name)


## Спрайт основного атласа по имени.
static func texture(name: StringName) -> AtlasTexture:
	return _atlas_texture(name, _main_regions(), MAIN_ATLAS_PATH)


static func die(dice_set: DiceSet, face: int) -> AtlasTexture:
	return texture(die_name(dice_set, face))


static func die_roll(dice_set: DiceSet, frame: int) -> AtlasTexture:
	return texture(die_roll_name(dice_set, frame % DIE_ROLL_FRAMES))


static func die_shadow() -> AtlasTexture:
	return texture(&"shadow_die")


static func cup(style: CupStyle, open: bool) -> AtlasTexture:
	return texture(cup_name(style, open))


static func cup_shadow() -> AtlasTexture:
	return texture(&"shadow_cup")


static func trick_icon(kind: Cheat.Kind) -> AtlasTexture:
	return texture(TRICK_ICONS[kind])


static func sanity_pip(full: bool) -> AtlasTexture:
	return texture(&"sanity_full" if full else &"sanity_empty")


static func portrait(character: StringName, mad: bool = false) -> AtlasTexture:
	return _atlas_texture(portrait_name(character, mad), _portrait_regions(), PORTRAIT_ATLAS_PATH)


static func has_portrait(character: StringName) -> bool:
	return _portrait_regions().has(portrait_name(character, false))


static func background(kind := Background.TAVERN) -> Texture2D:
	return load(BACKGROUND_PATHS[kind])


# --- UI-кит --------------------------------------------------------------

## Девятисрезная StyleBox из основного атласа. Центр и края тайлятся (не растягиваются),
## чтобы узоры оставались пиксель-в-пиксель.
static func nine_patch(name: StringName) -> StyleBoxTexture:
	var margins: Array = _regions_script().NINE_PATCH[name]
	var box := StyleBoxTexture.new()
	box.texture = load(MAIN_ATLAS_PATH)
	box.region_rect = Rect2(_main_regions()[name])
	box.texture_margin_left = margins[0]
	box.texture_margin_top = margins[1]
	box.texture_margin_right = margins[2]
	box.texture_margin_bottom = margins[3]
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


static func panel(kind: PanelKind) -> StyleBoxTexture:
	return nine_patch(PANEL_IDS[kind])


static func button_style(kind: ButtonKind, state: ButtonState) -> StyleBoxTexture:
	var box := nine_patch(button_name(kind, state))
	var content: Array = BUTTON_CONTENT_PRESSED if state == ButtonState.PRESSED else BUTTON_CONTENT
	box.content_margin_left = content[0]
	box.content_margin_top = content[1]
	box.content_margin_right = content[2]
	box.content_margin_bottom = content[3]
	return box


## Оформляет кнопку: все четыре состояния, цвета текста, без синей рамки фокуса.
static func style_button(button: Button, kind: ButtonKind) -> void:
	var names := {
		ButtonState.NORMAL: ["normal"], ButtonState.HOVER: ["hover", "hover_pressed"],
		ButtonState.PRESSED: ["pressed"], ButtonState.DISABLED: ["disabled"],
	}
	for state: ButtonState in names:
		var box := button_style(kind, state)
		for slot: String in names[state]:
			button.add_theme_stylebox_override(slot, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text: Color = BUTTON_TEXT[kind]
	for slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		button.add_theme_color_override(slot, text)
	button.add_theme_color_override("font_disabled_color", BUTTON_TEXT_DISABLED)


## Оформляет стрелку счётчика ◀ / ▶.
static func style_arrow(button: TextureButton, right: bool) -> void:
	button.texture_normal = texture(arrow_name(right, ButtonState.NORMAL))
	button.texture_hover = texture(arrow_name(right, ButtonState.HOVER))
	button.texture_pressed = texture(arrow_name(right, ButtonState.PRESSED))
	button.texture_disabled = texture(arrow_name(right, ButtonState.DISABLED))
	button.texture_focused = null


# --- Внутреннее ----------------------------------------------------------

static func _atlas_texture(name: StringName, regions: Dictionary, atlas_path: String) -> AtlasTexture:
	var key := atlas_path + ":" + name
	if _textures.has(key):
		return _textures[key]
	assert(regions.has(name), "Unknown sprite: %s" % name)
	var tex := AtlasTexture.new()
	tex.atlas = load(atlas_path)
	tex.region = Rect2(regions[name])
	_textures[key] = tex
	return tex


static func _main_regions() -> Dictionary:
	return _regions_script().MAIN


static func _portrait_regions() -> Dictionary:
	return _regions_script().PORTRAITS


static func _regions_script() -> GDScript:
	if not _regions.has(&"script"):
		_regions[&"script"] = load(REGIONS_PATH)
	return _regions[&"script"]
