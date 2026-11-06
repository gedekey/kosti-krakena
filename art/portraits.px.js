// Портреты персонажей 64×64 (М14). Только палитра игры (KrakenPalette, те же буквы).
// Свет: тёплый огонь слева, холодная тень справа. Каждый персонаж — обычный и в Безумии.
include("palette.px.js")

const S64 = { w: 64, h: 64 }

// --- Общие детали ----------------------------------------------------------

// Контур K вокруг непрозрачного (внутри холста 64×64).
function outline(c) {
  const add = []
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) {
      if (c.is(x, y, "*")) continue
      const n = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
        const nx = x + dx, ny = y + dy
        return nx >= 0 && ny >= 0 && nx < c.w && ny < c.h && c.is(nx, ny, "*") && !c.is(nx, ny, "K")
      })
      if (n) add.push([x, y])
    }
  for (const [x, y] of add) c.px(x, y, "K")
}

// Лицо. o: cx, cy (центр глаз), skin [тень, основа, свет], w (полуширина), jaw (низ подбородка).
function face(c, o) {
  const [sd, sm, sl] = o.skin
  const cx = o.cx ?? 32, ey = o.cy ?? 30, hw = o.w ?? 9, jaw = o.jaw ?? 43
  // профиль головы: полуширина по строкам от макушки (ey-12) до подбородка (jaw)
  const top = ey - (o.top ?? 12)
  const chinLen = jaw - ey
  const half = (y) => {
    const d = y - ey
    if (y < top + 3) return hw - [4, 2, 1][y - top]
    if (d <= 3) return hw
    const k = (d - 3) / (chinLen - 3)   // 0..1 от скул к подбородку
    return Math.max(2, Math.round(hw - k * k * (hw - 2) - k * 1.5))
  }
  for (let y = top; y <= jaw; y++) {
    const h = half(y)
    c.hline(cx - h, y, h * 2 + 1, sm)
    // тень справа (шире к подбородку), свет слева на скуле
    const sw = 2 + Math.round(Math.max(0, y - ey) / 4)
    c.hline(cx + h - sw + 1, y, sw, sd)
    if (y > ey - 8 && y < ey + 6) c.hline(cx - h, y, 2, sl)
  }
  c.hline(cx - 2, jaw, 4, sd)  // под подбородком
  // брови / глазницы
  c.hline(cx - 6, ey - 2, 4, sd); c.px(cx - 6, ey - 1, sd)
  c.hline(cx + 3, ey - 2, 4, sd); c.px(cx + 6, ey - 1, sd)
  // глаза
  const eye = o.eye ?? "P", pupil = o.pupil ?? "K"
  for (const ex of [cx - 5, cx + 3]) {
    c.rect(ex, ey, 3, 1, eye)
    c.px(ex + 1, ey, pupil)
    c.hline(ex, ey + 1, 3, sd)
  }
  // нос
  c.vline(cx, ey + 1, 5, sl)
  c.vline(cx + 1, ey + 2, 4, sd)
  c.hline(cx - 1, ey + 6, 3, sd)
  // рот
  if (o.mouth !== false) {
    c.hline(cx - 2, ey + 9, 5, o.mouthColor ?? sd)
    c.px(cx - 3, ey + 9, sm)
  }
}

// Плечи / торс: эллипс снизу.
function bust(c, col, o = {}) {
  c.ellipse(32, o.y ?? 68, o.rx ?? 28, o.ry ?? 20, col)
}

// Светящиеся глаза Безумия (поверх обычных).
function madEyes(c, cx, ey, col, core = "P") {
  for (const ex of [cx - 5, cx + 3]) {
    c.rect(ex, ey, 3, 1, core)
    c.px(ex - 1, ey, col); c.px(ex + 3, ey, col)
    c.px(ex + 1, ey + 1, col)
  }
}

// Прожилки: короткие ломаные линии.
function veins(c, pts, col) {
  for (const p of pts) c.line(p[0], p[1], p[2], p[3], col)
}

