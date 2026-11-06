// Фоны 640×360 (М14). Только палитра игры.
include("palette.px.js")

const W = 640, H = 360

// --- Детали ------------------------------------------------------------------

// Фонарь: каркас, стекло со светом.
sprite("_lantern", { w: 13, h: 22 }, (c) => {
  c.rect(5, 0, 3, 3, "K"); c.px(6, 1, "N")
  c.poly([2, 6, 11, 6, 9, 3, 4, 3], "K")
  c.rect(1, 6, 11, 2, "D")
  c.rect(2, 8, 9, 10, "F"); c.rect(4, 10, 5, 6, "P"); c.rect(5, 14, 3, 3, "O")
  c.vline(1, 8, 10, "K"); c.vline(11, 8, 10, "K"); c.vline(6, 8, 10, "D")
  c.rect(1, 18, 11, 2, "D"); c.rect(3, 20, 7, 2, "K")
})
sprite("_lantern_green", { base: "_lantern", swap: { F: "G", P: "L", O: "G" } })

// Бутылки на полке.
sprite("_bottle_a", { w: 7, h: 16 }, (c) => { c.rect(3, 0, 1, 2, "D"); c.rect(2, 2, 3, 5, "G"); c.rect(1, 7, 5, 9, "G"); c.vline(2, 8, 6, "L"); c.vline(5, 7, 9, "N") })
sprite("_bottle_b", { w: 6, h: 13 }, (c) => { c.rect(2, 0, 2, 3, "D"); c.rect(1, 3, 4, 10, "W"); c.rect(1, 6, 4, 3, "B"); c.vline(1, 3, 10, "F"); c.vline(4, 3, 10, "D") })
sprite("_bottle_c", { w: 8, h: 11 }, (c) => { c.rect(3, 0, 2, 2, "K"); c.ellipse(3.5, 6, 3, 4, "V"); c.px(2, 4, "U"); c.px(2, 5, "U"); c.rect(5, 5, 2, 4, "N") })
sprite("_bottle_d", { w: 6, h: 14 }, (c) => { c.rect(2, 0, 2, 4, "S"); c.rect(1, 4, 4, 10, "R"); c.vline(1, 5, 8, "O"); c.vline(4, 4, 10, "K") })

// Свеча.
sprite("_candle", ".F.\n.P.\nBBB\nBPB\nBBB\nWWW")

// Силуэт посетителя в капюшоне (сидит): тёмный, с контровым светом слева.
sprite("_patron", { w: 30, h: 50 }, (c) => {
  c.ellipse(15, 11, 8, 10, "K")
  c.poly([2, 50, 6, 20, 24, 20, 28, 50], "K")
  c.ellipse(15, 13, 4, 6, "N")
  c.px(13, 13, "F"); c.px(17, 13, "F")
  c.line(7, 4, 3, 22, "S"); c.line(3, 22, 1, 50, "S")
})
sprite("_patron_hat", { w: 34, h: 50 }, (c) => {
  c.ellipse(17, 14, 7, 8, "K")
  c.rect(4, 6, 26, 3, "K"); c.rect(10, 0, 14, 7, "K"); c.hline(4, 6, 26, "S")
  c.poly([3, 50, 7, 21, 27, 21, 31, 50], "K")
  c.line(7, 21, 3, 50, "S")
  c.rect(26, 30, 5, 7, "B"); c.hline(26, 30, 5, "P")   // кружка
})

// Знак Кракена: круг, глаз, щупальца.
sprite("_sigil", { w: 31, h: 31 }, (c) => {
  c.ring(15, 15, 14, "G")
  c.ring(15, 15, 11, "G")
  c.ellipse(15, 12, 5, 4, "G"); c.ellipse(15, 12, 3, 2, "N"); c.px(15, 12, "L")
  for (const x of [8, 12, 15, 18, 22]) c.line(15, 16, x, 24 + (x % 3), "G")
})

// Фоновая стена: доски, балки, стропила. y0..y1.
function plankWall(c, y0, y1) {
  c.rect(0, y0, W, y1 - y0, "N")
  for (let x = 0; x < W; x += 16) {
    c.vline(x, y0, y1 - y0, "K")
    // стыки досок вразбежку
    const j = y0 + 30 + ((x * 7) % 50)
    c.hline(x + 1, j, 15, "K")
  }
  c.rect(0, y0, W, 10, "D"); c.hline(0, y0 + 10, W, "K"); c.hline(0, y0 + 9, W, "W")
}

