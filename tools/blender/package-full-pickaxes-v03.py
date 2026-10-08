"""Package the complete 18-model FBX delivery and update canonical records."""
import json
import hashlib
import shutil
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'assets/items/pickaxes'
PACK=ASSETS/'pack'
OUT=PACK/'exports/roblox-import-v03'
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
inspection=json.loads((OUT/'export-inspection.json').read_text(encoding='utf-8'))
assert inspection['passed'] and len(manifest['models'])==18
assert sorted(r['tier'] for r in manifest['models'])==list(range(1,19))
names={json.loads(p.read_text(encoding='utf-8'))['key']:json.loads(p.read_text(encoding='utf-8'))['nameRu'] for p in ASSETS.glob('*/asset.json')}
manifest['models'].sort(key=lambda r:r['tier'])
manifest['completePack']=True
manifest['inspection']='export-inspection.json'
manifest['readme']='README_IMPORT.md'
manifest['geometryAudit']='attachment-audit.json'
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(PACK/'previews/pack-attachment-audit-v20.json',OUT/'attachment-audit.json')
shutil.copy2(PACK/'previews/pack-full-18-review-v02.png',OUT/'preview.png')
shutil.copy2(PACK/'previews/diamond-detail-review-v02.png',OUT/'diamond-preview.png')
readme='''# Полный пак кирок для Roblox Studio — v03

В этом паке **18 кирок**, включая алмазную. Источник — `pickaxes-asset-pack-review-v20.blend`, сцена `Pickaxe_Pack_Review`. Каждая кирка экспортирована одним отдельным именованным мешем с одним материалом и одной UV-развёрткой. Цвет, тёмные studs и гранёные вставки запечены в индивидуальные PNG 2048×2048. Выпуклой studs-геометрии нет.

## Импорт всего пака

1. Распакуйте ZIP целиком. В Studio откройте **File → Import** и выберите **Pickaxes_Pack.fbx**.
2. Установите **Scale Unit = Studs**, масштаб **1**, **World Up = Top**, **World Forward = Front**.
3. Оставьте **Merge Meshes выключенным**: в превью должны быть 18 отдельных MeshPart. У каждого объекта оставьте **Use Imported Pivot включённым**. Точка начала каждого меша находится в месте хвата рукояти.
4. Для первоначальной расстановки включите **Anchored**. Если хотите загрузить ассеты в аккаунт или группу игры, укажите нужного **Creator**. Перед импортом проверьте состав и цветные текстуры в превью.
5. Нажмите **Import**. Общий файл содержит кирки в одном ряду с шагом 6.5 studs. Для импорта отдельных кирок используйте файлы в `models/` — их точка хвата находится в (0, 0, 0).

Параметры соответствуют [документации Roblox Importer](https://create.roblox.com/docs/studio/importer) и [рекомендациям Roblox по Blender](https://create.roblox.com/docs/art/blender). FBX экспортирован с Apply Scaling = FBX Unit Scale, Scale = 1, Y Up, Z Forward; численные размеры мешей сохранены для Scale Unit = Studs.

## Текстуры

PNG встроены в FBX и лежат отдельно в `textures/`. Если Studio не подхватил цвет автоматически, загрузите PNG нужной кирки и назначьте его в **MeshPart.TextureID** либо **SurfaceAppearance.ColorMap**. Соответствия приведены в таблице ниже и `manifest.json`. У MeshPart оставьте белый Color, чтобы не тонировать запечённый атлас повторно. Прозрачность не требуется.

Атлас содержит цвет; свет от лавы, молнии или магических вставок дополнительно настраивается игровыми эффектами после импорта. Камеры, свет, история моделирования и Blender-шейдеры не входят в FBX.

## Файлы

- `Pickaxes_Pack.fbx` — основной полный пак, 18 отдельных мешей со встроенными текстурами.
- `models/` — 18 отдельных FBX.
- `textures/` — 18 индивидуальных цветовых PNG.
- `source/Pickaxes_Import.blend` — чистая экспортная сцена: 18 мешей с упакованными текстурами, без камер и света.
- `preview.png` и `diamond-preview.png` — общий ряд и крупный вид алмазной.
- `manifest.json` — ключи, размеры, треугольники, пути и настройки импорта.
- `export-inspection.json` — проверенный фактический состав бинарных FBX.
- `attachment-audit.json` — подтверждение креплений и закрытой геометрии всех 18 исходных кирок.
- `SHA256SUMS.txt` — контрольные суммы.

## Размеры и соответствия

Размеры указаны в studs: **X × Y × Z** в Studio. Файлы имеют названия `<Key>Pickaxe`; для текущего игрового кода шаблон MeshPart должен называться ровно `<Key>`, например `Wooden`, `Diamond`, `UFO`, и находиться в `ReplicatedStorage.PickaxeModels`. Сохраните исходные импорты в `ServerStorage.Assets.Items.Pickaxes.SourceImports`. Замена игровых шаблонов выполняется отдельно после проверки импорта.

| Кирка / ключ | MeshPart | Размер X × Y × Z | Треугольники | Текстура |
| --- | --- | --- | ---: | --- |
'''
for record in manifest['models']:
    key=record['assetKey'];size=' × '.join('%.3f'%v for v in record['sizeStuds'])
    readme+='| %s / `%s` | `%s` | %s | %d | `%s` |\n'%(names[key],key,record['name'],size,record['triangles'],record['texture'])
