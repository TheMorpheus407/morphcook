#!/usr/bin/env python3
"""Generate MorphCook launcher icons + Play Store art from the app's design
language (paper, terracotta stripes, Playfair italic). Run from app/:

    python3 tool/generate_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent
RES = APP / "android/app/src/main/res"
STORE = APP.parent / "docs/store-assets"
FONT = APP / "assets/fonts/PlayfairDisplay-Italic.ttf"

PAPER = (247, 241, 230, 255)
PAPER_DEEP = (239, 230, 212, 255)
INK = (44, 38, 30, 255)
TERRACOTTA = (194, 96, 60, 255)
TEAL = (80, 131, 123, 255)


def stripe_band(img: Image.Image, top_frac: float, alpha=255):
    """Diagonal terracotta stripes in the band below top_frac — the
    polaroid-placeholder motif at the icon's foot."""
    size = img.size[0]
    band = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(band)
    w = max(2, int(size * 0.07))
    gap = int(size * 0.19)
    c = (*TERRACOTTA[:3], alpha)
    for x in range(-size, 2 * size, gap):
        draw.line([(x, size + w), (x + size, -w)], fill=c, width=w)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rectangle(
        [0, int(size * top_frac), size, size], fill=255)
    img.paste(band, (0, 0), Image.composite(
        band.split()[3], Image.new("L", (size, size), 0), mask))


def glyph(img: Image.Image, scale: float, center_frac: float):
    """Playfair-italic lowercase 'm', centered on the upper paper field."""
    size = img.size[0]
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(FONT), int(size * scale))
    box = draw.textbbox((0, 0), "m", font=font)
    x = (size - (box[2] - box[0])) / 2 - box[0]
    y = size * center_frac - (box[3] - box[1]) / 2 - box[1]
    draw.text((x, y), "m", font=font, fill=INK)


def legacy_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), PAPER)
    stripe_band(img, top_frac=0.72)
    glyph(img, scale=0.52, center_frac=0.40)
    return img


def adaptive_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), PAPER)
    stripe_band(img, top_frac=0.78)
    return img


def adaptive_foreground(size: int) -> Image.Image:
    # transparent layer; glyph must stay inside the 66/108 safe zone
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph(img, scale=0.34, center_frac=0.47)
    return img


def blend(color, alpha: float):
    """Pre-blend color over paper (ImageDraw.line ignores RGBA alpha)."""
    return tuple(int(p + (c - p) * alpha) for p, c in zip(PAPER[:3], color[:3]))


def feature_graphic() -> Image.Image:
    w, h = 1024, 500
    img = Image.new("RGBA", (w, h), PAPER)
    draw = ImageDraw.Draw(img)
    c = blend(TERRACOTTA, 0.22)
    lw, gap = 26, 110
    for x in range(-h, w + h, gap):
        draw.line([(x, h + lw), (x + h, -lw)], fill=c, width=lw)
    title_font = ImageFont.truetype(str(FONT), 150)
    tag_font = ImageFont.truetype(str(FONT), 44)
    box = draw.textbbox((0, 0), "morphcook", font=title_font)
    draw.text(((w - box[2] + box[0]) / 2 - box[0], 130 - box[1]),
              "morphcook", font=title_font, fill=INK)
    tag = "the same dish exists for every body"
    tbox = draw.textbbox((0, 0), tag, font=tag_font)
    draw.text(((w - tbox[2] + tbox[0]) / 2 - tbox[0], 330 - tbox[1]),
              tag, font=tag_font, fill=TEAL)
    return img


def main():
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, factor in densities.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        legacy_icon(int(48 * factor)).save(d / "ic_launcher.png")
        adp = int(108 * factor)
        adaptive_background(adp).save(d / "ic_launcher_background.png")
        adaptive_foreground(adp).save(d / "ic_launcher_foreground.png")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')

    STORE.mkdir(parents=True, exist_ok=True)
    play_icon = legacy_icon(512)
    play_icon.convert("RGB").save(STORE / "play-icon-512.png")
    feature_graphic().convert("RGB").save(STORE / "feature-graphic-1024x500.png")
    print(f"icons -> {RES}\nstore art -> {STORE}")


if __name__ == "__main__":
    main()
