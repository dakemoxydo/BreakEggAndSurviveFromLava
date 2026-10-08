"""Save a clean standalone source and verify every packaged export."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
DEST=ROOT/'assets/items/pickaxes/pack/exports/roblox-import-v01'
assert bpy.app.background
with bpy.data.libraries.load(str(ROOT/'.tools/pickaxes-import-scene-library.blend'),link=False) as (source,target):
    target.scenes=['Pickaxes_Roblox_Import_v01']
scene=target.scenes[0]
bpy.context.window.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene: bpy.data.scenes.remove(other)
assert len(scene.objects)==2
assert set(o.name for o in scene.objects)=={'WoodenPickaxe','StonePickaxe'}
for image in bpy.data.images:
    if image.name.startswith('Pickaxes_Studs'):
        image.filepath='//../textures/Pickaxes_Studs.png'
        assert image.packed_file
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            region=area.spaces.active.region_3d
            region.view_location=(0,0,2.3)
            region.view_distance=14
            region.view_rotation=Vector((4,-18,8)).to_track_quat('Z','Y')
            region.view_perspective='PERSP'
            area.spaces.active.shading.type='MATERIAL'
scene['source_export_settings']='FBX Unit Scale, Scale=1, Z Forward, Y Up, embedded textures, selected meshes only.'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'source/Pickaxes_Import.blend'),compress=True)

manifest=json.loads((DEST/'manifest.json').read_text())
expected={m['name']:m for m in manifest['models']}
report={'files':{},'sourceObjects':['StonePickaxe','WoodenPickaxe'],'robloxImported':False}
paths=['Pickaxes_Wooden_Stone.fbx','Pickaxes_Wooden_Stone.glb']
paths += [m[format] for m in manifest['models'] for format in ['fbx','glb']]
for relative in paths:
    check=bpy.data.scenes.new('Check_'+relative.replace('/','_'))
    bpy.context.window.scene=check
    if relative.endswith('.fbx'): bpy.ops.import_scene.fbx(filepath=str(DEST/relative))
    else: bpy.ops.import_scene.gltf(filepath=str(DEST/relative))
    meshes=[o for o in check.objects if o.type=='MESH']
    count=2 if relative.startswith('Pickaxes_') else 1
    assert len(meshes)==count,(relative,len(meshes))
    assert len(check.objects)==count, 'Non-mesh objects in export'
    entry=[]
    for obj in meshes:
        name=obj.name.split('.')[0]
        assert name in expected,(relative,name)
        info=expected[name]
        obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles)==info['triangles']
        bpy.context.view_layer.update()
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        dimensions=[max(v[i] for v in points)-min(v[i] for v in points) for i in range(3)]
        target=[info['sizeStuds'][0],info['sizeStuds'][2],info['sizeStuds'][1]]
        assert max(abs(dimensions[i]-target[i]) for i in range(3))<.001,(relative,dimensions)
        assert len(obj.data.materials)==1
        images=[n.image for mat in obj.data.materials if mat and mat.node_tree for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        assert any(list(image.size)==[4096,2048] for image in images)
        uv=obj.data.uv_layers.active
        assert uv is not None
        for t in obj.data.loop_triangles:
            a,b,c=[uv.data[i].uv for i in t.loops]
            assert abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))>1e-12
        if count==1: assert obj.location.length<.001,(relative,list(obj.location))
        else:
            x=-3.1 if name=='WoodenPickaxe' else 3.1
            assert (obj.location-Vector((x,0,1.4))).length<.001
        entry.append({'name':name,'triangles':len(obj.data.loop_triangles),'blenderSize':dimensions,'pivot':list(obj.location),'textureLoaded':True,'uvValid':True})
    report['files'][relative]=entry
(DEST/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('IMPORT_PACK_VERIFIED '+json.dumps({'exportFiles':len(paths),'objectsInCombined':2,'triangles':[528,464],'sourceObjects':report['sourceObjects']}))
