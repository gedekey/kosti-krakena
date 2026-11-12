class_name PropArt
extends RefCounted
## Рисунок «живых» предметов стола (М22): пиксельные карты на палитре KrakenPalette
## (буквы — как в ui/sprites/src/symbols.txt) и покадровые реакции. Только целые пиксели.
##
## Предметы: свеча (задувается и вспыхивает снова, вспышка, треск), кружка (плеск, пена
## через край, подскок), череп (стучит челюстью, зевает, светит глазами), щель в досках
## (выглядывает щупальце, хватает воздух, в щели открывается глаз).
## Новый вид предмета (например, свеча культа для кампании) — новые карты и ветка в draw().

const CANDLE := &"candle"
const MUG := &"mug"
const SKULL := &"skull"
const CRACK := &"crack"

## Реакции каждого предмета и их длина в кадрах (TableClickBalance.PROP_FPS).
const REACTIONS := {
	CANDLE: {&"blow": 22, &"flare": 10, &"sputter": 12},
	MUG: {&"slosh": 12, &"spill": 18, &"hop": 10},
	SKULL: {&"chatter": 14, &"yawn": 16, &"glare": 14},
	CRACK: {&"peek": 16, &"grab": 20, &"eye": 16},
}

## Зона нажатия предмета (рисунок стоит по низу и середине).
const HIT_SIZE := {
	CANDLE: Vector2i(14, 26),
	MUG: Vector2i(18, 16),
	SKULL: Vector2i(16, 18),
	CRACK: Vector2i(22, 20),
}

## Звук в начале реакции.
const CUES := {
	&"blow": SoundCatalog.CANDLE_BLOW, &"flare": SoundCatalog.CANDLE_FLARE,
	&"sputter": SoundCatalog.CANDLE_FLARE,
	&"slosh": SoundCatalog.MUG_SLOSH, &"spill": SoundCatalog.MUG_SLOSH,
	&"hop": SoundCatalog.MUG_SLOSH,
	&"chatter": SoundCatalog.SKULL_CLACK, &"yawn": SoundCatalog.SKULL_CLACK,
	&"glare": SoundCatalog.SKULL_CLACK,
	&"peek": SoundCatalog.TENTACLE, &"grab": SoundCatalog.TENTACLE,
	&"eye": SoundCatalog.TENTACLE,
}
## Задутая свеча вспыхивает снова на этом кадре (второй звук).
const BLOW_RELIGHT_FRAME := 14

const MAPS := {
	&"candle": [
		"....K....",
		"..KKKKK..",
		"..KPPBK..",
		".KPPPBK..",
		".KBPPBK..",
		"..KPPBK..",
		"..KPPBK..",
		"..KPBBK..",
		"..KPPBK..",
		"..KPPBK..",
		"KKKKKKKKK",
		"KWWBWWWDK",
		"KDDDDDDDK",
		".KKKKKKK.",
	],
	&"flame_a": ["..F..", ".FF..", ".FFF.", "FFPFF", "FOPOF", ".OPO.", "..O.."],
	&"flame_b": ["..F..", "..FF.", ".FFF.", "FFPFF", "FOPOF", ".OPO.", "..O.."],
	&"flame_l": ["F....", ".FF..", ".FFF.", ".FPFF", "FOPOF", ".OPO.", "..O.."],
	&"flame_r": ["....F", "..FF.", ".FFF.", "FFPF.", "FOPOF", ".OPO.", "..O.."],
	&"flame_big": [
		"...F...",
		"..FF...",
		"..FFF..",
		".FFFF..",
		".FFPFF.",
		"FFPPPFF",
		"FOPPPOF",
		"FOOPOOF",
		".OOPOO.",
		"..OOO..",
	],
	&"flame_small": [".F.", "FFF", "FPF", ".O."],
	&"mug": [
		"..PPPPPPPP....",
		".PPBPPPPPBP...",
		".KPPPBPPPPK...",
		".KDWWWWWWDKKK.",
		".KDWWBWWWDK.K.",
		".KKKKKKKKKK.K.",
		".KDWWWWWWDK.K.",
		".KDWWWWWWDKKK.",
		".KDWWWWWWDK...",
		".KKKKKKKKKK...",
		".KDWWWWWWDK...",
		".KDDDDDDDDK...",
		"..KKKKKKKK....",
	],
	&"skull": [
		"...KKKKKK...",
		"..KPPPPPBK..",
		".KPPPPPPPBK.",
		".KPPPPPPPBK.",
		".KPKKPPKKBK.",
		".KPKKPPKKBK.",
		".KPPPKKPPBK.",
		"..KBPPPPBK..",
	],
	&"jaw": [
		"..KPKPKPBK..",
		"..KBPBPBBK..",
		"...KBBBBK...",
		"....KKKK....",
	],
	&"crack": [
		".WDKKKKKKKKKKKKKKDW.",
		"WKNNKNNNNNNNNNKNNNKW",
		".WDKKKKKKKKKKKKKKDW.",
	],
}

