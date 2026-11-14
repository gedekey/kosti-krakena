# М25 — новые сюжетные иллюстрации

Решение автора от 2026-11-14, согласованное интервью и утверждённый образец — `storm/concept.png`.
Создано встроенным инструментом ImageGen, без API/CLI. Исходники сохранены в этом каталоге;
`.gdignore` исключает крупные оригиналы и кадры проверки из импорта Godot и игровой сборки.

## Художественное задание и промпты

Общая часть промптов (EN):

> Narrative pixel-art cinematic for a dark Lovecraftian eighteenth-century pirate tavern game.
> Panoramic 640:260 composition, crisp square pixel clusters, deliberate stepped contours,
> readable silhouettes and cinematic lighting. Cold slate-blue and navy sea, muted grey foam,
> warm amber lantern accents, restrained violet and green in the finale. No blur, no antialiasing,
> no noisy all-over dithering, no text, UI, border or watermark. Logical 640x260 pixels rendered larger.

Каждый фон создавался отдельным запросом с утверждённой сценой или предыдущим рисунком
как референсом стиля. Ниже предметная часть набора промптов; фон и объект запрашиваются отдельно,
чтобы не дублировать неподвижный объект под анимированным.

| Источник | Предметная часть промпта (EN) |
|---|---|
| `storm/concept.png` | Two-masted wooden sailing ship struggles through violent night storm, three-quarter side view, tilted by swell, ragged wind-filled sails. Layered foamy waves, lightning behind ship, one warm stern lantern. No shoreline, monster or tentacles yet. |
| `storm/background.png` | Same storm composition without ship, masts, ropes, lantern, rain or lightning. Fill the removed ship area naturally with clouds and ocean. Tall foreground wave crests mostly in bottom quarter. |
| `storm/ship.png` | Isolated matching two-masted ship, bow right, wind-filled torn grey sails, dark wooden hull, warm stern lantern. Genuine transparent alpha, no water, foam, sky or rain. |
| `scenes/rocks.png` | Night storm ocean, jagged black coastal rocks at right, white-blue spray around their bases, middle-left sea open for a separate wreck. No ship, rain or lightning. |
| `scenes/wreck.png` | Same ship broken after striking rocks: fractured bow, snapped forward mast, collapsed torn sails, tilted hull and nearly extinguished lantern. Transparent sprite without rocks or water. |
| `scenes/shore.png` | Night beach after wreck, wet sand and driftwood, sea at left, winding path to lonely crooked tavern on cliff at upper right, one amber window. Leave lower beach open for silhouette hero. |
| `scenes/door.png` | Close exterior of the same tavern, heavy arched weathered door center-right, wet timber, stone foundations, kraken-symbol sign without letters, empty lantern hook right of door, amber slit under door. No people or rain. |
| `scenes/bar.png` | Tavern interior behind bar: shelves, bottles, barrels, beams, ropes and nets, low amber light with navy shadows. Empty center for bartender, no foreground counter or characters. |
| `scenes/hob.png` | Preserve Old Hob reference identity: burly old keeper, tangled dark hair, seaweed beard, milky eyes, stained shirt, brown vest and apron. Waist-up, both hands polishing a tankard with cloth, reserved expression. Transparent sprite, no monster reveal. |
| `scenes/counter.png` | Wide frontal wooden bar counter, straight amber tabletop edge, dark vertical front planks and iron fittings. Two small bottles far right, tankard far left, center free. Transparent above tabletop, no people or room. |
| `scenes/fallen.png` | Revealed true tavern: violet organic growths, barnacles, fireplace becomes tooth-lined maw with limp tentacles, overturned gambling table, scattered bone dice, wet dark floor. Center open for defeated boss. |
| `scenes/boss.png` | Preserve Deep One reference: green scales, bulging dim eyes, tentacle beard and crown, dark occult coat. Defeated and slumped, one weak reaching claw, full figure visible. Transparent, no background. |
| `scenes/ruin.png` | Same tavern collapsing and flooding, tilted cracked beams, roof breaches to night sky, broken windows, violet growths, seawater pours inside. No boss, people or foreground falling planks. |
| `scenes/dawn.png` | Calm dawn sea, worn pier from lower left, dark distant island at right, low sunrise and muted rose-grey clouds, cold slate foreground water. Leave open water center-right for boat. |
| `scenes/boat.png` | Small weathered rowing boat, bow right, one oar and a seated cloaked anonymous silhouette, hidden face, warm dawn edge light. Transparent, no water or ripples. |
| `scenes/hero.png` | Anonymous human seen strictly from behind, rounded hood, long dark navy cloak and boots, relaxed arms. Almost black silhouette with subtle cold rim light, no face, horns, pointed hat or weapon. Transparent full figure. |
| `scenes/deep.png` | Side cutaway of ocean at dawn: sky above y45, water surface y55, immense navy depths below. Faint tentacles at far edges, center-bottom dark and open for eye. No eye or boat in background. |
| `scenes/eye.png` | Enormous fully open horizontal almond Kraken eye, heavy indigo scaled eyelids, muted green-gold iris, black vertical pupil, small reflection, violet marine skin fringe. Transparent single sprite, no head or background. |

Для Хоба использован референс `новые портреты/bartender.webp`, для Глубоководного —
`новые портреты/deepone_mad.jpg`. Игровые портреты эти изображения не заменяют.

## Сборка и проверка

```bat
godot --headless --path . -s res://tools/import_storm_art.gd
godot --headless --path . --import
godot --path . --rendering-method gl_compatibility -s res://tools/preview_storm.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_campaign -gexit
```

`godot` здесь — путь к консольному исполняемому файлу Godot 4. Общая сборка
`tools/build_art.ps1` восстанавливает новые ассеты после pxl и импорта старых JPG.
Godot приводит размеры через nearest; исходная расширенная палитра сохраняется.
В игре используются `assets/generated/campaign/storm_*` и `cinematic_*`.
Старые `slide_*` оставлены для истории и прочих потребителей.

Preview снимает реальную отрисовку `SlideArt`: все девять сцен в нескольких моментах,
а также последовательность шторма. Движение привязано к целым пикселям.
