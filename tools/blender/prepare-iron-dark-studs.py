"""Recolor the common dark studs atlas for forged iron and charcoal leather."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
folder = ROOT / 'assets/items/pickaxes/pack/textures'
source = Image.open(folder / 'pickaxes-dark-studs-v01.png').convert('RGB')
old = ['AA5230', 'D17B46', '783A27', '48251D', '526B8E', '95ABC8', '727C88', 'A4AFBB']
colors = ['AA5230', 'D17B46', '783A27', '252C36', '465363', '8193A7', 'A3AEBC', 'D0D8E2']
atlas = Image.new('RGB', source.size)
for i, color in enumerate(colors):
    x, y = i % 4 * 1024, i // 4 * 1024
    red = source.crop((x, y, x + 1024, y + 1024)).getchannel('R')
    base = int(old[i][:2], 16)
    channels = [red.point([min(255, round(value * int(color[j:j + 2], 16) / base))
                          for value in range(256)]) for j in (0, 2, 4)]
    atlas.paste(Image.merge('RGB', channels), (x, y))
output = folder / 'iron-dark-studs-v01.png'
atlas.save(output)
print(output)
