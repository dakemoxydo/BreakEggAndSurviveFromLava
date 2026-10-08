# Полный пак кирок для Roblox Studio — v03

В этом паке **18 кирок**, включая алмазную. Источник — `pickaxes-asset-pack-review-v20.blend`, сцена `Pickaxe_Pack_Review`. Каждая кирка экспортирована одним отдельным именованным мешем с одним материалом и одной UV-развёрткой. Цвет, тёмные studs и гранёные вставки запечены в индивидуальные PNG 2048×2048. Выпуклой studs-геометрии нет.

## Импорт всего пака

1. Распакуйте ZIP целиком. В Studio откройте **File → Import** и выберите **Pickaxes_Pack.fbx**.
2. Установите **Scale Unit = Studs**, масштаб **1**, **World Up = Top**, **World Forward = Front**.
3. Оставьте **Merge Meshes выключенным**: в превью должны быть 18 отдельных MeshPart. У каждого объекта оставьте **Use Imported Pivot включённым**. Точка начала каждого меша находится в месте хвата рукояти.
4. Для первоначальной расстановки включите **Anchored**. Если хотите загрузить ассеты в аккаунт или группу игры, укажите нужного **Creator**. Перед импортом проверьте состав и цветные текстуры в превью.
5. Нажмите **Import**. Общий файл содержит кирки в одном ряду с шагом 6.5 studs. Для импорта отдельных кирок используйте файлы в `models/` — их точка хвата находится в (0, 0, 0).