function pillar(c, x, y0, y1) {
  c.rect(x, y0, 14, y1 - y0, "D")
  c.vline(x + 1, y0, y1 - y0, "W")
  c.vline(x + 12, y0, y1 - y0, "K")
  // подкос
  c.line(x + 14, y0 + 14, x + 34, y0 + 2, "D", 3)
  c.line(x, y0 + 14, x - 20, y0 + 2, "D", 3)
}

function fireplace(c, cx, y0, y1) {
  const w = 120
  c.rect(cx - w / 2, y0, w, y1 - y0, "S")
  for (let y = y0 + 6, r = 0; y < y1; y += 7, r++) {
    c.hline(cx - w / 2, y, w, "N")
    for (let x = cx - w / 2 + (r % 2) * 9; x < cx + w / 2; x += 18) c.vline(x, y - 6, 6, "N")
  }
  c.rect(cx - w / 2 - 6, y0 - 6, w + 12, 7, "D"); c.hline(cx - w / 2 - 6, y0 - 6, w + 12, "W")
  // проём
  c.rect(cx - 34, y0 + 40, 68, y1 - y0 - 40, "K")
  c.ellipse(cx, y0 + 40, 34, 22, "K")
  // огонь
  c.poly([cx - 26, y1, cx - 20, y1 - 22, cx - 12, y1 - 14, cx - 4, y1 - 38, cx + 6, y1 - 18, cx + 14, y1 - 30, cx + 26, y1], "O")
  c.poly([cx - 18, y1, cx - 10, y1 - 10, cx - 3, y1 - 26, cx + 6, y1 - 8, cx + 13, y1 - 18, cx + 18, y1], "F")
  c.poly([cx - 8, y1, cx - 3, y1 - 12, cx + 4, y1, ], "P")
  c.rect(cx - 30, y1 - 4, 60, 4, "D"); c.hline(cx - 30, y1 - 4, 60, "R")
}

// Стол: доски от линии y0 вниз, перспектива к центру.
function table(c, y0, lit = true) {
  c.rect(0, y0, W, H - y0, "D")
  c.hline(0, y0, W, "W"); c.hline(0, y0 + 1, W, "B")
  // продольные стыки досок (горизонтальные в кадре), расстояние растёт к зрителю
  let y = y0 + 2, step = 12
  while (y < H) {
    c.hline(0, y + step, W, "K")
    c.hline(0, y + step + 1, W, "W")
    // торцы досок вразбежку
    for (let x = ((y * 13) % 140); x < W; x += 170 + (y % 40)) c.vline(x, y + 1, step, "K")
    y += step + 2; step += 6
  }
  // волокна и сучки там, где дерево: короткие тёмные штрихи по доскам
  for (let i = 0; i < 70; i++) {
    const x = (i * 97) % W, yy = y0 + 6 + ((i * 53) % (H - y0 - 8))
    if (c.is(x, yy, "D")) c.hline(x, yy, 6 + (i % 9), "N")
  }
  // тёплое пятно света в центре
  if (!lit) return
  const pool = (rx, ry) => (x, yy) => yy > y0 + 2 && ((x - W / 2) / rx) ** 2 + ((yy - y0 - 40) / ry) ** 2 < 1
  c.light(pool(300, 120), 1, 0.5)
  c.light(pool(220, 84), 1, 0.5)
  c.light(pool(130, 46), 1, 0.25)
  // тень у краёв
  c.shade((x, yy) => yy > y0 + 2 && (x < 60 || x > W - 60), 1, 0.5)
}

// --- Таверна: стол ------------------------------------------------------------

