# Пак яиц для Roblox Studio — v01

В паке **6 яиц**: `DefaultEgg`, `MossEgg`, `BirchEgg`, `MushroomEgg`, `AcornEgg`, `EnchantedEgg`. Источник — `assets/items/eggs/default/models/egg-default.blend` (сцена `Scene`), сборка — `tools/blender/build-egg-pack.py`, экспорт — `tools/blender/export-egg-pack.py`.

Каждое яйцо — один меш, один материал, одна UV-развёртка. Цвет и studs запечены в индивидуальный PNG 2048×2048. Pivot каждого яйца — центр низа.

## Импорт всего пака

1. В Studio откройте **File → Import** и выберите **Eggs_Pack.fbx**.
2. **Scale Unit = Studs**, масштаб **1**, **World Up = Top**, **World Forward = Front**.
3. **Merge Meshes выключен**: в превью должно быть 6 отдельных MeshPart. **Use Imported Pivot включён**.
4. Для расстановки включите **Anchored**. Для загрузки в аккаунт или группу игры укажите нужного **Creator**. Перед импортом проверьте цветные текстуры в превью.
5. Нажмите **Import**. Яйца стоят в ряд по X с шагом 3 studs. Для импорта по одному используйте `models/` — там pivot каждого яйца в (0, 0, 0).

FBX экспортирован как пак кирок: Apply Scaling = FBX Units Scale, Scale = 1, Y Up, Z Forward; 1 единица Blender = 1 stud.

## Текстуры

PNG встроены в FBX и лежат отдельно в `textures/`. Если Studio не подхватил цвет, назначьте PNG нужного яйца в **MeshPart.TextureID** или **SurfaceAppearance.ColorMap**. Color у MeshPart оставьте белым, чтобы не тонировать текстуру повторно.

Свечение рун и кристаллов `EnchantedEgg` в FBX не переносится: в текстуре только их цвет. Свечение настраивается в игре (Neon-детали, PointLight или эффекты).

## Файлы

- `Eggs_Pack.fbx` — все 6 яиц со встроенными текстурами.
- `models/` — 6 отдельных FBX.
- `textures/` — 6 цветовых PNG `<Name>_Color.png`.
- `preview.png` — ряд запечённых моделей.
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

Пак импортирован в Studio: 6 MeshPart в `ServerStorage.Assets.Items.Eggs`. Обратный импорт FBX в Blender: 6 мешей, по одному материалу с текстурой и одной UV, размеры совпадают.
