class_name SpritePainter
extends RefCounted
## Рисует все спрайты проекта (М8) в Image: детерминированно, только цветами KrakenPalette.
##
## Мелкие символы и иконки — из текстового исходника ui/sprites/src/symbols.txt,
## формы (кубики, чашки, кнопки, панели, портреты, фон) — кодом.
## Используется генератором tools/build_sprites.gd и тестом актуальности атласов.
##
## build() возвращает:
##   main: Image, main_regions: {имя: Rect2i}, nine_patch: {имя: [л, в, п, н]},
##   portraits: Image, portrait_regions: {имя: Rect2i},
##   backgrounds: {Sprites.Background: Image}.
## Портреты и фоны из assets/generated/ (GeneratedArt, М14) заменяют заглушки.

const SYMBOLS_PATH := "res://ui/sprites/src/symbols.txt"
const MAIN_ATLAS_WIDTH := 256
const ATLAS_PADDING := 1
const PORTRAIT_COLUMNS := 5

const K := KrakenPalette.INK
const N := KrakenPalette.NIGHT
const S := KrakenPalette.SLATE
const D := KrakenPalette.DARK_WOOD
const W := KrakenPalette.WOOD
const B := KrakenPalette.BONE
const P := KrakenPalette.PARCHMENT
const F := KrakenPalette.FIRE
const O := KrakenPalette.EMBER
const G := KrakenPalette.GREEN
const L := KrakenPalette.LIME
const V := KrakenPalette.VIOLET
const U := KrakenPalette.LILAC
const R := KrakenPalette.BLOOD

## Пороговая матрица Байера 4×4 для дизеринга (значения 0..15).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# --- Кубики --------------------------------------------------------------
## Раскладка точек: клетки сетки 3×3 для граней 2..6 (грань 1 — символ).
const PIPS := {
	2: [Vector2i(2, 0), Vector2i(0, 2)],
	3: [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2)],
	4: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)],
	5: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)],
	6: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
}
## Левый верхний пиксель точки в клетке (0,0) и шаг сетки на передней грани.
const PIP_ORIGIN := Vector2i(3, 6)
const PIP_STEP := Vector2i(4, 3)
## Кадры броска: угол поворота (градусы), сжатие по вертикали и показываемая грань.
const ROLL_ANGLES := [12.0, 32.0, 57.0, 78.0]
const ROLL_SQUASH := [1.0, 0.85, 1.0, 0.85]
const ROLL_FACES := [3, 5, 2, 6]
const ROLL_HALF := 5.0

const DICE_STYLES := {
	Sprites.DiceSet.BONE: {
		# Грани — из assets/generated/dice/ (рисунок автора), отсюда цвета кадров броска.
		outline = K, top = P, edge = B, front = P, light = P, shade = B,
		pip = K, pip_shade = D, rune = null,
		one = "kraken_eye", one_inks = {"#": K, "+": R},
	},
	Sprites.DiceSet.OBSIDIAN: {
		outline = K, top = S, edge = K, front = N, light = S, shade = K,
		pip = L, pip_shade = G, rune = G,
		one = "octopus", one_inks = {"#": U, "+": V},
	},
}

# --- Чашки ---------------------------------------------------------------
const CUP_STYLES := {
	Sprites.CupStyle.WOOD: {
		body = W, light = B, shade = D, band = D, rim = B,
		carving = "carving_eye", inks = {"#": D, "+": F},
	},
	Sprites.CupStyle.BRINE: {
		body = D, light = W, shade = K, band = S, rim = W,
		carving = "carving_tentacle", inks = {"#": G, "+": L},
	},
	Sprites.CupStyle.ABYSS: {
		body = N, light = S, shade = K, band = V, rim = S,
		carving = "carving_tentacle", inks = {"#": V, "+": U},
	},
}

# --- Кнопки --------------------------------------------------------------
const BUTTON_SIZE := 16
const BUTTON_MARGINS := [4, 4, 4, 4]
const BUTTON_COLORS := {
	Sprites.ButtonKind.PLAIN: {fill = S, light = W, lip = N},
	Sprites.ButtonKind.BID: {fill = G, light = L, lip = S},
	Sprites.ButtonKind.LIAR: {fill = V, light = U, lip = N},
	Sprites.ButtonKind.CALZA: {fill = W, light = B, lip = D},
	Sprites.ButtonKind.ACCUSE: {fill = R, light = O, lip = N},
}
const BUTTON_DISABLED := {fill = N, light = S, lip = K}

# --- Портреты: цвет глаз в Безумии ----------------------------------------
const MAD_EYES := {
	&"scholar": L, &"occultist": U, &"sailor": L, &"witch": U, &"plague_cultist": F,
	&"drowned": F, &"deep_one": U, &"player1": L, &"player2": U, &"player3": L,
}

var _symbols := {}
var _entries: Array = []          # [имя, Image] или null (новая полка)
var _nine_patch := {}