scene("tavern_table", { w: W, h: H, bg: "K" },
  (c) => {
    plankWall(c, 0, 200)
    // пол за столом
    c.rect(0, 186, W, 20, "D"); for (let x = 0; x < W; x += 22) c.line(x, 186, x - 40 + (x / W) * 80, 206, "K")
    c.hline(0, 186, W, "K")
    fireplace(c, W / 2, 70, 186)
    pillar(c, 140, 10, 200); pillar(c, 486, 10, 200)
    // полки с бутылками справа
    for (const y of [70, 104, 138]) { c.rect(520, y, 110, 4, "D"); c.hline(520, y, 110, "W"); c.hline(520, y + 4, 110, "K") }
  },
  layer("props",
    stamp("_sigil", 305, 26),
    (c) => { const b = ["_bottle_a", "_bottle_b", "_bottle_c", "_bottle_d"]
             for (const [y, n] of [[70, 0], [104, 1], [138, 2]]) for (let i = 0, x = 524; x < 620; i++) {
               const k = b[(i * 3 + n) % 4], h = { _bottle_a: 16, _bottle_b: 13, _bottle_c: 11, _bottle_d: 14 }[k]
               c.stamp(k, x, y - h); x += 9 + ((i + n) % 3) * 3 } },
    stamp("_candle", 270, 56), stamp("_candle", 366, 56),
    stamp("_patron", 24, 138), stamp("_patron_hat", 60, 136), stamp("_patron", 100, 140, { flip: "x" }),
    stamp("_patron", 414, 138), stamp("_patron_hat", 446, 137, { flip: "x" }),
    // столы посетителей
    (c) => { c.rect(22, 176, 110, 4, "W"); c.rect(22, 180, 110, 3, "D"); c.rect(412, 176, 70, 4, "W"); c.rect(412, 180, 70, 3, "D")
             c.vline(30, 183, 10, "D"); c.vline(124, 183, 10, "D"); c.vline(420, 183, 10, "D"); c.vline(474, 183, 10, "D") },
  ),
  layer("lanterns",
    (c) => { for (const x of [70, 220, 420, 590]) c.vline(x + 4, 10, x === 220 || x === 590 ? 26 : 40, "K") },
    stamp("_lantern", 68, 50), stamp("_lantern_green", 218, 36), stamp("_lantern", 418, 50), stamp("_lantern", 588, 36),
  ),
  glow("PF", { r: 40, ramp: 2 }),
  glow("L", { r: 26, ramp: 1 }),
  (c) => table(c, 214),
)

// --- Главное меню: таверна на берегу ночью ------------------------------------

// Кубик-кость (для победы и поражения).
sprite("_die", { w: 15, h: 15 }, (c) => {
  c.rect(1, 1, 13, 13, "B"); c.hline(1, 1, 13, "P"); c.vline(1, 1, 13, "P"); c.hline(1, 13, 13, "W"); c.vline(13, 1, 13, "W")
  c.box(0, 0, 15, 15, "K")
  for (const [x, y] of [[3, 3], [6, 6], [9, 9]]) c.rect(x, y, 2, 2, "K")
})
sprite("_die_b", { base: "_die" }, (c) => { c.rect(6, 6, 2, 2, "B"); c.rect(3, 9, 2, 2, "K"); c.rect(9, 3, 2, 2, "K"); c.rect(9, 9, 2, 2, "B") })
sprite("_coin", { w: 9, h: 5 }, (c) => { c.ellipse(4, 2, 4, 2, "O"); c.ellipse(4, 1.5, 3, 1, "F"); c.px(3, 1, "P"); c.hline(1, 4, 7, "R") })

function waves(c, y0, cols) {
  for (let y = y0, i = 0; y < H; y += 5 + i, i++) {
    for (let x = (i * 17) % 23; x < W; x += 23 + (i % 3) * 4) c.hline(x, y, 6 + (i % 4) * 2, cols[i % cols.length])
  }
}

