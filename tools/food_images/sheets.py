import csv
import math
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2]
with (root / 'docs/food-image-manifest.csv').open(encoding='utf-8', newline='') as stream:
    rows = list(csv.DictReader(stream))
groups = defaultdict(list)
for row in rows:
    if (root / 'assets/food' / (row['id'] + '.webp')).exists():
        groups[row['group']].append(row)
folder = root / 'docs/scratch/gen/food/sheets'
folder.mkdir(parents=True, exist_ok=True)
font_path = root / 'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf'
font = ImageFont.truetype(str(font_path), 12)
for group, items in groups.items():
    sheet = Image.new('RGB', (960, math.ceil(len(items) / 6) * 222), 'white')
    draw = ImageDraw.Draw(sheet)
    for index, row in enumerate(items):
        x, y = index % 6 * 160, index // 6 * 222
        with Image.open(root / 'assets/food' / (row['id'] + '.webp')) as image:
            sheet.paste(image.resize((160, 160), Image.Resampling.LANCZOS), (x, y))
        id_size = 12
        id_font = font
        while draw.textlength(row['id'], font=id_font) > 156 and id_size > 6:
            id_size -= 1
            id_font = ImageFont.truetype(str(font_path), id_size)
        draw.text((x + 2, y + 160), row['id'], font=id_font, fill='black')
        lines = ['']
        for word in row['name'].split():
            candidate = (lines[-1] + ' ' + word).strip()
            if draw.textlength(candidate, font=font) > 156 and lines[-1]:
                lines.append(word)
            else:
                lines[-1] = candidate
        for line, label in enumerate(lines):
            draw.text((x + 2, y + 178 + line * 15), label, font=font, fill='black')
    sheet.save(folder / (group + '.jpg'), quality=90)
