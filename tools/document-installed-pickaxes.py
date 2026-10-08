"""Make asset documentation and portable package records reflect Studio import."""
import hashlib
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/items/pickaxes'
path=ASSETS/'README.md';text=path.read_text(encoding='utf-8')
text=text.replace('Игровые шаблоны в Studio пока не заменены.',
    'Все 18 игровых шаблонов в Studio заменены новыми MeshPart. Runtime-каталог ReplicatedStorage.PickaxeModels синхронизируется из XML через Rojo.')
text=text.replace('Фактический импорт в Roblox ещё не выполнен.',
    'Полный пак импортирован в Studio; все 18 игровых шаблонов заменены, текстуры и нормализованные точки хвата сохранены. Игровые ощущения проверяет пользователь.')
text+='''
## Установка в игру

Исходный импорт находится в `ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03`; 18 нормализованных копий — в `Templates`. Старые шаблоны сохранены в `Archive.BeforeFullPack_v03`. Выставленный пак удалён из Workspace переносом в хранилище. В `ReplicatedStorage.PickaxeModels` лежат все ключи GameConfig, каждый с новым MeshId/TextureID, белым Color, отключёнными коллизиями и включённым Massless. XML использует Color3uint8, чтобы Rojo не подменял цвет серым по умолчанию.

PetVisuals совмещает pivot mesh с Handle, поэтому импортные координаты ряда и поворот pivot не попадают в руку или магазин. PickaxeHead задаёт след удара; масштаб Tool остаётся 0.65 и применяется вместе с attachment. Игровые тесты и Play не запускались. Проверить вручную магазин, хват Wooden/Diamond/Crystal/Celestial, замах и попадание по яйцу, смену кирки и респавн. Place сохранить в Studio.
'''
path.write_text(text,encoding='utf-8')
path=ASSETS/'pack/README.md';text=path.read_text(encoding='utf-8').replace('импорт в Studio ещё не выполнен.',
    'полный пак импортирован в Studio и подключён к 18 runtime-шаблонам. Исходники и старые модели организованы в ServerStorage.Assets.Items.Pickaxes.')
path.write_text(text,encoding='utf-8')
OUT=ASSETS/'pack/exports/roblox-import-v03'
path=OUT/'README_IMPORT.md';text=path.read_text(encoding='utf-8')
text=text.replace('Импорт и загрузка в Roblox ещё не выполнены.',
    'В этом проекте полный пак уже импортирован в Studio; новые MeshId/TextureID записаны в manifest.json и соответствуют всем 18 runtime-шаблонам. Исходники сохранены в ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03, нормализованные копии — в Templates, предыдущие шаблоны — в Archive.BeforeFullPack_v03.')
text=text.replace('Замена игровых шаблонов выполняется отдельно после проверки импорта.',
    'В этом проекте игровые шаблоны уже заменены; при переносе в другой проект их подключение выполняется отдельно.')
path.write_text(text,encoding='utf-8')
files=sorted(p for p in OUT.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt')
(OUT/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(OUT).as_posix()+'\n' for p in files),encoding='utf-8')
zip_path=OUT.parent/'pickaxes-full-18-roblox-v03.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in sorted(OUT.rglob('*')):
        if p.is_file():archive.write(p,p.relative_to(OUT))
print('Installed asset documentation, IDs, checksums and package updated.')
