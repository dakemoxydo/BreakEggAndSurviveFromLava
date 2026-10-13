"""Persist imported Roblox IDs and grip anchors in the Rojo-owned templates."""
import sys
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'.tools/imported-full-pickaxes-v03.json').read_text(encoding='utf-8'))
manifest=json.loads((ROOT/'assets/items/pickaxes/pack/exports/roblox-import-v03/manifest.json').read_text(encoding='utf-8'))
expected={r['assetKey']:r for r in manifest['models']}
assert len(rows)==18 and {r['key'] for r in rows}==set(expected)
sys.path.insert(0,str(ROOT/'tools'))
import roblox_xml
namespace={'item':roblox_xml.item}
def prop(kind,value):return {'type':kind,'value':value}
def cf(x=0,y=0,z=0):return [x,y,z,1,0,0,0,1,0,0,0,1]
children=[]
for row in sorted(rows,key=lambda r:expected[r['key']]['tier']):
    key=row['key'];record=expected[key]
    assert row['mesh'].startswith('rbxassetid://') and row['texture'].startswith('rbxassetid://')
    assert max(abs(a-b) for a,b in zip(row['size'],record['sizeStuds']))<.001
    assert abs(row['gripOffset'][0])<.0001 and abs(row['gripOffset'][2])<.0001
    center=-row['gripOffset'][1]
    node={'id':'PICKAXE_'+key,'class':'MeshPart','properties':{
        'Name':prop('string',key),'MeshId':prop('Content',row['mesh']),'TextureID':prop('Content',row['texture']),
        'Size':prop('Vector3',row['size']),'InitialSize':prop('Vector3',row['meshSize']),
        'CFrame':prop('CoordinateFrame',cf(y=center)),
        'PivotOffset':prop('CoordinateFrame',cf(y=-center)),
        'Color3uint8':prop('Color3uint8',16777215),'Material':prop('token',256),
        'Anchored':prop('bool',True),'CanCollide':prop('bool',False),'CanTouch':prop('bool',False),
        'CanQuery':prop('bool',False),'Massless':prop('bool',True),'Transparency':prop('float',0),
        'CastShadow':prop('bool',True)},
        'attributes':{'AssetKey':prop('string',key),'Tier':prop('float',record['tier']),
                      'SourcePackVersion':prop('string','v03'),'SourceMeshName':prop('string',row['name'])},
        'children':[{'id':'PICKAXE_HEAD_'+key,'class':'Attachment',
            'properties':{'Name':prop('string','PickaxeHead'),'CFrame':prop('CoordinateFrame',cf(y=2.75-center))},
            'attributes':{},'children':[]}]}
    children.append(node)
root={'id':'PICKAXES_V03','class':'Folder','properties':{'Name':prop('string','PickaxeModels')},'attributes':{},'children':children}
path=ROOT/'assets/items/pickaxes/pack/exports/PickaxeModels.rbxmx'
backup=ROOT/'.tools/PickaxeModels-before-full-v03.rbxmx'
if not backup.exists():shutil.copy2(path,backup)
document=ET.Element('roblox',{'version':'4'});document.append(namespace['item'](root))
ET.ElementTree(document).write(path,encoding='utf-8',xml_declaration=True)
(ROOT/'.tools/pickaxe-runtime-v03-snapshot.json').write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Saved 18 Rojo templates with imported IDs, white colors, grip pivots and head attachments.')
