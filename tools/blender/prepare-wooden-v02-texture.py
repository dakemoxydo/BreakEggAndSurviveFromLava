"""Bake the user-provided translucent studs overlay into a portable color atlas."""
from pathlib import Path
from PIL import Image
import shutil

root = Path(__file__).resolve().parents[2]
asset = root / 'assets/items/pickaxes/01-wooden'
source = Path(r'C:\Users\dakem\AppData\Local\Temp\codex-clipboard-8b4c3454-7538-4174-9bdf-4d07242f8c00.png')
reference = asset / 'references/studs-overlay-user.png'
if not reference.exists():
    shutil.copy2(source, reference)
overlay = Image.open(reference).convert('RGBA')
assert overlay.size == (500,500)
repeat = Image.new('RGBA',(3000,3000))
for y in range(6):
    for x in range(6):
        repeat.paste(overlay,(x*500,y*500))
repeat = repeat.resize((1016,1016),Image.Resampling.LANCZOS)
colors = ['BF6120','EF8E30','843914','ECAF50','4B2515','263443','697C90','B0C1D2']
atlas = Image.new('RGBA',(4096,2048))
for i,color in enumerate(colors):
    tile = Image.new('RGBA',(1024,1024),'#'+color)
    tile.alpha_composite(repeat,(4,4))
    atlas.paste(tile,((i%4)*1024,(i//4)*1024))
atlas.convert('RGB').save(asset / 'textures/wooden-pickaxe-studs-atlas-v02.png')
print('Saved 4096x2048 atlas: original alpha overlay, 24 studs per six units.')
