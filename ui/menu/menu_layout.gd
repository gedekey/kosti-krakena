class_name MenuLayout
extends RefCounted
## Раскладка экранов меню 640×360 (М11). Все координаты — целые пиксели.

const SCREEN := Vector2i(640, 360)
## Затемнение фона таверны под меню.
const BACKDROP_DIM := Color(KrakenPalette.INK, 0.55)
const TITLE_RECT := Rect2i(0, 8, 640, 24)

# --- Главное меню ---
const MAIN_TITLE_RECT := Rect2i(0, 56, 640, 24)
const MAIN_SUBTITLE_RECT := Rect2i(0, 84, 640, 12)
const MAIN_BUTTONS_RECT := Rect2i(240, 112, 160, 200)
const MAIN_BUTTON_GAP := 5
## Подпись автора в левом нижнем углу.
const MAIN_AUTHOR_RECT := Rect2i(8, 344, 200, 12)

# --- Общие кнопки внизу ---
const BACK_RECT := Rect2i(16, 326, 110, 24)
const PRIMARY_RECT := Rect2i(484, 326, 140, 24)
const SECONDARY_RECT := Rect2i(140, 326, 140, 24)

# --- Выбор соперников ---
const PORTRAIT_CAPTION_POS := Vector2i(16, 40)
const PORTRAIT_ROW_POS := Vector2i(16, 54)
const MODE_ROW_POS := Vector2i(150, 54)
const COUNT_ROW_POS := Vector2i(150, 80)
const SETUP_INFO_POS := Vector2i(150, 104)
const SETUP_INFO_WIDTH := 470
const CARD_SIZE := Vector2i(84, 112)
const CARD_GAP := 4
const CARDS_Y := 140
const CARD_FRAME_X := 6
const CARD_NAME_Y := 74
const CARD_STARS_Y := 98
## Тёмная подложка под карточками.
const CARDS_PANEL_RECT := Rect2i(8, 132, 624, 126)
const RULES_INFO_RECT := Rect2i(16, 266, 608, 12)
## Притушенная карточка (случайный режим / больше не выбрать).
const CARD_DIM := Color(0.55, 0.55, 0.6, 1)

# --- Настройки и статистика ---
const FORM_RECT := Rect2i(120, 40, 400, 272)
const FORM_CAPTION_WIDTH := 170
const FORM_FIELD_WIDTH := 120
const FORM_ROW_GAP := 6
const FORM_NOTE_GAP := 10
const STATS_RECT := Rect2i(170, 70, 300, 180)
## Внутренние поля панелей форм.
const FORM_MARGIN := 16

# --- Достижения (М17): сетка 3 × 5 карточек ---
const ACH_COUNT_RECT := Rect2i(0, 32, 640, 12)
const ACH_GRID_POS := Vector2i(14, 47)
const ACH_COLUMNS := 3
const ACH_CELL_SIZE := Vector2i(200, 53)
const ACH_COL_GAP := 6
const ACH_ROW_GAP := 2
const ACH_CELL_MARGIN := 3
const ACH_ICON_GAP := 4

# --- Правила (М13) ---
const RULES_PAGE_RECT := Rect2i(24, 36, 592, 282)
const RULES_PAGE_MARGIN := 12
## Высота полосы с иллюстрацией страницы.
const RULES_ILLUSTRATION_H := 74
const RULES_NAV_RECT := Rect2i(250, 326, 140, 24)
## Подпись «ПКМ по выделенному слову — подсказка» (М13, доп.) справа от листалки.
const RULES_TERM_HINT_RECT := Rect2i(400, 326, 224, 24)
## Внутри иллюстраций — целый масштаб спрайтов.
const RULES_SCALE := 2


## Левые края карточек count штук по центру экрана.
static func card_positions(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var total := count * CARD_SIZE.x + maxi(count - 1, 0) * CARD_GAP
	var left := (SCREEN.x - total) / 2
	for i in count:
		out.append(Vector2i(left + i * (CARD_SIZE.x + CARD_GAP), CARDS_Y))
	return out
