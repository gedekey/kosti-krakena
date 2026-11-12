class_name MenuLayout
extends RefCounted
## Раскладка экранов меню 640×360 (М11). Все координаты — целые пиксели.

const SCREEN := Vector2i(640, 360)
## Затемнение фона таверны под меню.
const BACKDROP_DIM := Color(KrakenPalette.INK, 0.55)
const TITLE_RECT := Rect2i(0, 8, 640, 24)

# --- Главное меню ---
const MAIN_TITLE_RECT := Rect2i(0, 56, 640, 24)
## 3D-эмблема (табличка с глазом) над названием.
const MAIN_EMBLEM_RECT := Rect2i(280, 2, 80, 56)
const MAIN_SUBTITLE_RECT := Rect2i(0, 84, 640, 12)
## М23: 9 кнопок (с «Кампанией»).
const MAIN_BUTTONS_RECT := Rect2i(240, 104, 160, 216)
const MAIN_BUTTON_GAP := 3
## Одиночный ранг (М20) — в правом нижнем углу.
const MAIN_RANK_POS := Vector2i(470, 316)
## Подпись автора в левом нижнем углу.
const MAIN_AUTHOR_RECT := Rect2i(8, 344, 200, 12)

# --- Общие кнопки внизу ---
const BACK_RECT := Rect2i(16, 326, 110, 24)
const PRIMARY_RECT := Rect2i(484, 326, 140, 24)
const SECONDARY_RECT := Rect2i(140, 326, 140, 24)

# --- Выбор соперников ---
const PORTRAIT_CAPTION_POS := Vector2i(16, 34)
const PORTRAIT_ROW_POS := Vector2i(16, 46)
const MODE_ROW_POS := Vector2i(150, 46)
const COUNT_ROW_POS := Vector2i(150, 72)
const SETUP_INFO_POS := Vector2i(150, 96)
const SETUP_INFO_WIDTH := 470
## Карточка места в лобби (ряд по центру, card_positions).
const CARD_SIZE := Vector2i(84, 112)
const CARD_GAP := 4
const CARDS_Y := 140
const CARD_FRAME_X := 6
const CARD_NAME_Y := 74
## Карточки соперников — сетка по OPP_CARDS_PER_ROW (12 персонажей — два ряда):
## портрет в рамке, под ним имя в одну строку и ★.
const OPP_CARD_SIZE := Vector2i(100, 96)
const OPP_CARDS_PER_ROW := 6
const OPP_CARDS_Y := 124
const OPP_CARD_ROW_GAP := 4
const OPP_CARD_FRAME_X := 14
const OPP_CARD_NAME_Y := 73
const OPP_CARD_STARS_Y := 85
## Тёмная подложка под карточками.
const CARDS_PANEL_RECT := Rect2i(8, 120, 624, 202)
## Правила матча — внизу между «Назад» и «За стол!».
const RULES_INFO_RECT := Rect2i(134, 332, 344, 12)
## Притушенная карточка (случайный режим / больше не выбрать).
const CARD_DIM := Color(0.55, 0.55, 0.6, 1)

# --- Настройки и статистика ---
const FORM_RECT := Rect2i(120, 40, 400, 272)
const FORM_CAPTION_WIDTH := 170
const FORM_FIELD_WIDTH := 120
const FORM_ROW_GAP := 6
const FORM_NOTE_GAP := 10
const STATS_RECT := Rect2i(170, 40, 300, 272)
## Внутренние поля панелей форм.
const FORM_MARGIN := 16

# --- Достижения (М17): сетка 3 × 6 карточек (М23: 18 штук) ---
## «Открыто: N из M» — справа от заголовка.
const ACH_COUNT_RECT := Rect2i(440, 14, 190, 12)
const ACH_GRID_POS := Vector2i(14, 36)
const ACH_COLUMNS := 3
const ACH_CELL_SIZE := Vector2i(200, 46)
const ACH_COL_GAP := 6
const ACH_ROW_GAP := 2
const ACH_CELL_MARGIN := 3
const ACH_ICON_GAP := 4

# --- Сетевая игра (М19) ---
## Слева — имя, портрет, «Создать игру»; справа — найденные игры и ввод IP.
const NET_LEFT_RECT := Rect2i(16, 40, 292, 278)
const NET_RIGHT_RECT := Rect2i(320, 40, 304, 278)
## Поле ввода: высота с запасом под палец (М16: 1 px ≈ 1 dp).
const NET_FIELD_SIZE := Vector2i(150, 22)
const NET_GAME_BUTTON_WIDTH := 272
## Сколько найденных игр показывать.
const NET_GAMES_MAX := 4
const NET_STATUS_RECT := Rect2i(136, 326, 488, 24)
## Лобби: карточки мест в ряд, под ними — правила, адреса, подсказки.
const LOBBY_CARDS_Y := 40
const LOBBY_CARD_SIZE := Vector2i(84, 110)
## Имя — в две строки (длинные имена персонажей), под ним — кто сидит.
const LOBBY_CARD_NAME_H := 24
const LOBBY_CARD_ROLE_Y := 100
const LOBBY_ARROWS_Y := 152
## Значок сетевого ранга (М20) — в правом нижнем углу портрета.
const LOBBY_RANK_POS := Vector2i(50, 44)
const LOBBY_INFO_RECT := Rect2i(16, 178, 608, 140)
const LOBBY_INFO_GAP := 4

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


## Левые верхние углы карточек соперников: ряды по OPP_CARDS_PER_ROW, каждый по центру.
static func opponent_card_positions(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in count:
		var row := i / OPP_CARDS_PER_ROW
		var in_row := mini(count - row * OPP_CARDS_PER_ROW, OPP_CARDS_PER_ROW)
		var total := in_row * OPP_CARD_SIZE.x + maxi(in_row - 1, 0) * CARD_GAP
		var left := (SCREEN.x - total) / 2
		out.append(Vector2i(left + (i % OPP_CARDS_PER_ROW) * (OPP_CARD_SIZE.x + CARD_GAP),
				OPP_CARDS_Y + row * (OPP_CARD_SIZE.y + OPP_CARD_ROW_GAP)))
	return out


## Левые края карточек count штук по центру экрана.
static func card_positions(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var total := count * CARD_SIZE.x + maxi(count - 1, 0) * CARD_GAP
	var left := (SCREEN.x - total) / 2
	for i in count:
		out.append(Vector2i(left + i * (CARD_SIZE.x + CARD_GAP), CARDS_Y))
	return out
