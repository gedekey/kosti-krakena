"""Арт кампании (М25) из картинок автора «новые фоны/кампания/*.jpg».

    python tools/import_campaign_art.py [--preview C:/tmp/preview_dir]

Каждая картинка: даунскейл усреднением до размера, который ждёт игра (CampaignArt), затем
каждый пиксель → ближайший цвет палитры игры (как GeneratedArt.prepare). У стойки белый
фон над столешницей вырезается заливкой от краёв (там поверх рисуется Хоб).
Результат кладётся в assets/generated/campaign/ под старыми именами — код не меняется.
"""

import argparse
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "новые фоны" / "кампания"
OUT_DIR = ROOT / "assets" / "generated" / "campaign"

# исходник → (имя в CampaignArt, размер)
JOBS = {
    "storm.jpg": ("slide_storm", (640, 260)),
    "rocks.jpg": ("slide_rocks", (640, 260)),
    "shore.jpg": ("slide_shore", (640, 260)),
    "door.jpg": ("slide_door", (640, 260)),
    "bar.jpg": ("slide_bar", (640, 260)),
    "counter.jpg": ("slide_counter", (640, 106)),
    "map.jpg": ("campaign_map", (400, 282)),
}
# У этих картинок фон белый и должен стать прозрачным.
CUT_WHITE = {"counter.jpg"}
WHITE_MIN = 215
# Цвета палитры, которых нет в исходнике, в итог не пускаем: в палитре нет светлых серых,
# и серо-голубая пена прибоя иначе становится ярко-фиолетовой или зелёной.
PURPLES = {0x6B3FA6, 0xB57BFF}
GREENS = {0x3FA66B, 0x9CFF57}
EXCLUDE = {
    "shore.jpg": PURPLES | GREENS,
    "storm.jpg": PURPLES,
    "rocks.jpg": PURPLES,
    "door.jpg": PURPLES,
    "counter.jpg": PURPLES,
}
ALPHA_THRESHOLD = 128

PALETTE = [
    0x0D0B14, 0x1E1A2B, 0x2F2A3D, 0x4A3B2A, 0x7A5A36, 0xC9A66B, 0xE8D9B0,
    0xFFB347, 0xFF7B1C, 0x3FA66B, 0x9CFF57, 0x6B3FA6, 0xB57BFF, 0x8B1E2B,
]


def to_rgb(colors):
    return [((c >> 16) & 255, (c >> 8) & 255, c & 255) for c in colors]


RGB = to_rgb(PALETTE)


def remove_white(img: Image.Image) -> Image.Image:
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


_cache: dict = {}


def nearest(rgb, colors):
    key = (rgb, tuple(colors))
    if key not in _cache:
        _cache[key] = min(colors, key=lambda p: sum((a - b) ** 2 for a, b in zip(rgb, p)))
    return _cache[key]


def convert(src: Path, size, cut_white: bool, colors) -> Image.Image:
    img = Image.open(src)
    img = remove_white(img) if cut_white else img.convert("RGBA")
    small = img.resize(size, Image.Resampling.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    for y in range(size[1]):
        for x in range(size[0]):
            r, g, b, a = small.getpixel((x, y))
            if a < ALPHA_THRESHOLD:
                continue
            out.putpixel((x, y), nearest((r, g, b), colors) + (255,))
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="папка для увеличенных ×2 копий")
    args = parser.parse_args()
    for src_name, (name, size) in JOBS.items():
        colors = to_rgb([c for c in PALETTE if c not in EXCLUDE.get(src_name, set())])
        out = convert(SRC_DIR / src_name, size, src_name in CUT_WHITE, colors)
        dest = OUT_DIR / f"{name}.png"
        out.save(dest)
        print(f"{src_name} -> {dest.relative_to(ROOT)} {size}")
        if args.preview:
            prev = Path(args.preview)
            prev.mkdir(parents=True, exist_ok=True)
            bg = Image.new("RGBA", size, (255, 0, 255, 255))
            bg.alpha_composite(out)
            bg.resize((size[0] * 2, size[1] * 2), Image.Resampling.NEAREST).save(prev / f"{name}.png")


if __name__ == "__main__":
    main()
