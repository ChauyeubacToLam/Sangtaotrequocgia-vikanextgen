import csv
import sys
from pathlib import Path

from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[2]
manifest = root / 'docs/food-image-manifest.csv'
with manifest.open(encoding='utf-8', newline='') as stream:
    rows = list(csv.DictReader(stream))
by_id = {row['id']: row for row in rows}
for food_id in sys.argv[1:]:
    row = by_id[food_id]
    source = root / 'docs/scratch/gen/food' / (food_id + '.png')
    target = root / 'assets/food' / (food_id + '.webp')
    if target.exists() and row['status'] != 'redo':
        raise SystemExit(f'Refusing to overwrite {target}')
    with Image.open(source) as image:
        image = ImageOps.fit(image.convert('RGB'), (512, 512), Image.Resampling.LANCZOS)
        image.save(target, 'WEBP', quality=80, method=6)
    row['status'] = 'generated'
with manifest.open('w', encoding='utf-8', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=['id', 'name', 'group', 'aka', 'prompt', 'status', 'notes'])
    writer.writeheader()
    writer.writerows(rows)
