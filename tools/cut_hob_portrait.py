"""Портрет Старого Хоба (М25) из картинки автора «новые портреты/bartender.webp».

    python tools/cut_hob_portrait.py [--preview C:/tmp/hob.png]

Белый фон вырезается заливкой от краёв (белое внутри фигуры — глаза, рубаха — остаётся),
кадр «по плечи» — квадрат, даунскейл усреднением до 64×64, затем каждый пиксель → ближайший
цвет палитры игры (как GeneratedArt.prepare), полупрозрачность → да/нет по порогу.
Результат: assets/generated/portraits/hob_normal.png (его берёт HobPortrait).
"""

import argparse
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "новые портреты" / "bartender.webp"
OUT = ROOT / "assets" / "generated" / "portraits" / "hob_normal.png"

SIZE = 64
# Кадр «по плечи» в координатах исходника (1213×1296): голова сверху, плечи у нижнего края.
CROP = (190, 30, 1090, 930)
# Насколько светлым должен быть пиксель фона (все каналы выше порога).
WHITE_MIN = 200
ALPHA_THRESHOLD = 128

PALETTE = [
    0x0D0B14, 0x1E1A2B, 0x2F2A3D, 0x4A3B2A, 0x7A5A36, 0xC9A66B, 0xE8D9B0,
    0xFFB347, 0xFF7B1C, 0x3FA66B, 0x9CFF57, 0x6B3FA6, 0xB57BFF, 0x8B1E2B,
]
RGB = [((c >> 16) & 255, (c >> 8) & 255, c & 255) for c in PALETTE]


def remove_background(img: Image.Image) -> Image.Image:
    """Белый фон, связанный с краем картинки, → прозрачность."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        queue.extend([(0, y), (w - 1, y)])
    while queue:
        x, y = queue.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, _ = px[x, y]
        if min(r, g, b) < WHITE_MIN:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                queue.append((nx, ny))
    return img


# У Хоба только землистые цвета: без насыщенных цветов палитры ореол фона не уходит
# в фиолетовый. Водоросли в бороде и белёсые глаза при усреднении тонут в буром,
# поэтому их ищем по исходным пикселям и красим по доле в клетке 64×64.
EARTH = [RGB[i] for i in range(7)]          # K N S D W B P
SEAWEED = RGB[9]                             # G
EYE = RGB[6]                                 # P
SEAWEED_SHARE = 0.55
EYE_SHARE = 0.08
# Глаза ищем только в полосе лица (координаты исходника).
EYE_BOX = (540, 290, 800, 350)


def is_seaweed(r, g, b) -> bool:
    return r > 60 and g >= r * 0.85 and b <= r * 0.66


def is_eye(x, y, r, g, b) -> bool:
    x0, y0, x1, y1 = EYE_BOX
    return x0 <= x < x1 and y0 <= y < y1 and r + g + b > 400


def nearest(rgb):
    return min(EARTH, key=lambda p: sum((a - b) ** 2 for a, b in zip(rgb, p)))


def share_mask(img: Image.Image, test) -> Image.Image:
    """Доля пикселей, прошедших test, в каждой клетке итогового размера (0..255)."""
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    src = img.load()
    m = mask.load()
    ox, oy = CROP[0], CROP[1]
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a and test(x + ox, y + oy, r, g, b):
                m[x, y] = 255
    return mask.resize((SIZE, SIZE), Image.Resampling.BOX)


# Кайма волос: по краю силуэта остаются светлые пиксели (полутона между тёмными прядями и
# белым фоном) — волосы будто светятся. Светлое у края в зоне головы (выше плеч)
# перекрашиваем в тёмный цвет волос: соседний тёмный пиксель, иначе HAIR.
FRINGE_COLORS = {RGB[4], RGB[5], RGB[6]}     # W B P
HAIR = RGB[1]                                # N
DARK = {RGB[0], RGB[1], RGB[2], RGB[3]}      # K N S D
FRINGE_DEPTH = 3
# Ниже этой строки — плечи и светлая рубаха, их не трогаем.
HAIR_ROWS = 44


def darken_hair_fringe(img: Image.Image) -> None:
    px = img.load()

    def transparent(x, y):
        return not (0 <= x < SIZE and 0 <= y < SIZE) or px[x, y][3] == 0

    changes = {}
    for y in range(HAIR_ROWS):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a == 0 or (r, g, b) not in FRINGE_COLORS:
                continue
            near = [(x + dx, y + dy) for dy in range(-FRINGE_DEPTH, FRINGE_DEPTH + 1)
                    for dx in range(-FRINGE_DEPTH, FRINGE_DEPTH + 1)]
            if not any(transparent(nx, ny) and not (0 > nx or nx >= SIZE) for nx, ny in near):
                continue
            dark = [px[nx, ny][:3] for nx, ny in near
                    if not transparent(nx, ny) and px[nx, ny][:3] in DARK]
            changes[(x, y)] = max(set(dark), key=dark.count) if dark else HAIR
    for (x, y), c in changes.items():
        px[x, y] = c + (255,)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="сохранить ещё и увеличенную ×6 копию")
    args = parser.parse_args()
    img = remove_background(Image.open(SRC)).crop(CROP)
    small = img.resize((SIZE, SIZE), Image.Resampling.BOX)
    weed = share_mask(img, lambda x, y, r, g, b: is_seaweed(r, g, b))
    eyes = share_mask(img, is_eye)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = small.getpixel((x, y))
            if a < ALPHA_THRESHOLD:
                continue
            if eyes.getpixel((x, y)) >= EYE_SHARE * 255:
                color = EYE
            elif weed.getpixel((x, y)) >= SEAWEED_SHARE * 255:
                color = SEAWEED
            else:
                color = nearest((r, g, b))
            out.putpixel((x, y), color + (255,))
    darken_hair_fringe(out)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"Hob: {OUT}")
    if args.preview:
        out.resize((SIZE * 6, SIZE * 6), Image.Resampling.NEAREST).save(args.preview)


if __name__ == "__main__":
    main()
