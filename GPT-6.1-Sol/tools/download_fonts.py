#!/usr/bin/env python3
"""Bundle the exact Google Fonts assets; the app never fetches fonts."""
from pathlib import Path
from urllib.request import urlopen
root = Path(__file__).resolve().parents[1] / 'app/assets/fonts'
files = {
    'PlayfairDisplay-Regular.ttf': 'ofl/playfairdisplay/PlayfairDisplay[wght].ttf',
    'PlayfairDisplay-Italic.ttf': 'ofl/playfairdisplay/PlayfairDisplay-Italic[wght].ttf',
    'JetBrainsMono-Regular.ttf': 'ofl/jetbrainsmono/JetBrainsMono[wght].ttf',
    'Caveat-Regular.ttf': 'ofl/caveat/Caveat[wght].ttf',
}
base = 'https://raw.githubusercontent.com/google/fonts/main/'
for filename, upstream in files.items():
    destination = root / filename
    if not destination.exists():
        destination.write_bytes(urlopen(base + upstream.replace('[', '%5B').replace(']', '%5D'), timeout=30).read())
    license_file = root / (filename.split('-')[0] + '-OFL.txt')
    if not license_file.exists():
        license_file.write_bytes(urlopen(base + upstream.rsplit('/', 1)[0] + '/OFL.txt', timeout=30).read())
    print(filename, destination.stat().st_size)
