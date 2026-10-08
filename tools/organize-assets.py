"""Migrate project assets into explicit categories with a checked, reversible move ledger."""
import hashlib
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
assets = (root / 'assets').resolve()
old_pickaxes = assets / 'ui/pickaxes-studs-v01'
catalog_source = old_pickaxes / 'designs.json'
assert catalog_source.exists(), 'Migration already performed or source missing.'
catalog = json.loads(catalog_source.read_text(encoding='utf-8'))
mapping = {}

def add(source, destination):
    mapping['assets/' + source] = 'assets/' + destination

for item in catalog['items']:
    group = f"{item['tier']:02d}-{item['key'].lower()}"
    item['folder'] = group
    old_name = item['filename']
    item['filename'] = f'{group}/references/{old_name}'
    add(f'ui/pickaxes-studs-v01/{old_name}', f'items/pickaxes/{item["filename"]}')
    item['referenceImage'] = item['filename']
    for role in ('models', 'textures', 'icons', 'exports'):
        item[role + 'Directory'] = f'{group}/{role}'
for prompt in old_pickaxes.glob('*-prompt.txt'):
    key = prompt.name.split('-v')[0]
    item = next(item for item in catalog['items'] if item['key'].lower() == key)
    add('ui/pickaxes-studs-v01/' + prompt.name, f'items/pickaxes/{item["folder"]}/references/{prompt.name}')
add('ui/pickaxes-studs-v01/09-candy-pickaxe-studs-v01.png', 'items/pickaxes/09-candy/references/archive/09-candy-pickaxe-studs-v01.png')
add('ui/pickaxes-studs-v01/designs.json', 'items/pickaxes/catalog.json')
add('ui/pickaxes-studs-v01/README.md', 'items/pickaxes/README.md')
add('ui/pickaxes-studs-v01/pickaxes-overview-v01.jpg', 'items/pickaxes/previews/pickaxes-overview-v01.jpg')
add('ui/pickaxes-studs-v01/pickaxes-studs-v01.zip', 'items/pickaxes/exports/pickaxes-studs-v01.zip')

navigation = ['cart.png', 'egg.png', 'index.png', 'pets.png', 'settings-gear.png', 'reference-egg-v1.png', 'reference-home-v1.png', 'reference-index-v1.png', 'reference-paw-v1.png']
for name in navigation: add('ui/' + name, 'ui/icons/navigation/' + name)
add('ui/cash.png', 'ui/icons/resources/cash.png')
for name in ['simulator-atlas-v1.png', 'offers-atlas-v1.png', 'pets-tools-atlas-v2.png']:
    add('ui/' + name, 'ui/atlases/' + name)
add('ui/sunburst.png', 'ui/effects/sunburst.png')
add('studtexture.png', 'ui/textures/studtexture.png')
add('reference/video-contact.jpg', 'reference/gameplay/video-contact.jpg')
add('world/ReferenceMap.rbxmx', 'environment/maps/exports/ReferenceMap.rbxmx')
for name in ['ReferenceLighting.rbxmx', 'ReferenceClouds.rbxmx']:
    add('world/' + name, 'environment/lighting/exports/' + name)
for name in ['HDStudsMaterial.rbxmx', 'HD-Studs-LICENSE.txt', 'hd-studs-2x2-normal.png', 'hd-studs-2x2-ao.png']:
    add('world/' + name, 'environment/materials/hd-studs/' + name)
add('world/LavaBat.rbxmx', 'items/bats/lava-bat/exports/LavaBat.rbxmx')
add('world/AssetTemplates.rbxmx', 'exports/roblox/AssetTemplates.rbxmx')
for name in ['reference-assets.json', 'ui-manifest.json']:
    add(name, 'manifests/' + name)
for name in ['ui-source-bundle.json', 'sourcemap.json', 'bundle.json']:
    add(name, 'exports/ui/' + name)
for name in ['ShopButton.luau', 'cart.png', 'cart-generated-v2.png', 'cart-generated-v3.png']:
    add(name, 'archive/legacy-ui/' + name)
