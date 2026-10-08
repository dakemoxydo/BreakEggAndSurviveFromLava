# Кирки со studs — концепты v01

Набор содержит 18 отдельных PNG с настоящим прозрачным фоном. Файлы созданы встроенным ImageGen, а не Blender. Исходное разрешение каждого изображения — 1254 × 1254. Полные промпты, исходные файлы генератора и проверенные свойства alpha находятся в catalog.json.

Текущий проект: [pack/models/pickaxes-asset-pack-review-v20.blend](pack/models/pickaxes-asset-pack-review-v20.blend), сцена `Pickaxe_Pack_Review`. В одном горизонтальном ряду расположены все 18 моделей; шаг по X — 6.5. Алмазная v02 заново создана в слоте 05 по текущему стилю и референсу, с закреплёнными вставками. Историческая версия v06 сохранена.

Эталон — деревянная reference v04. Все модели используют согласованный блочный ступенчатый силуэт и плоские тёмные studs-текстуры. Каменная v03 и железная v02 имеют отдельные секции вместо ранних гладких дуг. Полный пак экспортирован в `pack/exports/roblox-import-v03/Pickaxes_Pack.fbx` и упакован в `pack/exports/pickaxes-full-18-roblox-v03.zip`. Все 18 игровых шаблонов в Studio заменены новыми MeshPart. Runtime-каталог ReplicatedStorage.PickaxeModels синхронизируется из XML через Rojo. Старые `.blend` сохранены.

По указанию пользователя оставшиеся кирки 13–18 закончены последовательно: каждая создана отдельно, проверена на крепление деталей и осмотрена на крупном рендере до перехода к следующей. Их художественное согласование остаётся за пользователем.

- **Хакерская** — Графитовые ступенчатые секции, зелёные наконечники и симметричные линии, экран с кодовыми скобками.
- **НЛО** — Бирюзовые ступенчатые секции, серебряная летающая тарелка с гранёным зелёным куполом, порты и зелёное навершие.
- **Тайная** — Тёмная фиолетовая броня, локальное светящееся ядро и швы, закреплённые кристальные зубцы и корона.
- **Ледяной дракон** — Голубые ступенчатые секции, парные ледяные рога и зубцы, синяя маска дракона с голубыми глазами, серебряные обоймы.
- **Галактическая** — Ступенчатые секции с рисунком туманности и тёмными studs, гранёная планета с золотой орбитой, звёзды и золотые кольца.
- **Небесная** — Светлые ступенчатые секции, широкие закреплённые перья, двойной золотой нимб, корона и голубые звёздные вставки.

Общий вид: [pack/previews/pack-full-18-review-v02.png](pack/previews/pack-full-18-review-v02.png). Крупные виды шести новых моделей: [pack/previews/remaining-six-review-v01.png](pack/previews/remaining-six-review-v01.png). Отдельные изображения — `pack/previews/<key>-detail-review-v01.png`. Тематические текстуры — `pack/textures/<key>-dark-studs-v01.png`; все используемые изображения упакованы в Blender. Клубничная дополнительно использует cream-studs, конфетная — striped-dark-studs.

### Проверка креплений

Итоговый отчёт: [pack/previews/pack-attachment-audit-v20.json](pack/previews/pack-attachment-audit-v20.json). Проверка охватывает все 18 видимых моделей, а не только новые шесть. Для каждой меш разбит на фактические связные острова; контакты подтверждены пересечениями треугольников, касанием поверхностей либо вложением объёма. Связный граф контактов включает все детали каждой кирки. Наличие общего parent само по себе не считается креплением. Допуск касания — 0.0002 единицы Blender. Отдельно проверены закрытые грани без вырожденных полигонов и геометрическая зеркальная симметрия новых моделей.

Исправлены измеренные зазоры под вставками деревянной, каменной, железной, золотой, конфетной, кристальной и демонической. Два свободных кристальных осколка опущены в посадочные места; лавовые накладки навершия получили закрытую толщину. У НЛО уменьшен центральный корпус для открытого купола, у галактической освобождён обзор планеты и орбиты. Линии хакерской рукояти сделаны парными; гранёная планета повернута вокруг своей оси для точной зеркальной геометрии. Резервная копия до правок старых моделей: `.tools/before-pack-attachment-fixes.blend`.

