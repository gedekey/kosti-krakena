# Кости Кракена — промпты для генерации ассетов

Здесь собрано то, что не рисуется кодом: портреты, фон, музыка, часть звуков.
Промпты на английском, так модели понимают их лучше. Пояснения на русском.

> **М14 (решение автора):** портреты и фоны из разделов 1–2 нарисованы кодом в pxl
> (`art/portraits.px.js`, `art/backgrounds.px.js`, сборка — `tools/build_art.ps1`) и лежат в
> `assets/generated/` под именами из таблиц ниже. Промпты оставлены на случай замены: положите свой файл
> с тем же именем и пересоберите атласы (`godot --headless --path . -s res://tools/build_sprites.gd`).
> Размер, хромакей и палитру приведёт `GeneratedArt`. Музыку и звуки (разделы 3–4) по-прежнему
> можно класть в `assets/generated/music|sfx/` — подхватятся сами.

## Общие требования

- **Стиль**: тёмный, атмосферный пиксель-арт. Лавкрафтовский хоррор плюс пиратская таверна, XVIII век. Ориентир — референсы в `Изображения/`.
- **Палитра** (держаться близко к ней):
  `#0d0b14` (почти чёрный), `#1e1a2b`, `#2f2a3d`, `#4a3b2a` (тёмное дерево), `#7a5a36` (дерево), `#c9a66b` (кость/пергамент), `#e8d9b0`,
  `#ffb347` (огонь), `#ff7b1c`, `#3fa66b` (зелёное свечение), `#9cff57`, `#6b3fa6` (фиолетовая магия), `#b57bff`, `#8b1e2b` (кровь).
- **Формат**: PNG. Где сказано «прозрачный фон», фон должен быть прозрачным или однотонным `#00ff00` (хромакей вырежу сам).
- **Размеры**: игра рисуется в 640×360. Генерируйте крупнее, но с явной пиксельной сеткой. Даунскейл nearest-neighbor до целевого размера сделаю я.
- Готовые файлы кладите в `assets/generated/<раздел>/` с именами из таблиц ниже. Если папки ещё нет, создайте её.

Общий суффикс стиля, который добавляется к каждому промпту изображения:

```
, pixel art, 16-bit era style, dark lovecraftian pirate tavern atmosphere, limited palette, crisp pixels, no anti-aliasing, no text, no watermark
```

---

## 1. Портреты персонажей

Целевой размер **64×64** (генерировать 512×512 или 1024×1024). Погрудный портрет анфас или вполоборота, прозрачный фон.
Каждому персонажу нужны **2 состояния**:
- `_normal` — обычный вид;
- `_mad` — в Безумии: светящиеся глаза, искажённые черты, зеленовато-фиолетовые прожилки.

| Файл | Промпт |
|---|---|
| `portraits/scholar_normal.png` | `bust portrait of a hooded scholar, pale gaunt face, sharp calculating eyes, dark green hood, small brass amulet, transparent background` |
| `portraits/scholar_mad.png` | `bust portrait of a hooded scholar going insane, pale gaunt face with glowing green eyes, dark veins on skin, dark green hood, transparent background` |
| `portraits/occultist_normal.png` | `bust portrait of a bearded middle-aged occultist, grey streaked hair, intense stare, dark brown coat with arcane pendant, transparent background` |
| `portraits/occultist_mad.png` | `bust portrait of a bearded occultist consumed by madness, glowing purple eyes, cracked skin with violet light, dark brown coat, transparent background` |
| `portraits/sailor_normal.png` | `bust portrait of a cheerful rough sailor, white captain cap, striped shirt, stubble, cocky grin, transparent background` |
| `portraits/sailor_mad.png` | `bust portrait of a sailor driven mad, white captain cap, wide glowing green eyes, wet seaweed in hair, twisted grin, transparent background` |
| `portraits/witch_normal.png` | `bust portrait of a young witch, wide-brimmed dark purple hat, auburn hair, sly smile, transparent background` |
| `portraits/witch_mad.png` | `bust portrait of a witch in madness, wide-brimmed dark purple hat, face shadowed, glowing violet eyes, dark tendrils around, transparent background` |
| `portraits/cultist_normal.png` | `bust portrait of a plague doctor cultist, beaked mask, dark purple hood and robe, red glowing eye lenses, transparent background` |
| `portraits/cultist_mad.png` | `bust portrait of a plague doctor cultist, cracked beaked mask revealing rotten skeletal face, glowing red eyes, dark purple hood, transparent background` |
| `portraits/drowned_normal.png` | `bust portrait of a drowned man, swollen green-grey skin, seaweed, tattered brown clothes, sad empty eyes, transparent background` |
| `portraits/drowned_mad.png` | `bust portrait of a drowned man, swollen green-grey skin, tentacle-like hair, glowing yellow eyes, open screaming mouth, transparent background` |
| `portraits/deepone_normal.png` | `bust portrait of a deep one fish-man creature, green scaly skin, face tentacles, large dark eyes, ancient and calm, transparent background` |
| `portraits/deepone_mad.png` | `bust portrait of a deep one creature, purple scaly skin, writhing face tentacles, multiple glowing eyes, transparent background` |

