"""Round-trip the isolated v02 FBX and GLB in a background Blender process."""
import bpy
import json
from pathlib import Path

root=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava\assets\items\pickaxes\01-wooden')
report={}
expected=json.loads((root/'models/validation-v02.json').read_text())['triangles']
for extension in ['fbx','glb']:
    scene=bpy.data.scenes.new('Import_Validation_'+extension)
    bpy.context.window.scene=scene
    path=root/('exports/wooden-pickaxe-studs-v02.'+extension)
    if extension=='fbx':
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        bpy.ops.import_scene.gltf(filepath=str(path))
    meshes=[o for o in scene.objects if o.type=='MESH']
    assert len(meshes)==1, [o.name for o in meshes]
    obj=meshes[0]
    bpy.context.view_layer.update()
    points=[obj.matrix_world @ v.co for v in obj.data.vertices]
    obj.data.calc_loop_triangles()
    uv=obj.data.uv_layers.active
    bad_uv=0
    for triangle in obj.data.loop_triangles:
        a,b,c=[uv.data[i].uv for i in triangle.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        bad_uv+=area<1e-12
    assert len(obj.data.loop_triangles)==expected
    assert bad_uv==0
    dimensions=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
    assert abs(dimensions[0]-4.86)<.001 and abs(dimensions[2]-4.615)<.001, dimensions
    images=[n.image for m in obj.data.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
    assert any(i.size[0]==4096 and i.size[1]==2048 for i in images)
    report[extension]={'meshCount':len(meshes),'triangles':len(obj.data.loop_triangles),'dimensions':dimensions,'badUVTriangles':bad_uv,'textureSizes':[list(i.size) for i in images]}
(root/'models/export-validation-v02.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('EXPORT_VALIDATION '+json.dumps(report))