// Щупальце из точки: синусоида, утончается.
function tentacle(c, x, y, len, dir, col, amp = 2, seed = 0) {
  const n = Math.hypot(dir[0], dir[1]), dx = dir[0] / n, dy = dir[1] / n
  for (let i = 0; i < len; i++) {
    const w = Math.sin(i * 0.45 + seed) * amp * Math.min(1, i / 4)
    const px = Math.round(x + dx * i - dy * w)
    const py = Math.round(y + dy * i + dx * w)
    c.rect(px, py, i < len * 0.45 ? 2 : 1, i < len * 0.45 ? 2 : 1, col)
  }
}

// --- Персонажи -------------------------------------------------------------

const P = {}

// Учёный в капюшоне: бледный, острый взгляд, тёмно-зелёный капюшон, латунный амулет.
// Капюшон: o.dark — основа, o.lit — освещённая огнём сторона, o.rim — кромка.
function hood(c, o) {
  const cy = o.cy ?? 30
  bust(c, o.dark)
  c.ellipse(32, cy - 2, 16, 19, o.dark)
  c.poly([16, cy, 48, cy, 55, 64, 9, 64], o.dark)
  // освещённая левая сторона
  for (let y = 0; y < 64; y++) for (let x = 0; x < 22; x++)
    if (c.is(x, y, o.dark) && x < 17 + Math.round((y - cy) / 6) && y > cy - 14) c.px(x, y, o.lit)
  // складки
  c.line(19, cy + 6, 22, 60, o.lit); c.line(45, cy + 6, 42, 60, "K")
  // проём
  c.ellipse(32, cy + 1, 11, 14, "K")
  if (o.rim) { c.line(16, cy - 12, 12, cy + 4, o.rim); c.line(12, cy + 5, 10, cy + 16, o.rim) }
}

P.scholar = (c, mad) => {
  hood(c, { dark: "N", lit: "S", rim: "G", cy: 30 })
  face(c, { cx: 32, cy: 31, skin: ["W", "B", "P"], w: 8, jaw: 44, top: 11 })
  // тень капюшона на лбу
  c.rect(23, 19, 18, 4, "K")
  c.recolor({ B: "W", P: "W" }, [23, 23, 18, 3])
  c.recolor({ W: "D" }, [23, 23, 18, 1])
  // амулет
  c.line(29, 47, 32, 52, "D"); c.line(35, 47, 32, 52, "D")
  c.rect(31, 52, 3, 3, "F"); c.px(31, 52, "P"); c.px(33, 54, "O")
  if (mad) {
    madEyes(c, 32, 31, "G", "L")
    veins(c, [[25, 34, 26, 38], [26, 38, 25, 41], [39, 33, 38, 37], [38, 37, 40, 40], [29, 24, 30, 27]], "V")
    c.rect(31, 52, 3, 3, "L"); c.px(32, 53, "P")
  }
}

// Персонажи, кроме Учёного (М14). Подключается из portraits.px.js; P, face, hood, ... — оттуда.

// Щетина / борода: дизеринг цветом по области.
function stubble(c, x, y, w, h, col, d = 0.5) { c.dither(x, y, w, h, ".", col, d) }

