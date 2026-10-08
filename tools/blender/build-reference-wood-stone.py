"""Build only the revised Wooden and second Stone pickaxe, sequentially.

Preserves previous scenes. EDIT_ITEM must be Wooden or Stone.
"""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, kdtree

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PICKS=ROOT/'assets/items/pickaxes'
PACK=PICKS/'pack'
SCENE_NAME='Review_Wooden_Stone'
KEY=globals().get('EDIT_ITEM','Wooden')
assert KEY in ['Wooden','Stone']
VERSION='v03' if KEY=='Wooden' else 'v01'
TIER=1 if KEY=='Wooden' else 2
FOLDER=PICKS/('%02d-%s'%(TIER,KEY.lower()))
STEM=KEY.lower()+'-pickaxe-reference-'+VERSION

if SCENE_NAME not in bpy.data.scenes:
 backup=ROOT/'.tools/blender-before-reference-wooden-stone.blend'
 if not backup.exists(): bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True)
 scene=bpy.data.scenes.new(SCENE_NAME)
 bpy.context.window.scene=scene
 studio=bpy.data.collections.new('Reference_Review_Studio')
 scene.collection.children.link(studio)
 world=bpy.data.worlds.new('Reference_Studio_World');world.use_nodes=True
 world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.30,.40,1)
 world.node_tree.nodes['Background'].inputs[1].default_value=.5
 scene.world=world
 scene.render.engine='BLENDER_EEVEE'
 scene.render.resolution_x=1024;scene.render.resolution_y=1024
 scene.render.resolution_percentage=100
 scene.render.film_transparent=True
 scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
 scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
 for name,location,power,size in [('Key',(-4,-6,9),720,5),('Fill',(5,-3,5),300,4),('Rim',(0,4,8),500,4)]:
  data=bpy.data.lights.new('Reference_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
  obj=bpy.data.objects.new(data.name,data);studio.objects.link(obj);obj.location=location
  obj.rotation_euler=(Vector((0,0,2.3))-obj.location).to_track_quat('-Z','Y').to_euler()
 for name,location in [('Reference_Icon_Camera',(6,-15,7)),('Reference_Front_Camera',(0,-16,2.3)),('Reference_Side_Camera',(13,-7,6.4))]:
  data=bpy.data.cameras.new(name);obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=location
  obj.rotation_mode='QUATERNION';obj.rotation_quaternion=(Vector((0,0,2.3))-obj.location).to_track_quat('-Z','Y')
  data.type='ORTHO';data.ortho_scale=6.0
 scene.unit_settings.system='NONE'
 scene['scope']='Only Wooden and Stone are finalized for this review. Continue after user feedback.'
 image=bpy.data.images.load(str(PACK/'textures/reference-wood-stone-studs-v01.png'),check_existing=False)
 image.name='Reference_Wood_Stone_Studs_Atlas';image.pack()
 for index,color in enumerate(['AA5230','D17B46','783A27','48251D','526B8E','95ABC8','626C78','A9B1BB']):
  mat=bpy.data.materials.new('Reference_Palette_%02d'%index);mat.use_nodes=True
  mat.diffuse_color=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))+(1,)
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
  bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.7
  mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
else:
 scene=bpy.data.scenes[SCENE_NAME];bpy.context.window.scene=scene

MATS=[bpy.data.materials['Reference_Palette_%02d'%i] for i in range(8)]
COLNAME='%02d_%s_Reference_%s'%(TIER,KEY,VERSION)
assert COLNAME not in bpy.data.collections, 'Revision already exists.'
collection=bpy.data.collections.new(COLNAME);scene.collection.children.link(collection)
root=bpy.data.objects.new(KEY+'_Reference_Grip',None);collection.objects.link(root)
root['asset_key']=KEY;root['tier']=TIER;root['version']=VERSION
root.empty_display_type='PLAIN_AXES'
parts=[]

def material_faces(obj,base):
 for mat in MATS: obj.data.materials.append(mat)
 for p in obj.data.polygons: p.material_index=base

def bevel(obj,width,edge):
 bpy.context.view_layer.objects.active=obj;bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
 modifier=obj.modifiers.new('Fine_Block_Bevel','BEVEL');modifier.width=width;modifier.segments=1;modifier.material=edge
 bpy.ops.object.modifier_apply(modifier=modifier.name)

