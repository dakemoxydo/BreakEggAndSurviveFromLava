# Работа с проектом

## Инструменты и источники

GitHub проекта: [dakemoxydo/BreakEggAndSurviveFromLava](https://github.com/dakemoxydo/BreakEggAndSurviveFromLava), основная ветка `main`. Бинарные модели, текстуры, архивы и Roblox-файлы хранятся через Git LFS; правила находятся в корневом `.gitattributes`. Перед клонированием установить Git LFS и выполнить `git lfs install`; после клонирования при необходимости выполнить `git lfs pull`. Папка `.tools/` и перечисленные в `.gitignore` сборочные артефакты не входят в репозиторий.

Правила работы агентов и граница Rojo/MCP — в `AGENTS.md`. Общая библиотека ассетов находится в `C:\Users\dakem\Documents\RobloxGames\Assets`; файлы конкретной игры — в локальном `assets/`.

Исходники Luau находятся в `src/`. `docs/` содержит правила и техническую документацию. `.rbxlx`, `.rbxmx` UI-пакет и JSON-экспорты исходников — сборочные артефакты; изменение только артефакта не обновляет исходник.

Не синхронизировать Markdown в DataModel: `docs/` не входит в проекты Rojo.

## Запуск и сборка

Рабочая папка: `C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava`. Версии инструментов закреплены в `rokit.toml` (rojo 7.7.0, selene 0.31.0, stylua 2.5.2); установка — `rokit install`. Если `selene`/`stylua` отвечают «Aftman error … no aftman.toml files list this tool», значит shim aftman стоит в PATH раньше rokit: вызывать `~/.rokit/bin/<tool>` или убрать `.aftman/bin` из PATH.

React, ReactRoblox и Ripple подключены через Wally: `wally.toml`, `wally.lock`, готовая папка `Packages/` хранится в репозитории. Wally нужен только для обновления зависимостей (`wally install`).

```powershell
stylua src
selene src
rojo build default.project.json -o .tools/check.rbxlx
```

Конфигурация: `stylua.toml`, `.styluaignore` (сторонняя ProfileStore не форматируется), `selene.toml` (std roblox; правило Roact для `Name` выключено, так как React Luau здесь задаёт `Name` пропом).

```powershell
rojo serve default.project.json --address 127.0.0.1
rojo build bundle.project.json -o ShopUIBundle.rbxmx
```

В Studio подключить плагин Rojo к `127.0.0.1:34872`. Для работы с полной игрой открыть существующий полный place, затем подключить default-проект. Default не содержит карту: он обновляет скрипты, зависимости и модели кирок в уже существующем мире.

| Проект | Назначение |
|---|---|
| default.project.json | Исходники в текущей ручной сцене; сохраняет неизвестные объекты в указанных сервисах через ignoreUnknownInstances |
| bundle.project.json | Отдельный UI-пакет; его дерево не включает всю серверную игру |

Успешная сборка подтверждает доступность указанных файлов и формирование артефакта. Она сама по себе не проверяет игровую логику, сетевые сценарии или покупки.

Источник истины для мира — сам place: карта, `ServerStorage.Assets`, освещение, Lava Bat в StarterPack и `UITemplates` хранятся только в нём. Код приходит из `src/` через Rojo. Игра публикуется из Studio (File → Publish); сборки полного place из файлов и экспорта мира нет. Резервная копия мира — история версий place в Roblox и сохранённые пользователем `.rbxl`.

## Studio и сохранения

Для постоянных Studio-профилей требуется Enable Studio Access to API Services в настройках безопасности experience. По умолчанию StudioMode — Persistent; данные идут в отдельное Studio-хранилище. Для экспериментов временно установить атрибут StudioMode="Mock" у ServerScriptService.PlayerData.Config в Edit до запуска Play и удалить после остановки. Исходники для этого не меняются; live игнорирует атрибут. Mock не включается автоматически при ошибке API.

Перед проверкой через RobloxMCP получить список Studio и их режим, выбрать нужный place. Дерево Edit подходит для инспекции сцены и исходников; runtime-механики проверять в Server/Client после запуска Play. Останавливать Play и возвращать временные параметры событий после экспериментов. Для проверки ProfileStore использовать отдельный Mock-ключ из `tools/verify-profiles.luau`, не игровые ключи.

## Порядок изменения механики

1. Прочитать [gameplay.md](gameplay.md), [architecture.md](architecture.md) и соответствующий специализированный документ.
2. Изменить канонические файлы в src; численные параметры вынести в существующий конфиг, где это соответствует системе.
3. Обновить описание правил, таблицу [баланса](balance.md), [API](network-api.md) и схему сохранений при необходимости.
4. Синхронизировать Rojo, проверить результат через RobloxMCP и выполнить подходящие методы и сценарии [verification.md](verification.md).
5. Изменения карты сохраняются в place; пользователь сохраняет и публикует его из Studio.
6. Обновить строку статуса в [verification.md](verification.md). Подробности проверки — в ответ пользователю и сообщение коммита, не в документы систем.

Не переименовывать DataStore при обычном обновлении. Не переставлять каталог оборудования без учёта сохранённых индексов. Не менять стабильные ключи животных без миграции. Модели, Instance, Vector3 и CFrame не добавлять в Profile.Data.

## Карта и ассеты

Организация файлов описана в [assets/README.md](../assets/README.md). Для предмета хранить references, models, textures, icons и exports рядом. Roblox ID, источники и выбранные варианты фиксировать в манифестах, включая `assets/manifests/reference-assets.json` и каталог кирок.

В Studio каталог шаблонов находится в ServerStorage.Assets: Items/Pickaxes/{Templates,SourceImports}, Items/Bats, Items/Eggs (воксельные MeshPart яиц, Color = акцент для осколков и трещин; runtime-копия — ReplicatedStorage.EggModels), Environment/Treadmills, Environment/Props и Pets. Исходные импорты не оставлять выставленными в Workspace. Runtime-копии кирок в ReplicatedStorage.PickaxeModels обслуживают UI и выдачу Tool. Шаблоны питомцев из Assets.Pets сервер копирует в ReplicatedStorage.PetModels при старте; Animation внутри шаблона требуют опубликованных AnimationId. После импорта FBX-анимации для костяного рига позы костей содержат и их исходный поворот, и Animator применяет его дважды (кости, направленные вниз, переворачиваются). Перед публикацией выполнить `tools/fix-bone-pose-rest.luau` для этих KeyframeSequence. Старый Assets.Weapons перенесён в Assets.Items.Bats; TreadmillLvl1 находится в Assets.Environment.Treadmills. Помощники place-treadmills и equip-imported-bat используют эти пути. Default синхронизирует исходники и рабочие PickaxeModels, сохраняя ручное серверное хранилище.

Окна и HUD из Figma хранятся только в place: `ReplicatedStorage.UITemplates` (ScreenGui с `Enabled=false`, импорт FigBlox). Default-проект их сохраняет. Подробнее — [ui-figma.md](ui-figma.md).

`tools/build-parkour-field.luau` строит паркур-уровни, украшения и `EggSpots` полевых зон; запускается повторно, старое окружение зон сохраняет в WorldBackups один раз. `tools/apply-reference-details.luau` предназначен для повторяемых правок оформления в Edit с резервной копией в ServerStorage.WorldBackups. Скрипты размещения и организации карты в tools — операции над сценой, а не обязательные шаги каждого запуска игры.

`tools/rojo-transfer.py` читает канонический XML из `.tools/reference-game.rbxlx` (`rojo build default.project.json -o .tools/reference-game.rbxlx`) для переноса модулей через MCP. Не использовать вместо перезапуска `rojo serve` после нового mapping; только если пользователь явно попросил.

## Публикация

Для нового аккаунта изображения из проекта повторно загружены; файлы, владелец и соответствие ID записаны в `assets/manifests/account-reimport.json`. `tools/rebind-local-images.py` обновляет ссылки в src, манифестах и генерируемых XML ассетов. Кирки и дорожки повторно импортированы; Lava Bat в Studio использует обычные Part. Локальное аудио требует отдельного импорта; порядок — `assets/IMPORT-TO-NEW-ACCOUNT.md`. Перенос изображений не означает завершённый перенос всех ассетов.

Локальная сборка не означает публикацию. Дата и версия последнего опубликованного состояния здесь не подтверждены. Текущие Robux-предложения имеют ID=0; перед их включением нужны реальные продукты/пасы, серверная выдача и обработка чеков. Полный перечень непроверенного находится в [verification.md](verification.md).
