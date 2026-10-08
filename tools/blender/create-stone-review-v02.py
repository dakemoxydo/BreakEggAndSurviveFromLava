"""Build one Stone revision beside the approved Wooden geometry for user review.

Run in the interactive scene created by appending 01_Wooden_Reference_v04.
No game assets are replaced. Older Blender files remain untouched.
"""
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review'
assert '02_Stone_Review_v02' not in bpy.data.collections
wood = bpy.data.collections['01_Wooden_Reference_v04']
wood.name = '01_Wooden_v04_DarkStuds'
wood_root = next(o for o in wood.objects if o.type == 'EMPTY')
wood_root.location = (-3.25, 0, 1.4)
image = bpy.data.images.load(str(PACK / 'textures/pickaxes-dark-studs-v01.png'), check_existing=True)
image.pack()
source_mats = list(next(o for o in wood.objects if o.type == 'MESH').data.materials)
mats = []
for i, original in enumerate(source_mats):
    mat = original.copy()
    mat.name = 'Pack_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .72
    mats.append(mat)
for obj in wood.objects:
    if obj.type == 'MESH':
        for i, mat in enumerate(mats):
            obj.data.materials[i] = mat
wood_root['geometry_source'] = 'Approved Wooden reference v04; geometry unchanged'
wood_root['texture_revision'] = 'Dark studs v01'

collection = bpy.data.collections.new('02_Stone_Review_v02')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Stone_Grip_v02', None)
collection.objects.link(root)
root.location = (3.25, 0, 1.4)
root['asset_key'] = 'Stone'
root['status'] = 'Awaiting user review'
root['revision'] = 'v02'
root.empty_display_type = 'PLAIN_AXES'

# Match the approved handle dimensions and metal fittings exactly.
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    source = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = 'Stone_' + key
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()

def finish_mesh(obj, bevel_width=0):
    for mat in mats:
        obj.data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    if bevel_width:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bevel = obj.modifiers.new('Clean_Edge_Chamfer', 'BEVEL')
        bevel.width = bevel_width
        bevel.segments = 1
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    uv = obj.data.uv_layers.new(name='StudsUV')
    uv.active_render = True
    for face in obj.data.polygons:
        major = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = [i for i in range(3) if i != major]
        for loop in face.loop_indices:
            # Same pattern scale and atlas padding as approved Wooden UVs.
            co = obj.data.vertices[obj.data.loops[loop].vertex_index].co + obj.location + Vector((0, 0, 1.4))
            a = (co[axes[0]] + 3.3) / 6.6
            b = (co[axes[1]] + (.3 if axes[1] == 2 else 3.3)) / 6.6
            i = face.material_index
            uv.data[loop].uv = ((i % 4 + (4 + 1016 * a) / 1024) / 4,
                                ((1 - i // 4) + (4 + 1016 * b) / 1024) / 2)
    obj.parent = root
    return obj

def mesh(name, vertices, faces, colors):
    data = bpy.data.meshes.new(name)
    data.from_pydata([(x, y, z - 1.4) for x, y, z in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    for face, color in zip(data.polygons, colors):
        face.material_index = color
    return obj

# Each arm is a single closed loft with eight-sided stone cross-sections.
# Mirror the same stations exactly; no raised studs or ornamental LEGO blocks.
stations = [(.34, 4.63, 3.64, .40), (1.08, 4.59, 3.66, .365),
            (1.70, 4.32, 3.52, .305), (2.22, 3.90, 3.24, .205),
            (2.66, 3.105, 3.02, .035)]
for side, suffix in [(-1, 'L'), (1, 'R')]:
    vertices = []
    for x, top, bottom, depth in stations:
        bevel_z = min(.16, (top - bottom) * .22)
        section = [(-depth * .64, top), (depth * .64, top),
                   (depth, top - bevel_z), (depth, bottom + bevel_z),
                   (depth * .64, bottom), (-depth * .64, bottom),
                   (-depth, bottom + bevel_z), (-depth, top - bevel_z)]
        vertices.extend((side * x, y, z) for y, z in section)
    faces = [tuple(reversed(range(8))), tuple(range(32, 40))]
    colors = [6, 6]
    for k in range(len(stations) - 1):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8,
                          (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
            colors.append([7, 7, 6, 6, 6, 6, 6, 7][j])
    finish_mesh(mesh('Stone_Faceted_Arm_' + suffix, vertices, faces, colors))

def box(name, location, size, base, top=None, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(location[0], location[1], location[2] - 1.4))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.material_index = top if top is not None and face.normal.z > .9 else base
    return finish_mesh(obj, bevel)

box('Stone_Central_Steel_Socket', (0, 0, 4.13), (.96, .88, 1.16), 4, 5, .035)
box('Stone_Handle_Tenon', (0, 0, 4.77), (.46, .50, .18), 0, 1, .018)
# A small matching diamond fastener on both faces links the family's visual style.
for side, suffix in [(-1, 'Front'), (1, 'Back')]:
    y = side * .445
    vertices = [(0, y, 4.55), (.33, y, 4.13), (0, y, 3.71), (-.33, y, 4.13), (0, side * .565, 4.13)]
    faces = [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    finish_mesh(mesh('Stone_Diamond_Fastener_' + suffix, vertices, faces, [4, 5, 4, 4, 5]))

studio = bpy.data.collections.new('Review_Studio_Do_Not_Export')
scene.collection.children.link(studio)
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('Pickaxe_Review_World')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.12, .15, .21, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .55
scene.world = world
for name, location, power, size in [('Key', (-5, -8, 10), 1500, 7),
                                     ('Fill', (7, -5, 7), 1050, 6), ('Rim', (1, 5, 8), 1900, 5)]:
    data = bpy.data.lights.new('Review_' + name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(data.name, data)
    studio.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 2.4)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
camera_data = bpy.data.cameras.new('Pack_Review_Camera')
camera = bpy.data.objects.new(camera_data.name, camera_data)
studio.objects.link(camera)
camera.location = (3.6, -27, 9)
camera.rotation_euler = (Vector((0, 0, 2.45)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 13.3
scene.camera = camera
scene['workflow'] = 'One pickaxe per review. Wooden approved base; Stone v02 awaiting feedback. Continue only after user approval.'
scene['style'] = 'Dark flat studs; Wooden v04 proportions; themed details; symmetry; no raised LEGO squares.'
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    if obj.type == 'MESH':
        obj.select_set(True)
bpy.context.view_layer.objects.active = next(o for o in collection.objects if o.type == 'MESH')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = (0, 0, 2.45)
            space.region_3d.view_distance = 13.8
scene.render.filepath = str(PACK / 'previews/wooden-stone-dark-studs-review-v01.png')
output = PACK / 'models/pickaxes-asset-pack-review-v02.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'wooden': wood.name, 'newModel': collection.name,
          'status': 'Stone awaits user review', 'preview': scene.render.filepath}
