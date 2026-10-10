# Импорт ассетов в новый аккаунт

Текущая игра: placeId 120440556374316, universeId 10770177677, владелец Dakemo555 (11789507527). Изображения загружены через Studio под этим аккаунтом. Соответствие файлов и ID — `manifests/account-reimport.json`.

## Кирки

1. В Roblox Studio откройте File → Import 3D (в некоторых версиях File → Import).
2. Выберите `assets/items/pickaxes/pack/exports/roblox-import-v03/Pickaxes_Pack.fbx`. Это общий файл всех 18 кирок со встроенными текстурами. Для импорта по одной используйте файлы из соседней папки `models/`.
3. Выберите Creator = Dakemo555 и включите Upload to Roblox, если опция отображается. Scale Unit = Studs, масштаб 1, World Up = Top, World Forward = Front. Merge Meshes выключен, Use Imported Pivot включён. На время импорта включите Anchored.
4. Перед Import проверьте наличие 18 отдельных цветных моделей в предпросмотре. Если текстуры отсутствуют, укажите соответствующие PNG из соседней папки `textures/`.
5. После импорта оставьте новую модель в Workspace и назовите её `ReimportedPickaxes`. Старые Templates и ReplicatedStorage.PickaxeModels пока не заменяйте: runtime-каталог управляется Rojo и требует обновления экспорта через инструменты проекта.

18 кирок уже распределены: исходный импорт находится в `ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03`, новые меши подключены к Templates и `ReplicatedStorage.PickaxeModels`. Runtime-каталог и AssetTemplates экспортированы через `tools/save-account-models.py`. Старые ключи и положение хвата сохранены.

## Дорожка и оставшаяся бита

Дорожка уже подключена: новые меши установлены в TreadmillLvl1 и семь станций карты. Игровая ширина — 7 studs. Исходный импорт сохранён в `ServerStorage.Assets.Environment.Treadmills.SourceImports.Blue_Treadmill_Roblox`.

Lava Bat в Studio заменена моделью из 15 обычных Part через tools/create-studio-bat.luau. Handle и Grip сохранены, меши старого аккаунта удалены из Tool и WoodenBatSource. Импорт GLB больше не требуется. Сохранение новой геометрии в release-экспорты ожидает разрешения пользователя.

Питомцы и яйца текущей игры процедурные; отдельный импорт их 3D-файлов не требуется.

## Звук

Локальный пользовательский звук — `assets/audio/sfx/ui-click.mp3`. Загрузите его через Creator Dashboard → Development Items → Audio под Dakemo555. Сообщите полученный Asset ID для обновления UIClick в `src/gameplay/SoundLibrary.luau` и аудио-манифесте. Если потребуется разрешение игры, добавьте universeId 10770177677 в Permissions → Experiences.

Большинство остальных звуков каталога взято из Creator Store; их исходные аудиофайлы в проекте не найдены. Для них нужно проверить доступ новой игре и при необходимости дать разрешение или подобрать доступный ассет, а не повторно загружать несуществующий локальный файл.

## Что не переносит локальная Roblox-модель

Файл rbxmx хранит ссылки MeshId/TextureID/SoundId и сам по себе не переносит владельца этих облачных ассетов. Для моделей нужны исходные FBX/GLB, для аудио — исходные записи. Все 18 исходных FBX кирок найдены; наличие исходных файлов остальных облачных моделей этим документом не утверждается.
