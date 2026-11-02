#!/usr/bin/env python3
"""Fetch static Google Fonts instances and name them for google_fonts bundling.

google_fonts resolves a pre-bundled asset by the suffix
``<Family>-<WeightPart><Italic>.<ext>`` (e.g. ``PlayfairDisplay-BoldItalic.ttf``).
This script downloads the matching static instances from the Google Fonts
stylesheet API and writes them into ``assets/fonts/`` with exactly that name.

Run once at development time; the resulting TTFs are committed to the repo so
the app never performs a network fetch at runtime.
"""

from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

CSS_URL = (
    "https://fonts.googleapis.com/css2?"
    "family=Playfair+Display:ital,wght@0,400;0,500;0,600;0,700;1,400;1,700"
    "&family=JetBrains+Mono:ital,wght@0,400;0,500;0,700;1,400"
    "&family=Caveat:wght@400;600;700"
)

WEIGHT_PARTS = {
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
}

FAMILY_FILES = {
    "Playfair Display": "PlayfairDisplay",
    "JetBrains Mono": "JetBrainsMono",
    "Caveat": "Caveat",
}

BLOCK_RE = re.compile(r"@font-face\s*\{(.*?)\}", re.S)
FIELD_RE = re.compile(r"(font-family|font-style|font-weight|src)\s*:\s*([^;]+);")


def parse_css(css: str) -> list[dict[str, str]]:
    faces: list[dict[str, str]] = []
    for block in BLOCK_RE.findall(css):
        fields = {key: value.strip() for key, value in FIELD_RE.findall(block)}
        match = re.search(r"url\((https://[^)]+\.ttf)\)", fields.get("src", ""))
        if not match:
            continue
        faces.append(
            {
                "family": fields.get("font-family", "").strip("'\""),
                "style": fields.get("font-style", "normal"),
                "weight": fields.get("font-weight", "400"),
                "url": match.group(1),
            }
        )
    return faces


def main() -> int:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/fonts")
    out_dir.mkdir(parents=True, exist_ok=True)

    request = urllib.request.Request(CSS_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        css = response.read().decode("utf-8")

    faces = parse_css(css)
    if not faces:
        print("no @font-face blocks parsed from stylesheet", file=sys.stderr)
        return 1

    written: list[str] = []
    for face in faces:
        family = FAMILY_FILES.get(face["family"])
        if family is None:
            continue
        weight = int(face["weight"])
        part = WEIGHT_PARTS.get(weight, "Regular")
        suffix = "Italic" if face["style"] == "italic" else ""
        if part == "Regular" and suffix:
            name = f"{family}-{suffix}.ttf"
        else:
            name = f"{family}-{part}{suffix}.ttf"

        target = out_dir / name
        if target.exists():
            continue
        with urllib.request.urlopen(face["url"], timeout=60) as response:
            target.write_bytes(response.read())
        written.append(name)

    print(f"wrote {len(written)} font file(s) to {out_dir}")
    for name in written:
        print(f"  - {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
