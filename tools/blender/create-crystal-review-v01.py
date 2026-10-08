"""Add only Crystal in the approved stepped block style; keep scene edits."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '11_Crystal_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-crystal-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/crystal-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Crystal_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .27 if i not in (4, 5) else .43
    shader.inputs['Metallic'].default_value = .2 if i in (4, 5) else 0
    mats.append(mat)
for name, color in [('Cyan', (.02, .53, .79, 1)), ('Ice_Light', (.37, .85, 1, 1)),
                    ('Violet', (.40, .12, .75, 1)), ('Blue_Shadow', (.035, .16, .37, 1))]:
    mat = bpy.data.materials.new('Crystal_Facet_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .22
    mats.append(mat)
collection = bpy.data.collections.new('11_Crystal_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Crystal_Grip_v01', None)
collection.objects.link(root)
root.location = (61.75, 0, 1.4)
root['asset_key'] = 'Crystal'
root['tier'] = 11
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped cyan-violet blocks, prism crown, mirrored shards, crystal shaft and navy fittings; dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Crystal_' + ('Prism_Shaft' if key == 'Wooden_Shaft' else key.replace('Steel', 'Navy'))
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat
for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Crystal_Inner_Cyan_Block_' + suffix, (side * .89, 0, 4.16), (.94, .76, 1.12), 6, 1, .085)
    outer = box('Crystal_Outer_Violet_Block_' + suffix, (side * 1.61, 0, 3.95), (.85, .70, 1.06), 7, 7, .075)
    outer.rotation_euler.y = side * .40
    vertices = []
    for x, top, bottom, depth in [(1.86, 4.06, 3.15, .32), (2.27, 3.81, 3.13, .27), (2.83, 3.08, 3.02, .03)]:
        chamfer = min(.13, (top - bottom) * .25)
        section = [(-depth * .62, top), (depth * .62, top),
                   (depth, top - chamfer), (depth, bottom + chamfer),
                   (depth * .62, bottom), (-depth * .62, bottom),
                   (-depth, bottom + chamfer), (-depth, top - chamfer)]
        vertices.extend((side * x, y, z) for y, z in section)
    faces = [tuple(reversed(range(8))), tuple(range(16, 24))]
    colors = [6, 6]
    for k in range(2):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8,
                          (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
            colors.append(1 if j in (0, 1, 7) else 6)
    finish(mesh('Crystal_Faceted_Point_' + suffix, vertices, faces, colors))
box('Crystal_Navy_Center_Socket', (0, 0, 4.17), (1.08, .90, 1.26), 4, 5, .045)
box('Crystal_Navy_Crown_Collar', (0, 0, 4.87), (.82, .81, .17), 4, 5, .025)

def prism(name, base, axis, width, depth, violet=False):
    base, axis = Vector(base), Vector(axis)
    tangent = Vector((axis.z, 0, -axis.x)).normalized()
    across = Vector((0, 1, 0))
    vertices = []
    for fraction, radius in [(0, 1), (.69, .78)]:
        center = base + axis * fraction
        for a, b in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
            vertices.append(tuple(center + tangent * (a * width * radius / 2) + across * (b * depth * radius / 2)))
    vertices.append(tuple(base + axis))
    faces = [(3, 2, 1, 0)]
    colors = [11]
    for j in range(4):
        faces += [(j, (j + 1) % 4, 4 + (j + 1) % 4, 4 + j), (4 + j, 4 + (j + 1) % 4, 8)]
        colors += [10 if violet else [8, 9, 8, 11][j], 10 if violet and j % 2 else 9]
    return finish(mesh(name, vertices, faces, colors))

prism('Crystal_Central_Crown_Prism', (0, 0, 4.90), (0, 0, 1.04), .45, .43)
for side, suffix in [(-1, 'L'), (1, 'R')]:
    prism('Crystal_Violet_Crown_' + suffix, (side * .29, 0, 4.87), (side * .24, 0, .68), .27, .31, True)
    prism('Crystal_Shoulder_Shard_' + suffix, (side * 1.50, 0, 4.41), (side * .15, 0, .43), .22, .27, True)
    prism('Crystal_Floating_Shard_' + suffix, (side * 1.02, 0, 4.96), (side * .12, 0, .40), .19, .21)
prism('Crystal_Prism_Pommel', (0, 0, .24), (0, 0, -.31), .56, .57)
for facing, suffix in [(-1, 'Front'), (1, 'Back')]:
    box('Crystal_Core_Setting_' + suffix, (0, facing * .476, 4.17), (.66, .08, .76), 3, 3, .025)
    vertices = [(0, facing * .522, 4.50), (.25, facing * .522, 4.17),
                (0, facing * .522, 3.84), (-.25, facing * .522, 4.17), (0, facing * .65, 4.17)]
    finish(mesh('Crystal_Faceted_Core_' + suffix, vertices,
                [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], [11, 9, 8, 11, 9]))
center = Vector((29.25, 0, 2.7))
camera = scene.camera
camera.location = (32.85, -27, 9.25)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 73
scene.render.resolution_x = 5200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 78
    light.data.energy *= 1.1
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Crystal_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (64.5, -15, 7)
detail.rotation_euler = (Vector((61.75, 0, 2.95)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 7.4
scene.render.filepath = str(PACK / 'previews/eleven-slots-crystal-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Crystal v01 awaits review. Preserve empty Diamond slot.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 73.5
output = PACK / 'models/pickaxes-asset-pack-review-v12.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
