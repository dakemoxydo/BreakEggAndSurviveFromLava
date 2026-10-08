"""Replace only Stone and Iron arms with the Wooden family's stepped blocks.

Preserves handles, central sockets, gemstones, Wooden and Golden geometry.
The prior v04 file remains available as the backup of the previous silhouettes.
"""
import ast
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK = ROOT / 'assets/items/pickaxes/pack'
scene = bpy.context.scene
assert scene.name == 'Pickaxe_Pack_Review' and bpy.context.mode == 'OBJECT'
assert '02_Stone_Review_v03' not in bpy.data.collections
assert '03_Iron_Review_v02' not in bpy.data.collections
helper = ROOT / 'tools/blender/create-iron-review-v01.py'
tree = ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)],
                        type_ignores=[]), str(helper), 'exec'))

for key, old_collection, new_collection, root_name, old_prefix in [
        ('Stone', '02_Stone_Review_v02', '02_Stone_Review_v03', 'Stone_Grip_v02', 'Stone_Faceted_Arm_'),
        ('Iron', '03_Iron_Review_v01', '03_Iron_Review_v02', 'Iron_Grip_v01', 'Iron_Forged_Blade_')]:
    collection = bpy.data.collections[old_collection]
    root = bpy.data.objects[root_name]
    old_arms = [o for o in collection.objects if o.name.startswith(old_prefix)]
    assert len(old_arms) == 2
    material_source = next(o for o in collection.objects if o.type == 'MESH' and o not in old_arms)
    mats = list(material_source.data.materials)
    # Delete the specifically requested old heads only; previous file is preserved.
    for obj in old_arms:
        bpy.data.objects.remove(obj, do_unlink=True)
    collection.name = new_collection
    root['status'] = 'Awaiting revised style review'
    root['revision'] = 'v03' if key == 'Stone' else 'v02'
    root['style'] = 'Wooden-family stepped blocks, themed facets, mirrored sharp tips, dark flat studs'
    for side, suffix in [(-1, 'L'), (1, 'R')]:
        if key == 'Stone':
            # Broad chamfers give separate stone chunks a mineral appearance.
            inner = box('Stone_Inner_Chunk_' + suffix, (side * .85, 0, 4.15),
                        (.85, .76, 1.10), 6, 7, .095)
            outer = box('Stone_Outer_Chunk_' + suffix, (side * 1.52, 0, 3.94),
                        (.82, .70, 1.04), 6, 7, .085)
            outer.rotation_euler.y = side * .40
            stations = [(1.76, 4.055, 3.14, .31), (2.18, 3.80, 3.13, .27),
                        (2.68, 3.09, 3.025, .035)]
            tip_bevel = .018
        else:
            # Tighter straight bevels distinguish forged metal from stone.
            inner = box('Iron_Inner_Steel_Block_' + suffix, (side * .85, 0, 4.16),
                        (.85, .70, 1.04), 6, 7, .035)
            outer = box('Iron_Outer_Steel_Block_' + suffix, (side * 1.52, 0, 3.95),
                        (.82, .64, .98), 6, 7, .028)
            outer.rotation_euler.y = side * .40
            stations = [(1.76, 4.045, 3.16, .285), (2.18, 3.79, 3.14, .245),
                        (2.68, 3.09, 3.025, .028)]
            tip_bevel = .012
        vertices = []
        for x, top, bottom, depth in stations:
            vertices.extend([(side * x, -depth, top), (side * x, depth, top),
                             (side * x, depth, bottom), (side * x, -depth, bottom)])
        faces = [(3, 2, 1, 0), (8, 9, 10, 11)]
        colors = [6, 6 if key == 'Stone' else 4]
        for k in range(2):
            for j in range(4):
                faces.append((k * 4 + j, k * 4 + (j + 1) % 4,
                              (k + 1) * 4 + (j + 1) % 4, (k + 1) * 4 + j))
                colors.append([7, 6, 6 if key == 'Stone' else 4, 6][j])
        finish(mesh(key + '_Stepped_Point_' + suffix, vertices, faces, colors), tip_bevel)

bpy.ops.object.select_all(action='DESELECT')
scene['workflow'] = 'Stone v03 and Iron v02 revised to match Wooden/Golden stepped style. Awaiting user feedback.'
scene['style'] = 'Common stepped block silhouette; stone broad facets; iron precise bevels; flat dark studs; symmetric tips.'
scene.render.filepath = str(PACK / 'previews/four-pickaxes-unified-block-style-v01.png')
output = PACK / 'models/pickaxes-asset-pack-review-v05.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output), compress=True)
result = {'file': str(output), 'revised': ['Stone v03', 'Iron v02'],
          'preserved': ['Wooden', 'Golden', 'all handles and center fittings'],
          'preview': scene.render.filepath}