readme+='''
## Проверка

Бинарные FBX прочитаны без импорта в сцену: общий файл содержит 18 мешей и 18 встроенных PNG; каждый отдельный файл содержит ровно один меш, один материал и одну текстуру. Имена, число треугольников, единичные масштабы, локальные размеры, UV внутри атласа и нулевая точка начала отдельных файлов совпадают с экспортными данными. Всего 21 250 треугольников; максимум на одной кирке — 2 438. Проверка геометрии исходного ряда подтвердила связный граф креплений для каждой модели и закрытые поверхности.

Импорт и загрузка в Roblox ещё не выполнены. Игровые тесты и Play не запускались. После импорта вручную проверьте: 18 отдельных цветных кирок, размеры по таблице, правильную вертикальную ориентацию и сохранённую точку хвата. Хват и удар в игре проверяются после замены шаблонов.
'''
(OUT/'README_IMPORT.md').write_text(readme,encoding='utf-8')
for path in ASSETS.glob('*/asset.json'):
    data=json.loads(path.read_text(encoding='utf-8'))
    key=data['key'];record=next(r for r in manifest['models'] if r['assetKey']==key)
    review=data['reviewModel']
    review['blend']='../pack/models/pickaxes-asset-pack-review-v20.blend'
    review['preview']='../pack/previews/pack-full-18-review-v02.png'
    review['attachmentAudit']='../pack/previews/pack-attachment-audit-v20.json'
    review['attachmentStatus']='passed'
    if key=='Diamond':
        review.update(version='v02',status='awaiting-user-review',collection='05_Diamond_Review_v02',
            detailPreview='../pack/previews/diamond-detail-review-v02.png',presentInCurrentScene=True)
    data['studioImportPackage']=dict(version='v03',fbx='../pack/exports/roblox-import-v03/'+record['fbx'],
        texture='../pack/exports/roblox-import-v03/'+record['texture'],meshName=record['name'],
        runtimeKey=key,triangles=record['triangles'],sizeStuds=record['sizeStuds'],
        materialCount=1,uvSets=1,importedToRoblox=False,
        manifest='../pack/exports/roblox-import-v03/manifest.json')
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
path=ASSETS/'README.md';text=path.read_text(encoding='utf-8')
text=text.replace('review-v19.blend','review-v20.blend').replace('pack-18-slots-review-v01.png','pack-full-18-review-v02.png')
text=text.replace('pack-attachment-audit-v19.json','pack-attachment-audit-v20.json')
text=text.replace('В одном горизонтальном ряду расположены 17 моделей; шаг по X — 6.5. Слот 05 свободен после ручного удаления алмазной из живой сцены. Алмазная сохранена в `pack/models/pickaxes-asset-pack-review-v06.blend` и не восстановлена автоматически.',
    'В одном горизонтальном ряду расположены все 18 моделей; шаг по X — 6.5. Алмазная v02 заново создана в слоте 05 по текущему стилю и референсу, с закреплёнными вставками. Историческая версия v06 сохранена.')
text=text.replace('Новые модели ещё не экспортированы и не заменяют игровые модели в Studio.',
    'Полный пак экспортирован в `pack/exports/roblox-import-v03/Pickaxes_Pack.fbx` и упакован в `pack/exports/pickaxes-full-18-roblox-v03.zip`. Игровые шаблоны в Studio пока не заменены.')
text=text.replace('все 17 видимых моделей','все 18 видимых моделей').replace('в текущем v19 на её месте свободный слот','в v19 на её месте оставался свободный слот; в v20 алмазная заново создана по указанию пользователя')
text+='''
## Полный пак для импорта — v03

[ZIP](pack/exports/pickaxes-full-18-roblox-v03.zip) · [Основной FBX](pack/exports/roblox-import-v03/Pickaxes_Pack.fbx) · [Инструкция импорта](pack/exports/roblox-import-v03/README_IMPORT.md).

18 отдельных именованных мешей, один материал и индивидуальный запечённый атлас 2048×2048 на каждую кирку. Все текстуры встроены в FBX и предоставлены отдельными PNG. Чистый Blender-исходник экспорта — `pack/exports/roblox-import-v03/source/Pickaxes_Import.blend`; исторические и обзорные сцены исключены из него. Подготовительная версия v02 содержала 17 моделей и заменена этим полным паком; используйте v03. Состав файлов проверен чтением бинарных FBX, без запуска игровых тестов. Фактический импорт в Roblox ещё не выполнен.
'''
path.write_text(text,encoding='utf-8')
files=sorted(p for p in OUT.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt')
checks=''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(OUT).as_posix()+'\n' for p in files)
(OUT/'SHA256SUMS.txt').write_text(checks,encoding='utf-8')
zip_path=PACK/'exports/pickaxes-full-18-roblox-v03.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in sorted(OUT.rglob('*')):
        if p.is_file():archive.write(p,p.relative_to(OUT))
with zipfile.ZipFile(zip_path) as archive:
    assert archive.testzip() is None
    assert len([n for n in archive.namelist() if n.startswith('models/') and n.endswith('.fbx')])==18
print(json.dumps({'zip':str(zip_path),'models':18,'zipBytes':zip_path.stat().st_size,'fbx':str(OUT/'Pickaxes_Pack.fbx')},ensure_ascii=False))
