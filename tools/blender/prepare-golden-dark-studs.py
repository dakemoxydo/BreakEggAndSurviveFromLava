"""Recolor the shared studs atlas for walnut and gold."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
folder = ROOT / 'assets/items/pickaxes/pack/textures'
source = Image.open(folder / 'pickaxes-dark-studs-v01.png').convert('RGB')
old = ['AA5230', 'D17B46', '783A27', '48251D', '526B8E', '95ABC8', '727C88', 'A4AFBB']
colors = ['65402E', '885C3E', '472B21', '302019', 'B87514', 'F4BD38', 'EAAF20', 'FFD96A']
atlas = Image.new('RGB', source.size)
for i, color in enumerate(colors):
    x, y = i % 4 * 1024, i // 4 * 1024
    red = source.crop((x, y, x + 1024, y + 1024)).getchannel('R')
    base = int(old[i][:2], 16)
    channels = [red.point([min(255, round(v * int(color[j:j + 2], 16) / base))
                          for v in range(256)]) for j in (0, 2, 4)]
    atlas.paste(Image.merge('RGB', channels), (x, y))
output = folder / 'golden-dark-studs-v01.png'
atlas.save(output)
print(output)
