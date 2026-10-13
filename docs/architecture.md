# Архитектура

## Разделение ответственности

Сервер определяет деньги, урон, результат яйца, владение, экипировку, награды и сохраняемый прогресс. Клиент отправляет намерения и отображает результат. UI читает реплицируемые атрибуты, а не Profile.Data.

| Исходник | Объект Studio | Ответственность |
|---|---|---|
| `src/server/Pets.server.luau` | ServerScriptService.PetGameplay | Базы, состояние игроков, UIAction, инвентарь, доход, загрузка и запуск Adventure |
| `src/server/Adventure.luau` | ServerScriptService.Adventure | Полевые яйца по точкам карты, груз, бита, лава, Titanic, стенды |
| `src/server/Treadmills.server.luau` | ServerScriptService.TreadmillTraining | Вход, фиксация, начисление Speed и выход |
| `src/server/PetWorld.luau` | ServerScriptService.PetWorld | Tool, модели яиц, таблички, оформление базы |
| `src/server/MergeSelection.luau` | ServerScriptService.MergeSelection | Проверка точной подтверждённой тройки ID до расходования |
| `src/server/WorldDisplays.server.luau` | ServerScriptService.WorldDisplays | Рейтинги и баннер события |
| `src/server/DevTools.luau` | ServerScriptService.DevTools | Команды DevAction и `DevAccess` только для владельца |
| `src/server/data/` | ServerScriptService.PlayerData | Config, Schema и Service сохранений |
| `src/serverPackages/ProfileStore.luau` | ServerStorage.ServerPackages.ProfileStore | Библиотека постоянных профилей и блокировки сессии |
| `src/gameplay/` | Модули ReplicatedStorage | GameConfig, PetConfig, TrainingConfig, PetVisuals, PetAnimation |
| `src/shared/` | ReplicatedStorage.ShopUI | React-компоненты, оформление и данные Shop |
| `src/client/ShopUI.client.luau` | StarterPlayerScripts.ShopUIBootstrap | Монтирование UI и контроллер окон |
| `src/client/Adventure.client.luau` | StarterPlayerScripts.AdventureControls | Выбор цели, удар, вспышки, маркер своей базы, забор баз, дистанция надписей в мире, отрисовка поднимающейся лавы |
| `src/gameplay/PickaxeEffects.luau` | ReplicatedStorage.PickaxeEffects | Клиентский замах, хват второй рукой (IK), hitstop, предсказание и эффекты попадания, крит, комбо, трещины яиц |
| `src/gameplay/HatchEffects.luau` | ReplicatedStorage.HatchEffects | Рост полевого яйца, лестница редкости, счётчик удачи, взрыв оболочки, титул редкости и появление питомца |
| `src/gameplay/BaseFence.luau` | ReplicatedStorage.BaseFence | Локальный вид забора базы по `PenLevel`: цвета, свечение, волна перестройки при улучшении |
| `src/gameplay/Audio.luau` | ReplicatedStorage.Audio | Единый клиентский звук: SoundGroup, громкость из настроек, лимиты, 3D/2D, музыка |
| `src/gameplay/SoundLibrary.luau` | ReplicatedStorage.SoundLibrary | Каталог всех звуков по ключам: ассеты, группа, громкость, высота, лимиты |
| `src/gameplay/GameFeel.luau` | ReplicatedStorage.GameFeel | Локальная тряска камеры и FOV punch |
| `src/client/Pets.client.luau` | StarterPlayerScripts.PetControls | Предпросмотр размещения, сглаживание питомцев, видимость; запускает Audio |
| `src/client/Treadmills.client.luau` | StarterPlayerScripts.TreadmillControls | Перехват прыжка для выхода |
| `src/client/DevPanel.client.luau` | StarterPlayerScripts.DevPanel | Монтирование DevPanel при `DevAccess` |

Имена StarterPlayerScripts в таблице относятся к содержимому `StarterPlayer.StarterPlayerScripts`, которое копируется в PlayerScripts игрока при запуске.

## Размер и геометрия кирок

`PetVisuals.pickaxe` клонирует MeshPart из `ReplicatedStorage.PickaxeModels`, совмещает его pivot с Handle и применяет равномерный `ScaleTo(PickaxeHeight / mesh.Size.Y)`. `PickaxeHeight = 4.875`: все 18 кирок получают одинаковую высоту при сохранении собственной ширины и толщины. Этот визуал также используется в магазине.

