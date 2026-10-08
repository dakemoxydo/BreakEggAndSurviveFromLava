"""Preserve generated approval concepts and their provenance without changing pixels."""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = root / 'assets/items/pickaxes'
library = Path(r'C:/Users/dakem/Documents/RobloxGames/Assets/Games/BreakEggAndSurviveFromLava/PickaxeConcepts/studs-v01')
parser = argparse.ArgumentParser()
parser.add_argument('tier', type=int)
parser.add_argument('source')
parser.add_argument('--version', type=int, default=1)
parser.add_argument('--approved', action='store_true')
parser.add_argument('--prompt-file')
args = parser.parse_args()
manifest_path = folder / 'catalog.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
item = manifest['items'][args.tier - 1]
name = f"{args.tier:02d}-{item['key'].lower()}-pickaxe-studs-v{args.version:02d}.png"
group = item.get('folder', f"{args.tier:02d}-{item['key'].lower()}")
reference = f'{group}/references/{name}'
folder.mkdir(parents=True, exist_ok=True)
library.mkdir(parents=True, exist_ok=True)
source = Path(args.source)
for dest in [folder / reference, library / name]:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.read_bytes() != source.read_bytes():
        raise RuntimeError(f'Refusing to overwrite another image: {dest}')
    shutil.copy2(source, dest)
with Image.open(source) as image:
    alpha = image.getchannel('A') if image.mode == 'RGBA' else None
    item['imageProperties'] = {'size': list(image.size), 'mode': image.mode,
        'alphaExtrema': list(alpha.getextrema()) if alpha else None,
        'visibleBounds': list(alpha.getbbox()) if alpha and alpha.getbbox() else None}
item['filename'] = reference
item['referenceImage'] = reference
item['source'] = str(source)
item['imageStatus'] = 'approved' if args.approved else 'awaiting-user-approval'
if args.prompt_file:
    item['generationPrompt'] = Path(args.prompt_file).read_text(encoding='utf-8')
manifest['status'] = 'concept-generation-in-progress'
manifest['modelingStatus'] = 'awaiting-user-approval'
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
library_manifest = json.loads(json.dumps(manifest))
for entry in library_manifest['items']:
    entry['filename'] = Path(entry['filename']).name
(library / 'designs.json').write_text(json.dumps(library_manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'tier': args.tier, 'filename': name, **item['imageProperties']}))
