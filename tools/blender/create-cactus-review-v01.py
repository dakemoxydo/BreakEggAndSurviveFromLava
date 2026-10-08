"""Add only Cactus in the accepted block style, retaining the live scene."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '07_Cactus_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-cactus-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/cactus-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Cactus_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .42 if i in (4, 5) else .61
    shader.inputs['Metallic'].default_value = .32 if i in (4, 5) else 0
    mats.append(mat)
for name, color in [('Spine_Cream', (.75, .60, .35, 1)), ('Spine_Light', (1, .88, .62, 1)),
                    ('Spine_Shadow', (.39, .27, .12, 1))]:
    mat = bpy.data.materials.new('Cactus_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .65
    mats.append(mat)
collection = bpy.data.collections.new('07_Cactus_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Cactus_Grip_v01', None)
collection.objects.link(root)
root.location = (35.75, 0, 1.4)
root['asset_key'] = 'Cactus'
root['tier'] = 7
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped cactus-green blocks, cream spines, ribbed stem, copper fittings; symmetric dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Cactus_' + ('Ribbed_Stem' if key == 'Wooden_Shaft' else key.replace('Steel', 'Copper'))
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat

for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Cactus_Inner_Branch_' + suffix, (side * .88, 0, 4.15), (.91, .76, 1.10), 6, 7, .06)
    outer = box('Cactus_Outer_Branch_' + suffix, (side * 1.58, 0, 3.94), (.84, .70, 1.06), 6, 7, .055)
    outer.rotation_euler.y = side * .40
    vertices = []
    for x, top, bottom, depth in [(1.84, 4.055, 3.14, .32), (2.23, 3.80, 3.13, .27), (2.76, 3.08, 3.02, .035)]:
        vertices.extend([(side * x, -depth, top), (side * x, depth, top),
                         (side * x, depth, bottom), (side * x, -depth, bottom)])
    faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
    colors = [6, 2]
    for k in range(2):
        for j in range(4):
            faces.append((k * 4 + j, k * 4 + (j + 1) % 4,
                          (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j))
            colors.append([7, 6, 2, 6][j])
    finish(mesh('Cactus_Pointed_Branch_' + suffix, vertices, faces, colors), .014)

box('Cactus_Copper_Center_Socket', (0, 0, 4.16), (1.04, .88, 1.24), 4, 5, .045)
box('Cactus_Copper_Top_Collar', (0, 0, 4.84), (.76, .78, .17), 4, 5, .025)
box('Cactus_Green_Tenon', (0, 0, 5.00), (.47, .51, .16), 6, 7, .02)
for z in [.68, 1.03]:
    box('Cactus_Lower_Copper_Ring_' + str(z), (0, 0, z), (.64, .66, .19), 4, 5, .025)
# Long, shallow ribs on both stem faces; no decorative LEGO blocks.
for facing, face_name in [(-1, 'Front'), (1, 'Back')]:
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        box('Cactus_Stem_Rib_' + face_name + '_' + suffix,
            (side * .16, facing * .264, 2.20), (.048, .024, 3.86), 1, 1, .006)

def spine(name, position, direction, width):
    base = Vector(position)
    axis = Vector(direction)
    # All directions lie in XZ; the square base lies across Y and a perpendicular.
    tangent = Vector((axis.z, 0, -axis.x)).normalized() * width / 2
    depth = Vector((0, width / 2, 0))
    vertices = [tuple(base - tangent - depth), tuple(base + tangent - depth),
                tuple(base + tangent + depth), tuple(base - tangent + depth), tuple(base + axis)]
    faces = [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    finish(mesh(name, vertices, faces, [10, 9, 8, 8, 9]))

for side, suffix in [(-1, 'L'), (1, 'R')]:
    spine('Cactus_Inner_Top_Spine_' + suffix, (side * .87, 0, 4.67), (side * .07, 0, .39), .24)
    spine('Cactus_Outer_Top_Spine_' + suffix, (side * 1.67, 0, 4.48), (side * .21, 0, .33), .23)
    spine('Cactus_Inner_Lower_Spine_' + suffix, (side * 1.02, 0, 3.61), (side * .05, 0, -.29), .21)
    spine('Cactus_Outer_Side_Spine_' + suffix, (side * 2.15, 0, 3.53), (side * .30, 0, .16), .20)

center = Vector((16.25, 0, 2.6))
camera = scene.camera
camera.location = (19.85, -27, 9.15)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 46.6
scene.render.resolution_x = 3600
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 50
    light.data.energy *= 1.16
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Cactus_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (38.5, -15, 6.6)
detail.rotation_euler = (Vector((35.75, 0, 2.55)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 6.7
scene.render.filepath = str(PACK / 'previews/seven-slots-cactus-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Cactus v01 awaits review. Diamond slot remains empty by preserved scene edits.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 47.1
output = PACK / 'models/pickaxes-asset-pack-review-v08.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