// Оккультист: борода с проседью, коричневый плащ, пентакль-амулет.
P.occultist = (c, mad) => {
  bust(c, "D")
  c.poly([22, 50, 42, 50, 46, 64, 18, 64], "N")
  c.line(22, 50, 27, 64, "W"); c.line(42, 50, 37, 64, "K")
  c.rect(28, 42, 9, 8, "W")
  // волосы: зачёсаны назад, виски с проседью
  c.ellipse(32, 23, 12, 10, "S")
  c.rect(21, 23, 3, 10, "S"); c.rect(41, 23, 3, 10, "S")
  face(c, { cx: 32, cy: 30, skin: ["D", "W", "B"], w: 9, jaw: 43, top: 9, mouth: false })
  c.poly([23, 21, 30, 18, 41, 20, 41, 23, 34, 21, 23, 23], "S")
  c.line(26, 15, 33, 19, "B"); c.line(33, 14, 38, 18, "B"); c.line(21, 25, 22, 31, "B"); c.line(43, 25, 43, 29, "W")
  // борода: клин, пара седых прядей
  c.poly([23, 35, 27, 38, 37, 38, 42, 35, 41, 42, 36, 49, 31, 50, 27, 46, 24, 41], "S")
  c.recolor({ S: "N" }, (x, y) => x > 37 && y > 34 && y < 52)
  c.hline(29, 39, 6, "K"); c.hline(30, 40, 4, "R")
  c.line(27, 42, 29, 47, "B"); c.line(33, 43, 33, 48, "W"); c.px(25, 39, "B")
  c.hline(25, 37, 4, "N"); c.hline(36, 37, 4, "N")
  c.line(28, 50, 32, 54, "B"); c.line(36, 50, 32, 54, "B")
  c.ring(32, 57, 3, "V"); c.px(32, 57, "U"); c.px(32, 55, "U"); c.px(30, 58, "U"); c.px(34, 58, "U")
  if (mad) {
    madEyes(c, 32, 30, "V", "U")
    for (const l of [[25, 21, 27, 25], [27, 25, 26, 28], [38, 22, 39, 26], [39, 26, 41, 27], [24, 33, 25, 35]]) c.line(...l, "U")
    c.circ(32, 57, 2, "U"); c.px(32, 57, "P")
  }
}

// Моряк: белая капитанская фуражка, тельняшка, щетина, наглая ухмылка.
P.sailor = (c, mad) => {
  bust(c, "P")
  for (let y = 50; y < 64; y += 3) for (let x = 0; x < 64; x++) if (c.is(x, y, "P")) c.px(x, y, "S")
  c.recolor({ P: "B" }, (x, y) => x > 42 && y > 46)
  c.poly([22, 48, 28, 48, 32, 56, 36, 48, 42, 48, 36, 62, 28, 62], "N")
  c.rect(28, 42, 9, 8, "W")
  face(c, { cx: 32, cy: 30, skin: ["D", "W", "B"], w: 9, jaw: 44, top: 9, mouth: false })
  stubble(c, 24, 38, 17, 6, "D", 0.35)
  c.hline(29, 40, 6, "K"); c.px(35, 39, "K"); c.px(36, 38, "K"); c.hline(30, 41, 3, "D")
  c.ellipse(32, 18, 14, 5, "P")
  c.rect(19, 18, 27, 4, "P")
  c.recolor({ P: "B" }, [38, 13, 9, 9])
  c.hline(19, 22, 27, "N")
  c.poly([19, 23, 45, 23, 42, 26, 22, 26], "K")
  c.hline(22, 23, 18, "S")
  c.rect(31, 19, 3, 3, "F"); c.px(31, 19, "P")
  if (mad) {
    madEyes(c, 32, 30, "G", "L")
    c.rect(28, 39, 9, 3, "K"); c.hline(29, 39, 7, "P"); c.px(31, 39, "K"); c.px(34, 39, "K")
    c.px(37, 38, "K"); c.px(38, 37, "K")
    for (const [x, len, s] of [[20, 14, 0], [23, 9, 2], [43, 16, 1], [46, 10, 3]]) tentacle(c, x, 24, len, [0, 1], "G", 1, s)
    c.px(20, 30, "L"); c.px(43, 33, "L")
  }
}

