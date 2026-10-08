"""Add only Demon in the approved stepped block style; keep scene edits."""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '12_Demon_Review_v01' not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / '.tools/before-demon-live-edits.blend'), copy=True, compress=True)
image = bpy.data.images.load(str(PACK / 'textures/demon-dark-studs-v01.png'), check_existing=True)
image.pack()
mats = []
for i in range(8):
    mat = bpy.data.materials['Pack_DarkStuds_%02d' % i].copy()
    mat.name = 'Demon_DarkStuds_%02d' % i
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE':
            node.image = image
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value = .27 if i not in (4, 5) else .43
    shader.inputs['Metallic'].default_value = .2 if i in (4, 5) else 0
    mats.append(mat)
for name, color, emission in [('Lava', (1, .19, .008, 1), 1.3),
                              ('Core_Light', (1, .65, .035, 1), .8),
                              ('Horn', (.028, .025, .043, 1), 0),
                              ('Horn_Edge', (.10, .09, .135, 1), 0)]:
    mat = bpy.data.materials.new('Demon_Facet_' + name)
    mat.use_nodes = True
    mat.diffuse_color = color
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .36
    shader.inputs['Emission Color'].default_value = color
    shader.inputs['Emission Strength'].default_value = emission
    mats.append(mat)
collection = bpy.data.collections.new('12_Demon_Review_v01')
scene.collection.children.link(collection)
root = bpy.data.objects.new('Demon_Grip_v01', None)
collection.objects.link(root)
root.location = (68.25, 0, 1.4)
root['asset_key'] = 'Demon'
root['tier'] = 12
root['status'] = 'Awaiting user review'
root['style'] = 'Stepped obsidian armor, crimson hooked tips, paired horns, orange lava core and seams; dark flat studs'
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))
wood = bpy.data.collections['01_Wooden_v04_DarkStuds']
for key in ['Wooden_Shaft', 'Top_Steel_Brace', 'Middle_Steel_Band', 'Bottom_Steel_Cap']:
    original = next(o for o in wood.objects if o.name == 'Wooden_' + key)
    obj = original.copy()
    obj.data = original.data.copy()
    obj.name = 'Demon_' + ('Armored_Shaft' if key == 'Wooden_Shaft' else key.replace('Steel', 'Crimson'))
    collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse.identity()
    for i, mat in enumerate(mats[:8]):
        obj.data.materials[i] = mat
