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

Портреты игрока (на выбор, тоже по 2 состояния):

| Файл | Промпт |
|---|---|
| `portraits/player1_normal.png` / `_mad` | `bust portrait of a young rogue gambler, dark bandana, scar on cheek, confident look, transparent background` (для `_mad` добавить: `glowing green eyes, dark veins`) |
| `portraits/player2_normal.png` / `_mad` | `bust portrait of a young woman smuggler, blue headscarf, brown hair, determined look, transparent background` (для `_mad`: `glowing violet eyes, pale skin, dark veins`) |
| `portraits/player3_normal.png` / `_mad` | `bust portrait of an old sea wolf with eyepatch, grey beard, tricorn hat, transparent background` (для `_mad`: `glowing green eye, barnacles on skin`) |

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
