"""Renders the 1024×1024 app icon: three happy pals (frog, cat, ghost) from Shared/Pets.swift
on a soft gradient. No alpha channel, as the App Store requires.

Usage: python3 tools/make_icon.py   (run from the IslandHub folder)
"""
import re
import struct
import zlib

SIZE = 1024

COMMON = {"K": (20, 20, 31), "E": (20, 20, 31), "W": (255, 255, 255), "P": (255, 140, 166), "R": (242, 89, 107)}
PALETTES = {
    "cat": {"B": (255, 184, 107), "D": (217, 128, 64), "L": (255, 237, 209)},
    "frog": {"B": (115, 209, 107), "D": (71, 148, 69), "L": (204, 242, 153)},
    "ghost": {"B": (240, 237, 255), "D": (184, 179, 224), "L": (255, 255, 255)},
}

# (pet, sprite pixel size, left x); all stand on the same baseline, the cat in front and bigger.
LAYOUT = [("frog", 21, 8), ("ghost", 21, 680), ("cat", 27, 296)]
BASELINE = 736


def happy_sprite(pet):
    source = open("Shared/Pets.swift").read()
    block = source[source.index(f"case .{pet}: (\n"):]
    block = block[:block.index("        )\n")]
    rows = re.findall(r'^\s+"([.A-Z]{16})",$', block, re.M)[:16]
    happy_line = [line for line in block.splitlines() if line.strip().startswith("[")][-1]
    for index, row in re.findall(r'(\d+): "([.A-Z]{16})"', happy_line):
        rows[int(index)] = row
    return rows


def background(y):
    top, bottom = (255, 214, 170), (255, 150, 180)
    t = y / (SIZE - 1)
    return tuple(round(a + (b - a) * t) for a, b in zip(top, bottom))


def render():
    canvas = [[background(y) for _ in range(SIZE)] for y in range(SIZE)]
    for pet, pixel, left in LAYOUT:
        colors = {**COMMON, **PALETTES[pet]}
        top = BASELINE - pixel * 16
        for sy, row in enumerate(happy_sprite(pet)):
            for sx, code in enumerate(row):
                color = colors.get(code)
                if not color:
                    continue
                for y in range(top + sy * pixel, top + (sy + 1) * pixel):
                    for x in range(left + sx * pixel, left + (sx + 1) * pixel):
                        canvas[y][x] = color
    raw = bytearray()
    for row in canvas:
        raw.append(0)  # PNG filter: none
        for pixel in row:
            raw.extend(pixel)
    return bytes(raw)


def png(data):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit RGB, no alpha
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(data, 9)) + chunk(b"IEND", b"")


if __name__ == "__main__":
    out = "IslandHub/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    open(out, "wb").write(png(render()))
    print("wrote", out)
