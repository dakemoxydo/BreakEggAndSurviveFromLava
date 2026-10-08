"""Record the next review artifact without changing runtime assets."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
assets = ROOT / 'assets/items/pickaxes'
blend = '../pack/models/pickaxes-asset-pack-review-v13.blend'
preview = '../pack/previews/twelve-slots-demon-review-v01.png'
for path in assets.glob('*/asset.json'):
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    if data['tier'] < 12 and data['key'] != 'Diamond' and 'reviewModel' in data:
        data['reviewModel'].update(blend=blend, preview=preview, status='accepted-for-continuation')
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
path = assets / '12-demon/asset.json'
data = json.loads(path.read_text(encoding='utf-8-sig'))
data['modelStatus'] = 'ready-for-user-review'
data['reviewModel'] = dict(version='v01', status='awaiting-user-review', blend=blend,
                         scene='Pickaxe_Pack_Review', collection='12_Demon_Review_v01',
                         texture='../pack/textures/demon-dark-studs-v01.png', preview=preview,
                         detailPreview='../pack/previews/demon-detail-review-v01.png',
                         raisedStudGeometry=False, runtimeReplaced=False)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
path = assets / 'README.md'
text = path.read_text(encoding='utf-8')
text = text.replace('review-v12.blend', 'review-v13.blend').replace('в текущем v12', 'в текущем v13')
text = text.replace('eleven-slots-crystal-review-v01.png', 'twelve-slots-demon-review-v01.png')
text = text.replace('Кристальная ожидает оценки пользователя; следующие кирки пока не моделировать.',
                    'В двенадцатый слот добавлена демоническая v01: отдельные обсидиановые ступенчатые секции, красные заострённые крючья, парные гранёные рога, оранжевое лавовое ядро и узкие светящиеся швы, угольная бронированная рукоять с красными кольцами и острым навершием. Геометрия зеркально симметрична; studs остаются плоской тёмной текстурой. Демоническая ожидает оценки пользователя; следующие кирки пока не моделировать.')
text = text.replace('Новые модели ещё не экспортированы',
                    'Текстура демонической: `pack/textures/demon-dark-studs-v01.png`, упакована в Blender. Крупный вид: `pack/previews/demon-detail-review-v01.png`. Новые модели ещё не экспортированы')
path.write_text(text, encoding='utf-8')
print('Review metadata and README updated to v13.')
