"""Create portable single-material Roblox meshes on a separate export scene."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK=ROOT/'assets/items/pickaxes/pack'
VERSION=globals().get('EXPORT_VERSION','v02')
EXPORT_SCENE='Pickaxes_Studio_Export_'+VERSION
OUT=PACK/('exports/roblox-import-'+VERSION)

def setup_export():
    review=bpy.context.scene
    assert review.name=='Pickaxe_Pack_Review' and bpy.context.mode=='OBJECT'
    assert EXPORT_SCENE not in bpy.data.scenes
    for folder in ['models','textures','source']: (OUT/folder).mkdir(parents=True,exist_ok=True)
    if bpy.data.is_dirty:
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.tools/before-pickaxe-export-v02.blend'),copy=True,compress=True)
    export=bpy.data.scenes.new(EXPORT_SCENE)
    export.unit_settings.system='NONE';export.unit_settings.scale_length=1
    export.render.engine='CYCLES';export.cycles.samples=1;export.cycles.device='CPU'
    export.render.bake.margin=12
    export.render.image_settings.file_format='PNG'
    export.view_settings.view_transform='Standard'
    export['source_scene']=review.name
    export['export_only']=True
    return {'scene':export.name,'directory':str(OUT)}

def emissive_source(original,target,cache):
    if original.name in cache:return cache[original.name]
    mat=original.copy();mat.name='BakeOnly_'+original.name
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    shader=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    emission=nodes.new('ShaderNodeEmission')
    base=shader.inputs['Base Color']
    if base.is_linked:links.new(base.links[0].from_socket,emission.inputs['Color'])
    else:emission.inputs['Color'].default_value=base.default_value
    links.new(emission.outputs[0],output.inputs['Surface'])
    uv=nodes.new('ShaderNodeUVMap');uv.uv_map='SourceUV'
    for node in list(nodes):
        if node.type=='TEX_IMAGE':links.new(uv.outputs['UV'],node.inputs['Vector'])
    node=nodes.new('ShaderNodeTexImage');node.name='Bake_Target';node.image=target
    nodes.active=node;node.select=True
    cache[original.name]=mat
    return mat

def export_asset(tier):
    review=bpy.data.scenes['Pickaxe_Pack_Review']
    export=bpy.data.scenes[EXPORT_SCENE]
    collection=next(c for c in review.collection.children if c.name.startswith('%02d_'%tier))
    root=next(o for o in collection.objects if o.type=='EMPTY' and 'asset_key' in o)
    key=root['asset_key'];name=key+'Pickaxe'
    assert name not in export.objects
    if name in bpy.data.objects:
        previous=bpy.data.objects[name]
        assert any('Studio_Export' in s.name for s in previous.users_scene)
        previous.name='Archived_'+name
    original_scene=bpy.context.window.scene
    bpy.context.window.scene=export
    target=bpy.data.images.new(key+'_Color_2048',width=2048,height=2048,alpha=False)
    target.colorspace_settings.name='sRGB'
    clones=[];cache={}
    try:
        for obj in collection.all_objects:
            if obj.type!='MESH':continue
            clone=bpy.data.objects.new('Export_'+obj.name,obj.data.copy())
            export.collection.objects.link(clone)
            clone.data.transform(root.matrix_world.inverted() @ obj.matrix_world)
            source=clone.data.uv_layers.get('StudsUV') or clone.data.uv_layers.active
            for uv in list(clone.data.uv_layers):
                if uv!=source:clone.data.uv_layers.remove(uv)
            source.name='SourceUV';source.active_render=True
            for i,mat in enumerate(list(clone.data.materials)):
                clone.data.materials[i]=emissive_source(mat,target,cache)
            clone.select_set(True);clones.append(clone)
        bpy.context.view_layer.objects.active=clones[0]
        bpy.ops.object.join();mesh=bpy.context.object;mesh.name=name;mesh.data.name=name+'_Geometry'
        mesh.data.uv_layers.new(name='ColorUV')
        mesh.data.uv_layers.active_index=1
        mesh.data.uv_layers['ColorUV'].active_render=True
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.012,area_weight=.5,correct_aspect=True,scale_to_bounds=True)
        bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.bake(type='EMIT',use_clear=True,margin=12)
        texture=OUT/('textures/'+key+'_Color.png')
        target.filepath_raw=str(texture);target.file_format='PNG';target.save();target.pack()
        baked=bpy.data.materials.new(key+'_Roblox_Color');baked.use_nodes=True
        node=baked.node_tree.nodes.new('ShaderNodeTexImage');node.image=target
        baked.node_tree.links.new(node.outputs['Color'],baked.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        baked.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.48
        mesh.data.materials.clear();mesh.data.materials.append(baked)
        for p in mesh.data.polygons:p.material_index=0
        mesh.data.uv_layers.remove(mesh.data.uv_layers['SourceUV'])
        tri=mesh.modifiers.new('Export_Triangles','TRIANGULATE')
        bpy.ops.object.modifier_apply(modifier=tri.name)
        mesh.data.calc_loop_triangles()
        triangles=len(mesh.data.loop_triangles)
        assert len(mesh.data.materials)==1 and len(mesh.data.uv_layers)==1
        assert triangles<20000
        assert mesh.location.length<.00001 and mesh.scale==Vector((1,1,1))
        points=[v.co for v in mesh.data.vertices]
        low=[min(p[i] for p in points) for i in range(3)]
        high=[max(p[i] for p in points) for i in range(3)]
        options=dict(use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',
            global_scale=1,apply_unit_scale=False,apply_scale_options='FBX_SCALE_UNITS',
            bake_space_transform=True,bake_anim=False,use_mesh_modifiers=True,
            path_mode='COPY',embed_textures=True,use_custom_props=True)
        mesh['asset_key']=key;mesh['tier']=tier;mesh['grip_origin']='0,0,0'
        mesh.asset_mark()
        bpy.ops.export_scene.fbx(filepath=str(OUT/('models/'+name+'.fbx')),**options)
        record=dict(name=name,assetKey=key,tier=tier,sourceCollection=collection.name,
            fbx='models/'+name+'.fbx',texture='textures/'+key+'_Color.png',triangles=triangles,
            vertices=len(mesh.data.vertices),materialCount=1,uvSets=1,gripOrigin=[0,0,0],
            boundsBlender={'min':low,'max':high},
            sizeStuds=[high[0]-low[0],high[2]-low[2],high[1]-low[1]],
            bakedBaseColor=True,importedToRoblox=False)
        records=json.loads(export.get('manifest_models','[]'));records.append(record)
        export['manifest_models']=json.dumps(records)
        mesh.location=(root.location.x+3.25,0,1.4)
        mesh.select_set(False)
        return record
    finally:
        if bpy.context.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
        bpy.context.window.scene=original_scene

def finish_export():
    export=bpy.data.scenes[EXPORT_SCENE]
    original=bpy.context.window.scene
    bpy.context.window.scene=export
    try:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.fbx(filepath=str(OUT/'Pickaxes_Pack.fbx'),use_selection=True,
            object_types={'MESH'},axis_forward='Z',axis_up='Y',global_scale=1,apply_unit_scale=False,
            apply_scale_options='FBX_SCALE_UNITS',bake_space_transform=True,bake_anim=False,
            path_mode='COPY',embed_textures=True,use_custom_props=True)
        records=json.loads(export['manifest_models'])
        expected=sum(c.name[:2].isdigit() for c in bpy.data.scenes['Pickaxe_Pack_Review'].collection.children)
        assert len(records)==expected and len(export.objects)==expected
        manifest=dict(version=VERSION,sourceBlend='../../models/'+Path(bpy.data.filepath).name,
            sourceScene='Pickaxe_Pack_Review',mainFile='Pickaxes_Pack.fbx',models=records,
            source='source/Pickaxes_Import.blend',
            exportSettings=dict(forward='Z',up='Y',scale=1,applyUnitScale=False,applyScaling='FBX Unit Scale',embedTextures=True),
            importSettings={'Scale Unit':'Studs','Merge Meshes':False,'Use Imported Pivot':True,'Anchored':True},
            runtimeTemplatePath='ReplicatedStorage.PickaxeModels',robloxImported=False)
        (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        # Write only the export scene, including its packed texture dependencies.
        bpy.data.libraries.write(str(OUT/'source/Pickaxes_Import.blend'),{export},fake_user=True,compress=True)
        return dict(file=str(OUT/'Pickaxes_Pack.fbx'),models=len(records),triangles=sum(m['triangles'] for m in records))
    finally:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.window.scene=original

result={'loaded':True}
