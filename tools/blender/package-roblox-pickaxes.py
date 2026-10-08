"""Package the verified two-pickaxe import bundle and register canonical paths."""
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PICKS=ROOT/'assets/items/pickaxes'
PACK=PICKS/'pack'
DEST=PACK/'exports/roblox-import-v01'
manifest=json.loads((DEST/'manifest.json').read_text())
validation=json.loads((DEST/'validation.json').read_text())
assert len(manifest['models'])==2 and len(validation['files'])==6
manifest['importSettings'].update({'Merge Meshes':False,'Use Imported Pivot':True})
manifest['validation']='All six FBX/GLB exports re-imported in Blender; two final named models only, scales, pivots, texture and UV verified.'
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(DEST/'README_IMPORT.md').write_text('''# Пак кирок для импорта в Roblox

В паке две актуальные модели: **WoodenPickaxe** (деревянная v04, 528 треугольников) и **StonePickaxe** (каменная v01, 464 треугольника). Встроенная текстура содержит цвет и плоские studs. Предыдущих вариантов, черновиков, камер и света в FBX/GLB нет.

## Импорт всего пака

1. Распакуйте ZIP целиком в одну папку.
2. В Roblox Studio откройте **File → Import** и выберите **Pickaxes_Wooden_Stone.fbx**.
3. Установите **Scale Unit = Stud/Studs**, масштаб **1**, **World Up = Top**, **World Forward = Front**. Оставьте **Merge Meshes выключенным**, чтобы кирки остались отдельными MeshPart.
4. У каждого дочернего объекта оставьте **Use Imported Pivot включённым**: точка начала модели находится на рукояти в месте хвата. Укажите владельца игры в **Creator**, если загружаете ассеты с ID.
5. Проверьте две кирки в превью и нажмите **Import**.

При импорте отдельных кирок используйте `models/WoodenPickaxe.fbx` и `models/StonePickaxe.fbx`. Их pivot находится в (0, 0, 0). В общем файле кирки расставлены рядом, каждая сохраняет свой pivot.

Настройки сверены с [руководством Roblox по Blender](https://create.roblox.com/docs/art/blender) и [документацией Importer](https://create.roblox.com/docs/studio/importer).

## Файлы

- `Pickaxes_Wooden_Stone.fbx` — основной файл: две именованные модели, текстура встроена, FBX Unit Scale, масштаб 1, Y Up.
- `Pickaxes_Wooden_Stone.glb` — альтернативный формат с встроенной текстурой.
- `models/` — отдельные FBX и GLB каждой кирки.
- `textures/Pickaxes_Studs.png` — общий цветовой атлас 4096×2048. Если текстура не подтянулась автоматически, используйте этот файл как цветовую текстуру модели; дополнительная окраска не нужна.
- `source/Pickaxes_Import.blend` — чистый Blender-файл из двух мешей с упакованной текстурой. Обе кирки отмечены как Blender Assets.
- `icons/` — прозрачные изображения кирок для магазина.
- `preview.png` — сравнение двух моделей.
- `manifest.json`, `validation.json`, `SHA256SUMS.txt` — состав, результат проверки и контрольные суммы.

## Контроль размеров в Studio

Размеры указаны в studs, порядок **X × Y × Z**:

| Модель | Размер |
| --- | --- |
| WoodenPickaxe | 5.32 × 4.785 × 1.39 |
| StonePickaxe | 4.94 × 4.655 × 0.85 |

FBX и GLB повторно импортированы в Blender: количество моделей, размеры, точки начала, UV и текстура сохранены. Фактический импорт и загрузка в Roblox Studio ещё не выполнялись. Пак содержит визуальные модели; настройка Roblox Tool и игрового поведения выполняется отдельно.
''',encoding='utf-8')
files=['README_IMPORT.md','Pickaxes_Wooden_Stone.fbx','Pickaxes_Wooden_Stone.glb',
       'models/WoodenPickaxe.fbx','models/WoodenPickaxe.glb','models/StonePickaxe.fbx','models/StonePickaxe.glb',
       'textures/Pickaxes_Studs.png','source/Pickaxes_Import.blend','icons/WoodenPickaxe.png','icons/StonePickaxe.png',
       'preview.png','manifest.json','validation.json']
checksums=[]
for relative in files:
    path=DEST/relative
    assert path.is_file() and path.stat().st_size>0
    checksums.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+relative)
(DEST/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n',encoding='utf-8')
files.append('SHA256SUMS.txt')
archive=PACK/'exports/pickaxes-wooden-stone-roblox-v01.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as package:
    for relative in files: package.write(DEST/relative,'Pickaxes_Wooden_Stone/'+relative)
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert len(package.namelist())==len(files)
    for line in checksums:
        expected,relative=line.split('  ',1)
        assert hashlib.sha256(package.read('Pickaxes_Wooden_Stone/'+relative)).hexdigest()==expected

# Media extracted by Blender's FBX validation is a cache, not an import dependency.
cache=ROOT/'.tools/pickaxe-import-validation-media'
for folder in list(DEST.rglob('*.fbm')):
    source=folder.resolve()
    assert source.is_relative_to(DEST.resolve())
    target=(cache/folder.relative_to(DEST)).resolve()
    assert target.is_relative_to((ROOT/'.tools').resolve())
    assert not target.exists()
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.move(str(source),str(target))

registration={'status':'prepared-for-import','archive':'pack/exports/'+archive.name,
              'fbx':'pack/exports/roblox-import-v01/Pickaxes_Wooden_Stone.fbx',
              'instructions':'pack/exports/roblox-import-v01/README_IMPORT.md','assetKeys':['Wooden','Stone'],
              'robloxImported':False}
path=PACK/'manifest.json';data=json.loads(path.read_text());data['importPackage']=registration
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for name in ['01-wooden','02-stone']:
    path=PICKS/name/'asset.json';data=json.loads(path.read_text(encoding='utf-8'));data['importPackage']=registration
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
path=PACK/'README.md';text=path.read_text(encoding='utf-8')
if '## Пак для импорта' not in text:
    text+='\n## Пак для импорта\n\n`exports/pickaxes-wooden-stone-roblox-v01.zip` — проверенный архив из двух актуальных кирок. Основной файл: `exports/roblox-import-v01/Pickaxes_Wooden_Stone.fbx`. Инструкция: `exports/roblox-import-v01/README_IMPORT.md`.\n'
path.write_text(text,encoding='utf-8')
global_root=Path(r'C:\Users\dakem\Documents\RobloxGames\Assets')
library=global_root/'Games/BreakEggAndSurviveFromLava/Pickaxes/pack'
target=library/'exports'/archive.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(archive,target)
for relative in files:
    target=library/'exports/roblox-import-v01'/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(DEST/relative,target)
for relative in ['README.md','manifest.json']: shutil.copy2(PACK/relative,library/relative)
index=global_root/'asset-index.md';text=index.read_text(encoding='utf-8')
entry='- `Games/BreakEggAndSurviveFromLava/Pickaxes/pack/exports/pickaxes-wooden-stone-roblox-v01.zip` — готовый пакет импорта Wooden v04 + Stone v01, общий именованный FBX, отдельные FBX/GLB, упакованная studs-текстура, чистый Blender-файл, иконки и инструкция. Проверены 6 экспортов; в Studio не импортирован.'
if entry not in text: index.write_text(text.rstrip()+'\n\n'+entry+'\n',encoding='utf-8')
print(json.dumps({'archive':str(archive),'sizeBytes':archive.stat().st_size,'files':len(files),'verified':True}))
