"""Add only Lightning: block shoulders and mirrored zigzag bolt ends."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '08_Lightning_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-lightning-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/lightning-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Lightning_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .37 if i >= 4 else .50
    shader.inputs['Metallic'].default_value = .28 if i >= 4 else .12
    mats.append(mat)
for name, color in [('Cyan_Energy', (.005, .68, .88, 1)), ('Cyan_Light', (.13, .93, 1, 1))]:
    mat = bpy.data.materials.new('Lightning_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .28
    shader.inputs['Emission Color'].default_value = color
    shader.inputs['Emission Strength'].default_value = .3
    mats.append(mat)
collection = bpy.data.collections.new('08_Lightning_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Lightning_Grip_v01', None)
collection.objects.link(root)
root.location = (42.25, 0, 1.4)
root['asset_key'] = 'Lightning'
root['tier'] = 8
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped yellow block shoulders and lightning tips; navy transformer, cyan core, dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Lightning_' + ('Navy_Shaft' if key == 'Wooden_Shaft' else key.replace('Steel', 'Conductor'))
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat
for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Lightning_Inner_Block_' + suffix, (side * .87, 0, 4.16), (.89, .74, 1.08), 6, 7, .035)
    # Concave lightning steps are the theme detail; no raised stud geometry.
    outline = [(1.17, 4.47), (1.84, 4.30), (1.71, 4.06), (2.12, 4.12),
               (2.78, 3.04), (2.00, 3.41), (2.09, 3.70), (1.49, 3.56),
               (1.59, 3.85), (1.17, 3.74)]
    n = len(outline)
    vertices = [(side * x, facing * (.33 if x < 2.3 else .035), z)
                for facing in [-1, 1] for x, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    colors = [6, 6]
    for j in range(n):
        faces.append((j, (j + 1) % n, n + (j + 1) % n, n + j))
        colors.append(7 if j in (0, 2, 3, 8) else 4)
    finish(mesh('Lightning_Zigzag_Blade_' + suffix, vertices, faces, colors), .017)
    box('Lightning_Yellow_Blade_Clamp_' + suffix, (side * .57, 0, 4.16), (.15, .85, 1.14), 6, 7, .02)
box('Lightning_Navy_Transformer_Socket', (0, 0, 4.16), (1.06, .88, 1.24), 0, 1, .045)
box('Lightning_Upper_Armor', (0, 0, 4.83), (.80, .81, .18), 0, 1, .025)
box('Lightning_Yellow_Top_Contact', (0, 0, 4.99), (.46, .50, .16), 6, 7, .02)
for facing, suffix in [(-1, 'Front'), (1, 'Back')]:
    box('Lightning_Core_Recess_' + suffix, (0, facing * .467, 4.16), (.75, .09, .84), 3, 3, .025)
    box('Lightning_Cyan_Energy_Core_' + suffix, (0, facing * .535, 4.16), (.53, .105, .59), 8, 9, .035)
    box('Lightning_Upper_Cyan_Channel_' + suffix, (0, facing * .275, 2.82), (.32, .035, .80), 8, 9, .009)
    box('Lightning_Lower_Cyan_Channel_' + suffix, (0, facing * .275, 1.12), (.32, .035, .77), 8, 9, .009)
for z in [2.40, 1.56, .69]:
    box('Lightning_Conductor_Ring_' + str(z), (0, 0, z), (.63, .65, .15), 6, 7, .02)
box('Lightning_Navy_Pommel', (0, 0, .19), (.72, .74, .34), 0, 1, .055)
box('Lightning_Cyan_Pommel_Contact', (0, 0, .41), (.65, .67, .09), 8, 9, .015)

center = Vector((19.5, 0, 2.6))
camera = scene.camera
camera.location = (23.1, -27, 9.15)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 53.2
scene.render.resolution_x = 4000
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 57
    light.data.energy *= 1.14
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Lightning_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (45, -15, 6.6)
detail.rotation_euler = (Vector((42.25, 0, 2.55)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 6.7
scene.render.filepath = str(PACK / 'previews/eight-slots-lightning-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Lightning v01 awaits review. Preserve empty Diamond slot.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 53.7
output = PACK / 'models/pickaxes-asset-pack-review-v09.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