func build() -> Dictionary:
	_symbols = _load_symbols(SYMBOLS_PATH)
	_entries.clear()
	_nine_patch.clear()

	_add_dice()
	_add_cups()
	_add_ui_kit()
	_add_icons()
	var packed := _pack(_entries, MAIN_ATLAS_WIDTH)

	var portraits := _build_portraits()
	return {
		main = packed.image, main_regions = packed.regions, nine_patch = _nine_patch.duplicate(),
		portraits = portraits.image, portrait_regions = portraits.regions,
		backgrounds = _backgrounds(),
	}


# === Сборка атласа ========================================================

func _add(name: StringName, img: Image, nine_patch: Array = []) -> void:
	_entries.append([name, img])
	if not nine_patch.is_empty():
		_nine_patch[name] = nine_patch


func _new_shelf() -> void:
	_entries.append(null)


## Полочная упаковка в порядке добавления. null — принудительный перенос на новую полку.
func _pack(entries: Array, width: int) -> Dictionary:
	var regions := {}
	var x := ATLAS_PADDING
	var y := ATLAS_PADDING
	var shelf := 0
	for e in entries:
		if e == null:
			if x > ATLAS_PADDING:
				x = ATLAS_PADDING
				y += shelf + ATLAS_PADDING
				shelf = 0
			continue
		var img: Image = e[1]
		if x + img.get_width() + ATLAS_PADDING > width:
			x = ATLAS_PADDING
			y += shelf + ATLAS_PADDING
			shelf = 0
		regions[e[0]] = Rect2i(x, y, img.get_width(), img.get_height())
		x += img.get_width() + ATLAS_PADDING
		shelf = maxi(shelf, img.get_height())
	var atlas := _blank(width, y + shelf + ATLAS_PADDING)
	for e in entries:
		if e != null:
			var r: Rect2i = regions[e[0]]
			atlas.blit_rect(e[1], Rect2i(Vector2i.ZERO, r.size), r.position)
	return {image = atlas, regions = regions}


# === Кубики ===============================================================

func _add_dice() -> void:
	for dice_set: Sprites.DiceSet in DICE_STYLES:
		var style: Dictionary = DICE_STYLES[dice_set]
		for face in range(1, 7):
			# Нарисованная автором грань (assets/generated/dice/) заменяет кодовую.
			var drawn := GeneratedArt.load_die(dice_set, face)
			_add(Sprites.die_name(dice_set, face), drawn if drawn != null else _die(style, face))
		for frame in Sprites.DIE_ROLL_FRAMES:
			_add(Sprites.die_roll_name(dice_set, frame), _die_roll(style, frame))
		_new_shelf()


## Кубик 16×16 в три четверти: верхняя грань (3 px), ребро, передняя грань с точками.
func _die(style: Dictionary, face: int) -> Image:
	var img := _blank(16, 16)
	_rect(img, Rect2i(1, 1, 14, 14), style.front)
	_rect(img, Rect2i(1, 1, 14, 3), style.top)
	_rect(img, Rect2i(1, 4, 14, 1), style.edge)
	_rect(img, Rect2i(1, 5, 1, 9), style.light)
	_rect(img, Rect2i(14, 5, 1, 10), style.shade)
	_rect(img, Rect2i(1, 14, 14, 1), style.shade)
	_box(img, Rect2i(0, 0, 16, 16), style.outline)
	if style.rune != null:
		_stamp(img, "rune_%d" % face, Vector2i(6, 1), {"#": style.rune})
	if face == 1:
		_stamp(img, style.one, Vector2i(4, 6), style.one_inks)
	else:
		for cell: Vector2i in PIPS[face]:
			var at := PIP_ORIGIN + cell * PIP_STEP
			_rect(img, Rect2i(at, Vector2i(2, 2)), style.pip)
			_put(img, at.x + 1, at.y + 1, style.pip_shade)
	return img


## Кадр кувыркающегося кубика: повёрнутый квадрат с «верхом», «тенью» и точками.
func _die_roll(style: Dictionary, frame: int) -> Image:
	var img := _blank(16, 16)
	var angle := deg_to_rad(ROLL_ANGLES[frame])
	var squash: float = ROLL_SQUASH[frame]
	var center := Vector2(8, 8)
	for y in 16:
		for x in 16:
			var local := ((Vector2(x, y) + Vector2(0.5, 0.5) - center) / Vector2(1, squash)).rotated(-angle)
			if absf(local.x) > ROLL_HALF or absf(local.y) > ROLL_HALF:
				continue
			var col: Color = style.front
			if local.y < -ROLL_HALF + 2.0:
				col = style.top
			elif local.y > ROLL_HALF - 1.5 or local.x > ROLL_HALF - 1.0:
				col = style.shade
			_put(img, x, y, col)
	var face: int = ROLL_FACES[frame]
	for cell: Vector2i in PIPS[face]:
		var local := Vector2(cell - Vector2i.ONE) * 3.0
		var world := center + (local.rotated(angle) * Vector2(1, squash))
		_rect(img, Rect2i(Vector2i(floori(world.x - 0.5), floori(world.y - 0.5)), Vector2i(2, 2)), style.pip)
	_outline(img, style.outline)
	return img


# === Чашки ================================================================

func _add_cups() -> void:
	for style_id: Sprites.CupStyle in CUP_STYLES:
		for open in [false, true]:
			_add(Sprites.cup_name(style_id, open), _cup(CUP_STYLES[style_id], open))
	_add(&"shadow_die", _shadow(16, 3))
	_add(&"shadow_cup", _shadow(22, 4))
	_new_shelf()