// Ведьма: широкополая фиолетовая шляпа, рыжие волосы, хитрая улыбка.
P.witch = (c, mad) => {
  bust(c, "N")
  c.poly([24, 50, 40, 50, 36, 58, 28, 58], "V")
  c.line(28, 50, 32, 57, "U"); c.line(36, 50, 32, 57, "N")
  c.ellipse(32, 30, 14, 14, "O")
  c.poly([18, 30, 46, 30, 49, 52, 15, 52], "O")
  c.recolor({ O: "R" }, (x, y) => x > 38 || y > 46)
  c.line(17, 34, 19, 50, "F"); c.line(21, 30, 22, 44, "F")
  c.rect(29, 42, 7, 8, "B")
  face(c, { cx: 32, cy: 31, skin: ["W", "B", "P"], w: 8, jaw: 43, top: 10, mouth: false })
  c.hline(30, 40, 4, "R"); c.px(34, 39, "R"); c.px(29, 40, "W")
  c.px(26, 31, "K"); c.px(38, 31, "K")
  c.ellipse(32, 22, 26, 4, "V")
  c.recolor({ V: "N" }, (x, y) => y >= 23)
  c.poly([22, 22, 42, 22, 40, 10, 47, 1, 50, 3, 44, 8, 36, 3, 26, 9], "V")
  c.recolor({ V: "N" }, (x, y) => y < 22 && x > 36)
  c.hline(23, 19, 18, "U"); c.hline(23, 20, 18, "N")
  c.rect(27, 18, 3, 3, "F")
  c.line(26, 9, 28, 17, "U")
  if (mad) {
    c.recolor({ P: "W", B: "D", W: "S", R: "N" }, [22, 22, 21, 23])
    madEyes(c, 32, 31, "V", "U")
    for (const [x, y, d, s] of [[14, 40, [-1, 1], 0], [50, 38, [1, 1], 2], [12, 26, [-1, 0], 1], [52, 24, [1, 0], 3], [18, 52, [-1, 1], 4]])
      tentacle(c, x, y, 12, d, "V", 2, s)
  }
}

// Чумной культист: клювастая маска, фиолетовый капюшон, красные линзы.
P.plague_cultist = (c, mad) => {
  hood(c, { dark: "N", lit: "V", rim: "U", cy: 30 })
  c.recolor({ N: "V" }, (x, y) => y > 46 && x < 26)
  c.ellipse(32, 30, 9, 11, "B")
  c.recolor({ B: "W" }, (x, y) => x > 36)
  c.recolor({ B: "P" }, (x, y) => x < 26)
  c.poly([27, 34, 37, 34, 44, 52, 41, 54, 33, 46], "B")
  c.recolor({ B: "W" }, (x, y) => x > 37 && y > 36)
  c.line(34, 40, 41, 52, "D")
  c.px(30, 36, "D"); c.px(29, 37, "D")
  for (const x of [25, 35]) { c.circ(x + 1, 29, 2, "K"); c.rect(x, 28, 3, 3, "R"); c.px(x, 28, "O") }
  c.rect(23, 19, 18, 3, "K")
  if (mad) {
    c.poly([33, 21, 41, 24, 40, 36, 36, 33, 34, 28], "K")
    c.rect(36, 27, 3, 2, "P"); c.px(37, 31, "B"); c.px(39, 33, "P")
    c.line(33, 21, 30, 25, "K"); c.line(41, 30, 44, 36, "K")
    for (const x of [25, 35]) { c.rect(x, 28, 3, 3, "O"); c.px(x + 1, 29, "F") }
    c.rect(36, 28, 3, 3, "O"); c.px(37, 29, "P")
  }
}

