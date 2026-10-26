"""Copies everything the Android app shares with iOS into app/src/main/assets:
the pets' sprite rows (read from ../Shared/Pets.swift) and the message, quote and horoscope
databases per language. Run it whenever the iOS data changes, so both apps stay identical.

Usage (from android/): python3 tools/export_shared.py
"""
import json
import re
import shutil
from pathlib import Path

ANDROID = Path(__file__).resolve().parent.parent
REPO = ANDROID.parent
ASSETS = ANDROID / "app/src/main/assets"


def export_pets():
    source = (REPO / "Shared/Pets.swift").read_text()
    pets = {}
    for pet in ["cat", "dog", "bunny", "frog", "ghost", "penguin", "axolotl", "dino"]:
        block = source[source.index(f"case .{pet}: (\n"):]
        block = block[:block.index("        )\n")]
        base = re.findall(r'^\s+"([.A-Z]{16})",$', block, re.M)[:16]
        overrides = [line for line in block.splitlines() if line.strip().startswith("[") and ': "' in line]

        def parse(line):
            return {int(i): row for i, row in re.findall(r'(\d+): "([.A-Z]{16})"', line)}

        pets[pet] = {"base": base, "blink": parse(overrides[0]), "happy": parse(overrides[1])}
        assert len(base) == 16, pet
    (ASSETS / "pets.json").write_text(json.dumps(pets, indent=1))


def export_messages():
    for lang in ["en", "ru"]:
        target = ASSETS / lang
        target.mkdir(parents=True, exist_ok=True)
        for name in ["motivations.json", "quotes.json", "horoscope.json"]:
            shutil.copy(REPO / f"Shared/{lang}.lproj/{name}", target / name)


if __name__ == "__main__":
    ASSETS.mkdir(parents=True, exist_ok=True)
    export_pets()
    export_messages()
    print("exported:", ", ".join(sorted(str(p.relative_to(ASSETS)) for p in ASSETS.rglob("*.json"))))
