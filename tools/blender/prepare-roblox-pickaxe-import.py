"""Export only the current Wooden v04 and Stone v01 as a clean import pack."""
import bpy
import json
import shutil
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PICKS=ROOT/'assets/items/pickaxes'
DEST=PICKS/'pack/exports/roblox-import-v01'
for sub in ['models','textures','source','icons']:
    (DEST/sub).mkdir(parents=True,exist_ok=True)
assert bpy.context.mode=='OBJECT'
assert bpy.context.scene.name=='Review_Wooden_Stone'
original=bpy.context.scene
assert 'Pickaxes_Roblox_Import_v01' not in bpy.data.scenes
scene=bpy.data.scenes.new('Pickaxes_Roblox_Import_v01')
bpy.context.window.scene=scene
scene.unit_settings.system='NONE'
scene.unit_settings.scale_length=1.0
collection=bpy.data.collections.new('Pickaxes_Import_Only_Final_Two')
scene.collection.children.link(collection)
texture=DEST/'textures/Pickaxes_Studs.png'
shutil.copy2(PICKS/'pack/textures/reference-wood-stone-studs-v01.png',texture)
image=bpy.data.images.load(str(texture),check_existing=False)
image.name='Pickaxes_Studs';image.pack()
material=bpy.data.materials.new('Pickaxes_Studs_Material')
material.use_nodes=True
tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.7
material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
objects=[]
manifest={'version':'v01','models':[],'mainFile':'Pickaxes_Wooden_Stone.fbx',
          'alternativeFile':'Pickaxes_Wooden_Stone.glb','texture':'textures/Pickaxes_Studs.png',
          'source':'source/Pickaxes_Import.blend','importSettings':{'Scale Unit':'Stud','Scale Factor':1,'World Up':'Top','World Forward':'Front'},
          'fbxExport':{'Apply Scalings':'FBX Unit Scale','Scale':1,'Forward':'Z','Up':'Y','Embed Textures':True},
          'pivot':'Origin of each mesh is at the handle grip. One Blender unit is one intended stud.',
          'robloxImported':False}

def select_only(items):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in items: obj.select_set(True)
    bpy.context.view_layer.objects.active=items[0]

def export_fbx(path,items):
    select_only(items)
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
        global_scale=1.0,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',
        axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False,
        path_mode='COPY',embed_textures=True,use_custom_props=True)

def export_glb(path,items):
    select_only(items)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='EXPORT')

for key,source_name,tier,version,x in [('Wooden','Wooden_Reference_Export_Mesh_v04',1,'v04',-3.1),('Stone','Stone_Reference_Export_Mesh',2,'v01',3.1)]:
    source=bpy.data.objects[source_name]
    assert source.type=='MESH' and source.parent is None
    name=key+'Pickaxe'
    obj=bpy.data.objects.new(name,source.data.copy());collection.objects.link(obj)
    obj.data.name=name+'_Mesh'
    obj.data.materials.clear();obj.data.materials.append(material)
    for p in obj.data.polygons: p.material_index=0
    obj['asset_key']=key;obj['tier']=tier;obj['revision']=version
    obj['grip_origin']=True
    obj.data.calc_loop_triangles()
    vertices=[v.co for v in obj.data.vertices]
    dimensions=[max(v[i] for v in vertices)-min(v[i] for v in vertices) for i in range(3)]
    record={'name':name,'assetKey':key,'tier':tier,'version':version,
            'fbx':'models/'+name+'.fbx','glb':'models/'+name+'.glb','icon':'icons/'+name+'.png',
            'triangles':len(obj.data.loop_triangles),'sizeStuds':[dimensions[0],dimensions[2],dimensions[1]],
            'gripOrigin':[0,0,0],'materialCount':1,'texture':'textures/Pickaxes_Studs.png'}
    assert obj.data.uv_layers.active and len(obj.data.materials)==1
    export_fbx(DEST/record['fbx'],[obj]);export_glb(DEST/record['glb'],[obj])
    obj.location=(x,0,1.4)
    obj.data['asset_marked']=True
    obj.asset_mark()
    obj.asset_data.description=key+' pickaxe; flat studs, one mesh, grip pivot; tier '+str(tier)
    obj.asset_data.tags.new('Pickaxe');obj.asset_data.tags.new('Roblox');obj.asset_data.tags.new(key)
    objects.append(obj);manifest['models'].append(record)
    folder=PICKS/('%02d-%s'%(tier,key.lower()))
    shutil.copy2(folder/'icons'/(key.lower()+'-pickaxe-reference-'+version+'.png'),DEST/record['icon'])

export_fbx(DEST/'Pickaxes_Wooden_Stone.fbx',objects)
export_glb(DEST/'Pickaxes_Wooden_Stone.glb',objects)
assert len(scene.objects)==2 and all(o.type=='MESH' for o in scene.objects)
scene['purpose']='Clean import pack: final Wooden and Stone only. No cameras, lights or earlier drafts.'
scene['import_scale_unit']='Stud'
scene['ready_asset_count']=2
select_only(objects)
bpy.data.libraries.write(str(ROOT/'.tools/pickaxes-import-scene-library.blend'),{scene},fake_user=True,compress=True)
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(PICKS/'pack/previews/wooden-stone-review-v02.png',DEST/'preview.png')
bpy.context.window.scene=original
result={'folder':str(DEST),'models':manifest['models'],'fbx':str(DEST/'Pickaxes_Wooden_Stone.fbx'),'originalSceneRestored':original.name}