const P := preload("res://ui/sprites/kraken_palette.gd")

static var _textures: Dictionary = {}


static func kinds() -> Array:
	return REACTIONS.keys()


static func has_kind(kind: StringName) -> bool:
	return REACTIONS.has(kind)


static func reactions(kind: StringName) -> Array:
	return REACTIONS[kind].keys()


static func frame_count(kind: StringName, reaction: StringName) -> int:
	return REACTIONS[kind][reaction]


static func hit_size(kind: StringName) -> Vector2i:
	return HIT_SIZE[kind]


## Текстура пиксельной карты (кэш).
static func texture(name: StringName) -> ImageTexture:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(map_image(MAPS[name]))
	return _textures[name]


static func map_image(rows: Array) -> Image:
	var img := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != ".":
				img.set_pixel(x, y, KrakenPalette.BY_LETTER[ch])
	return img


## Нарисовать предмет. foot — середина нижнего края (локальные пиксели ci);
## reaction "" — покой; frame — кадр реакции; idle — кадр покоя.
static func draw(ci: CanvasItem, kind: StringName, reaction: StringName, frame: int, idle: int,
		foot: Vector2i) -> void:
	match kind:
		CANDLE:
			_draw_candle(ci, reaction, frame, idle, foot)
		MUG:
			_draw_mug(ci, reaction, frame, foot)
		SKULL:
			_draw_skull(ci, reaction, frame, foot)
		CRACK:
			_draw_crack(ci, reaction, frame, foot)


static func px(ci: CanvasItem, at: Vector2i, color: Color, size := Vector2i.ONE) -> void:
	ci.draw_rect(Rect2(at, size), color)


static func _blit(ci: CanvasItem, name: StringName, top_left: Vector2i) -> void:
	ci.draw_texture(texture(name), top_left)


## Пламя стоит низом на точке wick_top (над фитилём), по середине.
static func _flame(ci: CanvasItem, name: StringName, wick_top: Vector2i) -> void:
	var t := texture(name)
	var s := Vector2i(t.get_size())
	ci.draw_texture(t, Vector2i(wick_top.x - s.x / 2, wick_top.y - s.y))


# --- Свеча --------------------------------------------------------------------------------

static func _draw_candle(ci: CanvasItem, reaction: StringName, f: int, idle: int,
		foot: Vector2i) -> void:
	var top := foot - Vector2i(4, 14)
	_blit(ci, &"candle", top)
	var wick := top + Vector2i(4, 0)
	var flame_at := wick   # низ пламени — на фитиле
	var idle_flame: StringName = &"flame_a" if idle % 2 == 0 else &"flame_b"
	match reaction:
		&"blow":
			if f < 2:
				_flame(ci, &"flame_r", flame_at)
			elif f < 3:
				_flame(ci, &"flame_small", flame_at)
			elif f < 6:
				if f % 2 == 1:
					px(ci, wick, P.EMBER)
			if f >= 3 and f < BLOW_RELIGHT_FRAME:
				_smoke(ci, wick, f - 3)
			if f == BLOW_RELIGHT_FRAME:
				_flame(ci, &"flame_small", flame_at)
			elif f > BLOW_RELIGHT_FRAME and f < BLOW_RELIGHT_FRAME + 4:
				_flame(ci, &"flame_big", flame_at)
				_sparks(ci, wick, f - BLOW_RELIGHT_FRAME)
			elif f >= BLOW_RELIGHT_FRAME + 4:
				_flame(ci, idle_flame, flame_at)
		&"flare":
			_flame(ci, &"flame_big" if f < 7 else idle_flame, flame_at)
			_sparks(ci, wick, f)
		&"sputter":
			_flame(ci, &"flame_l" if (f / 2) % 2 == 0 else &"flame_r", flame_at)
			if f % 4 == 1:
				px(ci, wick + Vector2i(-3 if (f / 4) % 2 == 0 else 3, -4 - f / 3), P.EMBER)
		_:
			_flame(ci, idle_flame, flame_at)


