"""Make an approval sheet and archive; preserve original generated PNG pixels."""
import json
import shutil
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
folder = root / 'assets/items/pickaxes'
library = Path(r'C:/Users/dakem/Documents/RobloxGames/Assets/Games/BreakEggAndSurviveFromLava/PickaxeConcepts/studs-v01')
manifest_path = folder / 'catalog.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
assert len(manifest['items']) == 18
manifest['status'] = 'images-ready-awaiting-user-approval'
manifest['modelingStatus'] = 'awaiting-user-approval; Blender modeling has not started'
manifest['items'][2]['generationPrompt'] = manifest['items'][2]['prompt'].replace('a short flat chisel', 'a slightly shorter sharp downturned chisel beak, neither end resembles a hammer')
font_root = Path(r'C:/Windows/Fonts')
title_font = ImageFont.truetype(str(font_root / 'arialbd.ttf'), 42)
name_font = ImageFont.truetype(str(font_root / 'arialbd.ttf'), 21)
small_font = ImageFont.truetype(str(font_root / 'arial.ttf'), 18)
sheet = Image.new('RGB', (1800, 1210), '#131d2c')
draw = ImageDraw.Draw(sheet)
draw.text((35, 24), '18 КИРОК · STUDS', fill='#ffffff', font=title_font)
draw.text((36, 78), 'Порядок усиления: слева направо, сверху вниз. Концепты для согласования перед Blender.', fill='#acbed2', font=small_font)
reports = []
for i, item in enumerate(manifest['items']):
    path = folder / item['filename']
    with Image.open(path) as original:
        assert original.mode == 'RGBA', f'Missing RGBA: {path}'
        alpha = original.getchannel('A')
        assert alpha.getextrema() == (0, 255), f'No true transparency: {path}'
        visible = alpha.point(lambda a: 255 if a >= 32 else 0).getbbox()
        assert visible is not None, f'Empty icon: {path}'
        item['imageProperties']['boundsAboveAlpha32'] = list(visible)
        reports.append({'tier': item['tier'], 'size': list(original.size), 'visible': list(visible)})
        # Resize only a separate review thumbnail. Original PNGs are never edited.
        thumb = original.copy()
        thumb.thumbnail((260, 260), Image.Resampling.LANCZOS)
        col, row = i % 6, i // 6
        x, y = 20 + col * 297, 127 + row * 354
        draw.rounded_rectangle((x, y, x + 276, y + 333), radius=13, fill='#223046', outline='#3c506a', width=2)
        sheet.paste(thumb, (x + (276 - thumb.width) // 2, y + 12), thumb)
        draw.text((x + 13, y + 275), f"{item['tier']:02d}  {item['nameRu']}", font=name_font, fill='#ffffff')
        draw.text((x + 13, y + 305), f"{item['key']} Pickaxe", font=small_font, fill='#b9c9dd')
sheet_path = folder / 'previews/pickaxes-overview-v01.jpg'
sheet.save(sheet_path, quality=95, subsampling=0)
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
readme = '''# Кирки со studs — концепты v01

Набор содержит 18 отдельных PNG с настоящим прозрачным фоном. Файлы созданы встроенным ImageGen, а не Blender. Исходное разрешение каждого изображения — 1254 × 1254. Полные промпты, исходные файлы генератора и проверенные свойства alpha находятся в catalog.json.

Пользователь одобрил деревянную кирку как образец стиля. Каменная переделана по его замечанию; используйте v02. Конфетная v02 исправляет обрезанный верх головки. Остальные изображения ожидают согласования. Моделирование в Blender начнётся только после одобрения пользователя.

## Порядок набора

'''
for item in manifest['items']:
    readme += f"{item['tier']}. {item['key']} — {item['nameRu']}: [{item['filename']}]({item['filename']})\n"
readme += '''
## Папка каждой кирки

- references/ — выбранный референс и промпты; archive/ внутри содержит заменённые варианты.
- models/ — исходные файлы Blender (.blend).
- textures/ — текстуры модели.
- icons/ — подготовленные финальные иконки магазина.
- exports/ — экспорт моделей для Roblox (.fbx, .glb, .rbxmx).
- asset.json — ключ предмета, выбранный референс и статус согласования.

Общий лист находится в previews/, архив набора — в exports/. PNG в references/ являются текущими концептами; финальные иконки и модели будут созданы после согласования.

## Общий принцип моделирования

Сохранять крупные квадратные studs, простые гранёные формы, заметные фаски, единый ракурс и последовательное усложнение силуэтов. Поздние кирки отличаются головками, вставками, рогами, разрывами, орбитальными кольцами и крыльями. Для галактического материала потребуется отдельная текстура; свечение и парящие детали будут подготовлены после согласования 3D-моделей.

PNG сохранены также в общей библиотеке: Games/BreakEggAndSurviveFromLava/PickaxeConcepts/studs-v01. Roblox asset ID пока не назначены. Действующий UI магазина и модели в Studio на этом этапе не заменены.
'''
(folder / 'README.md').write_text(readme, encoding='utf-8')
library_manifest = json.loads(json.dumps(manifest))
for entry in library_manifest['items']:
    entry['filename'] = Path(entry['filename']).name
(library / 'designs.json').write_text(json.dumps(library_manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
shutil.copy2(sheet_path, library / sheet_path.name)
archive_path = folder / 'exports/pickaxes-studs-v01.zip'
with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as archive:
    for item in manifest['items']:
        archive.write(folder / item['filename'], item['filename'])
    for file in [manifest_path, sheet_path, folder / 'README.md']:
        archive.write(file, str(file.relative_to(folder)))
    for item in manifest['items']:
        file = folder / item['folder'] / 'asset.json'
        archive.write(file, str(file.relative_to(folder)))
        for role in ['models', 'textures', 'icons', 'exports']:
            archive.writestr(f"{item['folder']}/{role}/", '')
    for file in folder.glob('*/references/*-prompt.txt'):
        archive.write(file, str(file.relative_to(folder)))
print(json.dumps({'pngCount': len(reports), 'alpha': 'all RGBA; 0..255', 'sheet': str(sheet_path), 'archive': str(archive_path), 'archiveBytes': archive_path.stat().st_size, 'checks': reports}, ensure_ascii=False))
