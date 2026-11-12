class_name TableClickBalance
extends RefCounted
## Числа кликов по столу (М22, DESIGN.md §6): паузы, темп кадров, сколько частиц.
## Чистая косметика — на правила не влияет, по сети не передаётся.

# --- «Живые» предметы ---
## Кадров в секунду у реакций предметов.
const PROP_FPS := 12.0
## Пауза после реакции, пока предмет не отвечает на клики (против спама), сек.
const PROP_COOLDOWN := 0.8
## Кадров в секунду у покоя предметов (дрожание пламени).
const PROP_IDLE_FPS := 6.0
## На сенсорном экране зона нажатия предмета не меньше этой (рисунок не меняется).
const PROP_TOUCH_HIT := Vector2i(20, 20)

# --- Всплеск ---
const SPLASH_FPS := 15.0
## Кадров у всплеска: обычного (пыль и щепки) и в Безумии (тушь и щупальца).
const SPLASH_FRAMES := 10
const MAD_SPLASH_FRAMES := 16
## Не чаще одного всплеска за столько секунд.
const SPLASH_MIN_INTERVAL := 0.1
## Одновременно на столе не больше стольких всплесков (старый уступает новому).
const SPLASH_MAX := 4
## Сколько частиц (от … до).
const DUST_COUNT := Vector2i(5, 8)
const SPLINTER_COUNT := Vector2i(3, 5)
const INK_COUNT := Vector2i(5, 8)
const MAD_TENTACLES := Vector2i(2, 3)
## Скорость разлёта частиц, px/с (от … до).
const DUST_SPEED := Vector2(12.0, 30.0)
const SPLINTER_SPEED := Vector2(40.0, 75.0)
const INK_SPEED := Vector2(30.0, 60.0)
## Тяжесть для щепок и туши, px/с².
const GRAVITY := 240.0
## Высота щупальца из лужи туши, px (от … до).
const MAD_TENTACLE_HEIGHT := Vector2i(5, 9)