`PetWorld.tool` умножает текущий масштаб визуала на `PetVisuals.PickaxeToolScale = 0.65 * 1.5`. Использование `GetScale()` сохраняет предварительную нормализацию; абсолютный `ScaleTo(0.975)` отменил бы её. Итоговая высота в руке — 4.753125 studs. Точка PickaxeHead и ширина следа замаха учитывают итоговый масштаб.

Исходные импортированные размеры сохраняются в FBX, SourceImports и Templates. Runtime XML содержит InitialSize. При загрузке PetWorld сверяет MeshSize с импортированным шаблоном и восстанавливает потерянные данные через ApplyMesh, сохраняя Size. Это предотвращает неравномерное растяжение MeshPart после синхронизации Rojo.

## Жизненный цикл

PetGameplay резервирует свободную базу, загружает профиль через DataService, восстанавливает инвентарь, размещённые яйца, Tool и оборудование, затем выставляет `PetDataReady=true`. До этого действия не изменяют прогресс. При отсутствии свободной базы профиль не открывается.

Оперативное состояние находится в таблице `states[player]`; оно содержит и данные, и ссылки на сцену. Schema формирует из него сохраняемый снимок только с сериализуемыми полями. Commit обновляет Profile.Data; запрос к DataStore не нужен на каждый игровой клик.

Adventure получает серверные зависимости через `Adventure.start(options)`: состояния, проверку активной сессии, банковку груза, действие и World. Модуль запускается один раз. Полевые яйца, лава и груз живут только в памяти текущего сервера.

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

PetContents создаётся для содержимого базы. `BaseAnchor` задаёт систему относительных координат сохранений; `FloorY`, `PenHalfWidth`, `PenHalfDepth` описывают пол и границы. Базы и дорожки получают `OwnerUserId`; база также получает `PenLevel` владельца. `TrainingCenter` задаёт направление персонажа, `BeltCollision` обеспечивает физическую опору.

Adventure обращается к `Map.StartZone.Shops` и `Map.Biomes.<имя>.Floor`/`EggSpots` напрямую. Эти имена нельзя менять как косметические подписи. Стенды `BlueShopStand` (кирки, синий) и `GreenShopStand` (следы, зелёный) — копии модели Shop; prompt у них нет: AdventureControls открывает окно, пока корень персонажа внутри `TouchZone.TouchPart` перед прилавком, и закрывает при выходе. Объекты ReferenceDetails с атрибутом Interaction получают prompts; таблички рейтингов `TopMoney`/`TopSpeed`/`TopPlaytime` — копии модели Leaderboard с ожидаемой иерархией Board/LeaderboardUI/Rows (SurfaceGui на грани Right панели, содержимое внутри рамки).

Шаблоны `ServerStorage.Assets`, материал ReferenceHDStuds, освещение, облака, карта и Lava Bat в StarterPack живут только в place. Модели кирок доступны как `ReplicatedStorage.PickaxeModels`. Lava Bat в Studio собрана из 15 обычных Part: деревянное навершие и сужающийся ствол, тёмная рукоять с пятью полосами. Невидимый Handle и Grip сохранены, визуальные детали приварены к Handle, без массы и коллизий; внешние меши биты не используются. Повторяемый помощник — tools/create-studio-bat.luau.

## UI и визуальные модели

PetGameplay согласует реальные Tool с сохраняемыми pets (equipped=false) и backpackEggs. InventoryId связывает Tool с записью; размещение проверяет ID выбранного Tool, снятие с базы возвращает Tool, респавн восстанавливает все неразмещённые предметы. Клиентский useBackpack отвечает только за выбор предмета и локальную раскладку десяти слотов. Inventory не вызывает действия управления базой.

Зависимости Wally: React Luau 17.2.1, ReactRoblox 17.2.1, Ripple 0.10.2. `Packages/` синхронизируется в ReplicatedStorage; серверная ProfileStore хранится отдельно.

App управляет окнами, читает атрибуты и вызывает UIAction. Правые Pets/Eggs открывают Sidebar с выездом справа. Общий Inventory открывается только Backquote и кнопкой рядом с Settings; его вкладки хранятся отдельно от состояния экранов. Hotbar и `useBackpack` работают с Tool. EquipmentShop и AdventurePanels обслуживают внутриигровые покупки, сумку и Merge; Config содержит предложения Shop. Theme/UI/Assets задают оформление, а ModelPreview и IndexSurface показывают модели через ViewportFrame. Полный контракт навигации и проверки перед изменениями — в [ui.md](ui.md).

