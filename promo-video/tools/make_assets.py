"""Exports the promo's assets from the app itself: every pet's sprite frames (read from
../Shared/Pets.swift, with the sad face and accessories applied the way the app does),
the props, the app icon, and a generated 15 s chiptune soundtrack with blips on each pop.

Usage (from promo-video/): python3 tools/make_assets.py
"""
import math
import re
import shutil
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT.parent
ASSETS = ROOT / "assets"
ASSETS.mkdir(exist_ok=True)

COMMON = {
    "K": (20, 20, 31), "E": (20, 20, 31), "W": (255, 255, 255),
    "P": (255, 140, 166), "R": (242, 89, 107), "T": (115, 191, 255),
    "M": (242, 89, 153), "Y": (255, 209, 51), "V": (89, 140, 255),
}
ORANGE = (255, 158, 51)
# Body, shade, belly and extra colours per pet, as in PetKind (Shared/Pets.swift).
PALETTES = {
    "cat": {"B": (255, 184, 107), "D": (217, 128, 64), "L": (255, 237, 209), "O": ORANGE, "G": ORANGE},
    "dog": {"B": (237, 158, 82), "D": (191, 107, 51), "L": (255, 242, 219), "O": ORANGE, "G": ORANGE},
    "bunny": {"B": (247, 245, 250), "D": (204, 199, 217), "L": (255, 224, 235), "O": ORANGE, "G": ORANGE},
    "frog": {"B": (115, 209, 107), "D": (71, 148, 69), "L": (204, 242, 153), "O": ORANGE, "G": ORANGE},
    "ghost": {"B": (240, 237, 255), "D": (184, 179, 224), "L": (255, 255, 255), "O": ORANGE, "G": ORANGE},
    "penguin": {"B": (56, 69, 107), "D": (38, 46, 77), "L": (255, 255, 255), "O": ORANGE, "G": ORANGE},
    "axolotl": {"B": (255, 184, 209), "D": (230, 128, 166), "L": (255, 224, 235), "O": (242, 97, 148), "G": (242, 97, 148)},
    "dino": {"B": (128, 204, 115), "D": (247, 148, 77), "L": (224, 245, 158), "O": ORANGE, "G": ORANGE},
}
PETS = list(PALETTES)

# Same tables as PetKind.face and PetKind.anchors.
FACES = {
    "cat": (9, [6, 9], 10, [7, 8], (9, 4)),
    "dog": (10, [6, 9], 11, [7, 8], (9, 3)),
    "bunny": (11, [6, 9], 12, [7, 8], (10, 4)),
    "frog": (9, [3, 12], 10, list(range(4, 12)), (5, 2)),
    "ghost": (8, [6, 9], 9, [7, 8], (7, 4)),
    "penguin": (0, [], 0, [], (6, 5)),
    "axolotl": (9, [6, 9], 10, [7, 8], (9, 4)),
    "dino": (8, [5, 10], 9, list(range(6, 10)), (7, 4)),
}
ANCHORS = {
    "cat": (4, (7, 4, 10)), "dog": (4, (7, 3, 11)), "bunny": (5, (8, 4, 10)), "frog": (4, (3, 3, 11)),
    "ghost": (0, (5, 4, 10)), "penguin": (1, (4, 5, 10)), "axolotl": (3, (7, 4, 10)), "dino": (2, (5, 4, 10)),
}
SOURCE = (APP / "Shared/Pets.swift").read_text()


def pet_rows(pet, frame):
    block = SOURCE[SOURCE.index(f"case .{pet}: (\n"):]
    block = block[:block.index("        )\n")]
    rows = [list(r) for r in re.findall(r'^\s+"([.A-Z]{16})",$', block, re.M)[:16]]
    # Only the blink and happy override lines ("[7: "...", ...]"), not the "[" that opens the rows.
    overrides = [line for line in block.splitlines() if line.strip().startswith("[") and ': "' in line]
    if frame in (1, 2):
        for index, row in re.findall(r'(\d+): "([.A-Z]{16})"', overrides[frame - 1]):
            rows[int(index)] = list(row)
    if frame == 3:
        top, corners, bottom, middle, tear = FACES[pet]

        def fill(r, c):
            return rows[r][c - 1] if rows[r][c - 1] != "K" else rows[r][c + 1]
        if corners:
            for c in corners:
                rows[top][c] = fill(top, c)
            for c in middle:
                rows[bottom][c] = fill(bottom, c)
            for c in middle:
                rows[top][c] = "K"
            for c in corners:
                rows[bottom][c] = "K"
        rows[tear[0]][tear[1]] = "T"
    return rows


def stamp(rows, sprite, row, col):
    for dy, line in enumerate(sprite):
        for dx, code in enumerate(line):
            if code != "." and 0 <= row + dy < 16 and 0 <= col + dx < 16:
                rows[row + dy][col + dx] = code


