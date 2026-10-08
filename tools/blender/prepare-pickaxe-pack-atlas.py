"""Create a shared portable palette using the approved flat studs overlay."""
from pathlib import Path
from PIL import Image
import json

ROOT=Path(__file__).resolve().parents[2]
PACK=ROOT/'assets/items/pickaxes/pack'
PACK.mkdir(exist_ok=True)
(PACK/'textures').mkdir(exist_ok=True)
palette={
 'wood':'BF6120','woodLight':'EF8E30','woodDark':'843914','walnut':'532915',
 'steelDark':'263443','steel':'697C90','silver':'B0C1D2','ivory':'EFE5CB',
 'gold':'F3B625','goldDark':'B56F08','goldLight':'FFE779','emerald':'10B95B',
 'cyan':'10C3EC','cyanLight':'88F3FF','navy':'162B65','blue':'275DDB',
 'red':'EA263F','redDark':'870D30','pink':'F75AAC','pinkLight':'FFB4DC',
 'green':'4EB82A','greenLight':'A9E75A','greenDark':'1E682B','copper':'D77626',
 'orange':'FF6F16','yellow':'FFDB2C','purple':'8242E9','violet':'4A2394',
 'magenta':'F02DDD','black':'171B28','white':'F8FAFF','ice':'BADFFF',
 'neon':'96F52C','teal':'165A68','tealLight':'31D5BF','lavender':'BBA1FF',
 'cream':'FFF0BC','darkPurple':'2E163F','cyanDeep':'076E99','brown':'9C5029',
}
texture=Image.open(ROOT/'assets/items/pickaxes/01-wooden/references/studs-overlay-user.png').convert('RGBA')
repeat=Image.new('RGBA',(3000,3000))
for y in range(6):
 for x in range(6): repeat.paste(texture,(500*x,500*y))
repeat=repeat.resize((504,504),Image.Resampling.LANCZOS)
atlas=Image.new('RGBA',(4096,2560))
for i,color in enumerate(palette.values()):
 tile=Image.new('RGBA',(512,512),'#'+color)
 tile.alpha_composite(repeat,(4,4))
 atlas.paste(tile,((i%8)*512,(i//8)*512))
atlas.convert('RGB').save(PACK/'textures/pickaxes-studs-atlas-v01.png')
(PACK/'textures/palette-v01.json').write_text(json.dumps(palette,indent=2),encoding='utf-8')
print('Shared atlas: 40 colors, 4096x2560, flat studs at 0.25 unit pitch.')
