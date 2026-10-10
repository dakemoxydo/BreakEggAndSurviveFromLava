"""Rig the chick from chick-v01.blend for Roblox and add a looping Walk action.

Run inside Blender with chick-v01.blend open. Saves chick-v02.blend and exports
assets/pets/exports/chick-v02.fbx (model + bones + Walk animation).
Parts are merged per colour because a Roblox MeshPart holds one texture;
every vertex is weighted 100% to one bone, so parts move rigidly.
"""
import math
from pathlib import Path

import bpy

ROOT = Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PETS = ROOT / 'assets/pets'
col = bpy.data.collections['Chick']
assert 'ChickRig' not in bpy.data.objects

# object -> bone
BONE_OF = {
    'Body': 'Body', 'Chest': 'Body', 'Tail': 'Tail',
    'Head': 'Head', 'Beak': 'Head', 'Mouth': 'Head',
    'Eye_L': 'Head', 'Eye_R': 'Head', 'EyeShine_L': 'Head', 'EyeShine_R': 'Head',
    'Wing_L': 'WingL', 'Wing_R': 'WingR',
    'Leg_L': 'LegL', 'Foot_L': 'LegL', 'Toe_L': 'LegL',
    'Leg_R': 'LegR', 'Foot_R': 'LegR', 'Toe_R': 'LegR',
}
# material -> merged mesh name and baked texture
MESHES = {
    'Chick_White': ('ChickWhite', 'white'), 'Chick_Orange': ('ChickOrange', 'orange'),
    'Chick_Red': ('ChickRed', 'red'), 'Chick_Black': ('ChickEyes', 'black'),
    'Chick_Shine': ('ChickEyeShine', 'shine'),
}
# bone: (head, tail, parent); front is -Y, up is +Z
BONES = {
    'Root': ((0, 0, 0), (0, 0, .4), None),
    'Body': ((0, .2, .6), (0, .2, 2.0), 'Root'),
    'Head': ((0, -.45, 2.15), (0, -.45, 3.5), 'Body'),
    'Tail': ((0, 1.3, 1.8), (0, 1.9, 2.1), 'Body'),
    'WingL': ((-1.12, .35, 1.85), (-1.12, .35, .95), 'Body'),
    'WingR': ((1.12, .35, 1.85), (1.12, .35, .95), 'Body'),
    'LegL': ((-.5, .1, .6), (-.5, .1, .05), 'Root'),
    'LegR': ((.5, .1, .6), (.5, .1, .05), 'Root'),
}

