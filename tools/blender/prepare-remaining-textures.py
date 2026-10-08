"""Prepare a themed flat dark-studs atlas for one pickaxe at a time."""
import ast
import math
import sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
tree=ast.parse((ROOT/'tools/blender/create-remaining-pickaxe.py').read_text(encoding='utf-8'))
config=ast.literal_eval(next(n.value for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='CONFIG' for t in n.targets)))
key=sys.argv[1]
tier,colors=config[key]
folder=ROOT/'assets/items/pickaxes/pack/textures'
source=Image.open(folder/'pickaxes-dark-studs-v01.png').convert('RGB')
old=['AA5230','D17B46','783A27','48251D','526B8E','95ABC8','727C88','A4AFBB']
atlas=Image.new('RGB',source.size)
for i,color in enumerate(colors):
    x,y=i%4*1024,i//4*1024
    red=source.crop((x,y,x+1024,y+1024)).getchannel('R')
    base=int(old[i][:2],16)
    if key=='Galaxy' and i in (0,1,6,7):
        # Broad nebula ribbons modulated by the existing studs shading.
        pixels=red.load();tile=Image.new('RGB',(1024,1024));out=tile.load()
        for v in range(1024):
            for u in range(1024):
                wave=.5+.5*math.sin(u*.008+v*.006+1.8*math.sin(v*.010)+i)
                cyan=max(0,(wave-.52)/.48);pink=max(0,(.40-wave)/.40)
                rgb=(74+120*pink,42+160*cyan,143+70*cyan+70*pink)
                shading=pixels[u,v]/base
                out[u,v]=tuple(min(255,round(c*shading)) for c in rgb)
        atlas.paste(tile,(x,y))
    else:
        channels=[red.point([min(255,round(v*int(color[j:j+2],16)/base)) for v in range(256)]) for j in (0,2,4)]
        atlas.paste(Image.merge('RGB',channels),(x,y))
atlas.save(folder/('%s-dark-studs-v01.png'%key.lower()))
print(key+' themed atlas prepared.')
