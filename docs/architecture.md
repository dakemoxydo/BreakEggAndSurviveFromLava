# Архитектура

## Разделение ответственности

Сервер определяет деньги, урон, результат яйца, владение, экипировку, награды и сохраняемый прогресс. Клиент отправляет намерения и отображает результат. UI читает реплицируемые атрибуты, а не Profile.Data.

| Исходник | Объект Studio | Ответственность |
|---|---|---|
| `src/server/Pets.server.luau` | ServerScriptService.PetGameplay | Базы, состояние игроков, UIAction, инвентарь, доход, загрузка и запуск Adventure |
| `src/server/Adventure.luau` | ServerScriptService.Adventure | Полевые яйца, груз, стражи, бита, лава, Titanic, стенды |
| `src/server/Treadmills.server.luau` | ServerScriptService.TreadmillTraining | Вход, фиксация, начисление Speed и выход |
| `src/server/PetWorld.luau` | ServerScriptService.PetWorld | Tool, модели яиц, таблички, оформление базы |
| `src/server/WorldDisplays.server.luau` | ServerScriptService.WorldDisplays | Рейтинги и баннер события |
| `src/server/data/` | ServerScriptService.PlayerData | Config, Schema и Service сохранений |
| `src/serverPackages/ProfileStore.luau` | ServerStorage.ServerPackages.ProfileStore | Библиотека постоянных профилей и блокировки сессии |
| `src/gameplay/` | Модули ReplicatedStorage | GameConfig, PetConfig, TrainingConfig, PetVisuals, PetAnimation |
| `src/shared/` | ReplicatedStorage.ShopUI | React-компоненты, оформление и данные Shop |
| `src/client/ShopUI.client.luau` | StarterPlayerScripts.ShopUIBootstrap | Монтирование UI и контроллер окон |
| `src/client/Adventure.client.luau` | StarterPlayerScripts.AdventureControls | Выбор цели, удар, вспышки и маркер своей базы |
| `src/gameplay/PickaxeEffects.luau` | ReplicatedStorage.PickaxeEffects | Клиентская анимация суставов, след кирки, звук и эффекты подтверждённого попадания |
| `src/gameplay/HatchEffects.luau` | ReplicatedStorage.HatchEffects | Рост и тряска полевого яйца, счётчик удачи, разлёт оболочки и появление питомца |
| `src/client/Pets.client.luau` | StarterPlayerScripts.PetControls | Предпросмотр размещения, сглаживание питомцев, видимость и громкость |
| `src/client/Treadmills.client.luau` | StarterPlayerScripts.TreadmillControls | Перехват прыжка для выхода |

Имена StarterPlayerScripts в таблице относятся к содержимому `StarterPlayer.StarterPlayerScripts`, которое копируется в PlayerScripts игрока при запуске.

## Размер и геометрия кирок

`PetVisuals.pickaxe` клонирует MeshPart из `ReplicatedStorage.PickaxeModels`, совмещает его pivot с Handle и применяет равномерный `ScaleTo(PickaxeHeight / mesh.Size.Y)`. `PickaxeHeight = 4.875`: все 18 кирок получают одинаковую высоту при сохранении собственной ширины и толщины. Этот визуал также используется в магазине.

`PetWorld.tool` умножает текущий масштаб визуала на `PetVisuals.PickaxeToolScale = 0.65 * 1.5`. Использование `GetScale()` сохраняет предварительную нормализацию; абсолютный `ScaleTo(0.975)` отменил бы её. Итоговая высота в руке — 4.753125 studs. Точка PickaxeHead и ширина следа замаха учитывают итоговый масштаб.

Исходные импортированные размеры сохраняются в FBX, SourceImports и Templates. Runtime XML содержит InitialSize. При загрузке PetWorld сверяет MeshSize с импортированным шаблоном и восстанавливает потерянные данные через ApplyMesh, сохраняя Size. Это предотвращает неравномерное растяжение MeshPart после синхронизации Rojo.

## Жизненный цикл

PetGameplay резервирует свободную базу, загружает профиль через DataService, восстанавливает инвентарь, размещённые яйца, Tool и оборудование, затем выставляет `PetDataReady=true`. До этого действия не изменяют прогресс. При отсутствии свободной базы профиль не открывается.

Оперативное состояние находится в таблице `states[player]`; оно содержит и данные, и ссылки на сцену. Schema формирует из него сохраняемый снимок только с сериализуемыми полями. Commit обновляет Profile.Data; запрос к DataStore не нужен на каждый игровой клик.