// Утопленник: распухшая серо-зелёная кожа, водоросли, рваное бурое, пустые глаза.
P.drowned = (c, mad) => {
  bust(c, "D")
  c.recolor({ D: "W" }, (x, y) => x < 20)
  for (const [x, y] of [[14, 54], [22, 50], [42, 52], [50, 56]]) { c.line(x, y, x - 2, 64, "K"); c.line(x + 1, y, x + 2, 64, "N") }
  c.poly([26, 47, 38, 47, 36, 52, 28, 52], "N")
  c.rect(28, 42, 9, 8, "S")
  face(c, { cx: 32, cy: 30, skin: ["N", "S", "G"], w: 10, jaw: 44, top: 11, eye: "S", pupil: "N", mouth: false })
  c.recolor({ S: "G" }, (x, y) => x < 37 && y > 18 && y < 41)
  c.hline(29, 40, 7, "N"); c.px(28, 41, "N"); c.px(36, 41, "N")
  c.hline(26, 32, 3, "N"); c.hline(35, 32, 3, "N")
  c.ellipse(32, 20, 11, 4, "N")
  for (const [x, len, s] of [[22, 20, 0], [25, 10, 1], [40, 18, 2], [43, 24, 3], [33, 6, 4]]) tentacle(c, x, 19, len, [0, 1], s % 2 ? "N" : "S", 1, s)
  c.px(24, 26, "L")
  if (mad) {
    for (const [x, len, d, s] of [[21, 20, [-1, 1], 0], [44, 20, [1, 1], 1], [28, 14, [-1, -1], 2], [37, 14, [1, -1], 3]]) { tentacle(c, x, 20, len, d, "S", 2, s); tentacle(c, x, 20, 5, d, "N", 2, s) }
    madEyes(c, 32, 30, "O", "F")
    c.ellipse(32, 41, 3, 4, "K"); c.ellipse(32, 42, 1, 2, "R")
  }
}

// Глубоководный: чешуйчатая зелёная кожа, щупальца на лице, большие тёмные глаза.
P.deep_one = (c, mad) => {
  const [sd, sm, sl] = mad ? ["N", "V", "U"] : ["N", "G", "L"]
  bust(c, "S")
  c.poly([20, 48, 44, 48, 48, 64, 16, 64], "D")
  c.rect(26, 40, 13, 10, sd)
  c.ellipse(32, 26, 15, 14, sm)
  c.ellipse(32, 34, 13, 10, sm)
  c.recolor({ [sm]: sd }, (x, y) => x > 43 || y > 41)
  c.recolor({ [sm]: sl }, (x, y) => x < 22 && y > 20 && y < 34)
  for (let y = 16; y < 38; y += 3) for (let x = 20 + (y % 2) * 2; x < 45; x += 4) if (c.is(x, y, sm)) { c.px(x, y, sd); c.px(x + 1, y + 1, sd) }
  for (let i = 0; i < 5; i++) c.poly([26 + i * 3, 14 - (i % 2), 28 + i * 3, 8 + (i === 2 ? -2 : 0), 30 + i * 3, 14], sd)
  for (const x of [22, 36]) { c.ellipse(x + 3, 26, 4, 3, "K"); c.px(x + 2, 25, "P") }
  for (const [x, len, s] of [[25, 18, 0], [29, 22, 1], [33, 21, 2], [37, 17, 3], [40, 13, 4]])
    tentacle(c, x, 36, len, [0, 1], sm, 1.5, s)
  for (const [x, len, s] of [[29, 22, 1], [37, 17, 3]]) tentacle(c, x + 1, 37, len - 2, [0, 1], sd, 1.5, s)
  if (mad) {
    for (const [x, y] of [[24, 25], [38, 25], [31, 19], [20, 31], [43, 31], [33, 29]]) { c.rect(x, y, 2, 2, "U"); c.px(x, y, "P") }
    for (const [x, len, d, s] of [[22, 16, [-1, 1], 0], [43, 16, [1, 1], 2]]) tentacle(c, x, 40, len, d, "U", 2, s)
  }
}

