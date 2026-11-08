# Иконка игры (М15): костяной кубик с глазом Кракена и щупальцами, 32×32, палитра KrakenPalette.
#   python tools/build_icon.py
# Пишет icon.png (128×128, ×4 nearest — иконка окна и проекта) и icon.ico
# (16, 32, 48, 64, 128, 256 — целые масштабы nearest; для .exe, export_presets.cfg).
# М16: иконки Android в assets/android/ — main 192 (×6), адаптивная: передний план 432
# (кубик ×6 = 192 по центру, влезает в безопасный круг 264) и фон 432 (цвет K).
import os, struct, io
from PIL import Image

PAL = {
    "K": "#0d0b14", "N": "#1e1a2b", "S": "#2f2a3d", "D": "#4a3b2a", "W": "#7a5a36",
    "B": "#c9a66b", "P": "#e8d9b0", "F": "#ffb347", "O": "#ff7b1c", "G": "#3fa66b",
    "L": "#9cff57", "V": "#6b3fa6", "U": "#b57bff", "R": "#8b1e2b",
}

# Кубик (грань «пять»: четыре точки и глаз Кракена в центре).
DIE = [
    "KKKKKKKKKKKKKKKKKK",
    "KPPPPPPPPPPPPPPPBK",
    "KPBBBBBBBBBBBBBBWK",
    "KPBKKBBBBBBBBKKBWK",
    "KPBKKBBBBBBBBKKBWK",
    "KPBBBBBBBBBBBBBBWK",
    "KPBBBKKKKKKKKBBBWK",
    "KPBKKGGGLGGGGKKBWK",
    "KPKGGGGLKLGGGGGKWK",
    "KPKGPGGLKLGGGGGKWK",
    "KPKGGGGLKLGGGGGKWK",
    "KPBKKGGGLGGGGKKBWK",
    "KPBBBKKKKKKKKBBBWK",
    "KPBBBBBBBBBBBBBBWK",
    "KPBKKBBBBBBBBKKBWK",
    "KPBKKBBBBBBBBKKBWK",
    "KPBBBBBBBBBBBBBBWK",
    "KBWWWWWWWWWWWWWWWK",
    "KKKKKKKKKKKKKKKKKK",
]
DIE_X, DIE_Y = 7, 5

# Левое щупальце: центр «трубки» по точкам (x, y, радиус); правое — зеркально.
TENTACLE = [
    (15.5, 28.6, 2.0), (11.0, 28.0, 1.9), (7.0, 26.0, 1.7), (4.6, 22.5, 1.5),
    (3.4, 18.5, 1.3), (3.2, 15.0, 1.1), (4.0, 12.6, 0.9), (5.4, 12.2, 0.7),
    (5.8, 13.8, 0.5),
]
SUCKERS = [(12, 29), (8, 27), (5, 24), (3, 20), (3, 16)]


def _tentacle_mask() -> set:
    pts = set()
    for (x0, y0, r0), (x1, y1, r1) in zip(TENTACLE, TENTACLE[1:]):
        for i in range(21):
            t = i / 20
            cx, cy, r = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t
            for y in range(32):
                for x in range(16):
                    if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                        pts.add((x, y))
    return pts


def _grid() -> list:
    g = [["." for _ in range(32)] for _ in range(32)]
    left = _tentacle_mask()
    body = left | {(31 - x, y) for x, y in left}
    for x, y in body:
        g[y][x] = "V"
    for x, y in SUCKERS:
        for px in (x, 31 - x):
            if g[y][px] == "V":
                g[y][px] = "U"
    for y in range(32):
        for x in range(32):
            if g[y][x] == "." and any(
                    0 <= x + dx < 32 and 0 <= y + dy < 32 and g[y + dy][x + dx] in "VU"
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "K"
    for dy, row in enumerate(DIE):
        for dx, ch in enumerate(row):
            g[DIE_Y + dy][DIE_X + dx] = ch
    return ["".join(r) for r in g]


def render() -> Image.Image:
    art = _grid()
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch != ".":
                c = PAL[ch]
                img.putpixel((x, y), (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255))
    return img


def write_ico(path: str, base: Image.Image, sizes) -> None:
    # ICO с PNG-кадрами (Windows Vista+), каждый — целый масштаб базы (16 — уменьшение ×½).
    frames = []
    for s in sizes:
        im = base.resize((s, s), Image.NEAREST)
        buf = io.BytesIO()
        im.save(buf, "PNG")
        frames.append((s, buf.getvalue()))
    header = struct.pack("<HHH", 0, 1, len(frames))
    offset = 6 + 16 * len(frames)
    entries, data = b"", b""
    for s, png in frames:
        dim = 0 if s >= 256 else s
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset + len(data))
        data += png
    with open(path, "wb") as f:
        f.write(header + entries + data)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    base = render()
    base.resize((128, 128), Image.NEAREST).save(os.path.join(root, "icon.png"))
    write_ico(os.path.join(root, "icon.ico"), base, [16, 32, 48, 64, 128, 256])
    android = os.path.join(root, "assets", "android")
    os.makedirs(android, exist_ok=True)
    base.resize((192, 192), Image.NEAREST).save(os.path.join(android, "icon_192.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(base.resize((192, 192), Image.NEAREST), (120, 120))
    fg.save(os.path.join(android, "icon_foreground_432.png"))
    k = PAL["K"]
    Image.new("RGBA", (432, 432), (int(k[1:3], 16), int(k[3:5], 16), int(k[5:7], 16), 255)).save(
        os.path.join(android, "icon_background_432.png"))
    print("icon.png, icon.ico, assets/android/icon_*.png")
