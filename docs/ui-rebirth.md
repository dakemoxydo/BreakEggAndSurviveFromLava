# UI: Rebirth

Часть [ui.md](ui.md) и [ui-figma.md](ui-figma.md); общие инварианты UI действуют здесь. Механика и сброс прогресса — [gameplay.md](gameplay.md#rebirth), статус проверок — [verification.md](verification.md).

## Макет и данные

`FigmaRebirthWindow.luau`, шаблон `ReplicatedStorage.UITemplates.Rebirth`: экспортируется `RebirthFrame` 975×668 из холста `Rebirth Window` 1920×1080, без фоновой сцены. Оболочка — Rewards; розовая шапка и иконка — из Rebirth в HUD. App использует общий `ModalTransition` и размеры центральных Figma-окон; кадр вписывается одним UIScale. Шаблон хранится в place; без него остаётся React fallback `RebirthWindow.luau`.

Код заполняет `MainFrame.Count`, `IncomeBonus.Values`, `LuckBonus.Values`, `RebirthProgress.Label` реальными атрибутами и формулами `GameConfig`; `Fill` плавно меняет ширину через Ripple, не выходя за полосу. Размер динамического текста рассчитывается через `TextService:GetTextBoundsAsync` с исходным FontFace, не выше размера макета и без переноса строки. `ResetNote`/`KeepNote` описывают сброс Cash/Speed и сохранение предметов. Вход — Rebirth широкого Figma-HUD; компактный вход отсутствует (BL-017).

## Действия и анимации

`RebirthAction` и `ConfirmAction` — зелёная и красная кнопки. В Figma обе включены, подтверждение лежит под обычной кнопкой; код показывает только нужное состояние. Первое нажатие включает подтверждение на 3 s, второе вызывает `Rebirth`; закрытие или потеря достаточного Cash отменяют подтверждение. При busy, закрытии, MAX и недостатке Cash запросы блокируются; обычная кнопка затеняется `DisabledVeil`, надпись показывает причину. Успех и бонусы отражаются после ответа сервера. `ExitBtn` закрывает окно.

Анимации: общий fade/scale окна, каскад появления карточек и прогресса, hover/press, отскок подтверждения, лента Studs шапки, покачивание иконок и блики карточек. Блики кнопок неподвижны. ReducedMotion останавливает движение и сразу задаёт прогресс. Маски — CanvasGroup; анимации освобождаются при закрытии. Экспорт `blend=bake` сохраняет цвета смешанных слоёв; дочерние ImageLabel с ZIndex=0 приведены к ZIndex контейнера, как в Index.
