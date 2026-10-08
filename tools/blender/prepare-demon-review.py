"""Prepare the next single pickaxe from the established pack workflow."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
folder = ROOT / 'assets/items/pickaxes/pack/textures'
source = Image.open(folder / 'pickaxes-dark-studs-v01.png').convert('RGB')
old = ['AA5230', 'D17B46', '783A27', '48251D', '526B8E', '95ABC8', '727C88', 'A4AFBB']
colors = ['31313B', '575361', '26252F', '15151E', 'AB202C', 'EE4541', '373642', 'E13B38']
atlas = Image.new('RGB', source.size)
for i, color in enumerate(colors):
    x, y = i % 4 * 1024, i // 4 * 1024
    red = source.crop((x, y, x + 1024, y + 1024)).getchannel('R')
    base = int(old[i][:2], 16)
    channels = [red.point([min(255, round(v * int(color[j:j + 2], 16) / base))
                          for v in range(256)]) for j in (0, 2, 4)]
    atlas.paste(Image.merge('RGB', channels), (x, y))
atlas.save(folder / 'demon-dark-studs-v01.png')

script = (ROOT / 'tools/blender/create-crystal-review-v01.py').read_text(encoding='utf-8')
script = script.replace('Crystal', 'Demon').replace('crystal', 'demon')
script = script.replace('11_Demon', '12_Demon').replace("root['tier'] = 11", "root['tier'] = 12")
script = script.replace('61.75', '68.25').replace('64.5', '71.0')
script = script.replace('29.25', '32.5').replace('32.85', '36.10')
script = script.replace('ortho_scale = 73', 'ortho_scale = 80').replace('size = 78', 'size = 85')
script = script.replace('view_distance = 73.5', 'view_distance = 80.5')
script = script.replace('5200', '5600').replace('review-v12.blend', 'review-v13.blend')
script = script.replace('eleven-slots', 'twelve-slots')
script = script.replace("root['style'] = 'Stepped cyan-violet blocks, prism crown, mirrored shards, demon shaft and navy fittings; dark flat studs'", "root['style'] = 'Stepped obsidian armor, crimson hooked tips, paired horns, orange lava core and seams; dark flat studs'")
start = script.index('for name, color in')
end = script.index("collection = bpy.data.collections.new", start)
script = script[:start] + '''for name, color, emission in [('Lava', (1, .19, .008, 1), 1.3),
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
''' + script[end:]
start = script.index('for side, suffix in')
end = script.index('center = Vector', start)
script = script[:start] + '''# Separate armor sections retain the approved stepped block silhouette.
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
''' + script[end:]
script = script.replace("'Prism_Shaft'", "'Armored_Shaft'").replace("key.replace('Steel', 'Navy')", "key.replace('Steel', 'Crimson')")
script = script.replace('Add only Demon in the approved stepped block style', 'Add only Demon in the approved stepped block style')
(ROOT / 'tools/blender/create-demon-review-v01.py').write_text(script, encoding='utf-8')
print('Demon texture and single-asset Blender script prepared.')