def box(name,location,size,base,angle=0,edge=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=location)
 obj=bpy.context.object;obj.name=KEY+'_'+name;obj.dimensions=size;obj.rotation_euler.y=angle
 for c in list(obj.users_collection): c.objects.unlink(obj)
 collection.objects.link(obj)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 material_faces(obj,base)
 for p in obj.data.polygons:
  if p.normal.z>.9: p.material_index=1 if base<4 else (5 if base==4 else 7)
  elif abs(p.normal.x)>.9 and base<4: p.material_index=2
 bevel(obj,.028,edge if edge is not None else (2 if base<4 else 4))
 parts.append(obj);return obj

def custom(name,vertices,faces,color,bevel_width=0):
 mesh=bpy.data.meshes.new(KEY+'_'+name);mesh.from_pydata(vertices,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 obj=bpy.data.objects.new(mesh.name,mesh);collection.objects.link(obj);material_faces(obj,color)
 if bevel_width: bevel(obj,bevel_width,6)
 parts.append(obj);return obj

def plate_diamond():
 # A metal fastener with a raised pyramidal center, rather than a magical crystal.
 for sign in [-1,1]:
  y=sign*.393
  vertices=[(0,y,4.68),(.48,y,4.12),(0,y,3.56),(-.48,y,4.12),(0,sign*.695,4.12)]
  faces=[(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)]
  obj=custom('Blue_Steel_Diamond',vertices,faces,4)
  for p in obj.data.polygons:
   if p.center.z>4.15: p.material_index=5

shaft=box('Wooden_Shaft',(0,0,2.20),(.50,.52,4.40),2)
box('Top_Steel_Brace',(0,0,3.42),(.71,.71,.23),5,edge=4)
box('Middle_Steel_Band',(0,0,2.04),(.72,.73,.43),5,edge=4)
box('Bottom_Steel_Cap',(0,0,.20),(.65,.67,.43),5,edge=4)

if KEY=='Wooden':
 box('Center_Wood_Block',(0,0,4.12),(.96,.76,1.30),0)
 for side in [-1,1]:
  box('Inner_Wood_Block',(side*.84,0,4.13),(.78,.70,1.14),0,side*.03)
  box('Outer_Wood_Block',(side*1.50,0,3.91),(.77,.66,1.02),0,side*.41)
  box('Blunt_End_Block',(side*1.99,0,3.46),(.65,.61,.99),0,side*.40)
 plate_diamond()
else:
 # Stone progression: grey faceted head, sharper mining ends, same wood/steel hardware.
 box('Center_Stone_Block',(0,0,4.12),(1.0,.78,1.04),6,edge=4)
 for side in [-1,1]:
  box('Inner_Stone_Block',(side*.87,0,4.12),(.78,.72,.93),6,side*.06,edge=6)
  box('Outer_Stone_Block',(side*1.52,0,3.99),(.66,.63,.84),6,side*.20,edge=6)
  # Thin double-ended stone wedges with a broad flat upper plane and faceted face.
  vertices=[(side*x,y,z) for x,y,z in [(1.68,-.27,4.28),(1.68,.27,4.28),(2.47,-.07,3.62),(2.47,.07,3.62),(1.77,-.27,3.61),(1.77,.27,3.61),(1.97,-.39,3.88),(1.97,.39,3.88)]]
  faces=[(0,1,3,2),(4,5,1,0),(4,2,3,5),(0,2,6),(2,4,6),(4,0,6),(1,7,3),(3,7,5),(5,7,1)]
  obj=custom('Faceted_Stone_End',vertices,faces,6)
  for p in obj.data.polygons:
   if p.center.z>3.93: p.material_index=7
 # A narrow steel socket marks the upgrade without changing the wooden hardware style.
 box('Center_Steel_Clasp',(0,0,4.12),(.54,.85,.80),4,edge=4)

def apply_uv(obj):
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges), obj.name
 bm.to_mesh(obj.data);bm.free()
 for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
 uv=obj.data.uv_layers.new(name='StudsUV');uv.active_render=True
 for p in obj.data.polygons:
  # Project blocks in their own axes so studs follow each rectangular timber.
  major=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=major]
  for loop in p.loop_indices:
   co=obj.data.vertices[obj.data.loops[loop].vertex_index].co
   coordinate=co+obj.location
   a=(coordinate[axes[0]]+3.3)/6.6
   b=(coordinate[axes[1]]+.3)/6.6 if axes[1]==2 else (coordinate[axes[1]]+3.3)/6.6
   i=p.material_index
   uv.data[loop].uv=((i%4+(4+1016*a)/1024)/4,((1-i//4)+(4+1016*b)/1024)/2)

bpy.context.view_layer.update()
for obj in parts: apply_uv(obj)
points=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
tree=kdtree.KDTree(len(points))
for i,p in enumerate(points): tree.insert(p,i)
tree.balance();error=max(tree.find(Vector((-p.x,p.y,p.z)))[2] for p in points)
assert error<1e-5,(KEY,error)
export_collection=bpy.data.collections.new(KEY+'_Reference_Export');scene.collection.children.link(export_collection)
bpy.ops.object.select_all(action='DESELECT')
clones=[]
for obj in parts:
 clone=bpy.data.objects.new(obj.name+'_Copy',obj.data.copy());export_collection.objects.link(clone)
 clone.data.transform(Matrix.Translation((0,0,-1.40))@obj.matrix_world);clone.select_set(True);clones.append(clone)
bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join()
export=bpy.context.object;export.name=KEY+'_Reference_Export_Mesh'
mat=MATS[0].copy();mat.name=KEY+'_Reference_Atlas';export.data.materials.clear();export.data.materials.append(mat)
for p in export.data.polygons: p.material_index=0
tri=export.modifiers.new('Triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
export.data.calc_loop_triangles();uv=export.data.uv_layers.active
for t in export.data.loop_triangles:
 a,b,c=[export.data.vertices[i].co for i in t.vertices]
 assert (b-a).cross(c-a).length>1e-9
 a,b,c=[uv.data[i].uv for i in t.loops]
 assert abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))>1e-12
bpy.ops.export_scene.fbx(filepath=str(FOLDER/'exports'/(STEM+'.fbx')),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_unit_scale=False,bake_anim=False,path_mode='COPY',embed_textures=True)
bpy.ops.export_scene.gltf(filepath=str(FOLDER/'exports'/(STEM+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='EXPORT')
export.hide_render=True;export.hide_set(True)

# Hide only other review models while rendering this item.
hide=[]
for c in scene.collection.children:
 if c.name.startswith(('01_','02_')) and c!=collection:
  hide.append((c,c.hide_render));c.hide_render=True
scene.camera=bpy.data.objects['Reference_Icon_Camera']
scene.camera.rotation_quaternion=(Vector((0,0,2.3))-scene.camera.location).to_track_quat('-Z','Y') @ Quaternion((0,0,1),math.radians(12))
scene.render.filepath=str(FOLDER/'icons'/(STEM+'.png'));bpy.ops.render.render(write_still=True)
for camera,suffix in [('Reference_Front_Camera','front'),('Reference_Side_Camera','side')]:
 scene.camera=bpy.data.objects[camera];scene.render.filepath=str(FOLDER/'models'/(STEM+'-'+suffix+'.png'));bpy.ops.render.render(write_still=True)
for c,value in hide: c.hide_render=value
for obj in parts:
 obj.parent=root;obj.location.z-=1.40
root.location=(-3.10 if KEY=='Wooden' else 3.10,0,1.40)
export.location=root.location
report={'key':KEY,'tier':TIER,'version':VERSION,'parts':len(parts),'collection':collection.name,
 'triangles':len(export.data.loop_triangles),'vertices':len(export.data.vertices),
 'maxMirrorError':error,'symmetryPlane':'X=0','closedMeshes':True,
 'degenerateTriangles':0,'degenerateUVTriangles':0,'studPitch':.55,'raisedStudMeshes':False,
 'stem':STEM,'boundsMin':[min(p[i] for p in points) for i in range(3)],'boundsMax':[max(p[i] for p in points) for i in range(3)],
 'packSource':'pack/models/pickaxes-asset-pack-v01.blend','scene':SCENE_NAME,'exportMesh':export.name}
(FOLDER/'models'/(STEM+'-validation.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.camera=bpy.data.objects['Reference_Icon_Camera']
bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'models/pickaxes-asset-pack-v01.blend'),compress=True)
result=report
