"""Create a new symmetrical revision with tapered tips and textured studs.

Reuses the explicit primitive builder without changing the preserved v01 scene.
"""
import bpy
import bmesh
from pathlib import Path

root_path=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
code=(root_path/'tools/blender/create-wooden-pickaxe.py').read_text(encoding='utf-8')
code=code.replace('v01','v02')
replacements={
    "obj.name = name":"obj.name = name + '_v02'",
    "Wooden_Pickaxe_Model'":"Wooden_Pickaxe_Model_v02'",
    "Preview_Studio_DO_NOT_EXPORT'":"Preview_Studio_DO_NOT_EXPORT_v02'",
    "Wooden_Pickaxe_Grip'":"Wooden_Pickaxe_Grip_v02'",
    "'Wooden_' + label":"'Wooden_v02_' + label",
    "def camera(name,location,target,scale,roll=0):":"def camera(name,location,target,scale,roll=0):\n    name += '_v02'",
    "def light(name,position,power,size):":"def light(name,position,power,size):\n    name += '_v02'",
    "(.26,4.29,3.74,.35),(.93,4.25,3.69,.35),(1.58,4.04,3.44,.33),(1.98,3.76,3.18,.30),(2.43,3.05,2.98,.13)":"(.26,4.29,3.74,.35),(.93,4.28,3.74,.35),(1.58,4.13,3.69,.30),(2.03,3.94,3.67,.22),(2.43,3.70,3.65,.065)",
    "enumerate((.62,1.18,1.70),1)":"enumerate((),1)",
    "for z in (3.80,4.15):":"for z in ():",
    "for side in (-1,1):\n        box('Band_FrontBack":"for side in ():\n        box('Band_FrontBack",
    "for z in (.23,1.15,1.75,2.35):":"for z in ():",
    "['C87932', 'E3943F', 'AF6129', 'F8B453', '704022', '46515F', '8493A2', 'B9C5D2']":"['BF6120','EF8E30','843914','ECAF50','4B2515','263443','697C90','B0C1D2']",
}
for before,after in replacements.items():
    assert before in code, 'Builder changed: '+before
    code=code.replace(before,after)
namespace={}
exec(compile(code,'create-wooden-pickaxe-v02-expanded.py','exec'),namespace)
scene=namespace['scene']
parts=namespace['parts']
atlas_path=namespace['ASSET']/'textures/wooden-pickaxe-studs-atlas-v02.png'
atlas=bpy.data.images.load(str(atlas_path),check_existing=False)
atlas.pack()
for mat in namespace['materials']:
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE':
            node.image=atlas
            node.interpolation='Linear'
    mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.68
for obj in parts:
    mesh=obj.data
    bm=bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    uv=mesh.uv_layers.active
    for polygon in mesh.polygons:
        normal=obj.matrix_world.to_3x3() @ polygon.normal
        major=max(range(3),key=lambda i:abs(normal[i]))
        axes=[i for i in range(3) if i!=major]
        index=polygon.material_index
        for loop in polygon.loop_indices:
            co=obj.matrix_world @ mesh.vertices[mesh.loops[loop].vertex_index].co
            a=(co[axes[0]]+3)/6
            b=(co[axes[1]]+(.3 if axes[1]==2 else 3))/6
            # Fixed world density, same phase across adjoining faces.
            uv.data[loop].uv=((index%4+(4+1016*a)/1024)/4,
                             ((1-index//4)+(4+1016*b)/1024)/2)
    mesh.update()
scene['studs']='Flat user-supplied alpha overlay baked into the color atlas; no raised square meshes.'
scene['stud_pitch']=.25
scene['revision']='v02: no geometric studs/rivets, shorter tapered tips, higher color contrast.'
scene['front_camera']=namespace['front'].name
scene['handle_object']=namespace['shaft'].name
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(namespace['BLEND']),{scene},fake_user=True,compress=True)
result={'scene':scene.name,'parts':len(parts),'blend':str(namespace['BLEND']),'render':scene.render.filepath}
