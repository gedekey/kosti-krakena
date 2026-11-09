# Иконки рангов: вырезает 6 значков с белого фона картинки автора.
#   python tools/cut_rank_icons.py <картинка.jpg>
# Порядок на картинке: верхний ряд — Дерево, Бронза, Серебро, Золото; нижний — Рубин, Философский камень.
# Пишет art/ranks/<rank>.png (полный размер, прозрачный фон — исходник)
# и ui/sprites/ranks/<rank>_64.png, <rank>_32.png (для игры: жёсткая альфа, без полупрозрачных краёв).
import os, sys
from collections import deque
import numpy as np
from PIL import Image

RANKS = ["wood", "bronze", "silver", "gold", "ruby", "philosopher"]
WHITE_MIN = 215      # фон: все каналы светлее этого...
WHITE_SPREAD = 30    # ...и почти без цвета (JPEG-шум)
PAD = 4
SIZES = (64, 32)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def is_white(px):
    return (px.min(axis=-1) > WHITE_MIN) & ((px.max(axis=-1) - px.min(axis=-1)) < WHITE_SPREAD)


def blobs(rgb):
    """Боксы связных областей не-фона, крупнейшие 6."""
    fg = ~is_white(rgb)
    h, w = fg.shape
    seen = np.zeros_like(fg)
    out = []
    for y in range(h):
        for x in range(w):
            if fg[y, x] and not seen[y, x]:
                q = deque([(y, x)]); seen[y, x] = True
                x0 = x1 = x; y0 = y1 = y; cnt = 0
                while q:
                    cy, cx = q.popleft(); cnt += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True; q.append((ny, nx))
                out.append((cnt, x0, y0, x1, y1))
    out.sort(reverse=True)
    boxes = [b[1:] for b in out[:6]]
    # сортировка: по строкам (верх/низ), внутри — слева направо
    mid = rgb.shape[0] // 2
    return sorted(boxes, key=lambda b: (b[1] > mid, b[0]))


def cut(rgb, box):
    x0, y0, x1, y1 = box
    h, w, _ = rgb.shape
    x0, y0 = max(0, x0 - PAD), max(0, y0 - PAD)
    x1, y1 = min(w - 1, x1 + PAD), min(h - 1, y1 + PAD)
    crop = rgb[y0:y1 + 1, x0:x1 + 1]
    white = is_white(crop)
    ch, cw = white.shape
    bg = np.zeros_like(white)
    q = deque()
    for y in range(ch):
        for x in (0, cw - 1):
            if white[y, x] and not bg[y, x]: bg[y, x] = True; q.append((y, x))
    for x in range(cw):
        for y in (0, ch - 1):
            if white[y, x] and not bg[y, x]: bg[y, x] = True; q.append((y, x))
    while q:  # фон — только белое, связанное с краем (блики внутри значка остаются)
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < ch and 0 <= nx < cw and white[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    lum = crop.mean(axis=-1)
    bg |= enclosed_holes(crop, white & ~bg, lum)
    # светлая JPEG-кайма у фона: снимаем один слой светлых пикселей по краю
    near = np.zeros_like(bg)
    near[1:] |= bg[:-1]; near[:-1] |= bg[1:]; near[:, 1:] |= bg[:, :-1]; near[:, :-1] |= bg[:, 1:]
    bg |= near & (lum > 170)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([crop.astype(np.uint8), alpha]), "RGBA")
    return img.crop(img.getbbox())


HOLE_MIN_MEAN = 238   # дыра фона внутри значка: почти чистый белый...
HOLE_RING_MAX = 90    # ...окружённый тёмным контуром (блики окружены светлым — остаются)
HOLE_MIN_SIZE = 2


def enclosed_holes(crop, white, lum):
    """Белые пятна фона, запертые внутри значка (между щупальцами, в водорослях)."""
    h, w = white.shape
    seen = np.zeros_like(white)
    holes = np.zeros_like(white)
    for y in range(h):
        for x in range(w):
            if not white[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)]); seen[y, x] = True; pts = []
            while q:
                cy, cx = q.popleft(); pts.append((cy, cx))
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
            if len(pts) < HOLE_MIN_SIZE:
                continue
            ys, xs = zip(*pts)
            mask = np.zeros_like(white); mask[ys, xs] = True
            ring = mask.copy()
            for _ in range(2):
                grown = ring.copy()
                grown[1:] |= ring[:-1]; grown[:-1] |= ring[1:]; grown[:, 1:] |= ring[:, :-1]; grown[:, :-1] |= ring[:, 1:]
                ring = grown
            ring &= ~mask & ~white
            if crop[ys, xs].mean() >= HOLE_MIN_MEAN and ring.any() and lum[ring].mean() < HOLE_RING_MAX:
                holes |= mask
    return holes


def square(img):
    s = max(img.size)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(img, ((s - img.width) // 2, (s - img.height) // 2))
    return out


def shrink(img, size):
    """Уменьшение с усреднением по премультиплицированным цветам и жёсткой альфой."""
    a = np.asarray(img).astype(float)
    pre = a.copy(); pre[..., :3] *= a[..., 3:4] / 255.0
    small = np.asarray(Image.fromarray(pre.astype(np.uint8), "RGBA").resize((size, size), Image.BOX)).astype(float)
    alpha = small[..., 3]
    rgb = np.where(alpha[..., None] > 0, small[..., :3] * 255.0 / np.maximum(alpha[..., None], 1), 0)
    hard = np.where(alpha >= 128, 255, 0)
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), hard]).astype(np.uint8), "RGBA")


def main(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    src_dir = os.path.join(ROOT, "art", "ranks")
    out_dir = os.path.join(ROOT, "ui", "sprites", "ranks")
    os.makedirs(src_dir, exist_ok=True); os.makedirs(out_dir, exist_ok=True)
    for rank, box in zip(RANKS, blobs(rgb)):
        icon = square(cut(rgb, box))
        icon.save(os.path.join(src_dir, rank + ".png"))
        for s in SIZES:
            shrink(icon, s).save(os.path.join(out_dir, "%s_%d.png" % (rank, s)))
        print(rank, box, icon.size)


if __name__ == "__main__":
    main(sys.argv[1])