def wear(pet, rows, accessory):
    head_top, (row, left, right) = ANCHORS[pet]
    if accessory == "bow":
        stamp(rows, ["MM.MM", ".MRM.", "MM.MM"], max(0, head_top - 2), 10)
    elif accessory == "partyhat":
        stamp(rows, ["..W..", "..V..", ".VYV.", "VYVYV"], max(0, head_top - 3), 5)
    elif accessory == "crown":
        stamp(rows, ["Y.YY.Y", "YYYYYY", "YRYYRY"], max(0, head_top - 2), 5)
    elif accessory == "sunglasses":
        for eye in (left, right):
            stamp(rows, ["KKKK", "KKKK"], row, eye - 1)
            rows[row][eye] = "W"
        for c in range(left + 3, right - 1):
            rows[row][c] = "K"
    return rows


def write_png(path, rows, palette):
    colors = {**COMMON, **palette}
    height, width = len(rows), len(rows[0])
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for code in row:
            raw.extend((*colors[code], 255) if code in colors else (0, 0, 0, 0))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


PROPS = {
    "heart": [".RR.RR.", "RRRRRRR", "RRRRRRR", ".RRRRR.", "..RRR..", "...R..."],
    "apple": ["...K...", "...KG..", ".RRRRR.", "RRRWRRR", "RRRRRRR", "RRRRRRR", ".RRRRR."],
    "ball": [".VVVV.", "VWVVWV", "VVVVVV", "VVWWVV", "VWVVWV", ".VVVV."],
}


def make_sprites():
    for old in ASSETS.glob("kuma-*.png"):
        old.unlink()
    for pet in PETS:
        palette = PALETTES[pet]
        for name, frame in {"idle": 0, "blink": 1, "happy": 2, "sad": 3}.items():
            write_png(ASSETS / f"{pet}-{name}.png", pet_rows(pet, frame), palette)
        for accessory in ("bow", "sunglasses", "partyhat", "crown"):
            write_png(ASSETS / f"{pet}-{accessory}.png", wear(pet, pet_rows(pet, 2), accessory), palette)
    write_png(ASSETS / "dog-crown-blink.png", wear("dog", pet_rows("dog", 1), "crown"), PALETTES["dog"])
    for name, rows in PROPS.items():
        write_png(ASSETS / f"{name}.png", [list(r) for r in rows], {"G": (102, 204, 89)})
    shutil.copy(APP / "IslandHub/Assets.xcassets/AppIcon.appiconset/AppIcon.png", ASSETS / "app-icon.png")


# --- Soundtrack -------------------------------------------------------------

RATE = 44100
LENGTH = 15.0
BPM = 120
BEAT = 60 / BPM

# Blips land on the film's pops (seconds): island pop, emotion swaps, apple, ball, hearts,
# accessory swaps, then the sleep chime and the end-card chord.
BLIPS = [0.15, 2.6, 3.25, 3.9, 4.55, 5.2, 6.75, 7.6, 8.0, 8.4, 8.75, 9.25, 9.85, 10.45, 11.05]
SLEEP_CHIME = 11.5
END_CHORD = 12.7


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def pulse(freq, t, duty=0.25):
    return 1.0 if (freq * t) % 1.0 < duty else -1.0


def tri(freq, t):
    x = (freq * t) % 1.0
    return 4 * abs(x - 0.5) - 1


def make_music():
    # I–V–vi–IV in C, one bar each, looping; arpeggio on top, bass below.
    chords = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
    seed = 1
    samples = []
    total = int(RATE * LENGTH)
    for i in range(total):
        t = i / RATE
        beat = t / BEAT
        bar = int(beat // 4) % 4
        chord = chords[bar]
        s = 0.0
        if t < 13.0:
            step = int(beat * 4) % 8  # sixteenth-note arpeggio
            arp = chord[[0, 1, 2, 1, 0, 2, 1, 2][step]] + 12
            sixteenth = (beat * 4) % 1
            s += pulse(note(arp), t) * 0.07 * math.exp(-sixteenth * 2.5)
            s += tri(note(chord[0] - 12), t) * 0.16
            hat_pos = (beat * 2) % 1
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            noise = seed / 0x7FFFFFFF * 2 - 1
            s += noise * 0.03 * math.exp(-hat_pos * 40)
        for b in BLIPS:
            dt = t - b
            if 0 <= dt < 0.12:
                s += pulse(note(84) * (1 + dt * 4), t, 0.5) * 0.12 * (1 - dt / 0.12)
        dt = t - SLEEP_CHIME
        if 0 <= dt < 1.2:
            s += tri(note(79 - int(dt * 5) * 3), t) * 0.14 * (1 - dt / 1.2)
        dt = t - END_CHORD
        if 0 <= dt < 1.9:
            for n in (72, 76, 79, 84):
                s += pulse(note(n), t, 0.5) * 0.045 * math.exp(-dt * 1.3)
        fade = min(1.0, (LENGTH - t) / 0.4)
        samples.append(max(-1.0, min(1.0, s * fade)))
    with wave.open(str(ASSETS / "chiptune.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(v * 32000)) for v in samples))


if __name__ == "__main__":
    make_sprites()
    make_music()
    print("assets:", ", ".join(sorted(p.name for p in ASSETS.iterdir())))
