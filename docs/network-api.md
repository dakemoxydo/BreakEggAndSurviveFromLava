# Сетевой API

Контракты реализованы в Pets.server.luau, Adventure.luau и Treadmills.server.luau. Все перечисленные remotes создаются в ReplicatedStorage сервером при запуске.

## UIAction — RemoteFunction

Вызов: `UIAction:InvokeServer(actionName, payload)`. Payload всегда таблица, в том числе `{}` для действия без параметров. Ответ: `{success: boolean, message: string?}`.

Общие условия: готовое состояние игрока, активная сессия профиля, строковое имя и таблица payload. Интервал принятых запросов — минимум 0.12 секунды. Успешное действие вызывает sync и Commit; ClaimOffline и ClaimCollectionReward дополнительно запрашивают сохранение.

| Действие | Поля payload | Поведение |
|---|---|---|
| PlacePet | position: Vector3, yaw: number? | Разместить переносимого питомца на своей базе |
| PlaceEgg | position: Vector3 | Разместить переносимое яйцо; запустить рост |
| EquipPet / UnequipPet | pet: string (ID) | Разместить на базе / вернуть Tool в Backpack; вызывается панелью базы, не Inventory |
| EquipBestPets | — | Выбрать наиболее доходных в пределах слотов |
| CarryPet | pet: string (ID) | Снять животное и взять его Tool в руку, сохраняя другие предметы Backpack |
| AddPetSlot | — | Купить один активный слот |
| GrowAllEggs | — | Вылупить размещённые яйца за Cash |
| ClaimOffline | — | Перенести офлайн-награду в Cash |
| ClaimCollectionReward | — | Забрать награду за 8 Forest видов |
| BuyPickaxe / BuyTrail | index: number | Купить или выбрать запись; индекс начинается с 1 |
| UpgradePen | — | Купить следующий уровень загона |
| UpgradeTreadmill | — | Купить следующий уровень дорожки |
| UpgradeSatchel | — | Увеличить вместимость полевого груза |
| MergePets | kind: string, pets: {string} (ровно 3 ID) | Объединить именно подтверждённые три записи одного вида и добавить отдельное яйцо в backpackEggs |
| ClaimFreeReward | — | Получить однократный подарок |
| ReturnBase | — | Переместить персонажа к базе; нельзя с грузом или на дорожке |
| SetSlowMode | enabled: boolean | Установить ограничение движения |
| SetSetting | setting: string, value: number/boolean | Изменить разрешённую настройку |

SetSetting принимает MusicVolume/SFXVolume как число с ограничением 0–1, ViewMyPets/ViewOthersPets/ViewMyEggs как boolean. Другие ключи отклоняются. Неизвестное действие возвращает отказ.

MergePets требует плотный массив трёх разных принадлежащих игроку ID с указанным kind. Отсутствующие, повторные, чужие или несовместимые ID, а также вызов только с kind отклоняются до изменения владения. Размещённые питомцы допустимы, если они входят в подтверждённую тройку. Результат сохраняет формулу 115% суммы; яйцо тяжелее лимита Schema 1e12 отклоняется до расходования. Сервер не заменяет исчезнувшего питомца другим совпадением. Reduced motion в Settings обрабатывается локально, не расширяет серверный SetSetting.

Индекс оборудования — позиция в GameConfig, а `kind` — стабильный ключ вида. В профиле оборудование хранится индексами: перестановка таблиц без миграции меняет смысл существующих сохранений.

## GameplayAction — RemoteEvent

| Вызов | Payload | Проверки |
|---|---|---|
| FireServer("Swing", eggId) | Строка ID яйца или nil для замаха без цели | Активный профиль, живой персонаж, кирка, задержка, отсутствие тренировки и груза; для урона дополнительно дистанция и состояние Egg |
| FireServer("Bat") | Нет | Lava Bat в руках, живой персонаж и задержка; воздействие на игрока требует обоих игроков в поле |

Урон кирки берётся из серверного уровня; клиент не передаёт мощность или новый HP. Бита использует отдельную ветку проверок: не следует автоматически приписывать ей все условия Swing.

Swing дополнительно отклоняется сервером при наличии полевого груза. Клиент не запускает удар при CarryingCount>0.

## GameplayFeedback — RemoteEvent