## Чашка 20×24. Закрытая — перевёрнута горлом вниз (накрывает кубики),
## открытая — горлом вверх, видна тёмная внутренность.
func _cup(style: Dictionary, open: bool) -> Image:
	var size := Sprites.CUP_SIZE
	var img := _blank(size.x, size.y)
	var first := 1
	var last := size.y - 2
	for r in range(first, last + 1):
		var t := float(r - first) / float(last - first)
		var mouth_t := (1.0 - t) if open else t
		var half := roundi(lerpf(6.0, 9.0, mouth_t))
		var x0 := size.x / 2 - half
		var x1 := size.x / 2 - 1 + half
		# Расстояние от горла и от дна в строках.
		var from_mouth := (r - first) if open else (last - r)
		var from_base := (last - r) if open else (r - first)
		var fill: Color = style.body
		var is_band := from_base >= 4 and from_base <= 5
		var is_rim := from_mouth <= 2 or from_base <= 1
		for x in range(x0, x1 + 1):
			var col := fill
			if is_rim:
				col = style.rim
			elif is_band:
				col = style.band
			elif x <= x0 + 1:
				col = style.light
			if x >= x1 - 1 and not (open and from_mouth <= 2 and x < x1):
				col = style.shade
			_put(img, x, r, col)
		# Внутренность открытой чашки.
		if open and from_mouth >= 1 and from_mouth <= 2:
			for x in range(x0 + 2, x1 - 1):
				_put(img, x, r, K if from_mouth == 1 else N)
		if not open and from_mouth == 0:
			_rect(img, Rect2i(x0, r, x1 - x0 + 1, 1), style.shade)
	var sym: PackedStringArray = _symbols[style.carving]
	var at := Vector2i(size.x / 2 - sym[0].length() / 2, 12 - sym.size() / 2 + (1 if open else 0))
	_stamp(img, style.carving, at, style.inks)
	_outline(img, K)
	return img


## Тень под кубиком/чашкой: эллипс шахматным дизерингом.
func _shadow(w: int, h: int) -> Image:
	var img := _blank(w, h)
	var c := Vector2(w, h) / 2.0
	for y in h:
		for x in w:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - c) / c
			if d.length_squared() <= 1.0 and (x + y) % 2 == 0:
				_put(img, x, y, K)
	return img


# === UI-кит ===============================================================

func _add_ui_kit() -> void:
	for kind: Sprites.ButtonKind in BUTTON_COLORS:
		for state: Sprites.ButtonState in Sprites.BUTTON_STATE_IDS:
			_add(Sprites.button_name(kind, state), _button(kind, state), BUTTON_MARGINS)
	_new_shelf()
	for right in [false, true]:
		for state: Sprites.ButtonState in Sprites.BUTTON_STATE_IDS:
			_add(Sprites.arrow_name(right, state), _arrow(right, state))
	_add(&"sanity_full", _symbol_image("sanity_full"))
	_add(&"sanity_empty", _symbol_image("sanity_empty"))
	_new_shelf()
	_add(&"panel_dark", _panel_dark(), [5, 5, 5, 5])
	_add(&"panel_parchment", _panel_parchment(), [4, 4, 4, 4])
	_add(&"frame", _frame(false), [8, 8, 8, 8])
	_add(&"frame_active", _frame(true), [8, 8, 8, 8])
	_add(&"bubble", _bubble(), [8, 4, 4, 8])
	_add(&"field", _field(), [3, 3, 3, 3])
	_new_shelf()


## Кнопка 16×16 (девятисрез): контур, блик сверху, «губа» снизу.
## Наведение — огненный контур, нажатие — лицо опущено на 1 px, губы нет.
func _button(kind: Sprites.ButtonKind, state: Sprites.ButtonState) -> Image:
	var colors: Dictionary = BUTTON_DISABLED if state == Sprites.ButtonState.DISABLED \
			else BUTTON_COLORS[kind]
	var pressed := state == Sprites.ButtonState.PRESSED
	var outline := F if state == Sprites.ButtonState.HOVER else K
	var img := _blank(BUTTON_SIZE, BUTTON_SIZE)
	var top := 1 if pressed else 0
	var h := BUTTON_SIZE - top
	_rect(img, Rect2i(1, top + 1, BUTTON_SIZE - 2, h - 2), colors.fill)
	if pressed:
		_rect(img, Rect2i(1, top + 1, BUTTON_SIZE - 2, 1), colors.lip)
		_rect(img, Rect2i(1, BUTTON_SIZE - 2, BUTTON_SIZE - 2, 1), colors.lip)
	else:
		_rect(img, Rect2i(1, 1, BUTTON_SIZE - 2, 1), colors.light)
		_rect(img, Rect2i(1, BUTTON_SIZE - 3, BUTTON_SIZE - 2, 2), colors.lip)
	_box(img, Rect2i(0, top, BUTTON_SIZE, h), outline)
	return img


