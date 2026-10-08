"""Add only Iron to the approved review row; preserve earlier models."""
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '03_Iron_Review_v01' not in bpy.data.collections
image = bpy.data.images.load(str(PACK / 'textures/iron-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Iron_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .42 if i >= 4 else .76
    shader.inputs['Metallic'].default_value = .38 if i >= 4 else 0
    mats.append(mat)
collection = bpy.data.collections.new('03_Iron_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Iron_Grip_v01', None)
collection.objects.link(root)
root.location = (9.75, 0, 1.4)
root['asset_key'] = 'Iron'
root['tier'] = 3
root['status'] = 'Awaiting user review'
root['style'] = 'Forged silver head, dark socket, wood shaft and charcoal grip; flat dark studs'
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    source = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = 'Iron_' + key
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats):
        obj.data.materials[i] = mat

def finish(obj, bevel_width=0):
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
        bevel = obj.modifiers.new('Forged_Edge_Bevel', 'BEVEL')
        bevel.width = bevel_width
        bevel.segments = 1
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    uv = obj.data.uv_layers.new(name='StudsUV')
    uv.active_render = True
    for face in obj.data.polygons:
        major = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = [i for i in range(3) if i != major]
        for loop in face.loop_indices:
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

# Broader machined planes and a thinner silver cutting edge distinguish iron.
stations = [(.34, 4.65, 3.65, .34), (1.17, 4.62, 3.72, .32),
            (1.85, 4.27, 3.50, .265), (2.30, 3.88, 3.22, .17),
            (2.68, 3.105, 3.025, .026)]
for side, suffix in [(-1, 'L'), (1, 'R')]:
    vertices = []
    for x, top, bottom, depth in stations:
        chamfer = min(.14, (top - bottom) * .25)
        section = [(-depth * .57, top), (depth * .57, top),
                   (depth, top - chamfer), (depth, bottom + chamfer),
                   (depth * .57, bottom), (-depth * .57, bottom),
                   (-depth, bottom + chamfer), (-depth, top - chamfer)]
        vertices.extend((side * x, y, z) for y, z in section)
    faces = [tuple(reversed(range(8))), tuple(range(32, 40))]
    colors = [6, 7]
    for k in range(len(stations) - 1):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8,
                          (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
            colors.append([7, 7, 6, 4, 4, 4, 6, 7][j])
    finish(mesh('Iron_Forged_Blade_' + suffix, vertices, faces, colors))

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
    return finish(obj, bevel)

box('Iron_Dark_Center_Socket', (0, 0, 4.14), (.96, .86, 1.13), 4, 5, .045)
box('Iron_Silver_Top_Ferrule', (0, 0, 4.74), (.74, .76, .17), 6, 7, .025)
box('Iron_Wooden_Tenon', (0, 0, 4.88), (.46, .50, .15), 0, 1, .018)
for side, suffix in [(-1, 'Front'), (1, 'Back')]:
    y = side * .435
    vertices = [(0, y, 4.52), (.30, y, 4.14), (0, y, 3.76), (-.30, y, 4.14), (0, side * .54, 4.14)]
    faces = [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    finish(mesh('Iron_Silver_Fastener_' + suffix, vertices, faces, [4, 7, 6, 6, 7]))

# A continuous dark sleeve with shallow horizontal wrap seams, not raised studs.
box('Iron_Charcoal_Grip', (0, 0, 1.12), (.58, .60, 1.37), 3, 3, .045)
for i in range(5):
    box('Iron_Grip_Wrap_Seam_%02d' % i, (0, 0, .61 + i * .255), (.594, .614, .035), 4, 4, .013)

camera = scene.camera
center = Vector((3.25, 0, 2.5))
camera.location = (6.85, -27, 9.05)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 20.2
scene.render.resolution_x = 2000
scene.render.resolution_y = 900
scene.render.filepath = str(PACK / 'previews/wooden-stone-iron-review-v01.png')
scene['workflow'] = 'Wooden and Stone accepted for continuation. Iron v01 awaiting review. Create only one new pickaxe per user instruction.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 20.7
output = PACK / 'models/pickaxes-asset-pack-review-v03.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
