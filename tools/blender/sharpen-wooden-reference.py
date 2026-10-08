"""Replace only the two terminal Wooden blocks with mirrored tapered tips."""
import bpy
import bmesh
import hashlib
import json
from pathlib import Path
from mathutils import Vector, Matrix, kdtree

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PICKS=ROOT/'assets/items/pickaxes'
FOLDER=PICKS/'01-wooden'
PACK=PICKS/'pack'
scene=bpy.context.scene
assert scene.name=='Review_Wooden_Stone'
collection=bpy.data.collections['01_Wooden_Reference_v03']
root=bpy.data.objects['Wooden_Reference_Grip']
ends=[o for o in collection.objects if o.name.startswith('Wooden_Blunt_End_Block')]
assert len(ends)==2 and root.parent is None
assert '01_Wooden_Reference_v04' not in bpy.data.collections
backup=ROOT/'.tools/blender-before-wooden-sharp-v04.blend'
if not backup.exists(): bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True)

def signature(obj):
    value=[list(obj.location),list(obj.rotation_euler),list(obj.scale),
           [list(v.co) for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons]]
    return hashlib.sha256(json.dumps(value).encode()).hexdigest()

protected=[o for o in scene.objects if o.type=='MESH' and o not in ends]
before={o.name:signature(o) for o in protected}
materials=list(ends[0].data.materials)
for obj in ends:
    side=1 if obj.location.x>0 else -1
    # Base block remains broad; the outboard half tapers in height and depth.
    stations=[(1.69,4.01,3.13,.30),(2.16,3.78,3.17,.27),(2.66,3.07,3.015,.035)]
    vertices=[]
    for x,top,bottom,depth in stations:
        vertices.extend([(side*x,-depth,top-1.4),(side*x,depth,top-1.4),
                         (side*x,depth,bottom-1.4),(side*x,-depth,bottom-1.4)])
    faces=[(3,2,1,0),(8,9,10,11)]
    colors=[0,2]
    for k in range(2):
        for j in range(4):
            faces.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
            colors.append([1,0,2,0][j])
    mesh=bpy.data.meshes.new('Wooden_Tapered_Tip_'+('R' if side>0 else 'L'))
    mesh.from_pydata(vertices,[],faces);mesh.update()
    for mat in materials: mesh.materials.append(mat)
    for p,color in zip(mesh.polygons,colors): p.material_index=color
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj.data=mesh
    obj.name='Wooden_Point_End_'+('R' if side>0 else 'L')
    obj.location=(0,0,0);obj.rotation_euler=(0,0,0);obj.scale=(1,1,1)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bevel=obj.modifiers.new('Fine_Tip_Bevel','BEVEL');bevel.width=.014;bevel.segments=1;bevel.material=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    assert all(e.is_manifold for e in bm.edges)
    bm.to_mesh(obj.data);bm.free()
    uv=obj.data.uv_layers.new(name='StudsUV');uv.active_render=True
    for p in obj.data.polygons:
        major=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=major]
        for loop in p.loop_indices:
            co=obj.data.vertices[obj.data.loops[loop].vertex_index].co+Vector((0,0,1.4))
            a=(co[axes[0]]+3.3)/6.6
            b=(co[axes[1]]+.3)/6.6 if axes[1]==2 else (co[axes[1]]+3.3)/6.6
            i=p.material_index
            uv.data[loop].uv=((i%4+(4+1016*a)/1024)/4,((1-i//4)+(4+1016*b)/1024)/2)

collection.name='01_Wooden_Reference_v04'
root['version']='v04'
bpy.context.view_layer.update()
parts=[o for o in collection.objects if o.type=='MESH']
points=[root.matrix_world.inverted()@o.matrix_world@v.co for o in parts for v in o.data.vertices]
tree=kdtree.KDTree(len(points))
for i,p in enumerate(points): tree.insert(p,i)
tree.balance();error=max(tree.find(Vector((-p.x,p.y,p.z)))[2] for p in points)
assert error<1e-5
assert before=={o.name:signature(o) for o in protected}, 'Unrequested geometry changed.'

export_collection=bpy.data.collections.new('Wooden_Reference_Export_v04');scene.collection.children.link(export_collection)
bpy.ops.object.select_all(action='DESELECT')
clones=[]
for obj in parts:
    clone=bpy.data.objects.new(obj.name+'_Export_v04',obj.data.copy());export_collection.objects.link(clone)
    clone.data.transform(root.matrix_world.inverted()@obj.matrix_world);clone.select_set(True);clones.append(clone)
bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join()
export=bpy.context.object;export.name='Wooden_Reference_Export_Mesh_v04'
mat=materials[0].copy();mat.name='Wooden_Reference_Atlas_v04'
export.data.materials.clear();export.data.materials.append(mat)
for p in export.data.polygons: p.material_index=0
tri=export.modifiers.new('Triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
export.data.calc_loop_triangles();uv=export.data.uv_layers.active
for t in export.data.loop_triangles:
    a,b,c=[export.data.vertices[i].co for i in t.vertices]
    assert (b-a).cross(c-a).length>1e-9
    a,b,c=[uv.data[i].uv for i in t.loops]
    assert abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))>1e-12
stem='wooden-pickaxe-reference-v04'
bpy.ops.export_scene.fbx(filepath=str(FOLDER/'exports'/(stem+'.fbx')),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_unit_scale=False,bake_anim=False,path_mode='COPY',embed_textures=True)
bpy.ops.export_scene.gltf(filepath=str(FOLDER/'exports'/(stem+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='EXPORT')
export.location=root.location;export.hide_render=True;export.hide_set(True)

review_camera=scene.camera
root_location=root.location.copy()
stone=bpy.data.collections['02_Stone_Reference_v01'];stone_hidden=stone.hide_render
stone.hide_render=True
root.location=(0,0,1.4)
scene.render.resolution_x=1024;scene.render.resolution_y=1024
for camera,relative in [('Reference_Icon_Camera','icons/'+stem+'.png'),('Reference_Front_Camera','models/'+stem+'-front.png'),('Reference_Side_Camera','models/'+stem+'-side.png')]:
    scene.camera=bpy.data.objects[camera];scene.render.filepath=str(FOLDER/relative);bpy.ops.render.render(write_still=True)
root.location=root_location;stone.hide_render=stone_hidden
scene.camera=review_camera;scene.render.resolution_x=1800;scene.render.resolution_y=1000
scene.render.filepath=str(PACK/'previews/wooden-stone-review-v02.png');bpy.ops.render.render(write_still=True)
report=json.loads((FOLDER/'models/wooden-pickaxe-reference-v03-validation.json').read_text())
report.update({'version':'v04','stem':stem,'collection':collection.name,'exportMesh':export.name,
               'triangles':len(export.data.loop_triangles),'vertices':len(export.data.vertices),
               'maxMirrorError':error,'onlyChanged':'Both Wooden terminal blocks tapered to mining tips',
               'protectedMeshesUnchanged':len(protected),
               'boundsMin':[min(p[i] for p in points)+(1.4 if i==2 else 0) for i in range(3)],
               'boundsMax':[max(p[i] for p in points)+(1.4 if i==2 else 0) for i in range(3)]})
(FOLDER/'models'/(stem+'-validation.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'models/pickaxes-asset-pack-v01.blend'),compress=True)
result=report