# --- materials: one baked inlets texture + shared inlets normal map each
normal = bpy.data.images.load(str(PETS / 'textures/inlets-2x2-normal.png'), check_existing=True)
normal.colorspace_settings.name = 'Non-Color'
for mat_name, (_, key) in MESHES.items():
    nt = bpy.data.materials[mat_name].node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = .6
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(PETS / f'textures/chick-{key}-inlets-v01.png'), check_existing=True)
    ntex = nt.nodes.new('ShaderNodeTexImage')
    ntex.image = normal
    nmap = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(ntex.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

# --- weights, then merge per colour
for obj in list(col.objects):
    vg = obj.vertex_groups.new(name=BONE_OF[obj.name])
    vg.add(range(len(obj.data.vertices)), 1.0, 'REPLACE')
merged = []
for mat_name, (mesh_name, _) in MESHES.items():
    parts = [o for o in col.objects if o.type == 'MESH' and o.data.materials[0].name == mat_name]
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = mesh_name
    merged.append(obj)

# --- armature
arm_data = bpy.data.armatures.new('ChickRig')
rig = bpy.data.objects.new('ChickRig', arm_data)
col.objects.link(rig)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name, (head, tail, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail, b.roll = head, tail, 0
    if parent:
        b.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for obj in merged:
    obj.parent = rig
    obj.modifiers.new('Armature', 'ARMATURE').object = rig

# --- Animations at 60 fps; last frame == first frame so loops are seamless
scene = bpy.context.scene
scene.render.fps = 60
rig.animation_data_create()
pose = rig.pose.bones
for pb in pose:
    pb.rotation_mode = 'XYZ'
rad = math.radians


def walk(t):  # 2 steps per second
    s, bob = math.sin(t), abs(math.sin(t))
    # Bone-local axes: X swings forward/back for vertical bones, Y is along the bone.
    pose['LegL'].rotation_euler = (rad(18) * s, 0, 0)
    pose['LegR'].rotation_euler = (-rad(18) * s, 0, 0)
    pose['Body'].location = (0, .05 * bob, 0)  # local Y = up for Body: hop on each step
    pose['Body'].rotation_euler = (rad(1.5) * bob, 0, rad(2) * s)
    pose['Head'].rotation_euler = (-rad(2.5) * math.sin(2 * t), 0, -rad(1.5) * s)
    # positive Z on WingL / negative on WingR swings the wing tips away from the body
    pose['WingL'].rotation_euler = (0, 0, rad(14) * bob)
    pose['WingR'].rotation_euler = (0, 0, -rad(14) * bob)
    pose['Tail'].rotation_euler = (0, 0, rad(10) * s)


def idle(t):  # slow breathing, a look to the side, small wing ruffle
    breath = (1 - math.cos(t * 2)) / 2
    pose['LegL'].rotation_euler = pose['LegR'].rotation_euler = (0, 0, 0)
    pose['Body'].location = (0, .03 * breath, 0)
    pose['Body'].rotation_euler = (rad(1) * breath, 0, 0)
    pose['Head'].rotation_euler = (rad(2) * math.sin(t * 2), rad(6) * math.sin(t), 0)
    flap = rad(5) * max(0, math.sin(t * 4)) ** 2
    pose['WingL'].rotation_euler = (0, 0, rad(2) * breath + flap)
    pose['WingR'].rotation_euler = (0, 0, -rad(2) * breath - flap)
    pose['Tail'].rotation_euler = (0, 0, rad(6) * math.sin(t * 2))


ANIMS = {'Walk': (60, walk, 'chick-v02.fbx'), 'Idle': (120, idle, 'chick-v02-idle.fbx')}
for name, (frames, fn) in ((k, v[:2]) for k, v in ANIMS.items()):
    if name in bpy.data.actions:  # rebuild from scratch on re-run
        bpy.data.actions.remove(bpy.data.actions[name])
    action = bpy.data.actions.new(name)
    action.use_fake_user = True  # keep both actions in the .blend
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, frames
    rig.animation_data.action = action
    for f in range(frames + 1):
        fn(f / frames * 2 * math.pi)
        for pb in pose:
            if pb.name != 'Root':
                pb.keyframe_insert('rotation_euler', frame=f)
        pose['Body'].keyframe_insert('location', frame=f)

# --- FBX for Roblox: chick-v02.fbx = model + Walk (3D Importer), each file = one
# animation for Animation Editor > Import From FBX Animation. FBX bakes the scene range.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in rig.children:
    obj.select_set(True)
for name, (frames, _, file_name) in ANIMS.items():
    rig.animation_data.action = bpy.data.actions[name]
    scene.frame_start, scene.frame_end = 0, frames
    bpy.ops.export_scene.fbx(
        filepath=str(PETS / 'exports' / file_name), use_selection=True,
        object_types={'ARMATURE', 'MESH'}, global_scale=1.0, apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z', axis_up='Y',
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X',
        use_armature_deform_only=False, bake_anim=True, bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
        bake_anim_simplify_factor=0, path_mode='COPY', embed_textures=True)
rig.animation_data.action = bpy.data.actions['Walk']
scene.frame_start, scene.frame_end = 0, 60
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(PETS / 'models/chick-v02.blend'), compress=True)
result = {'bones': list(BONES), 'actions': list(ANIMS)}
