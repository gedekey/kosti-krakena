class_name CampaignLayout
extends RefCounted
## Раскладка экранов кампании 640×360 (М23). Все координаты — целые пиксели.

# --- Экран кампании: слева карта таверны, справа карточка уровня ---
const MAP_RECT := Rect2i(8, 36, 400, 282)
const CARD_RECT := Rect2i(416, 36, 216, 282)
const CARD_MARGIN := 8
## Точка уровня на карте: квадрат со стороной (касание с запасом — TouchUI).
const POINT_SIZE := Vector2i(16, 16)
## Подпись места — под точкой.
const POINT_LABEL_GAP := 2
## Портреты соперников в карточке (масштаб 1/2 — 32 px).
const CARD_PORTRAIT := Vector2i(32, 32)
## Кнопки внизу: «Назад», «Портрет», «Вступление», «Заново».
const PORTRAIT_BUTTON_RECT := Rect2i(140, 326, 100, 24)
const INTRO_BUTTON_RECT := Rect2i(248, 326, 110, 24)
const RESTART_BUTTON_RECT := Rect2i(366, 326, 100, 24)

# --- Сцена с Хобом ---
const HOB_FRAME_POS := Vector2i(40, 120)
## Портрет Хоба — ×2 (128 px) в рамке.
const HOB_SCALE := 2
const HOB_NAME_POS := Vector2i(40, 270)
const HOB_CLOUD_RECT := Rect2i(200, 140, 400, 84)
const HOB_CLOUD_MARGIN := 10
## Хвостик облака к портрету — от левого края облака.
const HOB_TAIL_Y := 182
const SCENE_NEXT_RECT := Rect2i(484, 326, 140, 24)
const SCENE_SKIP_RECT := Rect2i(16, 326, 140, 24)

# --- Слайды ---
const SLIDE_ART_RECT := Rect2i(0, 0, 640, 260)
const SLIDE_TEXT_RECT := Rect2i(40, 264, 560, 56)
const SLIDE_TEXT_MARGIN := 8

# --- Выбор портрета ---
const PICKER_RECT := Rect2i(170, 70, 300, 200)

# --- «Конец» ---
const END_TITLE_RECT := Rect2i(0, 120, 640, 24)
const END_TEXT_RECT := Rect2i(80, 160, 480, 40)
const END_BUTTON_RECT := Rect2i(250, 230, 140, 24)

# --- Главное меню ---
## Отметка «Кампания пройдена» (над подписью автора).
const MAIN_FINISHED_RECT := Rect2i(8, 330, 200, 12)