Игровые тесты и Play не запускались. Пользователю остаётся оценить внешний вид, пропорции и тематические детали в Blender; игровой хват и масштаб проверяются после отдельного импорта.

## Порядок набора

1. Wooden — Деревянная: [01-wooden/references/01-wooden-pickaxe-studs-v01.png](01-wooden/references/01-wooden-pickaxe-studs-v01.png)
2. Stone — Каменная: [02-stone/references/02-stone-pickaxe-studs-v02.png](02-stone/references/02-stone-pickaxe-studs-v02.png)
3. Iron — Железная: [03-iron/references/03-iron-pickaxe-studs-v01.png](03-iron/references/03-iron-pickaxe-studs-v01.png)
4. Golden — Золотая: [04-golden/references/04-golden-pickaxe-studs-v01.png](04-golden/references/04-golden-pickaxe-studs-v01.png)
5. Diamond — Алмазная: [05-diamond/references/05-diamond-pickaxe-studs-v01.png](05-diamond/references/05-diamond-pickaxe-studs-v01.png)
6. Strawberry — Клубничная: [06-strawberry/references/06-strawberry-pickaxe-studs-v01.png](06-strawberry/references/06-strawberry-pickaxe-studs-v01.png)
7. Cactus — Кактусовая: [07-cactus/references/07-cactus-pickaxe-studs-v01.png](07-cactus/references/07-cactus-pickaxe-studs-v01.png)
8. Lightning — Молния: [08-lightning/references/08-lightning-pickaxe-studs-v01.png](08-lightning/references/08-lightning-pickaxe-studs-v01.png)
9. Candy — Конфетная: [09-candy/references/09-candy-pickaxe-studs-v02.png](09-candy/references/09-candy-pickaxe-studs-v02.png)
10. Rainbow — Радужная: [10-rainbow/references/10-rainbow-pickaxe-studs-v01.png](10-rainbow/references/10-rainbow-pickaxe-studs-v01.png)
11. Crystal — Кристальная: [11-crystal/references/11-crystal-pickaxe-studs-v01.png](11-crystal/references/11-crystal-pickaxe-studs-v01.png)
12. Demon — Демоническая: [12-demon/references/12-demon-pickaxe-studs-v01.png](12-demon/references/12-demon-pickaxe-studs-v01.png)
13. Hacker — Хакерская: [13-hacker/references/13-hacker-pickaxe-studs-v01.png](13-hacker/references/13-hacker-pickaxe-studs-v01.png)
14. UFO — НЛО: [14-ufo/references/14-ufo-pickaxe-studs-v01.png](14-ufo/references/14-ufo-pickaxe-studs-v01.png)
15. Secret — Тайная: [15-secret/references/15-secret-pickaxe-studs-v01.png](15-secret/references/15-secret-pickaxe-studs-v01.png)
16. Cool — Ледяной дракон: [16-cool/references/16-cool-pickaxe-studs-v01.png](16-cool/references/16-cool-pickaxe-studs-v01.png)
17. Galaxy — Галактическая: [17-galaxy/references/17-galaxy-pickaxe-studs-v01.png](17-galaxy/references/17-galaxy-pickaxe-studs-v01.png)
18. Celestial — Небесная: [18-celestial/references/18-celestial-pickaxe-studs-v01.png](18-celestial/references/18-celestial-pickaxe-studs-v01.png)

## Папка каждой кирки

- references/ — выбранный референс и промпты; archive/ внутри содержит заменённые варианты.
- models/ — исходные файлы Blender (.blend).
- textures/ — текстуры модели.
- icons/ — подготовленные финальные иконки магазина.
- exports/ — экспорт моделей для Roblox (.fbx, .glb, .rbxmx).
- asset.json — ключ предмета, выбранный референс и статус согласования.

Общий лист находится в previews/, архив набора — в exports/. PNG в references/ являются текущими концептами; финальные иконки и модели будут созданы после согласования.

## Общий принцип моделирования

Эталон стиля — итоговая деревянная reference v04. Сохранять её пропорции и язык простых гранёных форм, аккуратные фаски и тёмные квадратные studs в текстуре. PNG-концепты служат тематическими референсами, а не инструкциями для точного копирования. Выпуклые LEGO-квадратики из референсов не создавать геометрией; остальные детали адаптировать к теме каждой кирки. Делать модели симметричными, ровными и с аккуратными стыками.

