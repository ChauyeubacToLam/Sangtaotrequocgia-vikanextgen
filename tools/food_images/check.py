import json
import sys
import time
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[2]
while True:
    try:
        foods = json.loads((root / 'assets/data/vn_nutrition.json').read_text(encoding='utf-8'))['foods']
        break
    except json.JSONDecodeError:
        time.sleep(3)
folder = root / 'assets/food'
icon_only = {'nin_7008', 'nin_7009'}
missing = [food['id'] for food in foods if food['id'] not in icon_only and not (folder / (food['id'] + '.webp')).is_file()]
bad = []
for path in sorted(folder.glob('*')):
    if not path.is_file():
        continue
    try:
        with Image.open(path) as image:
            if image.format != 'WEBP' or image.size != (512, 512) or image.mode != 'RGB' or path.stat().st_size > 60 * 1024:
                bad.append(path.name)
    except (OSError, ValueError):
        bad.append(path.name)
print(f'Total foods: {len(foods)}')
print(f'Foods with image: {len(foods) - len(missing)}')
print(f'Missing ids ({len(missing)}): {", ".join(missing)}')
print(f'Bad files ({len(bad)}): {", ".join(bad)}')
sys.exit(bool(missing or bad))
