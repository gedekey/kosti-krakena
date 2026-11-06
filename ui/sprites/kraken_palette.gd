class_name KrakenPalette
extends RefCounted
## Палитра игры (ART_PROMPTS.md). Все нарисованные в проекте спрайты используют только её.
##
## Буквы — те же, что в текстовых исходниках ui/sprites/src/symbols.txt.

const INK := Color("#0d0b14")        ## K — почти чёрный, контур
const NIGHT := Color("#1e1a2b")      ## N
const SLATE := Color("#2f2a3d")      ## S
const DARK_WOOD := Color("#4a3b2a")  ## D — тёмное дерево
const WOOD := Color("#7a5a36")       ## W — дерево
const BONE := Color("#c9a66b")       ## B — кость / пергамент
const PARCHMENT := Color("#e8d9b0")  ## P — светлый пергамент
const FIRE := Color("#ffb347")       ## F — огонь
const EMBER := Color("#ff7b1c")      ## O — угли
const GREEN := Color("#3fa66b")      ## G — зелёное свечение
const LIME := Color("#9cff57")       ## L — яркое свечение
const VIOLET := Color("#6b3fa6")     ## V — фиолетовая магия
const LILAC := Color("#b57bff")      ## U — светлая магия
const BLOOD := Color("#8b1e2b")      ## R — кровь

const BY_LETTER := {
	"K": INK, "N": NIGHT, "S": SLATE, "D": DARK_WOOD, "W": WOOD, "B": BONE, "P": PARCHMENT,
	"F": FIRE, "O": EMBER, "G": GREEN, "L": LIME, "V": VIOLET, "U": LILAC, "R": BLOOD,
}


## Цвет входит в палитру (непрозрачный, точное совпадение по 8 бит на канал).
static func contains(color: Color) -> bool:
	if color.a8 != 255:
		return false
	for c: Color in BY_LETTER.values():
		if c.to_rgba32() == color.to_rgba32():
			return true
	return false
