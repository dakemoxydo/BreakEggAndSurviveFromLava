"""Add one Diamond pickaxe using the accepted stepped block family style."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '05_Diamond_Review_v01' not in bpy.data.collections
image = bpy.data.images.load(str(PACK / 'textures/diamond-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Diamond_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .26 if i >= 6 else .43
    shader.inputs['Metallic'].default_value = .38 if i in (4, 5) else .05
    mats.append(mat)
for name, color in [('Gem', (.006, .50, .75, 1)), ('Gem_Light', (.15, .88, 1, 1)),
                    ('Gem_Shadow', (.005, .20, .40, 1))]:
    mat = bpy.data.materials.new('Diamond_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .19
    mats.append(mat)
collection = bpy.data.collections.new('05_Diamond_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Diamond_Grip_v01', None)
collection.objects.link(root)
root.location = (22.75, 0, 1.4)
root['asset_key'] = 'Diamond'
root['tier'] = 5
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped cyan crystal blocks, navy armored handle, silver fittings; flat dark studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))

wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Diamond_' + ('Armored_Shaft' if key == 'Wooden_Shaft' else key)
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat

def crystal_block(name, location, size, angle=0):
    # Chamfered block silhouette with shallow faceted faces on both sides.
    w, d, h = size[0] / 2, size[1] / 2, size[2] / 2
    c = .085
    outline = [(-w + c, h), (w - c, h), (w, h - c), (w, -h + c),
               (w - c, -h), (-w + c, -h), (-w, -h + c), (-w, h - c)]
    vertices = [(x, y, z) for y in (-d, d) for x, z in outline]
    vertices += [(0, -d - .055, 0), (0, d + .055, 0)]
    faces, colors = [], []
    for j in range(8):
        nxt = (j + 1) % 8
        faces += [(j, nxt, 16), (8 + nxt, 8 + j, 17), (j, 8 + j, 8 + nxt, nxt)]
        colors += [7 if j in (0, 1, 7) else 6, 7 if j in (0, 1, 7) else 6,
                   7 if j in (0, 1, 7) else 6]
    # The helper accepts coordinates with the grip offset; leave mesh local to its block.
    obj = mesh(name, [(x, y, z + 1.4) for x, y, z in vertices], faces, colors)
    obj.location = (location[0], location[1], location[2] - 1.4)
    finish(obj)
    obj.rotation_euler.y = angle
    return obj

for side, suffix in [(-1, 'L'), (1, 'R')]:
    crystal_block('Diamond_Inner_Crystal_' + suffix, (side * .91, 0, 4.15), (.91, .73, 1.10))
    crystal_block('Diamond_Outer_Crystal_' + suffix, (side * 1.60, 0, 3.94), (.82, .68, 1.04), side * .40)
    stations = [(1.84, 4.055, 3.14, .31), (2.23, 3.80, 3.13, .25), (2.76, 3.085, 3.02, .025)]
    vertices = []
    for x, top, bottom, depth in stations:
        bevel_z = min(.12, (top - bottom) * .25)
        section = [(-depth * .62, top), (depth * .62, top),
                   (depth, top - bevel_z), (depth, bottom + bevel_z),
                   (depth * .62, bottom), (-depth * .62, bottom),
                   (-depth, bottom + bevel_z), (-depth, top - bevel_z)]
        vertices.extend((side * x, y, z) for y, z in section)
    faces = [tuple(reversed(range(8))), tuple(range(16, 24))]
    colors = [6, 6]
    for k in range(2):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8,
                          (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
            colors.append(7 if j in (0, 1, 7) else 6)
    finish(mesh('Diamond_Crystal_Point_' + suffix, vertices, faces, colors))
    box('Diamond_Silver_Blade_Brace_' + suffix, (side * .55, 0, 4.15), (.145, .84, 1.12), 4, 5, .024)

box('Diamond_Navy_Center_Socket', (0, 0, 4.15), (1.04, .88, 1.23), 0, 1, .045)
box('Diamond_Upper_Armored_Collar', (0, 0, 4.82), (.76, .78, .16), 0, 1, .025)
box('Diamond_Crystal_Tenon', (0, 0, 4.98), (.47, .51, .16), 6, 7, .02)
for side, suffix in [(-1, 'Front'), (1, 'Back')]:
    # Diamond-shaped silver setting, with a genuinely faceted cyan center.
    y = side * .45
    outline = [(0, y, 4.66), (.40, y, 4.15), (0, y, 3.64), (-.40, y, 4.15)]
    back = [(x, side * .49, z) for x, _, z in outline]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    finish(mesh('Diamond_Silver_Setting_' + suffix, outline + back, faces, [4, 5, 4, 4, 4, 4]))
    vertices = [(0, side * .496, 4.57), (.31, side * .496, 4.15), (0, side * .496, 3.73),
                (-.31, side * .496, 4.15), (0, side * .66, 4.15)]
    finish(mesh('Diamond_Center_Gem_' + suffix, vertices,
                [(3, 2, 1, 0), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], [10, 9, 8, 10, 9]))
# A small faceted crystal pommel echoes the reference without changing handle length.
vertices = [(-.31, -.31, .21), (.31, -.31, .21), (.31, .31, .21), (-.31, .31, .21),
            (0, 0, -.015)]
finish(mesh('Diamond_Crystal_Pommel', vertices,
            [(0, 3, 2, 1), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)], [8, 9, 8, 10, 9]))
center = Vector((9.75, 0, 2.5))
camera = scene.camera
camera.location = (13.35, -27, 9.05)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 33.4
scene.render.resolution_x = 2800
scene.render.resolution_y = 900
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 36
    light.data.energy *= 1.25
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(PACK / 'previews/five-pickaxes-unified-style-v01.png')
scene['workflow'] = 'First four pickaxes accepted for continuation. Diamond v01 awaiting review. One new model per user instruction.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 33.9
output = PACK / 'models/pickaxes-asset-pack-review-v06.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
