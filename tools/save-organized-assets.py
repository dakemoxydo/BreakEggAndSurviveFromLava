"""Save an Assets-only Studio snapshot without rewriting the map or place."""
import ast
import json
import xml.etree.ElementTree as ET
from pathlib import Path

project = Path(__file__).resolve().parents[1]
source = ast.parse((project / 'tools/build-world.py').read_text(encoding='utf-8'))
# Reuse the XML serializers without executing the full-world export operations.
definitions = [node for node in source.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
namespace = {}
exec(compile(ast.Module(body=definitions, type_ignores=[]), 'build-world serializers', 'exec'), namespace)
snapshot = json.loads((project / '.tools/organized-assets-snapshot.json').read_text(encoding='utf-8'))
def namespace_refs(node):
    node['id'] = node['id'].replace('WORLD', 'ASSET', 1)
    for entry in node['properties'].values():
        if entry['type'] == 'Ref' and entry['value'] != 'null':
            entry['value'] = entry['value'].replace('WORLD', 'ASSET', 1)
    for child in node['children']:
        namespace_refs(child)

namespace_refs(snapshot)
root = ET.Element('roblox', {'version': '4'})
root.append(namespace['item'](snapshot))
ET.ElementTree(root).write(project / 'assets/exports/roblox/AssetTemplates.rbxmx', encoding='utf-8', xml_declaration=True)
# Keep the asset root in the existing world snapshot current for later exports.
world_path = project / '.tools/world-snapshot.json'
if world_path.exists():
    world = json.loads(world_path.read_text(encoding='utf-8'))
    world[1] = snapshot
    world_path.write_text(json.dumps(world), encoding='utf-8')
print('Saved organized ServerStorage.Assets templates')