Новые соперники (Улитс, Ихтиандр, Омен, Крабер, Мастер Ужаса) — **по картинкам автора** (`новые портреты/нов`): белый фон вырезан, кадр «по плечи», цвета переведены в палитру. Файлы `portraits/<id>_normal.png` / `_mad`, id: `ulits`, `ichthyander`, `omen`, `craber`, `horror_master`.

Портреты игрока (на выбор, тоже по 2 состояния) — **по фото от автора** (`новые портреты/player1–6`):
фон вырезан, кадр «по плечи», цвета переведены в палитру. Версии `_mad` дорисованы поверх:

| Файл | Безумие |
|---|---|
| `portraits/player1_normal.png` / `_mad` | зелёные светящиеся глаза, зелёные жилы по черепу, тени под глазами |
| `portraits/player2_normal.png` / `_mad` | фиолетовые глаза, бледная кожа, фиолетовые жилы на лице и шее |
| `portraits/player3_normal.png` / `_mad` | зелёные глаза, водоросли в волосах и бороде, ракушки на плече |
| `portraits/player4_normal.png` / `_mad` | фиолетовые глаза, кубик в пальцах стал глазом Кракена, щупальце на руке |
| `portraits/player5_normal.png` / `_mad` | зелёные светящиеся глаза, зелёные жилы на висках, фиолетовые жилы на щеках |
| `portraits/player6_normal.png` / `_mad` | сиреневые светящиеся глаза, фиолетовые жилы на щеках, луна на шляпе светится зелёным |

---

## 2. Фоны

| Файл | Размер | Промпт |
|---|---|---|
| `backgrounds/tavern_table.png` | 640×360 (генерировать 1920×1080) | `first-person view at an empty wooden gambling table in a dark pirate tavern, table occupies lower 40% of the image and is empty, blurred background with lanterns, fireplace, hooded patrons, kraken sigils on walls, warm firelight and eerie green lantern glow, 16:9` |
| `backgrounds/main_menu.png` | 640×360 | `exterior of a crooked seaside pirate tavern at night, sign with a kraken, stormy sea, giant tentacles faintly visible in the fog, warm light from windows, 16:9` |
| `backgrounds/defeat.png` | 640×360 | `dark ocean depths, giant kraken eye opening in darkness, scattered dice sinking, 16:9` |
| `backgrounds/victory.png` | 640×360 | `tavern table with a pile of gold coins and bone dice, candlelight, triumphant warm mood, 16:9` |

Важно для `tavern_table`: стол в нижней части кадра должен быть **пустым и ровно освещённым**. На нём будут лежать кубики и чашки.

---

## 3. Музыка

Формат **OGG**, бесшовная петля. Если генератор выдаёт MP3/WAV, конвертирую сам.

| Файл | Длит. | Промпт |
|---|---|---|
| `music/tavern_ambient.ogg` | 2–3 мин, петля | `dark atmospheric tavern ambient music, slow tempo 70 bpm, low cello drone, hurdy-gurdy, muted accordion, distant creaking ship wood, subtle lovecraftian dread, seamless loop, no vocals` |
| `music/main_menu.ogg` | 1.5–2 мин, петля | `melancholic sea shanty theme, solo accordion and fiddle, minor key, foggy harbor ambience, seamless loop, no vocals` |
| `music/madness_layer.ogg` | 1 мин, петля | `unsettling dissonant drone, reversed whispers, deep underwater rumble, eerie choir pad, seamless loop, for horror game madness state` (накладывается поверх музыки таверны в Безумии) |
| `music/victory.ogg` | 10–15 с | `short triumphant pirate fanfare, fiddle and drums, celebratory, ending sting` |
| `music/defeat.ogg` | 10–15 с | `short ominous defeat sting, deep horn, descending cello, kraken roar in distance` |

