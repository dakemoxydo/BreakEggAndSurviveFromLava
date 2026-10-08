"""Register the completed local model and mirror it to the global asset library."""
from pathlib import Path
import json
import shutil
from PIL import Image

root=Path(__file__).resolve().parents[2]
pickaxes=root/'assets/items/pickaxes'
asset=pickaxes/'01-wooden'
properties=json.loads((asset/'models/validation-v02.json').read_text())
roundtrip=json.loads((asset/'models/export-validation-v02.json').read_text())
icon=Image.open(asset/'icons/wooden-pickaxe-shop-v02.png')
assert icon.mode=='RGBA' and icon.getchannel('A').getextrema()==(0,255)
box=icon.getchannel('A').getbbox()
assert box[0]>0 and box[1]>0 and box[2]<1024 and box[3]<1024
record={
    'version':'v02','modelStatus':'modeled-awaiting-visual-review',
    'blend':'models/wooden-pickaxe-studs-v02.blend',
    'fbx':'exports/wooden-pickaxe-studs-v02.fbx',
    'glb':'exports/wooden-pickaxe-studs-v02.glb',
    'shopIcon':'icons/wooden-pickaxe-shop-v02.png',
    'frontPreview':'models/wooden-pickaxe-front-v02.png',
    'texture':'textures/wooden-pickaxe-studs-atlas-v02.png',
    'studsReference':'references/studs-overlay-user.png',
    'symmetryPlane':'X=0','triangles':properties['triangles'],
    'studsGeometry':False,'studsTexture':True,'importedToRoblox':False,
    'exportValidation':roundtrip,
}
p=asset/'asset.json'
data=json.loads(p.read_text(encoding='utf-8'))
data['modelStatus']=record['modelStatus']
data['model']=record
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=pickaxes/'catalog.json'
catalog=json.loads(p.read_text(encoding='utf-8'))
catalog['modelingStatus']='Wooden v02 modeled; other 17 pickaxes await user approval.'
catalog['status']='concepts-ready-wooden-model-v02-ready-for-review'
wooden=next(item for item in catalog['items'] if item['key']=='Wooden')
wooden['modelStatus']=record['modelStatus']
wooden['model']={**record,**{key:'01-wooden/'+record[key] for key in ('blend','fbx','glb','shopIcon','frontPreview','texture','studsReference')}}
p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=pickaxes/'README.md'
readme=p.read_text(encoding='utf-8')
readme=readme.replace('Моделирование в Blender начнётся только после одобрения пользователя.',
    'Деревянная кирка смоделирована по отдельному запросу пользователя; текущая версия — v02. Остальные 17 кирок ещё не моделировались.')
p.write_text(readme,encoding='utf-8')
(asset/'README.md').write_text('''# Деревянная кирка

Текущая модель: **v02**. Голова симметрична относительно X=0. Концы укорочены и плавно сужаются. Выпуклые квадраты и заклёпки удалены. Приложенная пользователем studs-текстура запечена в цветовой атлас; контраст дерева и металлических обойм усилен.

- `models/wooden-pickaxe-studs-v02.blend` — редактируемый исходник Blender.
- `exports/wooden-pickaxe-studs-v02.fbx` — один меш с текстурой для импорта в Roblox.
- `exports/wooden-pickaxe-studs-v02.glb` — тот же меш с встроенным атласом.
- `icons/wooden-pickaxe-shop-v02.png` — прозрачный рендер 1024×1024.
- `models/wooden-pickaxe-front-v02.png` — прямой вид для оценки симметрии.
- `textures/wooden-pickaxe-studs-atlas-v02.png` — RGB-атлас 4096×2048.
- `references/studs-overlay-user.png` — исходная пользовательская текстура без изменений.

В Blender коллекция `Wooden_Pickaxe_Model_v02` содержит 8 редактируемых деталей. Отдельная скрытая коллекция `Export_One_Mesh_Grip_Pivot_v02` содержит собранный меш с pivot в месте хвата. Камеры и свет находятся в коллекции превью и исключены из экспорта.

496 треугольников, 264 геометрические вершины. Все оболочки закрыты; вырожденных треугольников и UV нет. FBX и GLB повторно импортированы в Blender: один меш, текстура и размеры сохранены. Габариты: 4.86×0.82×4.615 предполагаемых Roblox studs. Фактический импорт в Studio ещё не выполнен.

v01 сохранена для сравнения. v02 ожидает визуального отзыва пользователя.
''',encoding='utf-8')
global_root=Path(r'C:\Users\dakem\Documents\RobloxGames\Assets')
library=global_root/'Games/BreakEggAndSurviveFromLava/Pickaxes/01-wooden'
files=[record[key] for key in ('blend','fbx','glb','shopIcon','frontPreview','texture','studsReference')]+['asset.json','README.md','models/validation-v02.json','models/export-validation-v02.json']
for relative in files:
    target=library/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(asset/relative,target)
index=global_root/'asset-index.md'
content=index.read_text(encoding='utf-8')
lines=content.splitlines()
for i,line in enumerate(lines):
    if '01-wooden-pickaxe-studs-v01.png' in line and '3D-модель ещё не создана' in line:
        lines[i]=line.replace('3D-модель ещё не создана','Blender-модель v02 создана, см. Games/BreakEggAndSurviveFromLava/Pickaxes/01-wooden')
entry='- `Games/BreakEggAndSurviveFromLava/Pickaxes/01-wooden/models/wooden-pickaxe-studs-v02.blend` — Деревянная кирка Wooden; симметричная, 496 треугольников, без выпуклых квадратов, пользовательская studs-текстура, контрастная оранжевая древесина и тёмная сталь; FBX/GLB, цветовой атлас, прозрачный рендер магазина; готова к визуальной оценке, в Roblox не импортирована.'
if entry not in lines:
    lines.extend(['',entry])
index.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Registered Wooden v02. Export validation passed. Global copies: '+str(len(files)))
