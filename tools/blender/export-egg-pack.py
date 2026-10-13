"""Export the egg pack for Roblox Studio import.

Run inside Blender with assets/items/eggs/default/models/egg-default.blend open (after build-egg-pack.py).
Works on copies in a temporary scene and never saves the source file; revert it afterwards.
Save the source before running: bpy.data.is_dirty misses edits made from Python, and the revert drops an
unsaved build-egg-pack.py result.

Each egg becomes one mesh with one material and one UV set; colour and studs are baked into a PNG.
Output: assets/items/eggs/pack/exports/roblox-import-v02/ (v01 = forest pack only, already imported).
"""
import bpy, json, math, hashlib
from pathlib import Path

ROOT = Path(bpy.data.filepath).resolve().parents[5]
VERSION = "v02"
OUT = ROOT / ("assets/items/eggs/pack/exports/roblox-import-" + VERSION)
EGGS = [  # source object, Roblox name
    ("EggDefault", "DefaultEgg"),
    ("Egg01_Moss", "MossEgg"),
    ("Egg02_Birch", "BirchEgg"),
    ("Egg03_Mushroom", "MushroomEgg"),
    ("Egg04_Acorn", "AcornEgg"),
    ("Egg05_Enchanted", "EnchantedEgg"),
    ("Egg06_Cactus", "CactusEgg"),
    ("Egg07_Pharaoh", "PharaohEgg"),
    ("Egg08_Sandstorm", "SandstormEgg"),
    ("Egg09_Scorpion", "ScorpionEgg"),
    ("Egg10_Oasis", "OasisEgg"),
]
RES = 2048
FBX = dict(object_types={"MESH"}, axis_forward="Z", axis_up="Y", global_scale=1, apply_unit_scale=False,
           apply_scale_options="FBX_SCALE_UNITS", bake_space_transform=True, bake_anim=False,
           path_mode="COPY", embed_textures=True)

for d in ("models", "textures"):
    (OUT / d).mkdir(parents=True, exist_ok=True)

scene = bpy.data.scenes.new("Egg_Pack_Export")
bpy.context.window.scene = scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1


def select_only(ob):
    for o in scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


exported = []
for src_name, name in EGGS:
    src = bpy.data.objects[src_name]
    me = src.data.copy()
    me.name = name
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.location = src.location
    select_only(ob)

    # second UV set for the bake; the studs keep reading the original "UVMap"
    bake_uv = me.uv_layers.new(name="BakeUV")
    me.uv_layers.active = bake_uv
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    img = bpy.data.images.new(name + "_Color", RES, RES, alpha=False)
    temp_mats = []
    for i, m in enumerate(me.materials):
        mc = m.copy()
        temp_mats.append(mc)
        me.materials[i] = mc
        nt = mc.node_tree
        for tx in [n for n in nt.nodes if n.type == "TEX_IMAGE"]:
            uvn = nt.nodes.new("ShaderNodeUVMap")
            uvn.uv_map = "UVMap"
            nt.links.new(uvn.outputs[0], tx.inputs["Vector"])
        target = nt.nodes.new("ShaderNodeTexImage")
        target.image = img
        for n in nt.nodes:
            n.select = False
        target.select = True
        nt.nodes.active = target
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=16, margin_type="EXTEND", use_clear=True)
    img.filepath_raw = str(OUT / "textures" / (name + "_Color.png"))
    img.file_format = "PNG"
    img.save()

    # one baked material, one UV set
    mat = bpy.data.materials.new(name + "_Mat")
    mat.use_nodes = True
    bs = mat.node_tree.nodes["Principled BSDF"]
    tx = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tx.image = img
    mat.node_tree.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = 0.8
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    me.uv_layers.remove(me.uv_layers["UVMap"])
    me.uv_layers["BakeUV"].name = "UVMap"
    for mc in temp_mats:
        bpy.data.materials.remove(mc)

    # single-egg FBX with the pivot (bottom centre) at the origin
    pack_loc = ob.location.copy()
    ob.location = (0, 0, 0)
    select_only(ob)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "models" / (name + ".fbx")), use_selection=True, **FBX)
    ob.location = pack_loc
    lo = [min(v.co[k] for v in me.vertices) for k in range(3)]
    hi = [max(v.co[k] for v in me.vertices) for k in range(3)]
    exported.append(dict(
        name=name, source=src_name, fbx="models/" + name + ".fbx", texture="textures/" + name + "_Color.png",
        triangles=sum(len(p.vertices) - 2 for p in me.polygons), vertices=len(me.vertices),
        materialCount=1, uvSets=1, pivot="bottom centre",
        sizeStuds=[round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)],
        packOffsetStuds=[round(pack_loc.x, 3), 0, round(-pack_loc.y, 3)], importedToRoblox=False))

for o in scene.objects:
    o.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT / "Eggs_Pack.fbx"), use_selection=True, **FBX)

manifest = dict(pack="Eggs_Pack", version=VERSION, fbx="Eggs_Pack.fbx", unit="1 Blender unit = 1 stud",
                textureSize=RES, models=exported)
(OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
sums = []
for f in sorted(p for p in OUT.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt"):
    sums.append(hashlib.sha256(f.read_bytes()).hexdigest() + "  " + f.relative_to(OUT).as_posix())
(OUT / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
result = manifest
