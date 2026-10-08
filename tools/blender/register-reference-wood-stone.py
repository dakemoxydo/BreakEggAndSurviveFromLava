"""Register only the two finalized review models; mark the early batch as drafts."""
import json
import shutil
import sys
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[2]
picks=root/'assets/items/pickaxes'
pack=picks/'pack'
catalog_path=picks/'catalog.json'
catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
records=[]
wooden_version=sys.argv[1] if len(sys.argv)>1 else 'v03'
assert wooden_version in ['v03','v04']
preview_version='v02' if wooden_version=='v04' else 'v01'
for tier,key,version in [(1,'Wooden',wooden_version),(2,'Stone','v01')]:
 folder=picks/('%02d-%s'%(tier,key.lower()))
 stem=key.lower()+'-pickaxe-reference-'+version
 geometry=json.loads((folder/'models'/(stem+'-validation.json')).read_text())
 icon=Image.open(folder/'icons'/(stem+'.png'))
 assert icon.mode=='RGBA' and icon.getchannel('A').getextrema()==(0,255)
 bounds=icon.getchannel('A').getbbox()
 assert bounds[0]>0 and bounds[1]>0 and bounds[2]<1024 and bounds[3]<1024
 record={'version':version,'modelStatus':'ready-for-user-review','blend':'../pack/models/pickaxes-asset-pack-v01.blend',
         'scene':'Review_Wooden_Stone','collection':geometry['collection'],
         'fbx':'exports/'+stem+'.fbx','glb':'exports/'+stem+'.glb','shopIcon':'icons/'+stem+'.png',
         'texture':'textures/reference-wood-stone-studs-v01.png','frontPreview':'models/'+stem+'-front.png',
         'sidePreview':'models/'+stem+'-side.png','triangles':geometry['triangles'],
         'symmetryPlane':'X=0','studsGeometry':False,'studsTexture':True,'importedToRoblox':False}
 asset_path=folder/'asset.json'
 asset=json.loads(asset_path.read_text(encoding='utf-8'));asset['modelStatus']=record['modelStatus'];asset['model']=record
 asset_path.write_text(json.dumps(asset,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 item=next(i for i in catalog['items'] if i['key']==key)
 item['modelStatus']=record['modelStatus']
 item['model']={**record,'blend':'pack/models/pickaxes-asset-pack-v01.blend'}
 for field in ['fbx','glb','shopIcon','texture','frontPreview','sidePreview']:
  item['model'][field]=item['folder']+'/'+record[field]
 records.append({'key':key,'tier':tier,**record})
 description=('Голова из семи крупных деревянных блоков с тупыми концами. Форма и синий металлический ромб доработаны по двум фото оригинальной игры.' if key=='Wooden' else 'Голова из серых каменных блоков с острыми гранёными концами. Рукоять, металлические обоймы и масштаб studs согласованы с деревянной киркой.')
 if key=='Wooden' and version=='v04':
  description=description.replace('с тупыми концами','с симметричными заострёнными концами')
 (folder/'README.md').write_text(f'''# {key} — текущая модель {version}

{description}

Обе стороны зеркально симметричны. Studs выполнены плоской текстурой пользователя, шаг 0.55 единицы. Выпуклых квадратов нет. Pivot экспорта находится в точке хвата на рукояти.

Общий редактируемый исходник: `../pack/models/pickaxes-asset-pack-v01.blend`, сцена `Review_Wooden_Stone`, коллекция `{geometry['collection']}`. Отдельные файлы FBX и GLB: `exports/{stem}.fbx` и `exports/{stem}.glb`. Прозрачная иконка: `icons/{stem}.png`. Прямой и боковой виды находятся в `models`.

{geometry['triangles']} треугольников. Закрытая геометрия, без вырожденных треугольников и UV. FBX/GLB повторно импортированы в Blender, размеры и текстура сохранены. В Roblox Studio модель ещё не импортирована.

Модель ожидает визуального отзыва. Предыдущие версии сохранены для сравнения.
''',encoding='utf-8')
catalog['status']='wooden-and-stone-ready-for-review'
catalog['modelingStatus']='Wooden reference '+wooden_version+' and Stone reference v01 completed. Stop before tier 3, per user request.'
for item in catalog['items'][2:]:
 report=picks/item['folder']/'models/pack-v01-model.json'
 if report.exists():
  item['modelStatus']='early-draft-not-finalized'
  item['draftSource']='pack/models/pickaxes-asset-pack-v01.blend: Pickaxe_Asset_Pack_v01'
 else: item['modelStatus']='not-modeled'
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(pack/'manifest.json').write_text(json.dumps({'status':'awaiting-user-feedback','currentScene':'Review_Wooden_Stone','source':'models/pickaxes-asset-pack-v01.blend','reviewModels':records,'completedTiers':[1,2],'nextTier':3,'draftScene':'Pickaxe_Asset_Pack_v01','note':'The earlier batch remains as drafts. Do not continue before user feedback.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(pack/'README.md').write_text(('''# Кирки — проект Blender

Текущая сцена: **Review_Wooden_Stone**. На оценку готовы деревянная v03 по фото оригинала и каменная v01. Дальше третьей кирки работа не продолжается до отзыва пользователя.

`models/pickaxes-asset-pack-v01.blend` — единый редактируемый проект. Коллекции `01_Wooden_Reference_v03` и `02_Stone_Reference_v01` содержат детали моделей. Отдельные коллекции экспорта скрыты в превью. Камеры и свет не входят в FBX/GLB.

`previews/wooden-stone-review-v01.png` — сравнение двух моделей. Отдельные иконки и экспорты находятся в папках соответствующих кирок. Обе модели симметричны, с плоской studs-текстурой. FBX/GLB проверены повторным импортом; результатов импорта в Roblox Studio ещё нет.

Сцена `Pickaxe_Asset_Pack_v01` содержит ранние черновики 01–06, созданные до уточнения пользователя. Это не утверждённый готовый набор. Старая сцена Wooden v02 также сохранена для сравнения.
''').replace('деревянная v03','деревянная '+wooden_version).replace('01_Wooden_Reference_v03','01_Wooden_Reference_'+wooden_version).replace('wooden-stone-review-v01.png','wooden-stone-review-'+preview_version+'.png'),encoding='utf-8')
p=picks/'README.md';readme=p.read_text(encoding='utf-8')
start=readme.find('Пользователь одобрил')
if start<0: start=readme.find('Текущие модели:')
end=readme.find('\n\n## Порядок',start)
assert start>=0 and end>start
readme=readme[:start]+'Текущие модели: деревянная reference '+wooden_version+', доработанная по фото оригинальной игры, и каменная reference v01. Обе находятся в едином проекте pack/models/pickaxes-asset-pack-v01.blend, в сцене Review_Wooden_Stone. После второй кирки работа остановлена по запросу пользователя. Предыдущие концепты и версии сохранены. Ранние черновики 03–06 не считаются готовыми.'+readme[end:]
p.write_text(readme,encoding='utf-8')
library=Path(r'C:\Users\dakem\Documents\RobloxGames\Assets\Games\BreakEggAndSurviveFromLava\Pickaxes')
for relative in ['pack/models/pickaxes-asset-pack-v01.blend','pack/manifest.json','pack/README.md','pack/previews/wooden-stone-review-'+preview_version+'.png','pack/textures/reference-wood-stone-studs-v01.png','pack/models/wooden-stone-export-validation.json']:
 target=library/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(picks/relative,target)
for record in records:
 folder=('%02d-%s'%(record['tier'],record['key'].lower()))
 for relative in [record[key] for key in ['fbx','glb','shopIcon','texture','frontPreview','sidePreview']]+['asset.json','README.md']:
  target=library/folder/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(picks/folder/relative,target)
index=library.parents[2]/'asset-index.md'
text=index.read_text(encoding='utf-8')
text='\n'.join(line for line in text.splitlines() if not line.startswith('- `Games/BreakEggAndSurviveFromLava/Pickaxes/pack/models/pickaxes-asset-pack-v01.blend`'))
entry='- `Games/BreakEggAndSurviveFromLava/Pickaxes/pack/models/pickaxes-asset-pack-v01.blend` — деревянная reference v03 по фото оригинала и каменная reference v01; сцена Review_Wooden_Stone, симметричные, плоская studs-текстура, 496/464 треугольника, FBX/GLB и прозрачные иконки; работа остановлена после второй кирки, ожидают визуальной оценки.'
entry=entry.replace('reference v03','reference '+wooden_version).replace('496/464',str(records[0]['triangles'])+'/464')
if entry not in text: index.write_text(text.rstrip()+'\n\n'+entry+'\n',encoding='utf-8')
print('Wooden and Stone registered. Scope stopped before tier 3. Global library updated.')