scene("main_menu", { w: W, h: H, bg: "K" },
  (c) => {
    c.grad(0, 0, W, 250, "KNS", "v", 0.6)
    // штормовые облака: полосы с рваным краем
    // луна
    c.circ(200, 60, 18, "B"); c.circ(205, 56, 16, "P"); c.circ(196, 64, 3, "B"); c.circ(210, 50, 2, "B")
    // облака: цепочки эллипсов, светлая кромка сверху
    for (const [y, x0, len, col, rim] of [[34, -20, 280, "N", "S"], [70, 120, 200, "S", "S"], [96, 360, 300, "N", "S"], [24, 380, 280, "N", "S"], [120, -30, 180, "N", "S"]]) {
      for (let x = x0, i = 0; x < x0 + len; x += 22, i++) c.ellipse(x, y - (i % 3) * 3, 18 + (i % 2) * 6, 8 + (i % 3) * 2, col)
      for (let x = x0, i = 0; x < x0 + len; x += 22, i++) c.hline(x - 8, y - (i % 3) * 3 - 8 - (i % 3) * 2, 12, rim)
      c.rect(x0 - 10, y, len + 20, 6, col)
    }
    // море
    c.rect(0, 250, W, H - 250, "N")
    waves(c, 254, ["S", "K", "S", "N"])
    // лунная дорожка
    for (let y = 256; y < H; y += 5) c.hline(186 + ((y * 7) % 24) - ((y - 256) >> 3), y, 10 + ((y - 256) >> 3), "B")
    // утёс
    c.poly([300, 360, 330, 250, 380, 232, 640, 226, 640, 360], "K")
    c.poly([330, 250, 380, 232, 420, 236, 360, 262], "N")
  },
  // щупальца в тумане слева
  (c) => {
    const tent = (x0, y0, h, amp, ph, col, w0) => {
      for (let i = 0; i < h; i++) {
        const t = i / h, x = x0 + Math.sin(t * 5 + ph) * amp * t + t * t * amp * 1.5
        c.line(Math.round(x), y0 - i, Math.round(x) + Math.max(1, Math.round(w0 * (1 - t))), y0 - i, col)
      }
    }
    tent(40, 300, 200, 24, 0, "K", 22); tent(110, 296, 150, 18, 2, "K", 16); tent(262, 300, 90, 12, 4, "K", 10)
    for (let i = 0; i < 9; i++) c.rect(48 + i * 2 + Math.round(Math.sin(i) * 4), 280 - i * 18, 2, 2, "V")
  },
  // туман
  layer("fog", { light: true, density: 0.25 }, rect(0, 220, 300, 40, "K"), rect(0, 160, 200, 30, "K")),
  // таверна
  (c) => {
    // кривой дом
    c.poly([400, 232, 410, 120, 560, 112, 580, 226], "D")
    c.poly([392, 124, 482, 60, 572, 116], "K")         // крыша
    c.line(392, 124, 482, 60, "S", 2); c.line(482, 60, 572, 116, "N", 2)
    for (let x = 410; x < 560; x += 12) c.line(x, 120 - Math.max(0, 50 - Math.abs(x - 482) * 0.7), x, 118, "N")
    for (let y = 130; y < 228; y += 8) c.hline(404, y, 172, "K")   // доски обшивки
    c.recolor({ D: "N" }, (x, y) => x > 540)
    // труба с дымом
    c.rect(530, 70, 14, 34, "S"); c.rect(528, 66, 18, 5, "N")
    // окна
    for (const [x, y] of [[424, 148], [500, 146], [424, 186], [500, 184]]) {
      c.rect(x, y, 22, 18, "F"); c.rect(x + 3, y + 3, 7, 5, "P"); c.vline(x + 11, y, 18, "D"); c.hline(x, y + 9, 22, "D"); c.box(x - 1, y - 1, 24, 20, "K")
    }
    // дверь
    c.rect(464, 190, 22, 38, "K"); c.rect(466, 192, 18, 36, "W"); c.vline(475, 192, 36, "D"); c.px(481, 210, "F")
    // вывеска с Кракеном
    c.line(450, 128, 450, 108, "K"); c.rect(380, 104, 74, 4, "D")
    c.vline(390, 108, 6, "K"); c.vline(440, 108, 6, "K")
    c.rect(384, 114, 62, 24, "W"); c.box(384, 114, 62, 24, "K"); c.hline(385, 115, 60, "B")
    c.ellipse(415, 122, 6, 5, "G"); c.px(413, 121, "K"); c.px(417, 121, "K")
    for (const x of [404, 409, 414, 419, 424]) c.line(415, 126, x, 134 + (x % 2), "G")
    // свет из окон на воду и землю
    c.light([400, 228, 180, 12], 1, 0.5)
  },
  glow("FP", { r: 26, ramp: 1 }),
  glow("G", { r: 12, ramp: 1 }),
)

// --- Поражение: глаз Кракена в глубине ----------------------------------------

