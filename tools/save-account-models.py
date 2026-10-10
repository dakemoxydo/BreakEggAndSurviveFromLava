"""Regenerate current map, Assets and runtime pickaxes from a fresh Studio snapshot."""
import ast
import copy
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
roots = json.loads((ROOT / '.tools/world-snapshot.json').read_text(encoding='utf-8'))
source = ast.parse((ROOT / 'tools/build-world.py').read_text(encoding='utf-8'))
definitions = [node for node in source.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
namespace = {}
exec(compile(ast.Module(body=definitions, type_ignores=[]), 'world serializer', 'exec'), namespace)

def child(node, name):
    return next(value for value in node['children'] if value['properties']['Name']['value'] == name)

def write_model(relative, node):
    root = ET.Element('roblox', {'version': '4'})
    root.append(namespace['item'](node))
    ET.ElementTree(root).write(ROOT / relative, encoding='utf-8', xml_declaration=True)

map_node, assets_node = roots[0], roots[1]
assert map_node['properties']['Name']['value'] == 'Map'
assert assets_node['properties']['Name']['value'] == 'Assets'
pickaxes = child(child(assets_node, 'Items'), 'Pickaxes')
templates = child(pickaxes, 'Templates')
assert len(templates['children']) == 18
runtime = copy.deepcopy(templates)
runtime['properties']['Name']['value'] = 'PickaxeModels'

def runtime_refs(node):
    node['id'] = 'RUNTIME_' + node['id']
    for entry in node['properties'].values():
        if entry['type'] == 'Ref' and entry['value'] != 'null':
            entry['value'] = 'RUNTIME_' + entry['value']
    for descendant in node['children']:
        runtime_refs(descendant)

runtime_refs(runtime)
write_model('assets/items/pickaxes/pack/exports/PickaxeModels.rbxmx', runtime)
write_model('assets/exports/roblox/AssetTemplates.rbxmx', assets_node)
write_model('assets/environment/maps/exports/ReferenceMap.rbxmx', map_node)

rows = []
for model in templates['children']:
    props = model['properties']
    rows.append({'key': props['Name']['value'], 'mesh': props['MeshId']['value'],
                 'texture': props['TextureID']['value'], 'meshSize': props['InitialSize']['value']})

for path in (ROOT / 'assets/items/pickaxes').glob('*/asset.json'):
    data = json.loads(path.read_text(encoding='utf-8'))
    row = next((value for value in rows if value['key'] == data['key']), None)
    if row:
        data['studioImportPackage'].update(meshId=row['mesh'], textureId=row['texture'], importedToRoblox=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

package_path = ROOT / 'assets/items/pickaxes/pack/exports/roblox-import-v03/manifest.json'
package = json.loads(package_path.read_text(encoding='utf-8'))
for model in package['models']:
    row = next(value for value in rows if value['key'] == model['assetKey'])
    model.update(meshId=row['mesh'], textureId=row['texture'], importedToRoblox=True)
package['robloxImported'] = True
package['creatorId'] = 11789507527
package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

treadmill = child(child(child(assets_node, 'Environment'), 'Treadmills'), 'TreadmillLvl1')
treadmill_rows = [{'name': p['properties']['Name']['value'], 'mesh': p['properties']['MeshId']['value'],
                   'texture': p['properties']['TextureID']['value'], 'meshSize': p['properties']['InitialSize']['value']}
                  for p in treadmill['children'] if p['class'] == 'MeshPart']
account_path = ROOT / 'assets/manifests/account-reimport.json'
account = json.loads(account_path.read_text(encoding='utf-8'))
account['pickaxes'] = rows
account['treadmill'] = {'widthStuds': 7, 'stations': 7, 'meshes': treadmill_rows}
account['status'] = 'Images, 18 pickaxes and 7 treadmill stations rebound; Lava Bat remains on previous mesh IDs.'
account_path.write_text(json.dumps(account, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'pickaxes': len(rows), 'treadmillMeshes': len(treadmill_rows), 'exports': ['Map', 'Assets', 'PickaxeModels']}))
