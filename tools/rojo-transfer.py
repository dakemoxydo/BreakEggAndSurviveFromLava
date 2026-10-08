"""Read canonical Rojo output for an MCP fallback when new mappings are not applied."""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = ET.parse(Path(__file__).parents[1] / '.tools/reference-game.rbxlx').getroot()
scripts = []

def walk(item, ancestors):
    properties = item.find('Properties')
    name = next((p.text for p in properties if p.attrib.get('name') == 'Name'), '')
    path = ancestors + [name]
    kind = item.attrib['class']
    if kind in ('Script', 'LocalScript', 'ModuleScript') and 'Packages' not in path and 'ServerPackages' not in path:
        source = next((p.text for p in properties if p.attrib.get('name') == 'Source'), '')
        scripts.append({'path': path, 'class': kind, 'source': source})
    for child in item.findall('Item'):
        walk(child, path)

for item in root.findall('Item'):
    walk(item, [])
if len(sys.argv)>1:
    wanted=set(sys.argv[1:])
    scripts=[s for s in scripts if s['path'][-1] in wanted]
print(json.dumps(scripts, ensure_ascii=True))