Adventure получает серверные зависимости через `Adventure.start(options)`: состояния, проверку активной сессии, банковку груза, действие и World. Модуль запускается один раз. Полевые яйца, стражи, лава и груз живут только в памяти текущего сервера.

При выходе или потере сессии база и игровые модели освобождаются, прогресс прекращает изменяться. ProfileStore завершает сессию. Детали — в [saves.md](saves.md).

## Контракт сцены

```text
Workspace.Map
├── StartZone
│   ├── PlayerBases
│   │   └── <база>.BaseAnchor
│   ├── Treadmills
│   │   └── <дорожка>: TrainingCenter, BeltCollision
│   ├── Shops
│   ├── ReferenceDetails
│   └── SafeZoneBoundary
├── Biomes
│   ├── Forest.Floor
│   ├── Desert.Floor
│   └── Snow.Floor
└── Adventure                 создаётся сервером в Play
```

PetContents создаётся для содержимого базы. `BaseAnchor` задаёт систему относительных координат сохранений; `FloorY`, `PenHalfWidth`, `PenHalfDepth` описывают пол и границы. Базы и дорожки получают `OwnerUserId`. `TrainingCenter` задаёт направление персонажа, `BeltCollision` обеспечивает физическую опору.

Adventure обращается к `Map.StartZone.Shops` и `Map.Biomes.<имя>.Floor` напрямую. Эти имена нельзя менять как косметические подписи. Объекты ReferenceDetails с атрибутом Interaction получают prompts; таблички рейтингов имеют ожидаемую иерархию Board/LeaderboardUI/Rows.

Release дополнительно включает шаблоны `ServerStorage.Assets`, материал ReferenceHDStuds, освещение, облака, карту и Lava Bat в StarterPack. Модели кирок доступны как `ReplicatedStorage.PickaxeModels`.

## UI и визуальные модели

Зависимости Wally: React Luau 17.2.1, ReactRoblox 17.2.1, Ripple 0.10.2. `Packages/` синхронизируется в ReplicatedStorage; серверная ProfileStore хранится отдельно.

App управляет окнами, читает атрибуты и вызывает UIAction. Правые Pets/Eggs открывают Sidebar с выездом справа. Общий Inventory открывается только Backquote и кнопкой рядом с Settings; его вкладки хранятся отдельно от состояния экранов. Hotbar и `useBackpack` работают с Tool. EquipmentShop и AdventurePanels обслуживают внутриигровые покупки, сумку и Merge; Config содержит предложения Shop. Theme/UI/Assets задают оформление, а ModelPreview и IndexSurface показывают модели через ViewportFrame. Полный контракт навигации и проверки перед изменениями — в [ui.md](ui.md).

PetVisuals создаёт процедурные модели животных и яиц. Сервер задаёт целевую позицию, yaw и состояние ходьбы; PetControls сглаживает движение и применяет PetAnimation. Эти визуальные изменения не являются источником владения или дохода. Настройки видимости меняют локальное отображение.

PickaxeEffects поддерживает Motor6D и AnimationConstraint. В PreAnimation снимается предыдущая добавка к Transform, после Animator в PreSimulation применяется новая поза. Это предотвращает накопление поворотов и сохраняет обычную анимацию персонажа. Завершение или снятие инструмента отключает соединения, восстанавливает Transform и Grip и выключает Trail. Для кирок без импортированного меша PetVisuals создаёт отдельный невидимый Handle у нижней части рукояти, как у Wooden и Stone.

HatchEffects наблюдает модели Map.Adventure и их атрибуты. При Hatching останавливает отдачу попадания, скрывает серверную оболочку через LocalTransparencyModifier и анимирует локальную копию без гнезда. Серверная позиция и исходный scale не меняются. Нормальное окончание оставляет оболочку скрытой до удаления сервером; преждевременное удаление отменяет эффекты. Клиентский рост питомца восстанавливает исходный размер и pivot. Сервер различает Hatching, Revealing и Hatched, поэтому дополнительный удар и преждевременный подбор не создают дубликат добычи.

App объединяет события атрибутов и декодирует JSON только при изменении строки. React.memo и стабильные обработчики уменьшают перерисовки. Исторические измерения и ограничения — в [ui-performance.md](ui-performance.md).

Сетевые контракты вынесены в [network-api.md](network-api.md), численные правила — в [balance.md](balance.md).