---

## 4. Звуки (если процедурные не устроят)

Формат WAV или OGG, короткие, без хвоста тишины.

| Файл | Промпт |
|---|---|
| `sfx/dice_shake.ogg` | `bone dice shaking inside a wooden cup, 1 second` |
| `sfx/dice_roll.ogg` | `several dice tumbling onto a wooden table` |
| `sfx/cup_slam.ogg` | `wooden cup slammed upside down onto a table` |
| `sfx/cup_lift.ogg` | `lifting a wooden cup off a table, soft scrape` |
| `sfx/liar_call.ogg` | `fist banging on a wooden table, angry` |
| `sfx/cheat_fail.ogg` | `tense string stab with crowd gasp in a tavern` |
| `sfx/accuse.ogg` | `dramatic low drum hit with whispering crowd` |
| `sfx/whisper_abyss.ogg` | `eerie distorted whispers, underwater bubbles, 2 seconds` |
| `sfx/madness_onset.ogg` | `rising dissonant horror swell ending in a heartbeat, 3 seconds` |
| `sfx/ui_click.ogg` | `soft wooden click, ui button` |
| `sfx/table_knock.ogg` | `single knuckle knock on an old wooden table, tiny wood splinters` (клик по столу, М22) |
| `sfx/ink_splat.ogg` | `small wet ink splat with a slimy bubble, short` (клик по столу в Безумии) |
| `sfx/candle_blow.ogg` | `short breath blowing out a candle` |
| `sfx/candle_flare.ogg` | `candle flame flaring up, soft whoosh` |
| `sfx/mug_slosh.ogg` | `ale sloshing in a wooden tankard, short` |
| `sfx/skull_clack.ogg` | `skull jaw clacking three times, dry bone` |
| `sfx/tentacle.ogg` | `wet slimy tentacle slithering out of floorboards, short` |

---

## 5. Кампания (М25)

### Обновление вступления и финала — 2026-11-14

По решению автора девять сюжетных сцен заменены рисунками встроенной модели изображений.
Исходники и описание промптов — `art/campaign_imagegen/README.md`, `storm/` и `scenes/`.
Они используют расширенную морскую палитру, **не** переводятся в старые 14 цветов.
Игровой размер фонов — 640×260; прозрачные движущиеся объекты импортируются отдельно.
Воспроизводимый импорт: `godot --headless --path . -s res://tools/import_storm_art.gd`,
затем `godot --headless --path . --import`. Общая сборка `tools/build_art.ps1` вызывает этот импорт
после старых изображений, поэтому новые ассеты не теряются при пересборке.
Имена `storm_*` и `cinematic_*` отделяют новые сцены от прежних `slide_*`.
Таблицы ниже описывают прежние исходники и остальные ассеты М25.

Всё ниже уже **нарисовано кодом в pxl** (`art/campaign.px.js`, сборка — `tools/build_art.ps1`) и лежит
в `assets/generated/campaign/`. Промпты — на случай замены. Файл кладётся с тем же именем и **того же
размера, уже в палитре** (эти картинки игра берёт как есть, без приведения). Где «прозрачный фон» —
прозрачный PNG.

**Портрет Хоба** — картинка автора `новые портреты/bartender.webp`: белый фон вырезан, кадр «по плечи»,
64×64 в палитре (`python tools/cut_hob_portrait.py` → `portraits/hob_normal.png`).
Промпт на замену: `bust portrait of an old burly tavern keeper, long tangled dark hair and beard with strands of seaweed, milky pupil-less eyes, dark vest over a stained shirt, transparent background`.

**Детали таверны по уровням** — 640×360, прозрачный фон, ложатся поверх `backgrounds/tavern_table.png`
(та же таверна: балка вверху, столбы слева и справа, камин в центре, полки справа). Стол ниже y = 228 —
пустой.