# Separate armor sections retain the approved stepped block silhouette.
for side, suffix in [(-1, 'L'), (1, 'R')]:
    box('Demon_Inner_Obsidian_Block_' + suffix, (side * .88, 0, 4.16), (.93, .76, 1.12), 6, 1, .065)
    seam = box('Demon_Lava_Joint_' + suffix, (side * 1.31, 0, 4.09), (.085, .65, .98), 8, 8, .016)
    outer = box('Demon_Outer_Obsidian_Block_' + suffix, (side * 1.62, 0, 3.95), (.81, .70, 1.06), 0, 1, .06)
    outer.rotation_euler.y = side * .40
    # Crimson cutting hooks taper through three octagonal sections.
    vertices = []
    stations = [(1.91, 4.05, 3.13, .31), (2.39, 3.70, 2.98, .24), (2.81, 2.80, 2.75, .025)]
    for x, top, bottom, depth in stations:
        chamfer = min(.12, (top - bottom) * .24)
        section = [(-depth * .65, top), (depth * .65, top),
                   (depth, top - chamfer), (depth, bottom + chamfer),
                   (depth * .65, bottom), (-depth * .65, bottom),
                   (-depth, bottom + chamfer), (-depth, top - chamfer)]
        vertices.extend((side * x, y, z) for y, z in section)
    faces = [tuple(reversed(range(8))), tuple(range(16, 24))]
    colors = [4, 7]
    for k in range(2):
        for j in range(8):
            faces.append((k * 8 + j, k * 8 + (j + 1) % 8,
                          (k + 1) * 8 + (j + 1) % 8, (k + 1) * 8 + j))
            colors.append(5 if j in (0, 1, 7) else 7)
    finish(mesh('Demon_Crimson_Hook_' + suffix, vertices, faces, colors))
    collar = box('Demon_Tip_Lava_Seam_' + suffix, (side * 1.94, 0, 3.72), (.07, .63, .73), 8, 8, .014)
    collar.rotation_euler.y = side * .40
    box('Demon_Horn_Red_Setting_' + suffix, (side * .83, 0, 4.77), (.40, .47, .23), 4, 5, .025)
    vertices = []
    for x, z, width, depth in [(.83, 4.83, .33, .35), (.86, 5.13, .25, .28), (1.09, 5.51, .012, .014)]:
        vertices.extend((side * (x + a * width / 2), b * depth / 2, z)
                        for a, b in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
    faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
    colors = [10, 11]
    for k in range(2):
        for j in range(4):
            faces.append((4*k+j, 4*k+(j+1)%4, 4*(k+1)+(j+1)%4, 4*(k+1)+j))
            colors.append(11 if j % 2 == 0 else 10)
    finish(mesh('Demon_Faceted_Horn_' + suffix, vertices, faces, colors))
box('Demon_Crimson_Center_Socket', (0, 0, 4.17), (1.08, .9, 1.27), 4, 5, .055)
box('Demon_Obsidian_Top_Cap', (0, 0, 4.84), (.65, .71, .17), 0, 1, .022)
for facing, suffix in [(-1, 'Front'), (1, 'Back')]:
    setting = box('Demon_Diamond_Frame_' + suffix, (0, facing * .49, 4.17), (.71, .11, .71), 3, 3, .022)
    setting.rotation_euler.y = .7853981634
    vertices = [(0, facing*.553, 4.57), (.31, facing*.553, 4.17),
                (0, facing*.553, 3.77), (-.31, facing*.553, 4.17), (0, facing*.71, 4.17)]
    finish(mesh('Demon_Lava_Core_' + suffix, vertices,
                [(3,2,1,0), (0,1,4), (1,2,4), (2,3,4), (3,0,4)], [8,9,8,8,9]))
    # Molten channels are narrow inlays, rather than raised square studs.
    for side, label in [(-1, 'L'), (1, 'R')]:
        strip = box('Demon_Head_Channel_' + suffix + '_' + label,
                    (side*.86, facing*.387, 3.91), (.065,.025,.43), 8,8,.009)
        strip.rotation_euler.y = side*.22
for index, height in enumerate([.69, 1.35, 2.72]):
    box('Demon_Crimson_Grip_Ring_%02d' % index, (0,0,height), (.60,.62,.135), 4,5,.025)
vertices = [(-.28,-.29,.14),(.28,-.29,.14),(.28,.29,.14),(-.28,.29,.14),(0,0,-.37)]
finish(mesh('Demon_Obsidian_Pointed_Pommel', vertices,
            [(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)], [4,10,11,10,11]))
for facing, suffix in [(-1,'Front'),(1,'Back')]:
    vertices = [(-.13,facing*.295,.10),(.13,facing*.295,.10),(0,facing*.09,-.24)]
    # The insert lies just outside the pommel slope.
    finish(mesh('Demon_Lava_Pommel_Insert_' + suffix, vertices, [(0,1,2)], [8]))
center = Vector((32.5, 0, 2.7))
camera = scene.camera
camera.location = (36.10, -27, 9.25)
camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 80
scene.render.resolution_x = 5600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
for name in ['Review_Key', 'Review_Fill', 'Review_Rim']:
    light = bpy.data.objects[name]
    light.location.x += 3.25
    light.data.size = 85
    light.data.energy *= 1.1
    light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
studio = bpy.data.collections['Review_Studio_Do_Not_Export']
data = bpy.data.cameras.new('Demon_Detail_Camera')
detail = bpy.data.objects.new(data.name, data)
studio.objects.link(detail)
detail.location = (71.0, -15, 7)
detail.rotation_euler = (Vector((68.25, 0, 2.95)) - detail.location).to_track_quat('-Z', 'Y').to_euler()
data.type = 'ORTHO'
data.ortho_scale = 7.4
scene.render.filepath = str(PACK / 'previews/twelve-slots-demon-review-v01.png')
scene['workflow'] = 'Previous visible models accepted for continuation. Demon v01 awaits review. Preserve empty Diamond slot.'
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_location = center
            space.region_3d.view_distance = 80.5
output = PACK / 'models/pickaxes-asset-pack-review-v13.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'newModel': collection.name, 'status': 'Awaiting user review', 'preview': scene.render.filepath}
