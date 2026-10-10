# Организация ассетов

Храните ассеты по назначению. Исходные файлы, референсы и экспорт одного предмета находятся рядом, а не в общей папке всех моделей или всех картинок.

```text
assets/
├── items/
│   ├── pickaxes/                 18 папок кирок, catalog.json и общий лист
│   │   └── 01-wooden/
│   │       ├── references/       выбранный референс и промпты
│   │       ├── models/           исходные .blend
│   │       ├── textures/         текстуры модели
│   │       ├── icons/            финальные PNG магазина
│   │       ├── exports/          .fbx, .glb, .rbxmx
│   │       └── asset.json        ключ, версия и статус согласования
│   ├── bats/lava-bat/            биты с такой же структурой
│   └── eggs/                    будущие яйца
├── pets/                        питомцы; отдельная папка на каждого
├── environment/
│   ├── maps/exports/             снимок карты Roblox
│   ├── lighting/exports/         освещение и облака
│   ├── materials/hd-studs/       HD studs, normal map, MaterialVariant и лицензия
│   ├── props/                   будущие объекты окружения
│   └── treadmills/              будущие беговые дорожки
├── ui/
│   ├── icons/navigation/         кнопки разделов и настройки
│   ├── icons/resources/          валюты и ресурсы
│   ├── atlases/                 атласы UI
│   ├── effects/                 sunburst и другие эффекты
│   └── textures/                текстуры поверхностей UI
├── audio/
│   ├── music/
│   └── sfx/
├── animations/
│   ├── characters/
│   ├── pets/
│   └── items/
├── reference/
│   ├── gameplay/                контактные листы геймплея
│   ├── screenshots/
│   └── videos/
├── manifests/                   соответствие файлов, источников и Roblox ID
├── exports/
│   ├── roblox/                  общие AssetTemplates
│   └── ui/                      экспорт исходников UI и sourcemap
└── archive/legacy-ui/            прежние варианты и снимки UI
```

## Каталог моделей в Roblox Studio

Основное хранилище шаблонов — `ServerStorage.Assets`. Workspace содержит размещённый мир и игровые экземпляры, а не выставленные импортированные исходники.

```text
ServerStorage.Assets/
├── Items/
│   ├── Pickaxes/
│   │   ├── Templates/          все 18 кирок, игровые шаблоны v03
│   │   ├── SourceImports/     Pickaxes_Pack_v03 и старый Pickaxes_Wooden_Stone
│   │   └── Archive/           BeforeFullPack_v03 — предыдущие шаблоны
│   ├── Bats/                  WoodenBatSource
│   └── Eggs/                  будущие шаблоны яиц
├── Environment/
│   ├── Treadmills/            TreadmillLvl1
│   └── Props/                 будущий декор
└── Pets/                      будущие импортированные модели питомцев
```

Сохранять импорт в SourceImports до удаления его выставленного экземпляра из Workspace. Готовые игровые модели хранить в Templates; не заменять ими исходник импорта. Runtime-копии всех 18 кирок в ReplicatedStorage.PickaxeModels нужны для PetVisuals и ViewportFrame. Этот runtime-каталог управляется Rojo через `items/pickaxes/pack/exports/PickaxeModels.rbxmx`; изменения сохранять в исходном XML, иначе синхронизация их отменит. Процедурные питомцы и яйца создаются исходниками; пустые Pets/Items.Eggs не означают наличие импортированных моделей. WorldBackups содержит исторические резервные копии отдельно от каталога Assets.

8 октября 2026 года Wooden/Stone сохранены из Workspace в SourceImports, выставленный Pickaxes_Wooden_Stone удалён. Каталог экспортирован в assets/exports/roblox/AssetTemplates.rbxmx, который использует release.project.json. Для экспорта только каталога использовать снимок `.tools/organized-assets-snapshot.json` и `tools/save-organized-assets.py`; он не переписывает карту. После новых изменений сначала получить свежий снимок Assets через RobloxMCP.

Позже 8 октября полный импорт `Workspace.Pickaxes_Pack` перенесён в `SourceImports.Pickaxes_Pack_v03`. В Templates и runtime-каталоге все 18 ключей GameConfig соответствуют новым MeshPart. Цвет белый, реальные текстуры сохранены, коллизии отключены. Pivot каждой кирки расположен на хвате; `PickaxeHead` задаёт точку следа удара на высоте 2.75 studs от хвата до игрового уменьшения 0.65. Старые runtime- и storage-шаблоны сохранены в Archive.BeforeFullPack_v03. Сохранение нового каталога без карты выполняет `tools/save-full-pickaxe-assets.py`.

## Правила файлов

В текущем каталоге 18 кирок и три меша дорожки повторно импортированы под Dakemo555. Их ID записаны в `manifests/account-reimport.json` и индивидуальных манифестах кирок. `tools/save-account-models.py` пересоздаёт runtime-каталог, AssetTemplates и карту из свежего `tools/export-world.luau` снимка; MeshPart сохраняются с InitialSize. Исходный пак кирок хранится в прежнем SourceImports.Pickaxes_Pack_v03, исходник дорожки — в Environment.Treadmills.SourceImports. Старые шаблоны сохранены отдельно в ServerStorage.WorldBackups.BeforeAccountModelReimport. Lava Bat пока использует меши прежнего аккаунта.

- Новому предмету создавайте собственную папку с references, models, textures, icons и exports. Для кирок префикс номера сохраняет порядок магазина.
- Не меняйте ключи предметов: Wooden, Stone и остальные совпадают с GameConfig. Изображения кирок и порядок перечислены в [каталоге](items/pickaxes/catalog.json).
- Сохраняйте версии в именах файлов. Выбранный референс отмечайте в asset.json; заменённые варианты удаляйте: история хранится в git.
- Скрипты обработки находятся в tools/, а не среди ассетов. Исторические скрипты UI находятся в tools/archive/ui/.
- Пути в release.project.json и манифестах соответствуют этой структуре. При повторном импорте в другой аккаунт соответствие старых и новых Roblox ID хранится в `manifests/account-reimport.json`; ссылки обновляет `tools/rebind-local-images.py`.
- Структура папок не означает одобрение моделей: работа в Blender ожидает согласования набора кирок.

Подробнее: [кирки](items/pickaxes/README.md), [источники и ID](manifests/reference-assets.json), [UI-манифест](manifests/ui-manifest.json).