func _arrow(right: bool, state: Sprites.ButtonState) -> Image:
	var inks: Dictionary
	match state:
		Sprites.ButtonState.HOVER:
			inks = {"#": F, "+": P, "*": P}
		Sprites.ButtonState.PRESSED:
			inks = {"#": K, "+": W, "*": B}
		Sprites.ButtonState.DISABLED:
			inks = {"#": K, "+": S, "*": S}
		_:
			inks = {"#": K, "+": B, "*": P}
	var size := Sprites.ARROW_SIZE
	var img := _blank(size.x, size.y)
	var y := 1 if state == Sprites.ButtonState.PRESSED else 0
	_stamp(img, "arrow_left", Vector2i(0, y), inks, right)
	return img


func _panel_dark() -> Image:
	var img := _blank(24, 24)
	_rect(img, Rect2i(1, 1, 22, 22), N)
	_lines(img, Rect2i(1, 1, 22, 22), S)
	_box(img, Rect2i(0, 0, 24, 24), K)
	for at in [Vector2i(3, 3), Vector2i(20, 3), Vector2i(3, 20), Vector2i(20, 20)]:
		_put(img, at.x, at.y, W)
	return img


func _panel_parchment() -> Image:
	var img := _blank(24, 24)
	_rect(img, Rect2i(1, 1, 22, 22), B)
	for y in range(3, 21):
		for x in range(3, 21):
			var h := _hash(x, y)
			if h % 13 == 0:
				_put(img, x, y, P)
			elif h % 29 == 0:
				_put(img, x, y, W)
	_lines(img, Rect2i(1, 1, 22, 22), D)
	_lines(img, Rect2i(2, 2, 20, 20), W)
	_box(img, Rect2i(0, 0, 24, 24), K)
	return img


## Рамка 32×32 с пустым центром и пластинами в углах (для портретов и окон).
func _frame(active: bool) -> Image:
	var line := G if active else W
	var metal := L if active else B
	var img := _blank(32, 32)
	_lines(img, Rect2i(0, 0, 32, 32), K)
	_lines(img, Rect2i(1, 1, 30, 30), line)
	_lines(img, Rect2i(2, 2, 28, 28), line if active else D)
	_lines(img, Rect2i(3, 3, 26, 26), K)
	for at in [Vector2i(0, 0), Vector2i(26, 0), Vector2i(0, 26), Vector2i(26, 26)]:
		_stamp(img, "frame_plate", at, {"#": K, "+": metal})
	return img


## Пузырь реплики 24×24 с хвостиком снизу слева.
func _bubble() -> Image:
	var img := _blank(24, 24)
	_rect(img, Rect2i(1, 1, 22, 16), P)
	_rect(img, Rect2i(1, 16, 22, 1), B)
	_box(img, Rect2i(0, 0, 24, 18), K)
	_rect(img, Rect2i(4, 17, 2, 1), B)
	for p in [Vector2i(3, 18), Vector2i(6, 18), Vector2i(3, 19), Vector2i(5, 19),
			Vector2i(3, 20), Vector2i(4, 20), Vector2i(3, 21)]:
		_put(img, p.x, p.y, K)
	_rect(img, Rect2i(4, 18, 2, 1), B)
	_put(img, 4, 19, B)
	return img


## Утопленное поле для чисел (счётчики ◀ N ▶).
func _field() -> Image:
	var img := _blank(12, 12)
	_rect(img, Rect2i(1, 1, 10, 10), N)
	_rect(img, Rect2i(1, 1, 10, 1), K)
	_rect(img, Rect2i(1, 10, 10, 1), S)
	_box(img, Rect2i(0, 0, 12, 12), K)
	return img


# === Иконки ===============================================================

func _add_icons() -> void:
	for name: StringName in Sprites.TRICK_ICONS.values():
		_add(name, _symbol_image(name))
	for name in [Sprites.ICON_SANITY, Sprites.ICON_EVIDENCE, Sprites.ICON_MADNESS,
			Sprites.ICON_DICE, Sprites.ICON_ACCUSE]:
		_add(name, _symbol_image(name))
	_new_shelf()


# === Портреты-заглушки =====================================================

func _build_portraits() -> Dictionary:
	var entries: Array = []
	for character in Sprites.portrait_characters():
		for mad in [false, true]:
			entries.append([Sprites.portrait_name(character, mad), _portrait(character, mad)])
	var size := Sprites.PORTRAIT_SIZE
	var rows := ceili(float(entries.size()) / PORTRAIT_COLUMNS)
	var atlas := _blank(PORTRAIT_COLUMNS * size.x, rows * size.y)
	var regions := {}
	for i in entries.size():
		var at := Vector2i(i % PORTRAIT_COLUMNS, i / PORTRAIT_COLUMNS) * size
		regions[entries[i][0]] = Rect2i(at, size)
		atlas.blit_rect(entries[i][1], Rect2i(Vector2i.ZERO, size), at)
	return {image = atlas, regions = regions}