Работать строго по одной кирке: закончить отдельную модель, проверить крепление всех деталей и поставить рядом с предыдущими в одном ряду в Blender. По умолчанию дожидаться оценки перед следующей; явное указание пользователя закончить оставшиеся разрешает последовательную работу над всем остатком с отдельной проверкой каждой модели. Для будущих моделей продолжать сцену `Pickaxe_Pack_Review`; стартовый шаг ряда по X — 6.5. Референсы и исторические промпты могут содержать старые требования к выпуклым studs; правила этого раздела имеют приоритет.

PNG сохранены также в общей библиотеке: Games/BreakEggAndSurviveFromLava/PickaxeConcepts/studs-v01. Roblox asset ID пока не назначены. Действующий UI магазина и модели в Studio на этом этапе не заменены.

При начале работы над клубничной в живой сцене уже отсутствовала алмазная коллекция. Эти изменения сохранены: алмазная остаётся в предыдущем `pack/models/pickaxes-asset-pack-review-v06.blend`; в v19 на её месте оставался свободный слот; в v20 алмазная заново создана по указанию пользователя. Снимок живой сцены перед добавлением клубничной находится в `.tools/before-strawberry-live-edits.blend`.

## Полный пак для импорта — v03

[ZIP](pack/exports/pickaxes-full-18-roblox-v03.zip) · [Основной FBX](pack/exports/roblox-import-v03/Pickaxes_Pack.fbx) · [Инструкция импорта](pack/exports/roblox-import-v03/README_IMPORT.md).

18 отдельных именованных мешей, один материал и индивидуальный запечённый атлас 2048×2048 на каждую кирку. Все текстуры встроены в FBX и предоставлены отдельными PNG. Чистый Blender-исходник экспорта — `pack/exports/roblox-import-v03/source/Pickaxes_Import.blend`; исторические и обзорные сцены исключены из него. Подготовительная версия v02 содержала 17 моделей и заменена этим полным паком; используйте v03. Состав файлов проверен чтением бинарных FBX, без запуска игровых тестов. Полный пак импортирован в Studio; все 18 игровых шаблонов заменены, текстуры и нормализованные точки хвата сохранены. Игровые ощущения проверяет пользователь.

## Установка в игру

Исходный импорт находится в `ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03`; 18 нормализованных копий — в `Templates`. Старые шаблоны сохранены в `Archive.BeforeFullPack_v03`. Выставленный пак удалён из Workspace переносом в хранилище. В `ReplicatedStorage.PickaxeModels` лежат все ключи GameConfig, каждый с новым MeshId/TextureID, белым Color, отключёнными коллизиями и включённым Massless. XML использует Color3uint8, чтобы Rojo не подменял цвет серым по умолчанию.

PetVisuals совмещает pivot mesh с Handle, поэтому импортные координаты ряда и поворот pivot не попадают в руку или магазин. Все 18 визуалов, включая Wooden, равномерно приводятся к высоте 4.875 studs — исходной высоте Stone. Ширина и толщина сохраняют пропорции каждой модели; одинаковая высота не означает одинаковую ширину тематических деталей.

При сборке Tool нормализованный масштаб дополнительно умножается на `0.65 × 1.5 = 0.975`. Итоговая высота каждой кирки в руке — 4.753125 studs. Это увеличение в 1.5 раза относительно прежнего размера нормализованной кирки. Превью магазина использует общую высоту 4.875 studs; множитель Tool применяется только к предмету в руке. PickaxeHead задаёт центр следа удара, а ширина следа меняется вместе с размером кирки.

Исходный FBX, Blender-модели и шаблоны хранилища сохраняют импортные размеры. Нормализация выполняется в `src/gameplay/PetVisuals.luau`, увеличение Tool — в `src/server/PetWorld.luau`. XML содержит InitialSize; при потере MeshSize PetWorld восстанавливает геометрию через ApplyMesh из Templates до создания инструментов.

Игровые тесты, Play и сборки не запускались. Перезапустить Play и проверить одинаковую высоту Wooden/Stone/Diamond/Celestial, пропорции и толщину, хват, след замаха, попадание по яйцу, смену кирки и респавн. Place сохранить в Studio.
