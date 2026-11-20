#!/usr/bin/env python3
"""Turns the PNG originals of the "Монстрики" pictures into the WebP files
the app bundles.

    python3 tool/prepare_monster_art.py [originals] [out]

Defaults: tool/monsters_art/ (kept out of git) → assets/monsters/.

- faces and arms (<color>_idle/open/chomp/yuck/arm): 627×627 — the red
  ones were drawn at 1254 and are scaled down, so all faces line up;
- treats: fitted into 400×400;
- background.png: as is, without transparency;
- tray.png: cropped to the wood.
"""
import sys
from pathlib import Path

from PIL import Image

MONSTER_SIDE = 627
FOOD_SIDE = 400
QUALITY = 85
MONSTER_PICTURES = ("idle", "open", "chomp", "yuck", "arm")


def save(image, path):
    image.save(path, "WEBP", quality=QUALITY, method=4)


def prepare(src, out):
    name = src.stem
    image = Image.open(src)
    if name == "background":
        save(image.convert("RGB"), out / "background.webp")
        return
    image = image.convert("RGBA")
    if name == "tray":
        box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        save(image.crop(box), out / "tray.webp")
        return
    if name.rsplit("_", 1)[-1] in MONSTER_PICTURES:
        if image.width != image.height:
            sys.exit(f"{src.name}: a monster picture must be square, got {image.size}")
        if image.width != MONSTER_SIDE:
            image = image.resize((MONSTER_SIDE, MONSTER_SIDE), Image.LANCZOS)
    else:
        image.thumbnail((FOOD_SIDE, FOOD_SIDE), Image.LANCZOS)
    save(image, out / f"{name}.webp")


def main():
    root = Path(__file__).resolve().parent.parent
    originals = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "tool" / "monsters_art"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "assets" / "monsters"
    out.mkdir(parents=True, exist_ok=True)
    sources = sorted(originals.glob("*.png"))
    if not sources:
        sys.exit(f"no PNG files in {originals}")
    for src in sources:
        prepare(src, out)
    total = sum(p.stat().st_size for p in out.glob("*.webp"))
    print(f"{len(sources)} pictures → {out} ({total / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