## Погрудный силуэт 64×64: тёмные формы, тёплый контровой свет слева (огонь),
## холодный справа, контур, глаза. В Безумии — светящиеся глаза, прожилки и щупальца.
func _portrait(id: StringName, mad: bool) -> Image:
	var generated := GeneratedArt.load_portrait(id, mad)
	if generated != null:
		return generated
	var img := _blank(64, 64)
	var eyes: Array = []
	var eye_size := Vector2i(2, 1)
	var eye_color := B
	var details: Array = []   # [Rect2i, Color] поверх контура
	match id:
		&"scholar":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), S)
			_poly(img, [Vector2(18, 38), Vector2(46, 38), Vector2(54, 64), Vector2(10, 64)], S)
			_ellipse(img, Vector2(32, 30), Vector2(14, 17), S)
			_ellipse(img, Vector2(32, 34), Vector2(8, 10), K)
			_rect(img, Rect2i(31, 50, 2, 2), F)
			eyes = [Vector2i(28, 33), Vector2i(35, 33)]
		&"occultist":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), D)
			_rect(img, Rect2i(28, 38, 8, 10), N)
			_ellipse(img, Vector2(32, 25), Vector2(11, 12), S)
			_ellipse(img, Vector2(32, 30), Vector2(9, 10), N)
			_poly(img, [Vector2(23, 33), Vector2(41, 33), Vector2(36, 47), Vector2(28, 47)], S)
			_rect(img, Rect2i(30, 51, 4, 4), V)
			_rect(img, Rect2i(31, 52, 2, 2), U)
			eyes = [Vector2i(27, 29), Vector2i(35, 29)]
			eye_color = P
		&"sailor":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), S)
			for y in range(50, 64, 3):
				for x in 64:
					if img.get_pixel(x, y) == S:
						_put(img, x, y, P)
			_rect(img, Rect2i(28, 38, 8, 10), N)
			_ellipse(img, Vector2(32, 30), Vector2(9, 11), N)
			_ellipse(img, Vector2(32, 17), Vector2(12, 5), P)
			_rect(img, Rect2i(21, 17, 22, 5), P)
			_rect(img, Rect2i(19, 22, 26, 2), K)
			_rect(img, Rect2i(31, 18, 2, 2), F)
			eyes = [Vector2i(28, 28), Vector2i(35, 28)]
		&"witch":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), N)
			_ellipse(img, Vector2(32, 34), Vector2(13, 14), W)
			_ellipse(img, Vector2(32, 32), Vector2(8, 10), N)
			_poly(img, [Vector2(23, 21), Vector2(41, 21), Vector2(38, 8), Vector2(46, 2), Vector2(33, 5)], V)
			_ellipse(img, Vector2(32, 21), Vector2(23, 3), V)
			_rect(img, Rect2i(24, 17, 16, 2), U)
			eyes = [Vector2i(28, 30), Vector2i(35, 30)]
		&"plague_cultist":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), V)
			_poly(img, [Vector2(18, 38), Vector2(46, 38), Vector2(54, 64), Vector2(10, 64)], V)
			_ellipse(img, Vector2(32, 30), Vector2(15, 17), V)
			_ellipse(img, Vector2(32, 33), Vector2(9, 10), K)
			_poly(img, [Vector2(27, 33), Vector2(37, 33), Vector2(45, 50), Vector2(41, 51)], B)
			eyes = [Vector2i(25, 28), Vector2i(35, 28)]
			eye_size = Vector2i(3, 3)
			eye_color = R
		&"drowned":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), D)
			_rect(img, Rect2i(28, 38, 8, 10), S)
			_ellipse(img, Vector2(32, 29), Vector2(12, 13), S)
			for y in range(16, 42):
				for x in range(20, 45):
					if img.get_pixel(x, y) == S and _hash(x, y) % 11 == 0:
						_put(img, x, y, G)
			for strand in [Vector2(22, 18), Vector2(27, 15), Vector2(38, 15), Vector2(43, 19)]:
				_wave(img, strand, 26, G, 1.5, 0.5)
			if mad:
				_ellipse(img, Vector2(32, 39), Vector2(3, 4), K)
			else:
				_rect(img, Rect2i(29, 37, 6, 1), K)
			eyes = [Vector2i(27, 28), Vector2i(35, 28)]
			eye_size = Vector2i(2, 2)
			eye_color = K
		&"deep_one":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), S)
			var skin := V if mad else G
			_ellipse(img, Vector2(32, 25), Vector2(13, 12), skin)
			for i in 6:
				var root := Vector2(23 + i * 3.6, 31)
				for dx in 2:
					_wave(img, root + Vector2(dx, 0), 18 + (i % 3) * 3, skin, 1.2, 0.7 + i * 0.3)
			eyes = [Vector2i(25, 22), Vector2i(36, 22)]
			if mad:
				eyes.append_array([Vector2i(30, 16), Vector2i(31, 28)])
			eye_size = Vector2i(3, 3)
			eye_color = K
			if not mad:
				details = [[Rect2i(26, 22, 1, 1), L], [Rect2i(37, 22, 1, 1), L]]
		&"player1":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), D)
			_rect(img, Rect2i(28, 38, 8, 10), N)
			_ellipse(img, Vector2(32, 30), Vector2(9, 11), N)
			_ellipse(img, Vector2(32, 24), Vector2(10, 6), R)
			_rect(img, Rect2i(22, 24, 20, 2), R)
			_poly(img, [Vector2(40, 24), Vector2(47, 27), Vector2(45, 33), Vector2(41, 27)], R)
			details = [[Rect2i(37, 32, 1, 1), R], [Rect2i(38, 33, 1, 1), R], [Rect2i(39, 34, 1, 1), R]]
			eyes = [Vector2i(28, 29), Vector2i(35, 29)]
		&"player2":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), S)
			_ellipse(img, Vector2(32, 34), Vector2(12, 14), W)
			_ellipse(img, Vector2(32, 32), Vector2(8, 10), N)
			_ellipse(img, Vector2(32, 22), Vector2(12, 7), V)
			_rect(img, Rect2i(20, 22, 24, 3), V)
			_poly(img, [Vector2(20, 24), Vector2(24, 24), Vector2(20, 40), Vector2(17, 38)], V)
			eyes = [Vector2i(28, 31), Vector2i(35, 31)]
		&"player3":
			_ellipse(img, Vector2(32, 66), Vector2(28, 18), D)
			_rect(img, Rect2i(28, 38, 8, 10), N)
			_ellipse(img, Vector2(32, 31), Vector2(10, 11), N)
			_poly(img, [Vector2(23, 34), Vector2(41, 34), Vector2(37, 48), Vector2(27, 48)], S)
			_poly(img, [Vector2(14, 22), Vector2(50, 22), Vector2(42, 10), Vector2(32, 15), Vector2(22, 10)], D)
			_rect(img, Rect2i(16, 21, 32, 1), B)
			details = [[Rect2i(34, 27, 4, 3), K]]
			eyes = [Vector2i(27, 28)]
		_:
			push_error("No portrait silhouette for %s" % id)
	_rim(img, W, V if mad else S)
	_outline(img, K)
	for d in details:
		_rect(img, d[0], d[1])
	var glow: Color = MAD_EYES.get(id, L) if mad else eye_color
	for e: Vector2i in eyes:
		_rect(img, Rect2i(e, eye_size), glow)
		if mad:
			_put(img, e.x - 1, e.y, V)
			_put(img, e.x + eye_size.x, e.y, V)
	if mad:
		_madness_marks(img, eyes)
	return img