| Файл | Промпт |
|---|---|
| `campaign/level_1.png` | `overlay details for a tavern wall: fishing net hanging on nails, white and red life buoy, an oar leaning on a post, wet boot puddles on the floor, transparent background` |
| `campaign/level_2.png` | `overlay details: seaweed strands hanging from ceiling beams, orange starfish on the walls, sand drifts and seashells on the floorboards, transparent background` |
| `campaign/level_3.png` | `overlay details: small window with a violet crescent moon, bunches of drying herbs hanging from beams, violet candles, crystal ball, bubbling green brew in cauldrons, violet lantern glass, transparent background` |
| `campaign/level_4.png` | `overlay details: red cult banners with a kraken eye, blood red kraken sigil above the fireplace, black candles with green flames, chalk ritual circle on the floor, red lantern glass, transparent background` |
| `campaign/level_5.png` | `overlay details: flooded floor with dark water and ripples, ghostly green fire in the fireplace, seaweed on posts, anchor chain, ship wheel on the wall, green lantern glass, transparent background` |
| `campaign/level_6.png` | `overlay details: true form of the tavern, violet flesh growths creeping over walls and ceiling, fireplace turned into a toothed maw with tentacles, giant open eye above it, barnacles on posts, dark flooded floor, transparent background` |

**Картинки автора** (`новые фоны/кампания/*.jpg`) заменяют pxl-версии: `slide_storm`, `slide_rocks`,
`slide_shore`, `slide_door`, `slide_bar`, `slide_counter` (белый фон вырезан) и `campaign_map`.
`python tools/import_campaign_art.py` усредняет до нужного размера и приводит к палитре (у берега и
моря без фиолетового и зелёного — иначе в них уходит серая пена); `build_art.ps1` вызывает его после pxl.

**Слайды** — фон 640×260; что движется — отдельные файлы (прозрачный фон).

| Файл | Размер | Промпт |
|---|---|---|
| `campaign/slide_storm.png` | 640×260 | `stormy night sea under heavy clouds, rain, dark waves to the horizon, no ship, wide shot` |
| `campaign/slide_rocks.png` | 640×260 | `stormy night sea, jagged black rocks rising from the water on the right, rain, wide shot` |
| `campaign/slide_shore.png` | 640×260 | `night beach after a storm, wreckage washed ashore, distant cliff with a lonely tavern and one lit window` |
| `campaign/slide_door.png` | 640×260 | `wooden tavern wall at night in rain, heavy arched door, hanging sign with a green kraken, hook for a lantern` |
| `campaign/slide_bar.png` | 640×260 | `dark tavern interior behind the bar, shelves with bottles, barrels, empty space in the middle for the bartender` |
| `campaign/slide_fallen.png` | 640×260 | `dark tavern overgrown with violet flesh, overturned table, scattered bone dice, puddle of black water` |
| `campaign/slide_ruin.png` | 640×260 | `tavern collapsing: cracked walls with holes to the night sky, tilted beams` |
| `campaign/slide_dawn.png` | 640×260 | `dawn over a calm sea, sun rising from the water, wooden pier on the left, dark island on the horizon` |
| `campaign/slide_deep.png` | 640×260 | `calm sea surface at dawn seen from the side, below it dark ocean depths with faint tentacles` |
| `campaign/slide_ship.png` / `slide_wreck.png` | 120×110 / 130×100 | `silhouette of a two-masted sailing ship` / `broken shipwreck with a snapped mast` |
| `campaign/slide_boat.png` | 64×52 | `small rowing boat with a dark human silhouette and an oar` |
| `campaign/slide_hero.png` | 26×44 | `dark human silhouette in a cloak, standing` |
| `campaign/slide_counter.png` | 640×106 | `front of a wooden bar counter with a tankard and two bottles on top, white background` |
| `campaign/slide_waves.png` | 2560×60 (4 кадра) | `looping foreground storm waves, 4 frames side by side` |
| `campaign/slide_surf.png` | 2560×16 (4 кадра) | `looping shore foam line, 4 frames side by side` |
| `campaign/slide_eye.png` | 1600×80 (8 кадров) | `giant kraken eye opening in the dark depths, 8 frames from closed to fully open, side by side` |
| `campaign/slide_bolt.png`, `slide_lantern.png`, `slide_flame.png`, `slide_plank.png` | 40×170, 15×24, 3×4, 34×7 | молния, фонарь, язычок пламени, доска |

**Карта таверны** — `campaign/campaign_map.png`, 400×282: `top-down pixel map of a tavern interior: door at the bottom left with a bench, long table in the middle, round tables, corner table by a window on the left wall, fireplace, back room with a red round table at the top, L-shaped bar with barrels at the top right, cellar trapdoor at the bottom right`. Точки уровней рисует игра (координаты — в `campaign/levels/level_<N>.tres`, `map_point`).
