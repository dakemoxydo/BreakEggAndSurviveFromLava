"""Add only Strawberry; keep live edits and the accepted block family intact."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '06_Strawberry_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-strawberry-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/strawberry-dark-studs-v01.png'), check_existing=True)
cream = bpy.data.images.load(str(PACK / 'textures/strawberry-cream-studs-v01.png'), check_existing=True)
image.pack()
cream.pack()
mats = []
for i in range(10):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % (i % 8)].copy()
    mat.name = 'Strawberry_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = cream if i >= 8 else image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .5
    shader.inputs['Metallic'].default_value = 0
    mats.append(mat)
collection = bpy.data.collections.new('06_Strawberry_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Strawberry_Grip_v01', None)
collection.objects.link(root)
root.location = (29.25, 0, 1.4)
root['asset_key'] = 'Strawberry'
root['tier'] = 6
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped berry-red blocks, symmetrical green calyx, cream bands, dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
definitions = ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)], type_ignores=[])
code = ast.unparse(definitions).replace('i = face.material_index', 'i = face.material_index % 8')
exec(compile(code, str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Strawberry_' + ('Berry_Shaft' if key == 'Wooden_Shaft' else key)
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat
    if key != 'Wooden_Shaft':
        # Existing UVs use palette 4/5: remap them to cream tile 0/1.
        obj.data.materials.append(mats[8])
        obj.data.materials.append(mats[9])
        uv = obj.data.uv_layers.active
        for face in obj.data.polygons:
            old = face.material_index
            new = 9 if old == 5 else 8
            for loop in face.loop_indices:
                coord = uv.data[loop].uv
                coord.x += ((new % 8) % 4 - old % 4) / 4
                coord.y += ((1 - (new % 8) // 4) - (1 - old // 4)) / 2
            face.material_index = new

for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Strawberry_Inner_Berry_Block_' + suffix, (side * .90, 0, 4.15), (.94, .74, 1.10), 6, 7, .065)
    outer = box('Strawberry_Outer_Berry_Block_' + suffix, (side * 1.60, 0, 3.94), (.84, .68, 1.05), 6, 7, .055)
    outer.rotation_euler.y = side * .40
    vertices = []
    for x, top, bottom, depth in [(1.85, 4.055, 3.14, .31), (2.24, 3.80, 3.13, .265), (2.77, 3.08, 3.02, .035)]:
        vertices.extend([(side * x, -depth, top), (side * x, depth, top),
                         (side * x, depth, bottom), (side * x, -depth, bottom)])
    faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
    colors = [6, 2]
    for k in range(2):
        for j in range(4):
            faces.append((k * 4 + j, k * 4 + (j + 1) % 4,
                          (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j))
            colors.append([7, 6, 2, 6][j])
    finish(mesh('Strawberry_Pointed_Berry_Tip_' + suffix, vertices, faces, colors), .014)
box('Strawberry_Green_Center_Socket', (0, 0, 4.16), (1.03, .88, 1.20), 4, 5, .04)
box('Strawberry_Green_Top_Collar', (0, 0, 4.83), (.78, .78, .18), 4, 5, .025)
box('Strawberry_Berry_Tenon', (0, 0, 4.99), (.46, .50, .15), 6, 7, .025)

def leaf(name, outline, front, back):
    # A thick, pointed leaf with a central ridge; clean front/back symmetry.
    n = len(outline)
    vertices = [(x, front, z) for x, z in outline] + [(x, back, z) for x, z in outline]
    center_x = sum(x for x, _ in outline) / n
    center_z = sum(z for _, z in outline) / n
    vertices.append((center_x, front + (-.065 if front < 0 else .065), center_z))
    faces, colors = [tuple(range(n, 2 * n))], [3]
    for j in range(n):
        faces += [(j, (j + 1) % n, 2 * n), (j, n + j, n + (j + 1) % n, (j + 1) % n)]
        colors += [5 if j in (0, 1) else 4, 3]
    return finish(mesh(name, vertices, faces, colors))

# The leaf calyx replaces the earlier gem motif and stays integrated with the socket.
for facing, face_name in [(-1, 'Front'), (1, 'Back')]:
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        outline = [(side * .07, 4.46), (side * .42, 4.52), (side * .77, 4.22),
                   (side * .54, 3.61), (side * .18, 3.88)]
        leaf('Strawberry_Calyx_' + face_name + '_' + suffix, outline, facing * .49, facing * .42)
    leaf('Strawberry_Calyx_' + face_name + '_Center',
         [(-.22, 4.10), (.22, 4.10), (.24, 3.77), (0, 3.44), (-.24, 3.77)], facing * .57, facing * .48)

box('Strawberry_Green_Grip_Ring', (0, 0, 1.03), (.61, .63, .17), 4, 5, .025)
box('Strawberry_Green_Pommel_Collar', (0, 0, .43), (.68, .70, .12), 4, 5, .025)
for side, suffix in [(-1, 'L'), (1, 'R')]:
    leaf('Strawberry_Grip_Leaf_' + suffix,
         [(side * .19, 1.15), (side * .43, 1.22), (side * .49, 1.02), (side * .33, .70)], -.335, -.285)

center = Vector((13, 0, 2.5))
camera = scene.camera
camera.location = (16.6, -27, 9.05)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 40
scene.render.resolution_x = 3200
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 43
    light.data.energy *= 1.2
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(PACK / 'previews/six-pickaxes-unified-style-v01.png')
scene['workflow'] = 'First five accepted for continuation. Strawberry v01 awaits review. One new model per instruction.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 40.5
output = PACK / 'models/pickaxes-asset-pack-review-v07.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