## Прожилки у глаз и щупальца снизу по краям.
func _madness_marks(img: Image, eyes: Array) -> void:
	for e: Vector2i in eyes:
		for off in [Vector2i(-2, 2), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(4, 4), Vector2i(0, -2)]:
			var p: Vector2i = e + off
			if img.get_pixel(p.x, p.y).a8 == 255 and img.get_pixel(p.x, p.y) != K:
				_put(img, p.x, p.y, V)
	_wave(img, Vector2(4, 63), 22, V, 2.0, 0.0, U)
	_wave(img, Vector2(59, 63), 18, V, 2.0, 1.5, U)


# === Фон-заглушка =========================================================

## Фоны: сгенерированные, а где их нет — заглушка таверны.
func _backgrounds() -> Dictionary:
	var out := {}
	var stub: Image = null
	for kind: Sprites.Background in Sprites.BACKGROUND_PATHS:
		var img := GeneratedArt.load_background(kind)
		if img == null:
			if stub == null:
				stub = _background()
			img = stub
		out[kind] = img
	return out


## Заглушка: таверна 640×360: стена с балками, фонари, камин, сигил Кракена, силуэты посетителей,
## пустой стол на нижних 40 % кадра.
func _background() -> Image:
	var size := Sprites.BACKGROUND_SIZE
	var img := _blank(size.x, size.y)
	var table_top := 216
	# Стена: K → N → S сверху вниз.
	for y in table_top:
		for x in size.x:
			var col := K
			if y < 110:
				col = _dither(K, N, float(y) / 110.0, x, y)
			else:
				col = _dither(N, S, float(y - 110) / 160.0, x, y)
			_put(img, x, y, col)
	# Балки.
	_rect(img, Rect2i(0, 26, size.x, 8), D)
	_rect(img, Rect2i(0, 26, size.x, 1), W)
	_rect(img, Rect2i(0, 34, size.x, 1), K)
	for px in [52, 196, 434, 578]:
		_rect(img, Rect2i(px, 34, 10, table_top - 34), D)
		_rect(img, Rect2i(px, 34, 1, table_top - 34), W)
		_rect(img, Rect2i(px + 9, 34, 1, table_top - 34), K)
	# Камин.
	_rect(img, Rect2i(274, 104, 92, table_top - 104), S)
	for y in range(104, table_top, 6):
		for x in range(274, 366):
			if (x + (y / 6) * 7) % 15 == 0:
				_rect(img, Rect2i(x, y, 1, 6), N)
		_rect(img, Rect2i(274, y, 92, 1), N)
	_rect(img, Rect2i(268, 98, 104, 6), D)
	_rect(img, Rect2i(268, 98, 104, 1), W)
	_ellipse(img, Vector2(320, 150), Vector2(30, 22), K)
	_rect(img, Rect2i(290, 150, 60, table_top - 150), K)
	_glow(img, Vector2(320, 214), 30.0, [R, O], table_top)
	_poly(img, [Vector2(300, 216), Vector2(306, 192), Vector2(312, 204), Vector2(320, 176),
			Vector2(328, 200), Vector2(334, 188), Vector2(340, 216)], O)
	_poly(img, [Vector2(308, 216), Vector2(314, 200), Vector2(320, 190), Vector2(326, 204),
			Vector2(332, 216)], F)
	# Фонари: тёплые по бокам, зелёный у камина.
	for lamp in [[Vector2(124, 86), [D, W, F], F], [Vector2(516, 86), [D, W, F], F],
			[Vector2(236, 70), [S, G], L]]:
		_glow(img, lamp[0], 34.0, lamp[1], table_top)
		var c: Vector2 = lamp[0]
		_rect(img, Rect2i(int(c.x) - 1, 34, 2, int(c.y) - 40), K)
		_rect(img, Rect2i(int(c.x) - 4, int(c.y) - 6, 8, 12), K)
		_rect(img, Rect2i(int(c.x) - 3, int(c.y) - 4, 6, 8), lamp[2])
		_rect(img, Rect2i(int(c.x) - 1, int(c.y) - 2, 2, 4), P)
	# Сигил Кракена на стене.
	var sigil := Vector2(392, 132)
	for y in range(-12, 13):
		for x in range(-12, 13):
			var d := Vector2(x, y).length()
			if d >= 10.5 and d <= 11.6:
				_put(img, int(sigil.x) + x, int(sigil.y) + y, G)
	_stamp(img, "octopus", Vector2i(sigil) - Vector2i(3, 3), {"#": G, "+": S})
	# Столы и посетители по углам.
	for t in [Rect2i(70, 176, 100, 6), Rect2i(470, 176, 100, 6)]:
		_rect(img, t, D)
		_rect(img, Rect2i(t.position.x, t.position.y, t.size.x, 1), W)
		_rect(img, Rect2i(t.position.x + 6, t.end.y, 4, table_top - t.end.y), K)
		_rect(img, Rect2i(t.end.x - 10, t.end.y, 4, table_top - t.end.y), K)
	for patron in [[Vector2(86, 150), F], [Vector2(150, 146), B], [Vector2(490, 148), L],
			[Vector2(556, 152), F]]:
		_patron(img, patron[0], patron[1])
	# Стол.
	_table(img, table_top)
	_vignette(img)
	return img