scene("defeat", { w: W, h: H, bg: "K" },
  (c) => {
    c.grad(0, 0, W, H, "SNK", "v", 0.7)
  },
  layer("rays", { light: true, density: 0.25 }, (c) => { for (const x of [40, 520]) c.poly([x, 0, x + 26, 0, x + 70, 200, x + 50, 200], "K") }),
  (c) => {
    // веки и глаз
    const cx = 320, cy = 58
    c.ellipse(cx, cy, 150, 52, "N")
    c.ellipse(cx, cy, 130, 40, "K")
    c.ellipse(cx, cy, 120, 34, "R")
    c.ellipse(cx, cy, 44, 34, "O"); c.ellipse(cx, cy, 36, 30, "F")
    c.recolor({ F: "O" }, (x, y) => (x - cx) ** 2 / 36 ** 2 + (y - cy) ** 2 / 30 ** 2 > 0.6)
    c.ellipse(cx, cy, 7, 28, "K")
    c.rect(cx - 16, cy - 16, 5, 4, "P")
    // сосуды
    for (const [x0, y0, x1, y1] of [[200, 212, 240, 206], [240, 206, 270, 214], [210, 232, 250, 236], [440, 210, 400, 204], [400, 204, 372, 214], [430, 234, 392, 232]]) c.line(x0, y0 - 162, x1, y1 - 162, "K")
    // щупальца по краям
    for (const [x0, dir] of [[0, 1], [W, -1]]) for (let k = 0; k < 3; k++) {
      for (let i = 0; i < 140; i++) {
        const t = i / 140, y = 360 - i * 2.2 + k * 20, x = x0 + dir * (20 + k * 30 + Math.sin(t * 6 + k) * 14 + t * 40)
        c.rect(Math.round(x), Math.round(y), Math.max(1, Math.round(10 * (1 - t))), 3, k === 1 ? "S" : "N")
      }
    }
  },
  // тонущие кубики и пузыри
  stamp("_die", 120, 150), stamp("_die_b", 500, 130), stamp("_die", 300, 268), stamp("_die_b", 410, 300), stamp("_die", 200, 320),
  (c) => { for (let i = 0; i < 28; i++) { const x = (i * 131) % W, y = (i * 71) % H; if (!c.is(x, y, "ROF")) c.ring(x, y, i % 3 === 0 ? 2 : 1, "S") } },
  glow("F", { r: 40, ramp: 1 }),
)

// --- Победа: золото и кости на столе -------------------------------------------

scene("victory", { w: W, h: H, bg: "K" },
  (c) => {
    plankWall(c, 0, 170)
    table(c, 170, false)
    c.light((x, y) => y > 172 && ((x - 320) / 260) ** 2 + ((y - 280) / 90) ** 2 < 1, 1, 0.5)
    // кучи монет
    const pile = (cx, cy, r) => {
      c.ellipse(cx + 4, cy + 4, r + 4, 4, "N")                     // тень
      clipHalf(c, cx + 4, cy + 3, r + 2, r * 0.75)
      for (let y = 0; y < r * 0.75; y += 3) { const hw = Math.sqrt(1 - (y / (r * 0.75)) ** 2) * r
        for (let x = -hw; x <= hw - 6; x += 7) c.stamp("_coin", Math.round(cx + x + (y % 2) * 3), Math.round(cy - y)) } }
    function clipHalf(c, cx, cy, rx, ry) { for (let y = 0; y <= ry; y++) { const w = Math.round(Math.sqrt(1 - (y / ry) ** 2) * rx); c.hline(cx - w, Math.round(cy - y), w * 2, "O") } }
    pile(300, 270, 40); pile(380, 284, 26); pile(240, 290, 18)
    for (const [x, y] of [[180, 300], [440, 310], [470, 280], [150, 270], [350, 320]]) c.stamp("_coin", x, y)
    // кубики
    c.stamp("_die", 420, 250); c.stamp("_die_b", 210, 250); c.stamp("_die", 330, 300)
    // свечи
    for (const x of [90, 540]) {
      c.rect(x, 190, 12, 50, "B"); c.vline(x, 190, 50, "P"); c.vline(x + 11, 190, 50, "W")
      c.rect(x - 4, 238, 20, 4, "D"); c.vline(x + 6, 184, 6, "K")
      c.poly([x + 3, 186, x + 6, 168, x + 9, 186], "F"); c.rect(x + 5, 178, 2, 7, "P")
    }
    // кружка
    c.ring(508, 232, 7, "K"); c.ring(508, 232, 6, "D")
    c.rect(479, 213, 28, 36, "K"); c.rect(480, 218, 26, 30, "D"); c.rect(480, 214, 26, 5, "P"); c.vline(482, 220, 27, "W"); c.hline(480, 226, 26, "K"); c.hline(480, 240, 26, "K")
    // знак на стене и фонарь
    c.stamp("_sigil", 305, 40); c.vline(326 + 120, 10, 40, "K"); c.stamp("_lantern", 442, 50); c.vline(194, 10, 40, "K"); c.stamp("_lantern", 190, 50)
  },
  // свет свечей на стене — только по стене, монеты не трогаем
  layer("candlelight", { light: true, density: 0.25 }, ellipse(96, 172, 70, 60, "K"), ellipse(546, 172, 70, 60, "K")),
  layer("candlelight2", { light: true, density: 0.5 }, ellipse(96, 176, 34, 30, "K"), ellipse(546, 176, 34, 30, "K")),
)
