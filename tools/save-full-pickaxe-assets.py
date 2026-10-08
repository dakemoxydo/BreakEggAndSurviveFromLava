"""Update only Pickaxes within stored Assets XML and existing snapshots."""
import ast
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
snapshot=json.loads((ROOT/'.tools/organized-full-pickaxes-v03-snapshot.json').read_text(encoding='utf-8'))
def namespace_refs(node):
    node['id']=node['id'].replace('WORLD','PICKAXEPACK',1)
    for entry in node['properties'].values():
        if entry['type']=='Ref' and entry['value']!='null':entry['value']=entry['value'].replace('WORLD','PICKAXEPACK',1)
    color=node['properties'].pop('Color3',None)
    if color:
        r,g,b=[round(v*255) for v in color['value']]
        node['properties']['Color3uint8']={'type':'Color3uint8','value':(r<<16)|(g<<8)|b}
    if node['class']=='MeshPart':
        # Mesh geometry must retain its intrinsic dimensions, not only Part.Size.
        mesh_id=node['properties'].get('MeshId',{}).get('value')
        matches=[r for r in json.loads((ROOT/'.tools/imported-full-pickaxes-v03.json').read_text(encoding='utf-8')) if r['mesh']==mesh_id]
        if matches:node['properties']['InitialSize']={'type':'Vector3','value':matches[0]['meshSize']}
    for child in node['children']:namespace_refs(child)
namespace_refs(snapshot)
tree=ast.parse((ROOT/'tools/build-world.py').read_text(encoding='utf-8'))
namespace={}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.FunctionDef))],type_ignores=[]),'serializer','exec'),namespace)
path=ROOT/'assets/exports/roblox/AssetTemplates.rbxmx'
backup=ROOT/'.tools/AssetTemplates-before-full-pickaxes-v03.rbxmx'
if not backup.exists():shutil.copy2(path,backup)
document=ET.parse(path)
def name(element):return element.find("Properties/string[@name='Name']").text
assets=document.getroot().find('Item')
items=next(c for c in assets.findall('Item') if name(c)=='Items')
existing=next(c for c in items.findall('Item') if name(c)=='Pickaxes')
items.remove(existing);items.append(namespace['item'](snapshot))
document.write(path,encoding='utf-8',xml_declaration=True)
for file in ['.tools/organized-assets-snapshot.json','.tools/world-snapshot.json']:
    path=ROOT/file
    if not path.exists():continue
    data=json.loads(path.read_text(encoding='utf-8'))
    asset_root=data[1] if isinstance(data,list) else data
    items=next(c for c in asset_root['children'] if c['properties']['Name']['value']=='Items')
    index=next(i for i,c in enumerate(items['children']) if c['properties']['Name']['value']=='Pickaxes')
    items['children'][index]=snapshot
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for file in (ROOT/'assets/items/pickaxes').glob('*/asset.json'):
    data=json.loads(file.read_text(encoding='utf-8'))
    runtime=json.loads((ROOT/'.tools/imported-full-pickaxes-v03.json').read_text(encoding='utf-8'))
    row=next(r for r in runtime if r['key']==data['key'])
    data['reviewModel']['runtimeReplaced']=True
    data['studioImportPackage'].update(importedToRoblox=True,meshId=row['mesh'],textureId=row['texture'],
        templatePath='ReplicatedStorage.PickaxeModels.'+data['key'],
        sourcePath='ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03.'+row['name'])
    file.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
path=ROOT/'assets/items/pickaxes/pack/exports/roblox-import-v03/manifest.json'
data=json.loads(path.read_text(encoding='utf-8'));data['robloxImported']=True
for record in data['models']:
    row=next(r for r in runtime if r['key']==record['assetKey'])
    record.update(importedToRoblox=True,meshId=row['mesh'],textureId=row['texture'])
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Saved Assets pickaxes, scene snapshots and imported IDs without rebuilding the map.')