## Посетитель в капюшоне: силуэт и два огонька глаз.
func _patron(img: Image, at: Vector2, eyes: Color) -> void:
	_poly(img, [at + Vector2(-14, 40), at + Vector2(-9, 8), at + Vector2(9, 8), at + Vector2(14, 40)], K)
	_ellipse(img, at, Vector2(8, 10), K)
	_put(img, int(at.x) - 3, int(at.y) + 1, eyes)
	_put(img, int(at.x) + 2, int(at.y) + 1, eyes)


func _table(img: Image, top: int) -> void:
	var size := Sprites.BACKGROUND_SIZE
	var light_center := Vector2(320, 290)
	for y in range(top, size.y):
		var plank := (y - top - 4) % 24
		for x in size.x:
			var t := 1.0 - (Vector2(x, y).distance_to(light_center) / 360.0)
			var col := W
			if t > 0.72:
				col = _dither(W, B, (t - 0.72) * 2.0, x, y)
			elif t < 0.45:
				col = _dither(W, D, (0.45 - t) * 3.0, x, y)
			if _hash(x / 7, y) % 17 == 0:
				col = D if col != D else N
			if plank == 22:
				col = D
			elif plank == 23:
				col = K
			_put(img, x, y, col)
	_rect(img, Rect2i(0, top, size.x, 1), K)
	_rect(img, Rect2i(0, top + 1, size.x, 2), B)
	_rect(img, Rect2i(0, top + 3, size.x, 1), D)


## Затемнение углов кадра дизерингом в K.
func _vignette(img: Image) -> void:
	var size := Vector2(img.get_size())
	var c := size / 2.0
	for y in img.get_height():
		for x in img.get_width():
			var d := ((Vector2(x, y) - c) / c).length()
			if d > 1.0 and _bayer(x, y) < (d - 1.0) * 2.5:
				_put(img, x, y, K)


## Свет лампы: кольца палитры от края к центру, переходы дизерингом.
func _glow(img: Image, center: Vector2, radius: float, ramp: Array, max_y: int) -> void:
	for y in range(maxi(0, int(center.y - radius)), mini(max_y, int(center.y + radius) + 1)):
		for x in range(maxi(0, int(center.x - radius)), mini(img.get_width(), int(center.x + radius) + 1)):
			var t := 1.0 - Vector2(x, y).distance_to(center) / radius
			if t <= 0.0:
				continue
			var level := t * ramp.size()
			var step := int(level) - 1
			if _bayer(x, y) < level - int(level):
				step += 1
			if step >= 0:
				_put(img, x, y, ramp[mini(step, ramp.size() - 1)])


# === Символы ==============================================================

