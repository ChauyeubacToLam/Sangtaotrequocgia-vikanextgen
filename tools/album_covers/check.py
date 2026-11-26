from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
for path in sorted((root / 'assets/albums').glob('*.webp')):
    with Image.open(path) as image:
        assert image.size == (768, 768), f'{path}: {image.size}'
    assert path.stat().st_size < 120 * 1024, f'{path}: {path.stat().st_size} bytes'
    print(f'{path.name}: {path.stat().st_size / 1024:.1f} KB, 768x768')
