"""Record final geometric evidence and save the completed review row."""
import bpy
import json
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK=ROOT/'assets/items/pickaxes/pack'
scene=bpy.context.scene
assert scene.name=='Pickaxe_Pack_Review'
expected=[1,2,3,4]+list(range(6,19))
collections=[c for c in scene.collection.children if c.name!='Review_Studio_Do_Not_Export']
assert sorted(int(c.name[:2]) for c in collections)==expected
exec(compile((ROOT/'tools/blender/audit-pickaxe-attachments.py').read_text(encoding='utf-8'),'audit','exec'))
report=result
report['sourceBlend']='models/pickaxes-asset-pack-review-v19.blend'
report['method']='Actual mesh islands; triangle-edge intersection, surface contact and volume containment. A connected contact graph must include every mesh island.'
report['tolerance']=.0002
report['intentionalAbsentTier']=5
report['symmetry']=[]
for c in collections:
    root=next(o for o in c.objects if o.type=='EMPTY' and 'asset_key' in o)
    assert abs(root.location.x-(-3.25+(int(c.name[:2])-1)*6.5))<.0001
    if int(c.name[:2])<13:continue
    points=[root.matrix_world.inverted() @ obj.matrix_world @ v.co for obj in c.all_objects if obj.type=='MESH' for v in obj.data.vertices]
    tree=KDTree(len(points))
    for i,p in enumerate(points):tree.insert(p,i)
    tree.balance()
    error=max(tree.find(Vector((-p.x,p.y,p.z)))[2] for p in points)
    report['symmetry'].append(dict(asset=root['asset_key'],maxMirroredVertexDistance=error,passed=error<.0002))
report['passed']=all(a['contactComponents']==1 and not a['meshErrors'] for a in report['assets']) and all(a['passed'] for a in report['symmetry'])
(PACK/'previews/pack-attachment-audit-v19.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert report['passed'],report
for c in collections:
    root=next(o for o in c.objects if o.type=='EMPTY' and 'asset_key' in o)
    root['attachment_check']='passed';root['contact_components']=1
scene['workflow']='All remaining tiers 13-18 modeled one at a time. Entire visible pack audited for attached closed geometry. Awaiting aesthetic review. Diamond slot intentionally absent.'
scene['attachment_audit']='previews/pack-attachment-audit-v19.json'
scene.render.filepath=str(PACK/'previews/pack-18-slots-review-v01.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'models/pickaxes-asset-pack-review-v19.blend'),compress=True)
result=report