PetVisuals создаёт процедурные модели животных и яиц. `PetVisuals.egg(color, nest, skin)` с именем скина клонирует MeshPart из ReplicatedStorage.EggModels (PetWorld копирует его из ServerStorage.Assets.Items.Eggs при старте): масштаб ×4.2/2.325 (высота ступенчатого яйца), низ на 0.45 над pivot; без скина яйцо процедурное. Полевые яйца с `models` в GameConfig.Eggs получают случайный скин, Adventure сохраняет его для респавна. Яйцо на базе, Tool в руке и превью размещения — DefaultEgg в том же масштабе 1; Tool держит яйцо перед грудью (Grip 0.8, 0.4, 0.8). Сервер задаёт целевую позицию, yaw и состояние ходьбы; PetControls сглаживает движение и применяет PetAnimation. Эти визуальные изменения не являются источником владения или дохода. Настройки видимости меняют локальное отображение.

PickaxeEffects поддерживает Motor6D и AnimationConstraint. Кинематический AnimationConstraint имеет те же C0, C1, Part0, Part1 и Transform, поэтому мировые CFrame частей вычисляются одной цепочкой от HumanoidRootPart с уже записанными в этом шаге Transform. Ключевые кадры удара (`Swings` в PickaxeEffects) описывают путь кадра хвата правой руки (`RightHand · RightGrip.C0`) в пространстве HumanoidRootPart; `applySwingPose` применяет наклон и поворот к Waist/RootJoint, затем решает правую руку (плечо, локоть, запястье с пределом изгиба 55°) и после неё левую по фактическому положению инструмента, смешивая результат с позой Animator по весу. tool.Grip не меняется. Та же функция используется для проверки поз на неподвижном манекене в Edit. Hitstop останавливает только время замаха, соединения и восстановление Transform не меняются. В PreAnimation снимается предыдущая добавка к Transform, после Animator в PreSimulation применяется новая поза. Это предотвращает накопление поворотов и сохраняет обычную анимацию персонажа. Завершение или снятие инструмента отключает соединения, восстанавливает Transform и выключает Trail. Для кирок без импортированного меша PetVisuals создаёт отдельный невидимый Handle у нижней части рукояти, как у Wooden и Stone.

HatchEffects наблюдает модели Map.Adventure и их атрибуты. При Hatching останавливает отдачу попадания, скрывает серверную оболочку локальным Transparency=1 (LocalTransparencyModifier её не скрывал) и анимирует локальную копию без гнезда. Серверная позиция и исходный scale не меняются. Нормальное окончание оставляет оболочку скрытой до удаления сервером; преждевременное удаление отменяет эффекты. Клиентский рост питомца так же скрывает серверную модель на время появления и восстанавливает исходные Transparency, размер и pivot. Сервер различает Hatching, Revealing и Hatched, поэтому дополнительный удар и преждевременный подбор не создают дубликат добычи.

App объединяет события атрибутов и декодирует JSON только при изменении строки. React.memo и стабильные обработчики уменьшают перерисовки. Правила производительности UI — в [ui.md](ui.md#производительность).

## Звук

Весь звук идёт через `Audio`; ключи и ассеты описаны только в `SoundLibrary`. Код вызывает `Audio.play(key, target, options)`: без target — 2D, BasePart/Attachment — 3D с привязкой, Vector3 — 3D в точке. `options.pitch` и `options.volume` умножают значения каталога. `Audio.playMusic(key, fade)` и `Audio.stopMusic(fade)` переключают одну фоновую дорожку плавным переходом.

`Audio.start()` один раз создаёт `SoundService.AudioGroups` с SoundGroup Music, SFX, UI и Ambient. Громкость группы — базовая громкость каталога × сохраняемая настройка (`MusicVolume` для Music, `SFXVolume` для остальных). Sound.Volume после создания не пересчитывается; прежний двойной множитель SFXVolume (эффекты умножали громкость, затем PetControls умножал её ещё раз) устранён. Звуки, созданные вне Audio (персонаж, объекты Studio), получают группу SFX либо Music при атрибуте `IsMusic`. Для каждого ключа действуют cooldown и лимит одновременных голосов; лишний старейший голос останавливается. Ассеты каталога заранее загружаются через PreloadAsync. На сервере Audio ничего не воспроизводит.

Новый звук добавляется только записью в SoundLibrary и вызовом по ключу; Sound не создаётся вручную в игровых модулях. Источники и ID записаны в каталоге и в `assets/manifests/audio-assets.json`.

Сетевые контракты вынесены в [network-api.md](network-api.md), численные правила — в [balance.md](balance.md).
