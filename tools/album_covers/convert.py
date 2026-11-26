from pathlib import Path
from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[2]
source = root / 'docs/scratch/gen/albums'
target = root / 'assets/albums'
target.mkdir(parents=True, exist_ok=True)
for path in source.glob('*.png'):
    with Image.open(path) as image:
        image = ImageOps.fit(image.convert('RGB'), (768, 768), Image.Resampling.LANCZOS)
        image.save(target / (path.stem + '.webp'), 'WEBP', quality=82, method=6)
