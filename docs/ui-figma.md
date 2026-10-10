# UI: окна из Figma

Часть [ui.md](ui.md): инварианты UI действуют и здесь.

Дизайн — Figma `StealAnEggUI`; пользователь импортирует окно плагином FigBlox (Artwork layers: Separate) и кладёт ScreenGui с `Enabled=false` в Studio: `ReplicatedStorage.UITemplates.<Имя>`. Шаблон хранится только в place; Rojo его не удаляет (`ignoreUnknownInstances`), в release-сборке его нет, тогда показывается старое React-окно.

`FigmaTemplate.luau`: `get` ищет шаблон, `scroll` меняет клипующий Frame на ScrollingFrame (слой `ScrollBar` задаёт цвет и толщину), `button` добавляет кнопку-хитбокс (по умолчанию `Hitbox`), `UIClick` и hover/press по UI-09, `setText` пишет текст и его копию `<имя>_Shadow`. Имена слоёв в Figma совпадают с кодом.

Trails Shop (`TrailsShop.luau`, шаблон `TrailsShop`): App рендерит его внутри `ModalTransition` вместо `UI.Surface` с шапкой; блокер, переход и Escape общие. Окно 1301×720 масштабируется под `windowW×windowH`. По карточке `ShopItemN` на каждый `GameConfig.Trails`; цвет и картинка карточки — из шаблона, новый трейл требует нового импорта. Код меняет `Title`, `Value`, `Condition` (недостаток — `FEE545`), `Label` кнопки `BuyEquipmentN` и `Balance`. Кнопка нажимается для покупки при достатке Cash или для экипировки купленного; при `busy` и закрытии не нажимается. `ExitBtn` закрывает окно. Прокрутка горизонтальная.

HUD (`FigmaHud.luau`, шаблон `Hud`, кадр `Hud V2` 1920×1080) — только широкий экран; компактный экран оставляет React HUD. Группы `LeftSideButtons`, `RightSideButtins`, `Counters` масштабируются одним коэффициентом `min(width/1920, height/1080)`: левая колонка прижата влево, правая — вправо, обе на прежней доле высоты; `Counters` прижаты к левому нижнему углу. Хитбоксы носят имена прежних кнопок: `OpenShop`, `OpenIndex`, `OpenSettings`, `OpenPets`, `Eggs`, `GetSpeed` (Shop → Speed Packs), `GetCash` (Shop → Cash Packs). Rewards и Rebirth — оформление без действия: механик нет. Счётчики `SpeedValue` и `CashValue` показывают Speed и Cash числом, без множителя и дохода в секунду.

Видимость: правая колонка скрыта (`Visible=false`), пока открыт Sidebar (UI-05); счётчики скрыты при открытом Inventory; при Offline Cash HUD не рисуется. Остаются React-элементы: `SlowMode` и подпись в верхней строке справа от системных кнопок Roblox (x=244), `OpenInventory` над левой колонкой рядом с Settings (UI-02), таймер события, Auto Swing и хотбар.
