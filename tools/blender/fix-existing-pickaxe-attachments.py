"""Close measured ornament gaps while preserving the approved silhouettes."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
scene=bpy.context.scene
assert scene.name=='Pickaxe_Pack_Review' and bpy.context.mode=='OBJECT'
assert not scene.get('attachment_revision_20261008')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.tools/before-pack-attachment-fixes.blend'),copy=True,compress=True)
shifts={'Wooden_Blue_Steel_Diamond':.016,'Stone_Diamond_Fastener':.016,
        'Iron_Silver_Fastener':.016,'Golden_Faceted_Emerald':.025,
        'Candy_Peppermint':.020,'Crystal_Faceted_Core':.020,'Demon_Lava_Core':.025}
changed=[]
for obj in scene.objects:
    for prefix,distance in shifts.items():
        if obj.type=='MESH' and obj.name.startswith(prefix):
            center=obj.matrix_local @ Vector(obj.bound_box[0])
            obj.location.y += distance if center.y<0 else -distance
            changed.append(obj.name)
    if obj.name.startswith('Crystal_Floating_Shard'):
        obj.location.z-=.30
        obj.name=obj.name.replace('Floating','Mounted')
        changed.append(obj.name)
    if obj.name.startswith('Demon_Lava_Pommel_Insert'):
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        modifier=obj.modifiers.new('Closed_Lava_Inlay','SOLIDIFY')
        modifier.thickness=.02;modifier.offset=0
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        changed.append(obj.name)
scene['attachment_revision_20261008']=True
bpy.ops.object.select_all(action='DESELECT')
exec(compile((ROOT/'tools/blender/audit-pickaxe-attachments.py').read_text(encoding='utf-8'),'audit','exec'))
result['changed']=changed
