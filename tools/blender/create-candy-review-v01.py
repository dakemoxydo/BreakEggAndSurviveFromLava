"""Add only Candy: striped block shoulders, pointed hooks and peppermint discs."""
import ast
import math
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '09_Candy_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-candy-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/candy-striped-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Candy_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .39
    shader.inputs['Metallic'].default_value = 0
    mats.append(mat)
for name, color in [('Mint_White', (.95, .83, .87, 1)), ('Mint_Pink', (.85, .045, .30, 1))]:
    mat = bpy.data.materials.new('Candy_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .32
    mats.append(mat)
collection = bpy.data.collections.new('09_Candy_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Candy_Grip_v01', None)
collection.objects.link(root)
root.location = (48.75, 0, 1.4)
root['asset_key'] = 'Candy'
root['tier'] = 9
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped pink-white candy blocks, symmetric pointed hooks, peppermint discs, teal wrappers, dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Candy_' + ('Pink_Shaft' if key == 'Wooden_Shaft' else key.replace('Steel', 'Teal'))
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat
for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Candy_Inner_Striped_Block_' + suffix, (side * .90, 0, 4.15), (.94, .74, 1.10), 6, 7, .05)
    outer = box('Candy_Outer_Striped_Block_' + suffix, (side * 1.61, 0, 3.94), (.84, .68, 1.05), 6, 7, .045)
    outer.rotation_euler.y = side * .40
    # Angular hook preserves the shared stepped mining-tool silhouette.
    outline = [(1.84, 4.045), (2.28, 3.82), (2.65, 3.37), (2.70, 2.99),
               (2.32, 2.77), (2.42, 3.20), (2.07, 3.20), (1.84, 3.14)]
    n = len(outline)
    vertices = [(side * x, facing * (.30 if z > 3.3 else .16 if x > 2.55 else .05), z)
                for facing in (-1, 1) for x, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    colors = [6, 6]
    for j in range(n):
        faces.append((j, (j + 1) % n, n + (j + 1) % n, n + j))
        colors.append(7 if j < 3 else 6)
    finish(mesh('Candy_Pointed_Hook_' + suffix, vertices, faces, colors), .015)
box('Candy_Teal_Center_Socket', (0, 0, 4.16), (1.05, .88, 1.24), 4, 5, .04)
box('Candy_Teal_Top_Collar', (0, 0, 4.83), (.78, .78, .17), 4, 5, .025)
box('Candy_Pink_Tenon', (0, 0, 4.99), (.46, .50, .16), 0, 1, .025)

def peppermint(name, center_x, facing):
    n = 24
    vertices = []
    for radius, twist in [(.06, .55), (.22, .25), (.37, 0)]:
        for i in range(n):
            angle = 2 * math.pi * i / n + twist
            vertices.append((center_x + radius * math.cos(angle), facing * .48,
                             4.15 + radius * math.sin(angle)))
    for i in range(n):
        angle = 2 * math.pi * i / n
        vertices.append((center_x + .37 * math.cos(angle), facing * .375,
                         4.15 + .37 * math.sin(angle)))
    faces, colors = [tuple(reversed(range(n))), tuple(range(n * 3, n * 4))], [8, 9]
    for ring in range(2):
        for j in range(n):
            faces.append((ring * n + j, ring * n + (j + 1) % n,
                          (ring + 1) * n + (j + 1) % n, (ring + 1) * n + j))
            colors.append(8 + (j // 3) % 2)
    for j in range(n):
        faces.append((2 * n + j, 2 * n + (j + 1) % n, 3 * n + (j + 1) % n, 3 * n + j))
        colors.append(9)
    finish(mesh(name, vertices, faces, colors))

for side, suffix in [(-1, 'L'), (1, 'R')]:
    for facing, face_name in [(-1, 'Front'), (1, 'Back')]:
        peppermint('Candy_Peppermint_' + face_name + '_' + suffix, side * .91, facing)
    # Faceted wrapper bow ends integrated with the middle band.
    outline = [(side * .30, 2.19), (side * .68, 2.39), (side * .78, 2.02),
               (side * .66, 1.78), (side * .30, 1.92)]
    vertices = [(x, y, z) for y in (-.24, .24) for x, z in outline]
    faces = [(4, 3, 2, 1, 0), (5, 6, 7, 8, 9)]
    colors = [4, 5]
    for j in range(5):
        faces.append((j, (j + 1) % 5, 5 + (j + 1) % 5, 5 + j))
        colors.append(5 if j < 2 else 4)
    finish(mesh('Candy_Teal_Wrapper_Bow_' + suffix, vertices, faces, colors), .018)
box('Candy_Lower_Teal_Ring', (0, 0, .76), (.62, .64, .14), 4, 5, .02)

center = Vector((22.75, 0, 2.6))
camera = scene.camera
camera.location = (26.35, -27, 9.15)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 59.8
scene.render.resolution_x = 4400
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 64
    light.data.energy *= 1.13
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Candy_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (51.5, -15, 6.6)
detail.rotation_euler = (Vector((48.75, 0, 2.55)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 6.7
scene.render.filepath = str(PACK / 'previews/nine-slots-candy-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Candy v01 awaits review. Preserve empty Diamond slot.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 60.3
output = PACK / 'models/pickaxes-asset-pack-review-v10.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
