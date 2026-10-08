"""Add one symmetric Golden pickaxe beside the three accepted models."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '04_Golden_Review_v01' not in bpy.data.collections
image = bpy.data.images.load(str(PACK / 'textures/golden-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Golden_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .38 if i >= 4 else .76
    shader.inputs['Metallic'].default_value = .42 if i >= 4 else 0
    mats.append(mat)
for name, color in [('Emerald', (.005, .38, .095, 1)),
                    ('Emerald_Light', (.025, .68, .23, 1)),
                    ('Emerald_Shadow', (.003, .16, .045, 1))]:
    mat = bpy.data.materials.new('Golden_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .24
    mats.append(mat)
collection = bpy.data.collections.new('04_Golden_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Golden_Grip_v01', None)
collection.objects.link(root)
root.location = (16.25, 0, 1.4)
root['asset_key'] = 'Golden'
root['tier'] = 4
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped gold head, emerald setting, walnut handle, gold rings and pommel; flat dark studs'

# Reuse only geometry/UV helpers, without executing the earlier scene generator.
source = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(source.read_text(encoding='utf-8'))
functions = [node for node in tree.body if isinstance(node, ast.FunctionDef)]
exec(compile(ast.Module(body=functions, type_ignores=[]), str(source), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Golden_' + key
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat

# Closed, bevelled gold blocks form balanced shoulders and deliberate steps.
for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Golden_Inner_Block_' + suffix, (side * .86, 0, 4.14), (.94, .72, 1.02), 6, 7, .035)
    obj = box('Golden_Outer_Block_' + suffix, (side * 1.62, 0, 3.92), (.84, .66, .97), 6, 7, .035)
    obj.rotation_euler.y = side * .34
    # Tip starts within the shoulder so the stepped construction has no gap.
    stations = [(1.85, 4.03, 3.21, .30), (2.27, 3.70, 3.14, .24), (2.72, 3.07, 3.015, .028)]
    vertices = []
    for x, top, bottom, depth in stations:
        vertices.extend([(side * x, -depth, top), (side * x, depth, top),
                         (side * x, depth, bottom), (side * x, -depth, bottom)])
    faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
    colors = [6, 4]
    for k in range(2):
        for j in range(4):
            faces.append((k * 4 + j, k * 4 + (j + 1) % 4,
                          (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j))
            colors.append([7, 6, 4, 6][j])
    finish(mesh('Golden_Pointed_Tip_' + suffix, vertices, faces, colors), .012)

box('Golden_Central_Socket', (0, 0, 4.15), (1.07, .85, 1.27), 6, 7, .04)
box('Golden_Top_Ferrule', (0, 0, 4.83), (.72, .74, .16), 6, 7, .02)
box('Golden_Walnut_Tenon', (0, 0, 4.97), (.46, .50, .15), 0, 1, .018)
box('Golden_Pommel', (0, 0, .21), (.76, .77, .43), 6, 7, .09)
# Rectangular emerald, framed in gold on both sides; no stud geometry on the frame.
for side, suffix in [(-1, 'Front'), (1, 'Back')]:
    box('Golden_Emerald_Bezel_' + suffix, (0, side * .465, 4.15), (.82, .10, 1.01), 4, 5, .028)
    base = [(x, side * .526, z) for x, z in [(-.32, 3.76), (.32, 3.76), (.32, 4.54), (-.32, 4.54)]]
    table = [(x, side * .66, z) for x, z in [(-.205, 3.90), (.205, 3.90), (.205, 4.40), (-.205, 4.40)]]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    finish(mesh('Golden_Faceted_Emerald_' + suffix, base + table, faces, [10, 8, 10, 8, 9, 9]))

# Broaden the existing review lighting to illuminate the whole four-item row.
for name, energy in [('Review_Key', 5000), ('Review_Fill', 3700), ('Review_Rim', 5000)]:
    light = bpy.data.objects[name]
    light.location.x = 6.5 + (-3 if name == 'Review_Key' else 3 if name == 'Review_Fill' else 0)
    light.data.shape = 'RECTANGLE'
    light.data.size = 29
    light.data.size_y = 7
    light.data.energy = energy
    light.rotation_euler = (Vector((6.5, 0, 2.5)) - light.location).to_track_quat('-Z', 'Y').to_euler()
camera = scene.camera
center = Vector((6.5, 0, 2.5))
camera.location = (10.1, -27, 9.05)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 26.8
scene.render.resolution_x = 2400
scene.render.resolution_y = 900
scene.render.filepath = str(PACK / 'previews/wooden-stone-iron-golden-review-v01.png')
scene['workflow'] = 'First three pickaxes accepted for continuation. Golden v01 awaiting review. One new model per user instruction.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 27.3
output = PACK / 'models/pickaxes-asset-pack-review-v04.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
