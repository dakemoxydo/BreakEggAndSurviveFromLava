"""Rebuild Diamond in the current review row, with physically seated inserts."""
import ast
import json
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK=ROOT/'assets/items/pickaxes/pack'
scene=bpy.context.scene
assert scene.name=='Pickaxe_Pack_Review' and bpy.context.mode=='OBJECT'
assert not any(c.name.startswith('05_Diamond') for c in scene.collection.children)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.tools/before-diamond-restored-full-pack.blend'),copy=True,compress=True)
# Execute only the single model geometry, excluding historical layout/save logic.
source=(ROOT/'tools/blender/create-diamond-review-v01.py').read_text(encoding='utf-8')
source=source[:source.index('center = Vector((9.75')]
source=source.replace('05_Diamond_Review_v01','05_Diamond_Review_v02').replace('Diamond_Grip_v01','Diamond_Grip_v02')
exec(compile(source,'diamond-geometry','exec'))
for obj in collection.objects:
    if obj.name.startswith('Diamond_Silver_Setting_') or obj.name.startswith('Diamond_Center_Gem_'):
        distance=.04 if 'Center_Gem' in obj.name else .02
        local_y=(obj.matrix_local @ obj.data.vertices[0].co).y
        obj.location.y+=distance if local_y<0 else -distance
root['status']='Ready for user review';root['version']='v02'
audit=(ROOT/'tools/blender/audit-pickaxe-attachments.py').read_text(encoding='utf-8')
exec(compile(audit,'audit','exec'))
report=result
assert len(report['assets'])==18
assert all(a['contactComponents']==1 and not a['meshErrors'] for a in report['assets']),report
(PACK/'previews/pack-attachment-audit-v20.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
root['attachment_check']='passed';root['contact_components']=1
studio=bpy.data.collections['Review_Studio_Do_Not_Export']
data=bpy.data.cameras.new('Diamond_Detail_Camera');detail=bpy.data.objects.new(data.name,data);studio.objects.link(detail)
detail.location=(25.50,-15,7)
detail.rotation_euler=(Vector((22.75,0,2.8))-detail.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=7.4
camera=scene.camera;settings=(scene.render.resolution_x,scene.render.resolution_y)
hidden=[(c,c.hide_render) for c in scene.collection.children if c not in (collection,studio)]
try:
    for c,old in hidden:c.hide_render=True
    scene.camera=detail;scene.render.resolution_x=1100;scene.render.resolution_y=1100
    scene.render.filepath=str(PACK/'previews/diamond-detail-review-v02.png')
    bpy.ops.render.render(write_still=True)
finally:
    for c,old in hidden:c.hide_render=old
    scene.camera=camera;scene.render.resolution_x,scene.render.resolution_y=settings
scene.render.filepath=str(PACK/'previews/pack-full-18-review-v02.png')
bpy.ops.render.render(write_still=True)
scene['workflow']='Complete 18-model pickaxe pack. Diamond recreated in slot 05 with physically seated gem and setting. All contact graphs pass.'
scene['attachment_audit']='previews/pack-attachment-audit-v20.json'
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'models/pickaxes-asset-pack-review-v20.blend'),compress=True)
result={'file':bpy.data.filepath,'collection':collection.name,'auditPassed':True,'models':18,'detail':str(PACK/'previews/diamond-detail-review-v02.png')}
