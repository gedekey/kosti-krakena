class_name TableLayout
extends RefCounted
## Раскладка игрового стола 640×360 (М9) и темп показа. Все координаты — целые пиксели.
##
##   y 0..108    места соперников (портрет в рамке, кубики, улики, Безумие, чашка, реплика)
##   y 112..236  лента ставок · текущая ставка и статус · сообщения
##   y 240..360  своя зона: портрет, Рассудок, чашка и кубики, ввод ставки и кнопки

const SCREEN := Vector2i(640, 360)

# --- Места соперников ---
const SEAT_TOP := 2
const SEAT_SIZE := Vector2i(124, 106)
## Наибольший шаг между местами (при 5 соперниках они встают вплотную).
const SEAT_STEP_MAX := 160
const FRAME_SIZE := Vector2i(72, 72)
const SEAT_INFO_X := 76
const SEAT_NAME_Y := 73
## М21: итог «Шёпота Бездны» у соперника — [грань] ×N на подложке, слева от чашки, над именем.
const SEAT_WHISPER_POS := Vector2i(74, 54)
const SEAT_BUBBLE_Y := 86
const SEAT_BUBBLE_SIZE := Vector2i(124, 20)

# --- Середина стола ---
const FEED_RECT := Rect2i(4, 112, 150, 124)
const FEED_ROWS := 6
const BID_RECT := Rect2i(214, 114, 212, 62)
const STATUS_RECT := Rect2i(170, 180, 300, 54)
const MESSAGES_RECT := Rect2i(478, 112, 158, 124)
const MESSAGES_MAX := 6

# --- Своя зона ---
const OWN_PANEL_RECT := Rect2i(0, 240, 640, 120)
const OWN_FRAME_POS := Vector2i(6, 246)
const SANITY_POS := Vector2i(6, 322)
const SANITY_PIP_STEP := 7
const CUP_POS := Vector2i(86, 254)
## Свою чашку и кубики рисуем крупно — целым масштабом.
const OWN_SCALE := 2
const OWN_DICE_POS := Vector2i(134, 262)
const OWN_DIE_STEP := 36
const SLEEVE_POS := Vector2i(134, 302)
const CUP_HINT_POS := Vector2i(80, 304)
const CONTROLS_RECT := Rect2i(328, 244, 308, 112)

# --- Всплывающие панели ---
const POPUP_CENTER := Vector2i(320, 176)
const REVEAL_WIDTH := 380
const POPUP_WIDTH := 300
## Крупная надпись (Безумие, Палифико) — поверх текущей ставки.
const BANNER_RECT := Rect2i(214, 124, 212, 42)

# --- Пауза и достижения (М17) ---
const PAUSE_DIM := Color(KrakenPalette.INK, 0.6)
const PAUSE_RECT := Rect2i(210, 96, 220, 156)
const PAUSE_MARGIN := 10
const PAUSE_GAP := 6
## М19: таймер хода у портрета (секунды до автохода, над нижним краем портрета).
const TURN_TIMER_SIZE := Vector2i(24, 12)
## Всплывающее «Достижение открыто!» — сверху по центру, поверх мест соперников.
const TOAST_RECT := Rect2i(180, 4, 280, 40)
## Сколько держится одно уведомление (сек, не зависит от скорости ботов).
const TOAST_TIME := 3.0

# --- Эффекты (М10): точки привязки относительно места / своей зоны ---
## Низ восклицания «Пойман!»: оно рисуется на 33..80 px выше точки — так оно ложится на портрет.
const FX_EXCLAIM_Y := 84
## Облачко потери кубика у счётчика кубиков соперника.
const FX_SEAT_DICE_Y := 34
## Облачко у своих кубиков и «Шёпот Бездны» над ними (экранные координаты).
const FX_OWN_DICE := Vector2i(222, 296)
const FX_OWN_HAND := Vector2i(214, 330)

# --- Темп (сек при скорости 1.0) ---
## Пауза перед ходом бота.
const BOT_TURN_DELAY := 0.9
## Пауза перед автоматическим броском / следующим раундом, когда человек не участвует.
const AUTO_ROUND_DELAY := 2.5
## «Досмотреть ×2».
const SPECTATE_SPEED := 2.0
## Сколько держится крупная надпись (Безумие, Палифико).
const BANNER_TIME := 2.0


## Левые края мест соперников: по центру экрана, шаг не больше SEAT_STEP_MAX.
static func seat_positions(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if count <= 0:
		return out
	var step := mini(SEAT_STEP_MAX, (SCREEN.x - 8) / count)
	var total := step * (count - 1) + SEAT_SIZE.x
	var left := (SCREEN.x - total) / 2
	for i in count:
		out.append(Vector2i(left + step * i, SEAT_TOP))
	return out
