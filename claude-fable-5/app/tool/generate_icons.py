#!/usr/bin/env python3
"""Generate MorphCook launcher icons + Play Store art from the app's design
language (paper, terracotta stripes, Playfair italic). The mark is a small
hand-drawn-feeling chef's toque with the brand's diagonal terracotta stripes
on its band. Run from app/:

    python3 tool/generate_icons.py
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

APP = Path(__file__).resolve().parent.parent
RES = APP / "android/app/src/main/res"
STORE = APP.parent / "docs/store-assets"
FONT = APP / "assets/fonts/PlayfairDisplay-Italic.ttf"

PAPER = (247, 241, 230, 255)
PAPER_DEEP = (239, 230, 212, 255)
INK = (44, 38, 30, 255)
TERRACOTTA = (194, 96, 60, 255)
TEAL = (80, 131, 123, 255)
HAT_WHITE = (255, 252, 245, 255)  # a touch brighter than the paper

SS = 4          # supersample factor; render at SS*size, downscale w/ LANCZOS
TILT = 8        # degrees, counterclockwise — jaunty old-cookbook tilt


# ---------------------------------------------------------------- the toque

def _toque_silhouette(draw: ImageDraw.ImageDraw, s: int, g: float):
    """Union of the hat's shapes, each grown by g px (g>0 -> ink outline)."""
    def ell(cx, cy, r):
        draw.ellipse([s * cx - s * r - g, s * cy - s * r - g,
                      s * cx + s * r + g, s * cy + s * r + g], fill=255)
    # puffy crown: one big centre lobe flanked by two smaller ones
    ell(0.500, 0.305, 0.200)
    ell(0.285, 0.405, 0.155)
    ell(0.715, 0.405, 0.155)
    # body bridging the lobes down to the band
    draw.rectangle([s * 0.27 - g, s * 0.40 - g, s * 0.73 + g, s * 0.70 + g],
                   fill=255)
    # cylindrical band
    draw.rounded_rectangle(
        [s * 0.245 - g, s * 0.615 - g, s * 0.755 + g, s * 0.800 + g],
        radius=s * 0.045 + g, fill=255)


def draw_toque(s: int, band_stripes: bool = True) -> Image.Image:
    """Chef's hat on a transparent s*s layer (s is already supersampled;
    no extra AA here — callers downscale). Tilted, ink-outlined."""
    ow = max(5, round(s * 0.024))            # ink outline width
    lw = max(4, round(s * 0.016))            # interior line width

    outline = Image.new("L", (s, s), 0)
    _toque_silhouette(ImageDraw.Draw(outline), s, ow)
    fill = Image.new("L", (s, s), 0)
    _toque_silhouette(ImageDraw.Draw(fill), s, 0)

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    img.paste(INK, (0, 0), outline)
    img.paste(HAT_WHITE, (0, 0), fill)

    # interior details, clipped to the white fill
    band_top = 0.615
    if band_stripes:
        # ticking-stripe ribbon, inset in the band with a white stitch margin
        m = s * 0.022
        ribbon = Image.new("L", (s, s), 0)
        ImageDraw.Draw(ribbon).rounded_rectangle(
            [s * 0.245 + m, s * band_top + m * 1.7,
             s * 0.755 - m, s * 0.800 - m],
            radius=s * 0.030, fill=255)
        ribbon = ImageChops.multiply(ribbon, fill)
        det = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        dd = ImageDraw.Draw(det)
        sw = round(s * 0.034)
        gap = round(s * 0.105)
        for x in range(-s, 2 * s, gap):
            dd.line([(x, s * 0.85 + sw), (x + s * 0.28, s * band_top - sw)],
                    fill=TERRACOTTA, width=sw)
        det.putalpha(ImageChops.multiply(det.split()[3], ribbon))
        img.alpha_composite(det)

    # seam where the crown gathers into the band
    seam = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(seam).line(
        [(s * 0.18, s * band_top), (s * 0.82, s * band_top)],
        fill=INK, width=lw)
    seam.putalpha(ImageChops.multiply(seam.split()[3], fill))
    img.alpha_composite(seam)

    # soft creases falling from the valley notches between the lobes
    d = ImageDraw.Draw(img)
    crease = [(0.315, 0.268), (0.348, 0.345), (0.362, 0.420)]
    for sign in (1, -1):
        pts = [(s * (0.5 + sign * (x - 0.5)), s * y) for x, y in crease]
        d.line(pts, fill=INK, width=lw, joint="curve")

    return img.rotate(TILT, resample=Image.BICUBIC)


def paste_toque(canvas: Image.Image, frac: float, cx: float, cy: float,
                band_stripes: bool = True):
    """Paste a toque sized frac*canvas, centered at (cx, cy) fractions."""
    side = canvas.size[1]
    hat = draw_toque(round(side * frac), band_stripes=band_stripes)
    canvas.alpha_composite(
        hat, (round(canvas.size[0] * cx - hat.size[0] / 2),
              round(side * cy - hat.size[1] / 2)))


# ---------------------------------------------------------- shared elements

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


def blend(color, alpha: float):
    """Pre-blend color over paper (ImageDraw.line ignores RGBA alpha)."""
    return tuple(int(p + (c - p) * alpha) for p, c in zip(PAPER[:3], color[:3]))


# ----------------------------------------------------------------- the icons

def legacy_icon(size: int) -> Image.Image:
    s = size * SS
    img = Image.new("RGBA", (s, s), PAPER)
    d = ImageDraw.Draw(img)
    # soft ground shadow so the hat sits on the page
    d.ellipse([s * 0.22, s * 0.78, s * 0.80, s * 0.88], fill=PAPER_DEEP)
    paste_toque(img, frac=0.92, cx=0.515, cy=0.475)
    return img.resize((size, size), Image.LANCZOS)


def adaptive_background(size: int) -> Image.Image:
    img = Image.new("RGBA", (size * SS, size * SS), PAPER)
    stripe_band(img, top_frac=0.78)
    return img.resize((size, size), Image.LANCZOS)


def adaptive_foreground(size: int) -> Image.Image:
    # transparent layer; hat must stay inside the 66/108 safe-zone circle
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    paste_toque(img, frac=0.66, cx=0.50, cy=0.50)
    return img.resize((size, size), Image.LANCZOS)


def feature_graphic() -> Image.Image:
    w, h = 1024, 500
    img = Image.new("RGBA", (w * SS, h * SS), PAPER)
    draw = ImageDraw.Draw(img)
    c = blend(TERRACOTTA, 0.22)
    lw, gap = 26 * SS, 110 * SS
    for x in range(-h * SS, (w + h) * SS, gap):
        draw.line([(x, h * SS + lw), (x + h * SS, -lw)], fill=c, width=lw)
    paste_toque(img, frac=0.36, cx=0.50, cy=0.235)
    title_font = ImageFont.truetype(str(FONT), 130 * SS)
    tag_font = ImageFont.truetype(str(FONT), 42 * SS)
    box = draw.textbbox((0, 0), "morphcook", font=title_font)
    draw.text(((w * SS - box[2] + box[0]) / 2 - box[0], 235 * SS - box[1]),
              "morphcook", font=title_font, fill=INK)
    tag = "the same dish exists for every body"
    tbox = draw.textbbox((0, 0), tag, font=tag_font)
    draw.text(((w * SS - tbox[2] + tbox[0]) / 2 - tbox[0], 410 * SS - tbox[1]),
              tag, font=tag_font, fill=TEAL)
    return img.resize((w, h), Image.LANCZOS)


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
