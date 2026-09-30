#!/usr/bin/env python3
"""Render the existing italic wordmark initial for native launcher assets."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
font = ImageFont.truetype(str(ROOT/'app/assets/fonts/PlayfairDisplay-Italic.ttf'), 640)
image = Image.new('RGB', (1024, 1024), '#f4efe5')
draw = ImageDraw.Draw(image)
for x in range(0, 1024, 36):
    draw.rectangle((x, 0, x+12, 1024), fill='#e9e5d9')
draw.rectangle((115, 115, 909, 909), fill='#f4efe5', outline='#d8d3c5', width=3)
box = draw.textbbox((0, 0), 'm.', font=font)
width, height = box[2]-box[0], box[3]-box[1]
draw.text(((1024-width)/2-box[0], (1024-height)/2-box[1]-26), 'm.', font=font, fill='#343e37')
draw.line((345, 807, 679, 807), fill='#4d7565', width=7)

for density, size in {'mdpi':48, 'hdpi':72, 'xhdpi':96, 'xxhdpi':144, 'xxxhdpi':192}.items():
    path = ROOT/f'app/android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)
folder = ROOT/'app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((folder/'Contents.json').read_text())['images']:
    if 'filename' not in item:
        continue
    size = round(float(item['size'].split('x')[0])*float(item['scale'].removesuffix('x')))
    image.resize((size, size), Image.Resampling.LANCZOS).save(folder/item['filename'])
print('Rendered native wordmark launcher assets.')