Параметры соответствуют [документации Roblox Importer](https://create.roblox.com/docs/studio/importer) и [рекомендациям Roblox по Blender](https://create.roblox.com/docs/art/blender). FBX экспортирован с Apply Scaling = FBX Unit Scale, Scale = 1, Y Up, Z Forward; численные размеры мешей сохранены для Scale Unit = Studs.

## Текстуры

PNG встроены в FBX и лежат отдельно в `textures/`. Если Studio не подхватил цвет автоматически, загрузите PNG нужной кирки и назначьте его в **MeshPart.TextureID** либо **SurfaceAppearance.ColorMap**. Соответствия приведены в таблице ниже и `manifest.json`. У MeshPart оставьте белый Color, чтобы не тонировать запечённый атлас повторно. Прозрачность не требуется.

Атлас содержит цвет; свет от лавы, молнии или магических вставок дополнительно настраивается игровыми эффектами после импорта. Камеры, свет, история моделирования и Blender-шейдеры не входят в FBX.

## Файлы

- `Pickaxes_Pack.fbx` — основной полный пак, 18 отдельных мешей со встроенными текстурами.
- `models/` — 18 отдельных FBX.
- `textures/` — 18 индивидуальных цветовых PNG.
- `source/Pickaxes_Import.blend` — чистая экспортная сцена: 18 мешей с упакованными текстурами, без камер и света.
- `preview.png` и `diamond-preview.png` — общий ряд и крупный вид алмазной.
- `manifest.json` — ключи, размеры, треугольники, пути и настройки импорта.
- `export-inspection.json` — проверенный фактический состав бинарных FBX.
- `attachment-audit.json` — подтверждение креплений и закрытой геометрии всех 18 исходных кирок.
- `SHA256SUMS.txt` — контрольные суммы.

## Размеры и соответствия

Размеры указаны в studs: **X × Y × Z** в Studio. Файлы имеют названия `<Key>Pickaxe`; для текущего игрового кода шаблон MeshPart должен называться ровно `<Key>`, например `Wooden`, `Diamond`, `UFO`, и находиться в `ReplicatedStorage.PickaxeModels`. Сохраните исходные импорты в `ServerStorage.Assets.Items.Pickaxes.SourceImports`. В этом проекте игровые шаблоны уже заменены; при переносе в другой проект их подключение выполняется отдельно.

| Кирка / ключ | MeshPart | Размер X × Y × Z | Треугольники | Текстура |
| --- | --- | --- | ---: | --- |
| Деревянная / `Wooden` | `WoodenPickaxe` | 5.320 × 4.785 × 1.358 | 528 | `textures/Wooden_Color.png` |
| Каменная / `Stone` | `StonePickaxe` | 5.360 × 4.875 × 1.098 | 572 | `textures/Stone_Color.png` |
| Железная / `Iron` | `IronPickaxe` | 5.360 × 4.970 × 1.048 | 880 | `textures/Iron_Color.png` |
| Золотая / `Golden` | `GoldenPickaxe` | 5.440 × 5.050 × 1.270 | 716 | `textures/Golden_Color.png` |
| Алмазная / `Diamond` | `DiamondPickaxe` | 5.520 × 5.075 × 1.240 | 654 | `textures/Diamond_Color.png` |
| Клубничная / `Strawberry` | `StrawberryPickaxe` | 5.540 × 5.080 × 1.270 | 828 | `textures/Strawberry_Color.png` |
| Кактусовая / `Cactus` | `CactusPickaxe` | 5.520 × 5.095 × 0.880 | 916 | `textures/Cactus_Color.png` |
| Молния / `Lightning` | `LightningPickaxe` | 5.542 × 5.085 × 1.175 | 1288 | `textures/Lightning_Color.png` |
| Конфетная / `Candy` | `CandyPickaxe` | 5.396 × 5.085 × 0.920 | 1560 | `textures/Candy_Color.png` |
| Радужная / `Rainbow` | `RainbowPickaxe` | 5.560 × 5.080 × 1.280 | 1148 | `textures/Rainbow_Color.png` |
| Кристальная / `Crystal` | `CrystalPickaxe` | 5.660 × 6.010 × 1.260 | 740 | `textures/Crystal_Color.png` |
| Демоническая / `Demon` | `DemonPickaxe` | 5.620 × 5.880 × 1.370 | 1262 | `textures/Demon_Color.png` |
| Хакерская / `Hacker` | `HackerPickaxe` | 5.603 × 4.935 × 1.147 | 2056 | `textures/Hacker_Color.png` |
| НЛО / `UFO` | `UFOPickaxe` | 5.603 × 5.320 × 2.060 | 1972 | `textures/UFO_Color.png` |
| Тайная / `Secret` | `SecretPickaxe` | 5.603 × 5.450 × 1.290 | 1070 | `textures/Secret_Color.png` |
| Ледяной дракон / `Cool` | `CoolPickaxe` | 5.603 × 5.980 × 1.408 | 1038 | `textures/Cool_Color.png` |
| Галактическая / `Galaxy` | `GalaxyPickaxe` | 5.603 × 5.276 × 1.198 | 1584 | `textures/Galaxy_Color.png` |
| Небесная / `Celestial` | `CelestialPickaxe` | 5.603 × 6.107 × 1.470 | 2438 | `textures/Celestial_Color.png` |

## Проверка

Бинарные FBX прочитаны без импорта в сцену: общий файл содержит 18 мешей и 18 встроенных PNG; каждый отдельный файл содержит ровно один меш, один материал и одну текстуру. Имена, число треугольников, единичные масштабы, локальные размеры, UV внутри атласа и нулевая точка начала отдельных файлов совпадают с экспортными данными. Всего 21 250 треугольников; максимум на одной кирке — 2 438. Проверка геометрии исходного ряда подтвердила связный граф креплений для каждой модели и закрытые поверхности.

В этом проекте полный пак уже импортирован в Studio; новые MeshId/TextureID записаны в manifest.json и соответствуют всем 18 runtime-шаблонам. Исходники сохранены в ServerStorage.Assets.Items.Pickaxes.SourceImports.Pickaxes_Pack_v03, нормализованные копии — в Templates, предыдущие шаблоны — в Archive.BeforeFullPack_v03. Игровые тесты и Play не запускались. После импорта вручную проверьте: 18 отдельных цветных кирок, размеры по таблице, правильную вертикальную ориентацию и сохранённую точку хвата. Хват и удар в игре проверяются после замены шаблонов.