## Дымок над задутым фитилём: три завитка поднимаются и качаются.
static func _smoke(ci: CanvasItem, wick: Vector2i, s: int) -> void:
	for k in 3:
		var age := s - k * 2
		if age < 0 or age > 9:
			continue
		var x := wick.x + roundi(sin(age * 0.9 + k) * 1.5)
		var y := wick.y - 2 - age * 2
		px(ci, Vector2i(x, y), P.BONE if age < 4 else P.SLATE, Vector2i(1, 2))


## Искры вверх от пламени.
static func _sparks(ci: CanvasItem, wick: Vector2i, f: int) -> void:
	var xs := [-3, 1, 4]
	for k in xs.size():
		var age := f - k
		if age < 0 or age > 6:
			continue
		var x: int = wick.x + xs[k] + (age % 2)
		var y := wick.y - 9 - age * 2
		px(ci, Vector2i(x, y), P.FIRE if age < 3 else P.EMBER)


# --- Кружка -------------------------------------------------------------------------------

const MUG_SLOSH_DX := [-1, 0, 1, 0, -1, 0, 1, 0, 0, 0, 0, 0]
const MUG_HOP_DY := [0, -2, -4, -5, -4, -2, 0, 0, 0, 0]


static func _draw_mug(ci: CanvasItem, reaction: StringName, f: int, foot: Vector2i) -> void:
	var dx := 0
	var dy := 0
	match reaction:
		&"slosh":
			dx = MUG_SLOSH_DX[mini(f, MUG_SLOSH_DX.size() - 1)]
		&"spill":
			dx = -1 if f < 4 else 0
		&"hop":
			dy = MUG_HOP_DY[mini(f, MUG_HOP_DY.size() - 1)]
	var top := foot + Vector2i(-6 + dx, -13 + dy)
	if reaction == &"spill":
		_mug_spill(ci, top, foot, f)
	_blit(ci, &"mug", top)
	match reaction:
		&"slosh":
			# Капли пены вылетают из-за края по дуге.
			var starts := [1, 3, 5]
			var xs := [2, 8, 5]
			var dirs := [-1, 1, -1]
			for k in starts.size():
				var g: int = f - starts[k]
				if g < 0:
					continue
				var y: int = top.y - 4 * g + g * g
				if y > foot.y - 1:
					continue
				px(ci, Vector2i(top.x + xs[k] + dirs[k] * g, y), P.PARCHMENT if g < 3 else P.BONE)
		&"hop":
			if f >= 6:
				var g := f - 6
				px(ci, Vector2i(foot.x - 8 - g, foot.y - 2 + g / 2), P.PARCHMENT)
				px(ci, Vector2i(foot.x + 5 + g, foot.y - 2 + g / 2), P.PARCHMENT)


## Пена бежит по левому боку, на столе — лужица.
static func _mug_spill(ci: CanvasItem, top: Vector2i, foot: Vector2i, f: int) -> void:
	var length := mini(f + 1, 12)
	var start := maxi(0, (f - 11) * 2)
	for i in range(start, length):
		px(ci, Vector2i(top.x, top.y + 1 + i), P.PARCHMENT if i % 3 != 2 else P.BONE)
	var pool := mini(maxi(f - 8, 0), 5) - maxi(f - 15, 0) * 2
	if pool > 0:
		px(ci, Vector2i(top.x - pool + 1, foot.y - 1), P.BONE, Vector2i(pool + 1, 1))


# --- Череп --------------------------------------------------------------------------------

const SKULL_CHATTER := [0, 2, 0, 2, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0]
const SKULL_YAWN := [0, 1, 1, 2, 2, 3, 3, 3, 3, 3, 2, 2, 1, 1, 0, 0]
const SKULL_RATTLE := [1, -1, 1, -1, 1, 0, -1, 0]


