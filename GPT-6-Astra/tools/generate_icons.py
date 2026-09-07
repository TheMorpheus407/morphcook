#!/usr/bin/env python3
"""Rasterize the bundled Playfair wordmark at native launcher sizes.

Requires Pillow. No image sources, external fonts, or network access are used.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "app/assets/fonts/PlayfairDisplay-Italic.ttf"
PAPER = "#F6F1E7"
INK = "#343C35"


def wordmark(size: int) -> Image.Image:
    # Supersampling keeps the small italic punctuation readable at 29 px.
    side = size * 4
    image = Image.new("RGB", (side, side), PAPER)
    draw = ImageDraw.Draw(image)
    font_size = round(side * 0.82)
    font = ImageFont.truetype(str(FONT), font_size)
    bounds = draw.textbbox((0, 0), "m.", font=font)
    width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
    adjustment = min(side * 0.67 / width, side * 0.54 / height)
    font = ImageFont.truetype(str(FONT), round(font_size * adjustment))
    bounds = draw.textbbox((0, 0), "m.", font=font)
    width, height = bounds[2] - bounds[0], bounds[3] - bounds[1]
    position = ((side - width) / 2 - bounds[0], (side - height) / 2 - bounds[1])
    draw.text(position, "m.", font=font, fill=INK)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    assets = ROOT / "app/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    manifest = json.loads((assets / "Contents.json").read_text())
    targets: dict[Path, int] = {}
    for item in manifest["images"]:
        if "filename" not in item:
            continue
        size = round(float(item["size"].split("x")[0]) * float(item["scale"].removesuffix("x")))
        targets[assets / item["filename"]] = size
    android = ROOT / "app/android/app/src/main/res"
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        targets[android / f"mipmap-{density}" / "ic_launcher.png"] = size
    for path, size in targets.items():
        wordmark(size).save(path, optimize=True)
        with Image.open(path) as image:
            assert image.size == (size, size), path
            assert image.mode == "RGB", "iOS icons must have no alpha channel"
    print(f"Generated and verified {len(targets)} MorphCook launcher icons.")


if __name__ == "__main__":
    main()
