"""Draws the adaptive launcher icon's foreground: frog, cat and ghost (happy) from assets/pets.json,
centred in the 66 dp safe zone of a 108 dp layer, on transparency. The peach-to-pink background
and the monochrome (themed icon) layer are XML drawables next to it.

Usage (from android/): python3 tools/make_launcher_icon.py
"""
import json
import struct
import zlib
from pathlib import Path

ANDROID = Path(__file__).resolve().parent.parent
PETS = json.loads((ANDROID / "app/src/main/assets/pets.json").read_text())

COMMON = {"K": (20, 20, 31), "E": (20, 20, 31), "W": (255, 255, 255), "P": (255, 140, 166), "R": (242, 89, 107)}
PALETTES = {
    "frog": {"B": (115, 209, 107), "D": (71, 148, 69), "L": (204, 242, 153)},
    "cat": {"B": (255, 184, 107), "D": (217, 128, 64), "L": (255, 237, 209)},
    "ghost": {"B": (240, 237, 255), "D": (184, 179, 224), "L": (255, 255, 255)},
}
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def happy(pet):
    rows = list(PETS[pet]["base"])
    for index, row in PETS[pet]["happy"].items():
        rows[int(index)] = row
    return rows


def render(scale):
    size = int(108 * scale)
    canvas = [[(0, 0, 0, 0)] * size for _ in range(size)]
    # Cat in front and bigger, frog and ghost either side, all on one baseline.
    layout = [("frog", 1.15, 26), ("ghost", 1.15, 63), ("cat", 1.45, 42.5)]
    baseline = 70
    for pet, px_dp, left_dp in layout:
        px = px_dp * scale
        top = (baseline - 16 * px_dp) * scale
        left = left_dp * scale
        colors = {**COMMON, **PALETTES[pet]}
        for sy, row in enumerate(happy(pet)):
            for sx, code in enumerate(row):
                if code not in colors:
                    continue
                for y in range(int(top + sy * px), int(top + (sy + 1) * px)):
                    for x in range(int(left + sx * px), int(left + (sx + 1) * px)):
                        if 0 <= x < size and 0 <= y < size:
                            canvas[y][x] = (*colors[code], 255)
    raw = b"".join(b"\0" + bytes(c for p in row for c in p) for row in canvas)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


if __name__ == "__main__":
    for name, scale in DENSITIES.items():
        folder = ANDROID / f"app/src/main/res/mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "ic_launcher_foreground.png").write_bytes(render(scale))
    print("foregrounds written")
