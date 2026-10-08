"""Create the shared dark studs atlas, retaining the approved UV layout."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PICKS = ROOT / 'assets/items/pickaxes'
colors = ['AA5230', 'D17B46', '783A27', '48251D', '526B8E', '95ABC8', '727C88', 'A4AFBB']
source = Image.open(PICKS / '01-wooden/references/studs-overlay-user.png').convert('RGBA')
pattern = Image.new('RGBA', (1500, 1500))
for y in range(3):
    for x in range(3):
        pattern.paste(source, (x * 500, y * 500))
pattern = pattern.resize((1016, 1016), Image.Resampling.LANCZOS)
atlas = Image.new('RGB', (4096, 2048))
for index, color in enumerate(colors):
    rgb = tuple(int(color[i:i + 2], 16) for i in (0, 2, 4))
    # All stud pixels remain darker than their surrounding surface.
    overlay = Image.new('RGBA', pattern.size)
    overlay.putdata([tuple(round(c * (.27 + .29 * max(r, g, b) / 255)) for c in rgb) + (a,)
                     for r, g, b, a in pattern.getdata()])
    tile = Image.new('RGBA', (1024, 1024), rgb + (255,))
    tile.alpha_composite(overlay, (4, 4))
    atlas.paste(tile.convert('RGB'), ((index % 4) * 1024, (index // 4) * 1024))
output = PICKS / 'pack/textures/pickaxes-dark-studs-v01.png'
atlas.save(output)
print(output)
