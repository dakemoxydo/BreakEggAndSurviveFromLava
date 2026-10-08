# Break Egg and Survive From Lava

Roblox-игра: разбивать яйца, возвращать животных в Safe Zone, размещать их на базе и развивать оборудование.

Источник истины о правилах, балансе, архитектуре и разработке — [docs/README.md](docs/README.md). Изменения механик сопровождать обновлением соответствующих Markdown-файлов в docs.

- [Правила игры](docs/gameplay.md)
- [UI и правила навигации](docs/ui.md) — прочитать перед изменением интерфейса или его ввода.
- [Баланс и каталог](docs/balance.md)
- [Архитектура](docs/architecture.md) и [сетевой API](docs/network-api.md)
- [Сборка и работа с проектом](docs/development.md)
- [Сохранения](docs/saves.md)
- [Проверки и ограничения](docs/verification.md)

Исходники находятся в src, локальные ассеты — в assets. Для Studio использовать RobloxMCP, для синхронизации — Rojo, согласно AGENTS.md. Команды сборки и различия default/release/bundle описаны в документации разработки.

Текущая реализация содержит три обычных биома и 25 видов животных. Платные предложения не настроены. История воссоздания и прежних проверок сохранена в [docs/reference-recreation.md](docs/reference-recreation.md).
