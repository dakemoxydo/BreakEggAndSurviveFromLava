"""Update canonical metadata and make a six-model review sheet."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
assets=ROOT/'assets/items/pickaxes'
PACK=assets/'pack'
audit=json.loads((PACK/'previews/pack-attachment-audit-v19.json').read_text(encoding='utf-8'))
assert audit['passed'] and len(audit['assets'])==17
names={'Hacker':'Хакерская','UFO':'НЛО','Secret':'Тайная','Cool':'Ледяной дракон','Galaxy':'Галактическая','Celestial':'Небесная'}
descriptions={
 'Hacker':'Графитовые ступенчатые секции, зелёные наконечники и симметричные линии, экран с кодовыми скобками.',
 'UFO':'Бирюзовые ступенчатые секции, серебряная летающая тарелка с гранёным зелёным куполом, порты и зелёное навершие.',
 'Secret':'Тёмная фиолетовая броня, локальное светящееся ядро и швы, закреплённые кристальные зубцы и корона.',
 'Cool':'Голубые ступенчатые секции, парные ледяные рога и зубцы, синяя маска дракона с голубыми глазами, серебряные обоймы.',
 'Galaxy':'Ступенчатые секции с рисунком туманности и тёмными studs, гранёная планета с золотой орбитой, звёзды и золотые кольца.',
 'Celestial':'Светлые ступенчатые секции, широкие закреплённые перья, двойной золотой нимб, корона и голубые звёздные вставки.'}
for path in sorted(assets.glob('*/asset.json')):
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    if data['key']=='Diamond':continue
    key=data['key'];tier=data['tier']
    if key in names:
        data['modelStatus']='ready-for-user-review'
        data['reviewModel']=dict(version='v01',status='awaiting-user-review',
            scene='Pickaxe_Pack_Review',collection='%02d_%s_Review_v01'%(tier,key),
            texture='../pack/textures/%s-dark-studs-v01.png'%key.lower(),
            detailPreview='../pack/previews/%s-detail-review-v01.png'%key.lower(),
            raisedStudGeometry=False,runtimeReplaced=False,descriptionRu=descriptions[key])
    review=data['reviewModel']
    review['blend']='../pack/models/pickaxes-asset-pack-review-v19.blend'
    review['preview']='../pack/previews/pack-18-slots-review-v01.png'
    review['attachmentAudit']='../pack/previews/pack-attachment-audit-v19.json'
    review['attachmentStatus']='passed'
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

readme=assets/'README.md'
text=readme.read_text(encoding='utf-8')
start=text.index('Текущий проект для последовательной работы:')
end=text.index('## Порядок набора')
intro='''Текущий проект: [pack/models/pickaxes-asset-pack-review-v19.blend](pack/models/pickaxes-asset-pack-review-v19.blend), сцена `Pickaxe_Pack_Review`. В одном горизонтальном ряду расположены 17 моделей; шаг по X — 6.5. Слот 05 свободен после ручного удаления алмазной из живой сцены. Алмазная сохранена в `pack/models/pickaxes-asset-pack-review-v06.blend` и не восстановлена автоматически.

Эталон — деревянная reference v04. Все модели используют согласованный блочный ступенчатый силуэт и плоские тёмные studs-текстуры. Каменная v03 и железная v02 имеют отдельные секции вместо ранних гладких дуг. Новые модели ещё не экспортированы и не заменяют игровые модели в Studio. Старые `.blend` сохранены.

По указанию пользователя оставшиеся кирки 13–18 закончены последовательно: каждая создана отдельно, проверена на крепление деталей и осмотрена на крупном рендере до перехода к следующей. Их художественное согласование остаётся за пользователем.

'''
for key,description in descriptions.items():intro+='- **'+names[key]+'** — '+description+'\n'
intro+='''
Общий вид: [pack/previews/pack-18-slots-review-v01.png](pack/previews/pack-18-slots-review-v01.png). Крупные виды шести новых моделей: [pack/previews/remaining-six-review-v01.png](pack/previews/remaining-six-review-v01.png). Отдельные изображения — `pack/previews/<key>-detail-review-v01.png`. Тематические текстуры — `pack/textures/<key>-dark-studs-v01.png`; все используемые изображения упакованы в Blender. Клубничная дополнительно использует cream-studs, конфетная — striped-dark-studs.

### Проверка креплений

Итоговый отчёт: [pack/previews/pack-attachment-audit-v19.json](pack/previews/pack-attachment-audit-v19.json). Проверка охватывает все 17 видимых моделей, а не только новые шесть. Для каждой меш разбит на фактические связные острова; контакты подтверждены пересечениями треугольников, касанием поверхностей либо вложением объёма. Связный граф контактов включает все детали каждой кирки. Наличие общего parent само по себе не считается креплением. Допуск касания — 0.0002 единицы Blender. Отдельно проверены закрытые грани без вырожденных полигонов и геометрическая зеркальная симметрия новых моделей.

Исправлены измеренные зазоры под вставками деревянной, каменной, железной, золотой, конфетной, кристальной и демонической. Два свободных кристальных осколка опущены в посадочные места; лавовые накладки навершия получили закрытую толщину. У НЛО уменьшен центральный корпус для открытого купола, у галактической освобождён обзор планеты и орбиты. Линии хакерской рукояти сделаны парными; гранёная планета повернута вокруг своей оси для точной зеркальной геометрии. Резервная копия до правок старых моделей: `.tools/before-pack-attachment-fixes.blend`.

Игровые тесты и Play не запускались. Пользователю остаётся оценить внешний вид, пропорции и тематические детали в Blender; игровой хват и масштаб проверяются после отдельного импорта.

'''
text=text[:start]+intro+text[end:]
text=text.replace('Работать строго по одной кирке: закончить отдельную модель, поставить рядом с предыдущими в одном ряду в Blender и дождаться оценки пользователя. После оценки исправить текущую или переходить к следующей только по его указанию.',
    'Работать строго по одной кирке: закончить отдельную модель, проверить крепление всех деталей и поставить рядом с предыдущими в одном ряду в Blender. По умолчанию дожидаться оценки перед следующей; явное указание пользователя закончить оставшиеся разрешает последовательную работу над всем остатком с отдельной проверкой каждой модели.')
text=text.replace('в текущем v13','в текущем v19')
readme.write_text(text,encoding='utf-8')

sheet=Image.new('RGB',(1800,1280),(49,60,75));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(r'C:\Windows\Fonts\segoeui.ttf',27)
for i,key in enumerate(names):
    img=Image.open(PACK/('previews/%s-detail-review-v01.png'%key.lower())).convert('RGB')
    img.thumbnail((590,590),Image.Resampling.LANCZOS)
    x=(i%3)*600+5;y=(i//3)*640
    sheet.paste(img,(x,y))
    label=names[key];bounds=draw.textbbox((0,0),label,font=font)
    draw.text((x+(590-(bounds[2]-bounds[0]))/2,y+595),label,font=font,fill=(235,241,248))
sheet.save(PACK/'previews/remaining-six-review-v01.png')
print('Six review models documented. Audit covers 17 current models; Diamond remains in its historical file.')
