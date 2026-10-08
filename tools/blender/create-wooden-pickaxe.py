"""Build the approved Wooden pickaxe in a separate Blender scene.

Run inside Blender. Does not replace existing scenes or overwrite asset versions.
Coordinates: X across the head, -Y front, Z up. Grip pivot is Z=1.45.
"""
import bpy
import bmesh
import json
import math
import struct
import zlib
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
ASSET = ROOT / 'assets/items/pickaxes/01-wooden'
BLEND = ASSET / 'models/wooden-pickaxe-studs-v01.blend'
assert not BLEND.exists(), 'Version exists; create a new version instead.'
assert bpy.context.mode == 'OBJECT', 'Switch to Object mode first.'
assert 'Wooden_Pickaxe_v01' not in bpy.data.scenes, 'Scene already exists.'
original_scene = bpy.context.scene
backup = ROOT / '.tools/blender-before-wooden-v01.blend'
if not backup.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(backup), copy=True)
scene = bpy.data.scenes.new('Wooden_Pickaxe_v01')
bpy.context.window.scene = scene
scene.unit_settings.system = 'NONE'
model = bpy.data.collections.new('Wooden_Pickaxe_Model')
studio = bpy.data.collections.new('Preview_Studio_DO_NOT_EXPORT')
scene.collection.children.link(model)
scene.collection.children.link(studio)
root = bpy.data.objects.new('Wooden_Pickaxe_Grip', None)
model.objects.link(root)
root.location = (0, 0, 1.45)
root.empty_display_type = 'PLAIN_AXES'
root['asset_key'] = 'Wooden'
root['symmetry_plane'] = 'X=0'
root['roblox_grip_axis'] = 'Blender Z; FBX Y-up'

