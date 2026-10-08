"""Add only Rainbow, preserving the shared stepped silhouette and live scene."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '10_Rainbow_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-rainbow-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/rainbow-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Rainbow_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .40
    shader.inputs['Metallic'].default_value = .10
    mats.append(mat)
for name, color in [('Star_White', (.92, .92, 1, 1)), ('Star_Lilac', (.64, .61, .82, 1))]:
    mat = bpy.data.materials.new('Rainbow_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .3
    mats.append(mat)
collection = bpy.data.collections.new('10_Rainbow_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Rainbow_Grip_v01', None)
collection.objects.link(root)
root.location = (55.25, 0, 1.4)
root['asset_key'] = 'Rainbow'
root['tier'] = 10
root['status'] = 'Awaiting user review'
root['style'] = 'Six colored stepped head sections, violet socket and shaft, white star, rainbow rings; dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
original = next(o for o in wood.objects if o.name == 'Wooden_Wooden_Shaft')
obj = original.copy()
obj.data = original.data.copy()
obj.name = 'Rainbow_Violet_Shaft'
collection.objects.link(obj)
obj.parent = root
obj.matrix_parent_inverse.identity()
for i, mat in enumerate(mats[:8]):
    obj.data.materials[i] = mat
for side, suffix, colors in [(-1, 'L', (5, 4, 3)), (1, 'R', (6, 7, 1))]:
    # Geometry mirrors exactly; the color order follows the reference spectrum.
    inner, outer, tip = colors
    box('Rainbow_Inner_Block_' + suffix, (side * .87, 0, 4.15), (.91, .75, 1.10), inner, inner, .04)
    obj = box('Rainbow_Outer_Block_' + suffix, (side * 1.57, 0, 3.94), (.84, .69, 1.06), outer, outer, .035)
    obj.rotation_euler.y = side * .40
    vertices = []
    for x, top, bottom, depth in [(1.82, 4.055, 3.14, .31), (2.22, 3.80, 3.13, .265), (2.78, 3.08, 3.02, .035)]:
        vertices.extend([(side * x, -depth, top), (side * x, depth, top),
                         (side * x, depth, bottom), (side * x, -depth, bottom)])
    faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
    for k in range(2):
        for j in range(4):
            faces.append((k * 4 + j, k * 4 + (j + 1) % 4,
                          (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j))
    finish(mesh('Rainbow_Pointed_End_' + suffix, vertices, faces, [tip] * len(faces)), .014)
box('Rainbow_Violet_Center_Socket', (0, 0, 4.16), (1.06, .88, 1.25), 0, 1, .04)
box('Rainbow_Violet_Upper_Collar', (0, 0, 4.84), (.77, .79, .17), 0, 1, .025)
box('Rainbow_Violet_Tenon', (0, 0, 5.00), (.46, .50, .16), 0, 1, .02)
box('Rainbow_Violet_Lower_Collar', (0, 0, 3.42), (.71, .73, .23), 0, 1, .025)
for z, color in zip([3.04, 2.53, 2.02, 1.51, 1.0, .49], [3, 4, 5, 6, 7, 1]):
    box('Rainbow_Color_Ring_' + str(color), (0, 0, z), (.67, .69, .17), color, color, .025)
for facing, suffix in [(-1, 'Front'), (1, 'Back')]:
    box('Rainbow_Star_Frame_' + suffix, (0, facing * .466, 4.16), (.86, .08, .96), 1, 1, .026)
    outline = [(0, 4.59), (.105, 4.27), (.385, 4.16), (.105, 4.05),
               (0, 3.73), (-.105, 4.05), (-.385, 4.16), (-.105, 4.27)]
    vertices = [(x, facing * .514, z) for x, z in outline]
    vertices += [(x, facing * .505, z) for x, z in outline]
    vertices.append((0, facing * .64, 4.16))
    faces, colors = [tuple(range(8, 16))], [9]
    for j in range(8):
        faces.extend([(j, (j + 1) % 8, 16), (j, 8 + j, 8 + (j + 1) % 8, (j + 1) % 8)])
        colors.extend([8 if j in (0, 1, 6, 7) else 9, 9])
    finish(mesh('Rainbow_White_Star_' + suffix, vertices, faces, colors))
# Compact rainbow pommel made from four aligned colored slices.
for i, color in enumerate([3, 5, 6, 7]):
    box('Rainbow_Pommel_Slice_' + str(i), ((i - 1.5) * .18, 0, .19), (.18, .72, .36), color, color, .015)
box('Rainbow_Pommel_Cap', (0, 0, .405), (.76, .76, .09), 0, 1, .015)
center = Vector((26, 0, 2.6))
camera = scene.camera
camera.location = (29.6, -27, 9.15)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 66.4
scene.render.resolution_x = 4800
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 71
    light.data.energy *= 1.11
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Rainbow_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (58, -15, 6.6)
detail.rotation_euler = (Vector((55.25, 0, 2.55)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 6.7
scene.render.resolution_percentage = 100
scene.render.filepath = str(PACK / 'previews/ten-slots-rainbow-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Rainbow v01 awaits review. Preserve empty Diamond slot.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 66.9
output = PACK / 'models/pickaxes-asset-pack-review-v11.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
