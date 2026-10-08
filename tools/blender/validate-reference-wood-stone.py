"""Verify just the revised Wooden and Stone exports in background Blender."""
import bpy
import json
import sys
from pathlib import Path

root=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava\assets\items\pickaxes')
version=sys.argv[sys.argv.index('--wooden-version')+1] if '--wooden-version' in sys.argv else 'v03'
result={}
entries=[('01-wooden','wooden-pickaxe-reference-'+version),('02-stone','stone-pickaxe-reference-v01')]
if '--only-wooden' in sys.argv:
    result=json.loads((root/'pack/models/wooden-stone-export-validation.json').read_text())
    entries=entries[:1]
for folder,stem in entries:
    source=json.loads((root/folder/'models'/(stem+'-validation.json')).read_text())
    result[folder]={}
    for extension in ['fbx','glb']:
        scene=bpy.data.scenes.new('Export_Check_'+folder+'_'+extension)
        bpy.context.window.scene=scene
        path=root/folder/'exports'/(stem+'.'+extension)
        if extension=='fbx': bpy.ops.import_scene.fbx(filepath=str(path))
        else: bpy.ops.import_scene.gltf(filepath=str(path))
        meshes=[o for o in scene.objects if o.type=='MESH']
        assert len(meshes)==1
        obj=meshes[0];bpy.context.view_layer.update();obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles)==source['triangles']
        uv=obj.data.uv_layers.active
        for triangle in obj.data.loop_triangles:
            a,b,c=[uv.data[i].uv for i in triangle.loops]
            assert abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))>1e-12
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        bounds=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
        expected=[source['boundsMax'][i]-source['boundsMin'][i] for i in range(3)]
        assert max(abs(bounds[i]-expected[i]) for i in range(3))<.001
        images=[node.image for mat in obj.data.materials if mat and mat.node_tree for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image]
        assert any(list(image.size)==[4096,2048] for image in images)
        result[folder][extension]={'meshCount':1,'triangles':len(obj.data.loop_triangles),'size':bounds,'texture':True,'uv':True}
(root/'pack/models/wooden-stone-export-validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('VERIFIED '+json.dumps(result))
