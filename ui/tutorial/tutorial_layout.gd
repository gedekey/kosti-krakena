class_name TutorialLayout
extends RefCounted
## Раскладка подсказок и обучающего матча (М13), 640×360. Все координаты — целые пиксели.
##
## В обучении за столом один соперник — его место в центре сверху (x 258..382),
## слева сверху свободно под панель тренера, справа сверху — «Пропустить».

# --- Тренер в обучающем матче ---
const COACH_RECT := Rect2i(4, 2, 250, 106)
const COACH_MARGIN := 6
const SKIP_RECT := Rect2i(526, 4, 110, 22)
## Рамка вокруг кнопки, которую ждёт шаг: отступ и толщина, мигание (сек на фазу).
const HIGHLIGHT_PAD := 2
const HIGHLIGHT_WIDTH := 2
const HIGHLIGHT_BLINK := 0.35
const HIGHLIGHT_COLOR := KrakenPalette.LIME
## Итог обучения.
const FINISH_RECT := Rect2i(150, 96, 340, 150)
const FINISH_MARGIN := 12

# --- Подсказки при первом использовании ---
const HINT_DIM := Color(KrakenPalette.INK, 0.6)
const HINT_RECT := Rect2i(140, 96, 360, 156)
const HINT_MARGIN := 12


## Ширина текста в тёмной панели шириной panel_width с полями margin_px
## (за вычетом рамки самой панели — иначе панель раздувается шире своего места).
static func text_width(panel_width: int, margin_px: int) -> int:
	var frame := Sprites.panel(Sprites.PanelKind.DARK).get_minimum_size()
	return panel_width - 2 * margin_px - int(frame.x)


static func margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, px)
	return m