## Разбор ui/sprites/src/symbols.txt → {имя: PackedStringArray строк}.
static func _load_symbols(path: String) -> Dictionary:
	var out := {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read %s" % path)
		return out
	var current := ""
	var rows := PackedStringArray()
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with(";") or line.is_empty():
			continue
		if line.begins_with("=="):
			if current != "":
				out[current] = rows
			current = line.trim_prefix("==").strip_edges()
			rows = PackedStringArray()
			continue
		if not rows.is_empty() and line.length() != rows[0].length():
			push_error("Symbol %s: row %d has width %d, expected %d" % [current, rows.size(),
					line.length(), rows[0].length()])
		rows.append(line)
	if current != "":
		out[current] = rows
	return out


func _symbol_image(name: String, inks: Dictionary = {}) -> Image:
	var rows: PackedStringArray = _symbols[name]
	var img := _blank(rows[0].length(), rows.size())
	_stamp(img, name, Vector2i.ZERO, inks)
	return img


func _stamp(img: Image, name: String, at: Vector2i, inks: Dictionary = {}, flip_h := false) -> void:
	assert(_symbols.has(name), "Unknown symbol: %s" % name)
	var rows: PackedStringArray = _symbols[name]
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color
			if KrakenPalette.BY_LETTER.has(ch):
				col = KrakenPalette.BY_LETTER[ch]
			elif inks.has(ch):
				col = inks[ch]
			else:
				push_error("Symbol %s: no color for '%s'" % [name, ch])
				continue
			var px := (row.length() - 1 - x) if flip_h else x
			_put(img, at.x + px, at.y + y, col)


# === Примитивы ============================================================

static func _blank(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


static func _rect(img: Image, r: Rect2i, col: Color) -> void:
	var clipped := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.has_area():
		img.fill_rect(clipped, col)


## Контур прямоугольника по краю r.
static func _lines(img: Image, r: Rect2i, col: Color) -> void:
	_rect(img, Rect2i(r.position.x, r.position.y, r.size.x, 1), col)
	_rect(img, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), col)
	_rect(img, Rect2i(r.position.x, r.position.y, 1, r.size.y), col)
	_rect(img, Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), col)


## Контур со скруглёнными углами: углы прозрачные, внутренние угловые пиксели — контур.
static func _box(img: Image, r: Rect2i, col: Color) -> void:
	_lines(img, r, col)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1
	var y1 := r.end.y - 1
	for c in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1)]:
		_put(img, c.x, c.y, Color(0, 0, 0, 0))
	for c in [Vector2i(x0 + 1, y0 + 1), Vector2i(x1 - 1, y0 + 1), Vector2i(x0 + 1, y1 - 1),
			Vector2i(x1 - 1, y1 - 1)]:
		_put(img, c.x, c.y, col)


## Обводка: прозрачные пиксели, соседние (по 4 сторонам) с непрозрачными, красятся в col.
static func _outline(img: Image, col: Color) -> void:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a8 != 0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
						and src.get_pixel(p.x, p.y).a8 != 0:
					img.set_pixel(x, y, col)
					break


## Контровой свет: крайние слева пиксели силуэта — warm, справа — cold.
static func _rim(img: Image, warm: Color, cold: Color) -> void:
	var src := img.duplicate() as Image
	var w := img.get_width()
	for y in img.get_height():
		for x in w:
			if src.get_pixel(x, y).a8 == 0:
				continue
			if x == 0 or src.get_pixel(x - 1, y).a8 == 0:
				img.set_pixel(x, y, warm)
			elif x == w - 1 or src.get_pixel(x + 1, y).a8 == 0:
				img.set_pixel(x, y, cold)


static func _ellipse(img: Image, c: Vector2, radii: Vector2, col: Color) -> void:
	for y in range(maxi(0, floori(c.y - radii.y)), mini(img.get_height(), ceili(c.y + radii.y) + 1)):
		for x in range(maxi(0, floori(c.x - radii.x)), mini(img.get_width(), ceili(c.x + radii.x) + 1)):
			var d := (Vector2(x, y) + Vector2(0.5, 0.5) - c) / radii
			if d.length_squared() <= 1.0:
				img.set_pixel(x, y, col)


static func _poly(img: Image, points: Array, col: Color) -> void:
	var poly := PackedVector2Array(points)
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for y in range(maxi(0, floori(r.position.y)), mini(img.get_height(), ceili(r.end.y) + 1)):
		for x in range(maxi(0, floori(r.position.x)), mini(img.get_width(), ceili(r.end.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x, y) + Vector2(0.5, 0.5), poly):
				img.set_pixel(x, y, col)


## Волнистая линия вверх (length < 0) или вниз от точки: водоросли, щупальца.
static func _wave(img: Image, from: Vector2, length: int, col: Color, amplitude: float,
		phase: float, tip: Variant = null) -> void:
	var dir := -1 if from.y > img.get_height() / 2.0 else 1
	for i in length:
		var x := roundi(from.x + sin(phase + i * 0.45) * amplitude)
		var y := int(from.y) + i * dir
		_put(img, x, y, tip if tip != null and i == length - 1 else col)


static func _bayer(x: int, y: int) -> float:
	return (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0


## Дизеринг: доля t пикселей цвета b, остальные a.
static func _dither(a: Color, b: Color, t: float, x: int, y: int) -> Color:
	return b if _bayer(x, y) < clampf(t, 0.0, 1.0) else a


## Детерминированный хэш пикселя (для крапин, мха, текстуры дерева).
static func _hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)