Сервер отправляет `EggHit(position, data)`, `ToolSwing(position, character)` для биты и замаха киркой без подходящей цели, `Hatch(position, data)` и `Open(windowName)`. ToolSwing рассылается всем клиентам; другие игроки видят завершающую часть замаха, атакующий сохраняет свою локальную анимацию. В Safe Zone ToolSwing биты не сопровождается уроном, отбрасыванием или потерей груза. События Stolen/Banked и текстовые уведомления успешного подбора и возврата удалены. CarryingCount/CarryingName продолжают отражать полевой груз. EggHit и Hatch рассылаются всем клиентам. EggHit содержит `model` (модель яйца), `character` (атакующий персонаж), `damage` (фактически снятые HP), `scale`, `color`, `crit` (критический удар) и `final` (удар обнулил HP). Клиент создаёт эффекты подтверждённого попадания; для чужого персонажа отображается завершающая часть удара. Атакующий уже проиграл физическую часть попадания локально в момент контакта и по EggHit добавляет число, крит и комбо. Эффекты попаданий дальше 120 studs от камеры пропускаются.

Hatch содержит `model`, `started` (GetServerTimeNow), `duration` и `luck`. Модель яйца дополнительно реплицирует HatchStarted, HatchDuration, HatchGrowth, HatchLuck, HatchRarity (редкость уже выбранного животного) и HatchedBy (UserId нанёсшего последний удар); модель появляющегося питомца — HatchRevealStarted, HatchRevealDuration, HatchRarity и HatchedBy. HatchRarity раскрывает результат с момента обнуления HP, за `FieldHatchDuration` (7 s) до появления, только для визуальной лестницы редкости; выбор уже сделан сервером и не зависит от клиента. HatchEffects следит за атрибутами моделей, поэтому событие не является единственным способом начать визуальную анимацию. Промежуточный рост и счётчик вычисляются клиентом по серверному времени. Сервер сохраняет оригинальную модель яйца до конца этапа `FieldHatchDuration` и блокирует подбор питомца ещё на `FieldRevealDuration` (0.65 s).

AdventureControls обрабатывает Open, ToolSwing, EggHit и Hatch. Запросы Swing и Bat клиент отправляет в момент контакта, через GameConfig.SwingImpactTime после начала локального замаха. Клиент не передаёт серверу урон. Текстовые уведомления также приходят через GameplayNotice/GameplayNoticeAt.

## ExitTreadmill — RemoteEvent

`ExitTreadmill:FireServer()` без payload. Сервер освобождает существующую тренировочную сессию, перемещает персонажа за ленту и устанавливает задержку повторного входа. Клиент ограничивает свои запросы интервалом 0.25 секунды; серверное состояние остаётся определяющим.

## Репликация состояния

| Атрибуты Player | Назначение |
|---|---|
| PetDataReady, BaseName | Готовность игрового состояния и текущая база |
| DataSavingEnabled, DataStoreEnvironment, DataStoreMode, LastDataSaveAt | Статус постоянных сохранений |
| Cash, Income, OfflineCash, Speed, Multiplier, Playtime, SlowMode | Экономика и передвижение |
| PetInventory, GrowingEggs | JSON-массивы данных питомцев и размещённых яиц |
| PetCapacity, PetSlotCost, GrowAllCost | Вместимость и цены действий |
| DiscoveredPets, UnlockedPets, TotalPets, CollectionRewardClaimed | Коллекция |
| OwnedPickaxes, OwnedTrails | JSON-массивы индексов купленного оборудования |
| PickaxeLevel, TrailLevel, PenLevel, TreadmillLevel, SatchelLevel | Текущие индексы/уровни |
| CarryingCount, CarryingName, InField | Полевой груз и положение относительно границы |
| EventRemaining, GameplayNotice, GameplayNoticeAt | Обратный отсчёт лавы и уведомления |
| MusicVolume, SFXVolume, ViewMyPets, ViewOthersPets, ViewMyEggs | Сохраняемые настройки |

Локальные UI-атрибуты: UIWindowOpen, PlacementKind, PlacementValid, PlacementError, AutoSwing, ReducedMotion. Их нельзя использовать как доказательство владения или успешной серверной операции. AutoSwing и ReducedMotion не входят в сохраняемые настройки Schema.

Workspace получает LavaCountdown, TitanCountdown и LavaActive. Полевые яйца имеют EggId, BreakableEgg, HP, MaxHP и Hatching. Модели базовых питомцев — OwnerUserId, PetId, PetKind, PetVisual, PetPosition, PetYaw, PetWalking, AnimationOffset и Weight. Все модели питомцев создаются с Weight в kg; Tool питомца также имеет Weight. Tool размещения сохраняет PlacementKind, PetKind и PetWeight для существующего протокола; Weight совпадает с PetWeight и сохраняемым weight. Кирка помечена Pickaxe.

JSON-атрибуты являются представлением для UI, а не интерфейсом записи профиля. Новые действия должны проверять типы payload и права на сервере; общий проверяющий код UIAction не валидирует автоматически каждое вложенное поле.
