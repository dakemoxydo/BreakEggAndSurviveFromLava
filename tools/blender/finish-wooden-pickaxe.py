"""Export the created Wooden scene and record geometry validation."""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Matrix, Vector, kdtree

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
ASSET = ROOT / 'assets/items/pickaxes/01-wooden'
VERSION = globals().get('ASSET_VERSION','v01')
scene = bpy.data.scenes['Wooden_Pickaxe_'+VERSION]
assert bpy.context.scene == scene
export_name='Wooden_Pickaxe_Export_'+VERSION
assert not bpy.data.objects.get(export_name), 'Export already exists.'
parts = [o for o in bpy.data.collections[scene['export_collection']].objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in parts for v in o.data.vertices]
tree = kdtree.KDTree(len(points))
for i,p in enumerate(points):
    tree.insert(p,i)
tree.balance()
mirror_error = max(tree.find(Vector((-p.x,p.y,p.z)))[2] for p in points)
assert mirror_error < 1e-6
report = {'symmetryPlane':'X=0','maxMirrorError':mirror_error,'sourceParts':len(parts),
          'boundsMin':[min(p[i] for p in points) for i in range(3)],
          'boundsMax':[max(p[i] for p in points) for i in range(3)],
          'vertices':len(points),'triangles':0,'nonManifoldEdges':0,'degenerateFaces':0,
          'exportPivot':[0,0,1.45],'units':'1 intended Roblox stud per Blender unit',
          'importedToRoblox':False}
for o in parts:
    o.data.calc_loop_triangles()
    report['triangles'] += len(o.data.loop_triangles)
    bm=bmesh.new()
    bm.from_mesh(o.data)
    report['nonManifoldEdges'] += sum(not e.is_manifold for e in bm.edges)
    report['degenerateFaces'] += sum(f.calc_area()<1e-10 for f in bm.faces)
    bm.free()
assert report['nonManifoldEdges']==0 and report['degenerateFaces']==0

exports=bpy.data.collections.new('Export_One_Mesh_Grip_Pivot_'+VERSION)
scene.collection.children.link(exports)
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for obj in parts:
    clone=bpy.data.objects.new(obj.name+'_ExportPart',obj.data.copy())
    exports.objects.link(clone)
    clone.data.transform(Matrix.Translation((0,0,-1.45)) @ obj.matrix_world)
    clone.select_set(True)
    copies.append(clone)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
export=bpy.context.object
export.name=export_name
export.data.name='Wooden_Pickaxe_Mesh'
mat=parts[0].data.materials[0].copy()
mat.name='Wooden_Pickaxe_Atlas'
mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.62
export.data.materials.clear()
export.data.materials.append(mat)
for p in export.data.polygons:
    p.material_index=0
export.data.uv_layers.active_index=export.data.uv_layers.find('PaletteUV')
export.data.uv_layers.active.active_render=True
tri=export.modifiers.new('Export_Triangles','TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=tri.name)

# Both formats contain just one mesh, with the palette image included.
fbx=ASSET / ('exports/wooden-pickaxe-studs-'+VERSION+'.fbx')
glb=ASSET / ('exports/wooden-pickaxe-studs-'+VERSION+'.glb')
bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH'},
    axis_forward='-Z',axis_up='Y',global_scale=1.0,apply_unit_scale=False,
    bake_anim=False,use_mesh_modifiers=True,path_mode='COPY',embed_textures=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,use_active_scene=True,
    export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
export.hide_render=True
export.hide_set(True)
report['exportMeshCount']=1
report['exportMaterialCount']=1
report['fbx']=str(fbx)
report['glb']=str(glb)

# Inspectable straight front view plus an isolated transparent shop render.
shop=scene.camera
shop_path=scene.render.filepath
scene.camera=bpy.data.objects[scene.get('front_camera','Symmetry_Front_Camera')]
scene.render.filepath=str(ASSET / ('models/wooden-pickaxe-front-'+VERSION+'.png'))
bpy.ops.render.render(write_still=True)
scene.camera=shop
scene.render.filepath=shop_path
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects[scene.get('handle_object','Handle_Wood')]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'

bpy.data.libraries.write(str(ASSET / ('models/wooden-pickaxe-studs-'+VERSION+'.blend')),{scene},fake_user=True,compress=True)
(ASSET / ('models/validation-'+VERSION+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report
