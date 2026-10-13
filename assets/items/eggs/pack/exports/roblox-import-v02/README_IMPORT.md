# Пак яиц для Roblox Studio — v02

В паке **11 яиц**. Лесной ряд: `DefaultEgg`, `MossEgg`, `BirchEgg`, `MushroomEgg`, `AcornEgg`, `EnchantedEgg` (те же, что в v01). Пустынный ряд: `CactusEgg`, `PharaohEgg`, `SandstormEgg`, `ScorpionEgg`, `OasisEgg`. Источник — `assets/items/eggs/default/models/egg-default.blend` (сцена `Scene`), сборка — `tools/blender/build-egg-pack.py`, экспорт — `tools/blender/export-egg-pack.py`.

Каждое яйцо — один меш, один материал, одна UV-развёртка. Цвет и studs запечены в индивидуальный PNG 2048×2048. Pivot каждого яйца — центр низа.

## Импорт всего пака

1. В Studio откройте **File → Import** и выберите **Eggs_Pack.fbx**.
2. **Scale Unit = Studs**, масштаб **1**, **World Up = Top**, **World Forward = Front**.
3. **Merge Meshes выключен**: в превью должно быть 11 отдельных MeshPart. **Use Imported Pivot включён**.
4. Для расстановки включите **Anchored**. Для загрузки в аккаунт или группу игры укажите нужного **Creator**. Перед импортом проверьте цветные текстуры в превью.
5. Нажмите **Import**. Лесной ряд стоит по X с шагом 3 studs, пустынный — так же, на 6 studs дальше по −Z. Для импорта по одному используйте `models/` — там pivot каждого яйца в (0, 0, 0).

FBX экспортирован как пак кирок: Apply Scaling = FBX Units Scale, Scale = 1, Y Up, Z Forward; 1 единица Blender = 1 stud.

## Текстуры

PNG встроены в FBX и лежат отдельно в `textures/`. Если Studio не подхватил цвет, назначьте PNG нужного яйца в **MeshPart.TextureID** или **SurfaceAppearance.ColorMap**. Color у MeshPart оставьте белым, чтобы не тонировать текстуру повторно.

Свечение в FBX не переносится: у `EnchantedEgg` (руны, кристаллы), `SandstormEgg` (трещины) и `OasisEgg` (кристаллы) в текстуре только цвет. Свечение настраивается в игре.

У `SandstormEgg` кольцо парящих кубиков, у `PharaohEgg` кобра, у `ScorpionEgg` хвост и лапы — часть того же меша. С CollisionFidelity PreciseConvexDecomposition хитбокс этих яиц шире корпуса; для простого хитбокса используйте Box или Hull.

## Файлы

- `Eggs_Pack.fbx` — все 11 яиц со встроенными текстурами.
- `models/` — 11 отдельных FBX.
- `textures/` — 11 цветовых PNG `<Name>_Color.png`.
- `preview.png` — оба ряда запечённых моделей.
- `manifest.json` — имена, треугольники, размеры, смещения в паке.
- `SHA256SUMS.txt` — контрольные суммы.

## Размеры

X × Y × Z в studs (Y — высота):

| MeshPart | Размер | Треугольники |
|---|---|---|
| DefaultEgg | 1.86 × 2.33 × 1.86 | 1616 |
| MossEgg | 2.48 × 2.40 × 2.48 | 4752 |
| BirchEgg | 1.86 × 2.33 × 1.86 | 1616 |
| MushroomEgg | 2.17 × 2.40 × 2.17 | 3784 |
| AcornEgg | 2.17 × 2.33 × 2.17 | 3464 |
| EnchantedEgg | 2.17 × 2.33 × 2.17 | 4336 |
| CactusEgg | 2.33 × 2.56 × 2.33 | 6616 |
| PharaohEgg | 2.02 × 3.26 × 2.02 | 5740 |
| SandstormEgg | 2.79 × 2.33 × 2.79 | 5080 |
| ScorpionEgg | 2.79 × 3.10 × 2.79 | 5656 |
| OasisEgg | 2.02 × 3.18 × 2.02 | 4776 |

Обратный импорт `Eggs_Pack.fbx` в Blender: 11 мешей, у каждого один материал с текстурой и одна UV, треугольники и размеры совпадают с таблицей. В Studio из v02 взяты 5 пустынных MeshPart (в `ServerStorage.Assets.Items.Eggs`); лесные шаблоны остались из v01.