static func _draw_skull(ci: CanvasItem, reaction: StringName, f: int, foot: Vector2i) -> void:
	var open := 0
	var dx := 0
	var glow := false
	match reaction:
		&"chatter":
			open = SKULL_CHATTER[mini(f, SKULL_CHATTER.size() - 1)]
		&"yawn":
			open = SKULL_YAWN[mini(f, SKULL_YAWN.size() - 1)]
			glow = open >= 2
		&"glare":
			dx = SKULL_RATTLE[f] if f < SKULL_RATTLE.size() else 0
			glow = f < 12
	# Челюсть лежит на столе, череп над ней поднимается.
	var jaw_top := foot + Vector2i(-6, -4)
	var top := foot + Vector2i(-6 + dx, -12 - open)
	if open > 0:
		px(ci, Vector2i(top.x + 3, top.y + 8), P.INK, Vector2i(6, open))
	_blit(ci, &"jaw", jaw_top)
	_blit(ci, &"skull", top)
	if glow:
		var bright := reaction != &"glare" or f % 2 == 0
		for sx in [3, 7]:
			px(ci, top + Vector2i(sx, 4), P.GREEN, Vector2i(2, 2))
			px(ci, top + Vector2i(sx + (1 if sx == 3 else 0), 4), P.LIME if bright else P.GREEN)


# --- Щель в досках ------------------------------------------------------------------------

const TENTACLE_PEEK := [1, 2, 4, 5, 6, 7, 7, 7, 7, 7, 7, 6, 5, 3, 1, 0]
const TENTACLE_GRAB := [2, 5, 8, 11, 14, 16, 17, 17, 16, 15, 16, 17, 14, 10, 6, 3, 1, 0, 0, 0]
const EYE_OPEN := [0, 1, 2, 2, 2, 2, 1, 0, 1, 2, 2, 2, 2, 1, 0, 0]


static func _draw_crack(ci: CanvasItem, reaction: StringName, f: int, foot: Vector2i) -> void:
	var top := foot + Vector2i(-10, -3)
	_blit(ci, &"crack", top)
	var base := Vector2i(foot.x + 1, foot.y - 2)
	match reaction:
		&"peek":
			draw_tentacle(ci, base, TENTACLE_PEEK[mini(f, TENTACLE_PEEK.size() - 1)],
					f * 0.8, 1.2, 3)
		&"grab":
			var amp := 3.0 if f >= 7 and f <= 11 else 1.5
			draw_tentacle(ci, base, TENTACLE_GRAB[mini(f, TENTACLE_GRAB.size() - 1)],
					f * 0.7, amp, 3)
		&"eye":
			_crack_eye(ci, top + Vector2i(10, 1), EYE_OPEN[mini(f, EYE_OPEN.size() - 1)])


## Глаз в щели: 1 — щёлочка, 2 — открыт со зрачком.
static func _crack_eye(ci: CanvasItem, center: Vector2i, open: int) -> void:
	if open <= 0:
		return
	if open == 1:
		px(ci, center + Vector2i(-2, 0), P.GREEN, Vector2i(4, 1))
		return
	px(ci, center + Vector2i(-3, 0), P.GREEN, Vector2i(6, 1))
	px(ci, center + Vector2i(-1, -1), P.GREEN, Vector2i(2, 1))
	px(ci, center + Vector2i(-1, 1), P.GREEN, Vector2i(2, 1))
	px(ci, center + Vector2i(-2, 0), P.LIME, Vector2i(4, 1))
	px(ci, center, P.INK)


## Щупальце растёт вверх из base на height px, качается (phase, amp), у основания width px.
## Общее для щели в досках и всплеска в Безумии.
static func draw_tentacle(ci: CanvasItem, base: Vector2i, height: int, phase: float, amp: float,
		width := 3) -> void:
	if height <= 0:
		return
	var tip := base
	for i in height:
		var t := float(i) / height
		var w := width if t < 0.45 else (maxi(width - 1, 1) if i < height - 2 else 1)
		var cx := base.x + roundi(sin(i * 0.45 + phase) * amp * t)
		var y := base.y - i
		var left := cx - w / 2
		px(ci, Vector2i(left - 1, y), P.INK, Vector2i(w + 2, 1))
		px(ci, Vector2i(left, y), P.VIOLET, Vector2i(w, 1))
		if w >= 2:
			px(ci, Vector2i(left, y), P.LILAC)
		if w >= 3 and i % 3 == 1:
			px(ci, Vector2i(left + w - 1, y), P.BONE)
		tip = Vector2i(cx, y)
	px(ci, tip + Vector2i(0, -1), P.INK)
