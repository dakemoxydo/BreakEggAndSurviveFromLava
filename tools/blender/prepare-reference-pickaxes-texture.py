"""Reference-matched burnt wood, blue steel and stone, using the user's studs."""
from pathlib import Path
from PIL import Image
import shutil
import json

root=Path(__file__).resolve().parents[2]
picks=root/'assets/items/pickaxes'
folder=picks/'pack/textures'
colors=['AA5230','D17B46','783A27','48251D','526B8E','95ABC8','626C78','A9B1BB']
overlay=Image.open(picks/'01-wooden/references/studs-overlay-user.png').convert('RGBA')
pattern=Image.new('RGBA',(1500,1500))
for y in range(3):
 for x in range(3): pattern.paste(overlay,(x*500,y*500))
pattern=pattern.resize((1016,1016),Image.Resampling.LANCZOS)
atlas=Image.new('RGBA',(4096,2048))
for i,color in enumerate(colors):
 tile=Image.new('RGBA',(1024,1024),'#'+color)
 tile.alpha_composite(pattern,(4,4))
 atlas.paste(tile,((i%4)*1024,(i//4)*1024))
output=folder/'reference-wood-stone-studs-v01.png'
atlas.convert('RGB').save(output)
for key in ['01-wooden','02-stone']:
 shutil.copy2(output,picks/key/'textures'/output.name)
photos=[('codex-clipboard-e51973df-8f1f-4f54-bbd4-84221d5dc292.png','wooden-original-front.png'),('codex-clipboard-eb41fbc0-57fe-4712-aae7-3ff4e85f0eea.png','wooden-original-side.png')]
for source,target in photos:
 shutil.copy2(Path(r'C:\Users\dakem\AppData\Local\Temp')/source,picks/'01-wooden/references'/target)
print('Burnt orange wood / blue steel / grey stone atlas; studs pitch 0.55 units.')