// Игрок 1: молодой шулер, тёмная бандана, шрам.
P.player1 = (c, mad) => {
  bust(c, "D")
  c.poly([24, 48, 40, 48, 36, 60, 28, 60], "B")
  c.line(28, 49, 32, 58, "W")
  c.rect(28, 42, 9, 8, "W")
  c.ellipse(32, 24, 11, 9, "D")
  face(c, { cx: 32, cy: 30, skin: ["D", "W", "B"], w: 9, jaw: 43, top: 10, mouth: false })
  c.hline(30, 40, 4, "D"); c.px(34, 39, "D")
  c.ellipse(32, 20, 12, 5, "R")
  c.rect(20, 20, 25, 3, "R")
  c.recolor({ R: "N" }, (x, y) => x > 39 && y < 23)
  c.hline(21, 22, 23, "K")
  c.poly([43, 18, 50, 24, 48, 28, 44, 22], "R")
  c.line(37, 32, 40, 37, "R"); c.px(38, 34, "P")
  if (mad) {
    madEyes(c, 32, 30, "G", "L")
    veins(c, [[24, 33, 26, 37], [26, 37, 24, 40], [41, 30, 40, 34], [28, 23, 29, 26]], "N")
  }
}

// Игрок 2: контрабандистка, платок, каштановые волосы, решительный взгляд.
P.player2 = (c, mad) => {
  bust(c, "N")
  c.poly([22, 48, 42, 48, 38, 58, 26, 58], "W")
  c.rect(29, 42, 7, 8, "B")
  c.ellipse(32, 32, 13, 14, "D")
  c.poly([19, 32, 45, 32, 46, 50, 18, 50], "D")
  c.line(19, 36, 20, 49, "W")
  const skin = mad ? ["S", "B", "P"] : ["W", "B", "P"]
  face(c, { cx: 32, cy: 31, skin, w: 8, jaw: 43, top: 10, mouth: false })
  c.hline(30, 40, 5, "R"); c.px(30, 40, "W")
  c.ellipse(32, 21, 13, 7, "S")
  c.rect(19, 21, 27, 3, "S")
  c.recolor({ S: "N" }, (x, y) => x > 38)
  c.hline(20, 23, 25, "N")
  c.poly([19, 24, 15, 34, 19, 33, 21, 26], "S")
  if (mad) {
    madEyes(c, 32, 31, "V", "U")
    veins(c, [[24, 34, 26, 38], [40, 33, 38, 38], [30, 25, 31, 28]], "V")
  }
}

// Игрок 3: старый морской волк, повязка, седая борода, треуголка.
P.player3 = (c, mad) => {
  bust(c, "N")
  c.poly([22, 48, 42, 48, 40, 64, 24, 64], "S")
  c.rect(28, 42, 9, 6, "W")
  face(c, { cx: 32, cy: 30, skin: ["D", "W", "B"], w: 9, jaw: 43, top: 10, mouth: false })
  c.hline(26, 26, 5, "D"); c.hline(25, 27, 2, "D")
  c.poly([22, 34, 26, 37, 38, 37, 43, 34, 42, 45, 36, 52, 28, 52, 23, 45], "B")
  c.recolor({ B: "W" }, (x, y) => x > 38)
  for (const x of [25, 29, 33, 37]) c.line(x, 40, x, 48, "P")
  c.hline(29, 39, 6, "D")
  c.rect(34, 28, 5, 4, "K"); c.line(22, 23, 40, 31, "K")
  c.poly([12, 21, 52, 21, 46, 12, 32, 16, 18, 12], "N")
  c.ellipse(32, 17, 11, 5, "N")
  c.hline(13, 20, 39, "D"); c.px(12, 21, "F"); c.px(51, 21, "F")
  c.recolor({ N: "K" }, (x, y) => x > 40 && y < 21)
  c.recolor({ N: "S" }, (x, y) => x < 22 && y < 21)
  if (mad) {
    c.rect(26, 29, 5, 3, "G"); c.rect(27, 30, 3, 1, "L")
    for (const [x, y] of [[23, 33], [25, 35], [40, 24], [41, 27], [22, 30]]) { c.px(x, y, "P"); c.px(x + 1, y, "B"); c.px(x, y + 1, "D") }
  }
}

for (const id of Object.keys(P)) {
  sprite(id + "_normal", S64, (c) => { P[id](c, false); outline(c) })
  sprite(id + "_mad", S64, (c) => { P[id](c, true); outline(c) })
}
sheet("all_portraits", ["*"], { cols: 4, pad: 2 })