# One small, portable color atlas. All exported faces have nondegenerate UVs.
colors = ['C87932', 'E3943F', 'AF6129', 'F8B453', '704022', '46515F', '8493A2', 'B9C5D2']
labels = ['Wood', 'Wood_Light', 'Wood_Shadow', 'Stud_Wood', 'Wood_End', 'Steel_Dark', 'Steel', 'Steel_Stud']
texture = ASSET / 'textures/wooden-pickaxe-palette-v01.png'
def png_chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
row = b''.join(bytes.fromhex(c) * 32 for c in colors)
texture.write_bytes(b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', struct.pack('!2I5B', 256, 32, 8, 2, 0, 0, 0)) + png_chunk(b'IDAT', zlib.compress((b'\0' + row) * 32)) + png_chunk(b'IEND', b''))
image = bpy.data.images.load(str(texture), check_existing=False)
image.pack()
materials = []
for index, label in enumerate(labels):
    mat = bpy.data.materials.new('Wooden_' + label)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.interpolation = 'Closest'
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = .72 if index < 5 else .47
    # Non-metallic painted steel gives the same colors in Roblox imports.
    bsdf.inputs['Metallic'].default_value = 0
    mat.diffuse_color = tuple(int(colors[index][i:i+2], 16) / 255 for i in (0,2,4)) + (1,)
    materials.append(mat)

parts = []
def prepare(obj, name, color, bevel=.025):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    model.objects.link(obj)
    for mat in materials:
        obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.material_index = color
    obj.parent = root
    obj.matrix_parent_inverse = root.matrix_world.inverted()
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Small_Planar_Bevel', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        modifier.affect = 'EDGES'
        modifier.material = 5 if color >= 5 else 4
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    parts.append(obj)
    return obj

def box(name, center, size, color, bevel=.025, angle_y=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.dimensions = size
    obj.rotation_euler.y = angle_y
    return prepare(obj, name, color, bevel)

shaft = box('Handle_Wood', (0,0,2.20), (.46,.50,4.40), 0, .045)
for polygon in shaft.data.polygons:
    if polygon.normal.y < -.9:
        polygon.material_index = 1
    elif max(abs(v) for v in polygon.normal) < .99:
        polygon.material_index = 4
    elif polygon.normal.x != 0:
        polygon.material_index = 2

# Explicitly reflected lofts give two identical descending mining tips.
stations = [(.26,4.29,3.74,.35),(.93,4.25,3.69,.35),(1.58,4.04,3.44,.33),(1.98,3.76,3.18,.30),(2.43,3.05,2.98,.13)]
for side, suffix in ((-1,'L'),(1,'R')):
    verts = []
    for x, top, bottom, depth in stations:
        mid = bottom + (top-bottom)*.45
        for y,z in ((-depth,top),(depth,top),(depth,mid),(depth,bottom),(-depth,bottom),(-depth,mid)):
            verts.append((side*x,y,z))
    faces = [tuple(range(5,-1,-1)), tuple(range(24,30))]
    face_colors = [0,4]
    for k in range(4):
        for j in range(6):
            faces.append((k*6+j,k*6+(j+1)%6,(k+1)*6+(j+1)%6,(k+1)*6+j))
            face_colors.append([1,0,2,2,2,0][j])
    mesh = bpy.data.meshes.new('Head_Loft_'+suffix)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new('Head_Wood_'+suffix,mesh)
    model.objects.link(obj)
    # Assign face color before bevel so bevel inherits the adjacent face color.
    prepare(obj,obj.name,0,0)
    for p,c in zip(obj.data.polygons,face_colors):
        p.material_index=c
    bevel = obj.modifiers.new('Head_Edge_Bevel','BEVEL')
    bevel.width=.024
    bevel.segments=1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for stud_num,x in enumerate((.62,1.18,1.70),1):
        for a,b in zip(stations,stations[1:]):
            if a[0] <= x <= b[0]:
                slope=(b[1]-a[1])/(b[0]-a[0])
                top=a[1]+(x-a[0])*slope
                break
        angle=-math.atan(side*slope)
        normal=Vector((math.sin(angle),0,math.cos(angle)))
        center=Vector((side*x,0,top))+normal*.046
        box('Head_Stud_%s_%02d'%(suffix,stud_num),center,(.25,.27,.108),3,.012,angle)

box('Head_Center_Block',(0,0,4.015),(.64,.70,.60),0,.028)
box('Head_Steel_Socket',(0,0,3.98),(.72,.82,.80),5,.045)
box('Handle_Top_Cap',(0,0,4.47),(.51,.56,.29),1,.026)
for side in (-1,1):
    for z in (3.80,4.15):
        box('Socket_Rivet_%s_%.2f'%(side,z),(0,side*.438,z),(.23,.075,.23),7,.016)

# Closed collars surround the shaft; the through-shaft socket is hidden inside.
for band_name,z in (('Upper',2.95),('Lower',.62)):
    box('Steel_Band_'+band_name,(0,0,z),(.59,.64,.30),5,.032)
    for side in (-1,1):
        box('Band_FrontBack_Rivet_%s_%d'%(band_name,side),(0,side*.343,z),(.21,.075,.20),7,.013)
        box('Band_Side_Rivet_%s_%d'%(band_name,side),(side*.317,0,z),(.073,.20,.19),6,.013)
for z in (.23,1.15,1.75,2.35):
    for side in (-1,1):
        box('Handle_Stud_%s_%.2f'%(side,z),(0,side*.280,z),(.22,.105,.23),3,.014)

# Smart per-face planar UVs inside one atlas cell, without zero-area UVs.
for obj in parts:
    mesh=obj.data
    uv=mesh.uv_layers.new(name='PaletteUV')
    mesh.uv_layers.active_index=len(mesh.uv_layers)-1
    uv.active_render=True
    for unused_uv in list(mesh.uv_layers):
        if unused_uv != uv:
            mesh.uv_layers.remove(unused_uv)
    for polygon in mesh.polygons:
        major=max(range(3),key=lambda i:abs(polygon.normal[i]))
        axes=[i for i in range(3) if i != major]
        coordinates=[mesh.vertices[mesh.loops[i].vertex_index].co for i in polygon.loop_indices]
        mins=[min(v[a] for v in coordinates) for a in axes]
        spans=[max(v[a] for v in coordinates)-mins[k] for k,a in enumerate(axes)]
        for loop_idx,co in zip(polygon.loop_indices,coordinates):
            u=(co[axes[0]]-mins[0])/max(spans[0],1e-9)
            v=(co[axes[1]]-mins[1])/max(spans[1],1e-9)
            uv.data[loop_idx].uv=((polygon.material_index+.12+.76*u)/8,.12+.76*v)
    mesh.update()

# Preview cameras and lights belong to a separate collection.
def camera(name,location,target,scale,roll=0):
    data=bpy.data.cameras.new(name)
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=location
    rotation=(Vector(target)-obj.location).to_track_quat('-Z','Y')
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=rotation @ Quaternion((0,0,1),roll)
    data.type='ORTHO'
    data.ortho_scale=scale
    data.lens=50
    return obj
scene.camera=camera('Shop_Icon_Camera',(6,-13,8),(0,0,2.26),6.1,math.radians(17))
front=camera('Symmetry_Front_Camera',(0,-16,2.27),(0,0,2.27),5.45)
def light(name,position,power,size):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=position
    obj.rotation_euler=(Vector((0,0,2.2))-obj.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-4,-6,9),650,5)
light('Fill',(5,-3,5),350,4)
light('Rim',(0,4,8),500,4)
world=bpy.data.worlds.new('Wooden_Studio_World')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.38,.48,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.world=world
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1024
scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
scene.render.filepath=str(ASSET / 'icons/wooden-pickaxe-shop-v01.png')

bpy.ops.object.select_all(action='DESELECT')
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active=shaft
scene['approved_reference']='01-wooden-pickaxe-studs-v01.png'
scene['symmetry']='All model geometry and palette are mirrored across X=0.'
scene['model_units']='1 Blender unit = 1 intended Roblox stud; grip at (0,0,1.45).'
scene['export_collection']=model.name
scene['original_scene_preserved']=original_scene.name
bpy.context.view_layer.update()

# Save only the new scene and its dependencies, preserving the original in backup.
bpy.data.libraries.write(str(BLEND),{scene},fake_user=True,compress=True)
result={'blend':str(BLEND),'parts':len(parts),'scene':scene.name,'original_scene':original_scene.name,'texture':str(texture),'ready_to_render':True}