mapping['assets/package_bundle.py'] = 'tools/assets/package-ui-bundle.py'
for name in ['update_style.py', 'add_shine.py', 'draw_cart.py']:
    mapping['assets/' + name] = 'tools/archive/ui/' + name

# Resolve and validate every path before performing any move.
plan = []
for old, new in mapping.items():
    source, destination = (root / old).resolve(), (root / new).resolve()
    assert source.is_relative_to(assets), f'Source outside assets: {source}'
    assert destination.is_relative_to(root), f'Destination outside project: {destination}'
    assert source.is_file(), f'Missing source: {source}'
    assert not destination.exists(), f'Destination already exists: {destination}'
    plan.append({'from': old, 'to': new, 'sha256': hashlib.sha256(source.read_bytes()).hexdigest()})
original_files = {str(path.relative_to(root)).replace('\\', '/') for path in assets.rglob('*') if path.is_file()}
assert original_files == set(mapping), f'Unclassified assets: {original_files - set(mapping)}'
ledger = root / '.tools/asset-layout-migration.json'
ledger.parent.mkdir(parents=True, exist_ok=True)
ledger.write_text(json.dumps({'moves': plan, 'state': 'validated-before-move'}, indent=2), encoding='utf-8')
for entry in plan:
    source, destination = root / entry['from'], root / entry['to']
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(source), str(destination))
    assert hashlib.sha256(destination.read_bytes()).hexdigest() == entry['sha256']

for group in ['items/bats/lava-bat', 'items/eggs', 'pets', 'environment/props', 'environment/treadmills']:
    for role in ['references', 'models', 'textures', 'icons', 'exports']:
        (assets / group / role).mkdir(parents=True, exist_ok=True)
for directory in ['audio/music', 'audio/sfx', 'animations/characters', 'animations/pets', 'animations/items', 'reference/screenshots', 'reference/videos']:
    (assets / directory).mkdir(parents=True, exist_ok=True)
for item in catalog['items']:
    base = assets / 'items/pickaxes' / item['folder']
    for role in ['references', 'models', 'textures', 'icons', 'exports']:
        (base / role).mkdir(parents=True, exist_ok=True)
    (base / 'asset.json').write_text(json.dumps({
        'tier': item['tier'], 'key': item['key'], 'nameRu': item['nameRu'],
        'referenceImage': 'references/' + Path(item['filename']).name,
        'imageStatus': item['imageStatus'], 'modelStatus': 'awaiting-user-approval',
        'generator': catalog['generator'], 'prompt': item.get('generationPrompt', item['prompt']),
        'directories': {'models': 'models', 'textures': 'textures', 'icons': 'icons', 'exports': 'exports'}
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(assets / 'items/pickaxes/catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def update_value(value, asset_relative=False):
    if isinstance(value, dict): return {key: update_value(item, asset_relative) for key, item in value.items()}
    if isinstance(value, list): return [update_value(item, asset_relative) for item in value]
    if isinstance(value, str):
        if value in mapping: return mapping[value]
        if asset_relative and 'assets/' + value in mapping:
            return mapping['assets/' + value].removeprefix('assets/')
    return value
for path, relative in [(root / 'release.project.json', False), (assets / 'manifests/reference-assets.json', False), (assets / 'manifests/ui-manifest.json', True)]:
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    path.write_text(json.dumps(update_value(data, relative), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
for path in [root / 'README.md', root / 'docs/reference-recreation.md']:
    text = path.read_text(encoding='utf-8')
    for old, new in mapping.items(): text = text.replace(old, new)
    text = text.replace('assets/world/*.rbxmx', 'assets/environment/ и assets/items/ (экспорты .rbxmx)')
    path.write_text(text, encoding='utf-8')

# Empty previous categories only; never remove assets recursively.
for old_dir in [assets / 'ui/pickaxes-studs-v01', assets / 'world']:
    assert old_dir.resolve().is_relative_to(assets)
    if old_dir.exists(): old_dir.rmdir()
ledger.write_text(json.dumps({'moves': plan, 'state': 'completed'}, indent=2), encoding='utf-8')
print(json.dumps({'moved': len(plan), 'pickaxeFolders': len(catalog['items']), 'allMoveHashesVerified': True, 'ledger': str(ledger)}))
