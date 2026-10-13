"""Build the egg pack next to EggDefault in assets/items/eggs/default/models/egg-default.blend.

Run inside Blender with that file open. Every egg reuses the EggDefault voxel shape and stud UVs;
re-running replaces the Egg0N_* objects and their materials.

Row 1 (y = 0) is the forest pack, row 2 (y = 2 * SPACING) the desert pack.
Shells keep the template symmetry (mirror X, mirror Y, 90 degree turn): colour patterns are computed
on folded voxel coordinates; decor is drawn once on the front side and mirrored / turned 4 x 90 degrees.
Exceptions placed once: the cobra (Pharaoh), the tail (Scorpion) and the floating sand ring (Sandstorm).
Decor is made of half-size cubes on a grid aligned with the egg grid, never rotated.
"""
import bpy, bmesh, math
from mathutils import Vector, noise

# EggDefault shape (see assets/items/eggs/default/README.md)
S = 0.155
RW, RH, TAPER, TH = 0.96, 1.17, 0.16, 0.95
N = 12
K = 1.6  # one stud spans K cubes
TILE = 4 * K * S  # studtexture holds 4x4 studs
SPACING = 3.0
DIRS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
AX = (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
UP = Vector((0, 0, 1))


def egg_voxels(rw=RW, rh=RH):
    out = set()
    for i in range(-N, N):
        for j in range(-N, N):
            for l in range(-N, N + 1):
                z = l * S / rh
                if abs(z) > 1:
                    continue
                r = math.hypot((i + 0.5) * S, (j + 0.5) * S) / (rw * (1 - TAPER * z))
                if r * r + z * z <= TH:
                    out.add((i, j, l))
    return out


BASE = egg_voxels()
LMIN = min(v[2] for v in BASE)
LAYERS = max(v[2] for v in BASE) - LMIN + 1
HEIGHT = LAYERS * S


def center(v):
    return Vector(((v[0] + 0.5) * S, (v[1] + 0.5) * S, (v[2] - LMIN + 0.5) * S))


def tfrac(v):
    """Height of voxel v as 0..1 of the egg."""
    return (v[2] - LMIN + 0.5) / LAYERS


def layer(zfrac):
    return LMIN + min(LAYERS - 1, int(zfrac * LAYERS))


def fold(i):
    return i if i >= 0 else -1 - i


def canon(v):
    """Voxel coordinates folded by the egg symmetry group: equal for all mirrored/rotated copies."""
    a, b = fold(v[0]), fold(v[1])
    return max(a, b), min(a, b), v[2]


def checker(v):
    a, b, l = canon(v)
    return (a + b + l) % 2


def sym_noise(v, scale, seed):
    a, b, l = canon(v)
    return noise.noise(Vector((a, b, l)) * scale + Vector((seed * 3.1, seed * 1.7, seed * 2.3)))


def exposed(vox, v):
    return [d for d in DIRS if (v[0] + d[0], v[1] + d[1], v[2] + d[2]) not in vox]


IMG = next(i for i in bpy.data.images if "studtexture" in i.filepath)


def material(name, rgb, studs=True, emit=0.0):
    """rgb is linear. Stud materials: studtexture over white, multiplied by rgb (same as EggStud)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bs.inputs["Roughness"].default_value = 0.8
    col = (*rgb, 1)
    if studs:
        tx = nt.nodes.new("ShaderNodeTexImage")
        tx.image = IMG
        tx.interpolation = "Linear"
        ov = nt.nodes.new("ShaderNodeMix")
        ov.data_type = "RGBA"
        ov.inputs[6].default_value = (1, 1, 1, 1)
        nt.links.new(tx.outputs["Alpha"], ov.inputs[0])
        nt.links.new(tx.outputs["Color"], ov.inputs[7])
        mx = nt.nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = "MULTIPLY"
        mx.inputs[0].default_value = 1
        mx.inputs[6].default_value = col
        nt.links.new(ov.outputs[2], mx.inputs[7])
        nt.links.new(mx.outputs[2], bs.inputs["Base Color"])
    else:
        bs.inputs["Base Color"].default_value = col
    if emit:
        bs.inputs["Emission Color"].default_value = col
        bs.inputs["Emission Strength"].default_value = emit
    nt.links.new(bs.outputs[0], out.inputs[0])
    m.diffuse_color = col
    return m


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def box(self, c, axes, half, m, skip=()):
        X, Y, Z = [a * h for a, h in zip(axes, half)]
        # (normal, tangent, bitangent) per face, right-handed so quads face outward
        faces = {
            (1, 0, 0): (X, Y, Z), (-1, 0, 0): (-X, -Y, Z), (0, 1, 0): (Y, -X, Z),
            (0, -1, 0): (-Y, X, Z), (0, 0, 1): (Z, X, Y), (0, 0, -1): (-Z, -X, Y),
        }
        if m not in self.mats:
            self.mats.append(m)
        for d, (n, t, b) in faces.items():
            if d in skip:
                continue
            pts = [c + n - t - b, c + n + t - b, c + n + t + b, c + n - t + b]
            f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
            f.material_index = self.mats.index(m)
            f.normal_update()
            ax = max(range(3), key=lambda k: abs(f.normal[k]))
            a, bb = [(1, 2), (0, 2), (0, 1)][ax]
            for lp in f.loops:
                lp[self.uv].uv = (lp.vert.co[a] / TILE, lp.vert.co[bb] / TILE)

    def shell(self, vox, pick):
        for v in vox:
            dirs = exposed(vox, v)
            if dirs:
                skip = [d for d in DIRS if d not in dirs]
                self.box(center(v), AX, (S / 2,) * 3, pick(v), skip)

    def finish(self, name, x):
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old)
        if name in bpy.data.meshes:
            bpy.data.meshes.remove(bpy.data.meshes[name])
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = (x, 0, 0)
        return ob


# ---------------------------------------------------------------- decor on a half-size voxel grid

F = S / 2  # decor cube size; the fine grid is aligned with the egg grid, z = 0 at the egg bottom


def fl(zfrac):
    """Fine layer index for a height fraction, snapped to the bottom of an egg layer."""
    return 2 * (layer(zfrac) - LMIN)


class Decor:
    """Decor cubes on the fine grid. Patterns are drawn on the front (-Y) side for u >= 0 and are
    mirrored (u -> -1-u) and turned 4 x 90 degrees, so the result keeps the egg symmetry.
    solo cells (a cobra, a tail) are placed once, without turning."""

    def __init__(self, vox):
        self.vox = vox
        self.cells = {}
        self.solo = {}
        self.front_j = {}
        for i, j, l in vox:
            k = (i, l)
            self.front_j[k] = min(j, self.front_j.get(k, j))

    def main(self, i, j, l):
        return (i // 2, j // 2, LMIN + l // 2) in self.vox

    def put(self, i, j, l, m, solo=False):
        if not self.main(i, j, l):
            (self.solo if solo else self.cells).setdefault((i, j, l), m)

    def surf(self, u, h):
        j = self.front_j.get((u // 2, LMIN + h // 2))
        return None if j is None else 2 * j

    def front(self, pattern, u0=0, h0=0, hug=False):
        """pattern: (u, out, h, material). hug=True follows the surface per column, else rigid at the anchor."""
        anchor = self.surf(u0, h0)
        for u, o, h, m in pattern:
            for uu in {u0 + u, -1 - (u0 + u)}:
                J = self.surf(uu, h0 + h) if hug else anchor
                if J is not None:
                    self.put(uu, J - 1 - o, h0 + h, m)

    def face(self, v, d, m):
        """Cover the exposed face d of egg voxel v with a 2x2 slab of decor cubes."""
        i0, j0, l0 = 2 * v[0], 2 * v[1], 2 * (v[2] - LMIN)
        rng = lambda base, dd: [base + (2 if dd > 0 else -1)] if dd else [base, base + 1]
        for i in rng(i0, d[0]):
            for j in rng(j0, d[1]):
                for l in rng(l0, d[2]):
                    self.put(i, j, l, m)

    def build(self, b):
        cells = {}
        for (i, j, l), m in self.cells.items():
            for _ in range(4):
                cells.setdefault((i, j, l), m)
                i, j = -1 - j, i
        for k, m in self.solo.items():
            cells.setdefault(k, m)
        for (i, j, l), m in cells.items():
            skip = [d for d in DIRS if (i + d[0], j + d[1], l + d[2]) in cells or self.main(i + d[0], j + d[1], l + d[2])]
            if len(skip) < 6:
                b.box(Vector(((i + 0.5) * F, (j + 0.5) * F, (l + 0.5) * F)), AX, (F / 2,) * 3, m, skip)


def row(us, o, h, m):
    return [(u, o, h, m) for u in us]


def frond(stem, a, bm, length=7, widths=(3, 3, 3, 2, 2, 1, 0)):
    """Pixel fern leaning out of the surface: stem plus shrinking leaflet rows in two greens."""
    out = []
    for k in range(length):
        o = k // 2
        out.append((0, o, k, stem))
        out += row(range(1, widths[k] + 1), o, k, a if k % 2 == 0 else bm)
    return out


def mini_mushroom(stem, cap, dot, big=True):
    if big:
        p = [(u, o, h, stem) for u in (-1, 0) for o in (0, 1) for h in range(4)]
        p += [(u, o, 4, cap) for u in range(-3, 3) for o in range(-2, 4)]
        p += [(u, o, 5, dot if (u in (-2, 1) and o in (-1, 2)) else cap) for u in range(-2, 2) for o in range(-1, 3)]
        p += [(u, o, 6, cap) for u in (-1, 0) for o in (0, 1)]
    else:
        p = [(u, 0, h, stem) for u in (-1, 0) for h in range(3)]
        p += [(u, o, 3, cap) for u in range(-2, 2) for o in range(-1, 3)]
        p += [(u, o, 4, dot) for u in (-1, 0) for o in (0, 1)]
    return p


def crystal_pat(m, tip, height=6):
    p = [(u, k // 2, k, m) for k in range(height) for u in (-1, 0)]
    p += [(u, height // 2, height + h, tip) for u in (-1, 0) for h in (0, 1)]
    return p


# ---------------------------------------------------------------- eggs


def moss(b):
    greens = [material("EggMoss_Green", (0.11, 0.36, 0.03)), material("EggMoss_GreenAlt", (0.14, 0.42, 0.04))]
    tops = [material("EggMoss_Light", (0.26, 0.6, 0.05)), material("EggMoss_LightAlt", (0.32, 0.68, 0.07))]
    dirts = [material("EggMoss_Dirt", (0.16, 0.075, 0.03)), material("EggMoss_DirtAlt", (0.21, 0.1, 0.04))]
    stone = material("EggMoss_Stone", (0.32, 0.34, 0.37))
    stone_top = material("EggMoss_StoneTop", (0.55, 0.57, 0.6))
    fern = material("EggMoss_Fern", (0.55, 0.85, 0.12))
    fern_dark = material("EggMoss_FernDark", (0.3, 0.6, 0.04))
    tuft = material("EggMoss_Tuft", (0.45, 0.8, 0.1))

    def pick(v):
        t, c = tfrac(v), checker(v)
        if t < 0.1 or t < 0.55 and sym_noise(v, 0.9, 1) < -0.32:
            return dirts[c]
        if t > 0.78 or sym_noise(v, 0.5, 2) > 0.3:
            return tops[c]
        return greens[c]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    dec.front(frond(fern_dark, fern, fern_dark), 0, fl(0.5))
    stone_p = [(u, o, h, stone) for u in (-1, 0, 1) for o in range(3) for h in range(3)]
    stone_p += [(u, o, 3, stone_top) for u in (-1, 0, 1) for o in range(3)]
    stone_p += [(u, o, 4, tuft) for u, o in ((0, 1), (1, 1))]
    dec.front(stone_p, 5, fl(0.26))
    for v in BASE:  # grass tufts on some upward steps
        a, bb, l = canon(v)
        if tfrac(v) > 0.3 and (0, 0, 1) in exposed(BASE, v) and (a * 5 + bb * 3 + l) % 6 == 0:
            dec.face(v, (0, 0, 1), tuft)
    dec.front(frond(fern_dark, fern, fern_dark, length=5, widths=(2, 2, 2, 1, 0)), 5, fl(0.68))
    dec.build(b)


def birch(b):
    whites = [material("EggBirch_White", (0.83, 0.8, 0.73)), material("EggBirch_WhiteAlt", (0.74, 0.71, 0.64))]
    dark = material("EggBirch_Stripe", (0.02, 0.02, 0.02))
    grey = material("EggBirch_Mark", (0.28, 0.27, 0.25))

    def pick(v):
        # bark stripes every second layer, centred on each side (gaps on the diagonals, so no paired "eyes"):
        # odd stripes are long black bands, even stripes are short black dashes with grey ends
        l = v[2] - LMIN
        if 0.05 < tfrac(v) < 0.86 and l % 2 == 1:
            a, bb, _ = canon(v)
            off = a - bb  # 0 on the diagonals, large in the middle of a side
            if (l // 2) % 2:
                if off >= 2:
                    return dark
            elif off >= 5:
                return dark
            elif off >= 3:
                return grey
        return whites[checker(v)]

    b.shell(BASE, pick)


def capped(cap_l, widen, lip=None):
    """BASE plus the part of a wider egg from layer cap_l up; lip = (layer count, widen) flares the cap edge."""
    vox = BASE | {v for v in egg_voxels(RW * widen, RH * 1.03) if v[2] >= cap_l}
    if lip:
        rows, lw = lip
        vox |= {v for v in egg_voxels(RW * lw, RH * 1.03) if cap_l <= v[2] < cap_l + rows}
    return vox


def mushroom(b):
    reds = [material("EggMushroom_Red", (0.66, 0.02, 0.02)), material("EggMushroom_RedAlt", (0.52, 0.012, 0.012))]
    rim = material("EggMushroom_Rim", (0.36, 0.01, 0.01))
    dot = material("EggMushroom_Dot", (0.92, 0.88, 0.76))
    stem = material("EggMushroom_Stem", (0.86, 0.8, 0.66))
    soils = [material("EggMushroom_Soil", (0.22, 0.1, 0.04)), material("EggMushroom_SoilAlt", (0.28, 0.14, 0.06))]
    grass = [material("EggMushroom_Moss", (0.16, 0.44, 0.04)), material("EggMushroom_MossAlt", (0.22, 0.52, 0.05))]
    cap_l = layer(0.55)
    vox = capped(cap_l, 1.14, lip=(1, 1.24))

    def is_dot(v):
        a, bb, l = canon(v)
        return (a * 3 + bb * 5 + l * 2) % 7 == 0

    def pick(v):
        c = checker(v)
        if v[2] == cap_l:
            return rim
        if v[2] > cap_l:
            return reds[c]
        drip = 2 + (1 if sym_noise(v, 0.6, 5) > 0 else 0)
        if v[2] >= cap_l - drip:
            return grass[c]
        return soils[c]

    b.shell(vox, pick)
    dec = Decor(vox)
    for v in vox:  # raised spots on the cap
        if v[2] > cap_l and is_dot(v):
            for d in exposed(vox, v):
                if d[2] >= 0:
                    dec.face(v, d, dot)
    dec.front(mini_mushroom(stem, reds[0], dot), 0, fl(0.24))
    dec.front(mini_mushroom(stem, reds[0], dot, big=False), 5, fl(0.1))
    dec.build(b)


def acorn(b):
    shells = [material("EggAcorn_Shell", (0.74, 0.4, 0.07)), material("EggAcorn_ShellAlt", (0.63, 0.31, 0.05))]
    shell_light = material("EggAcorn_ShellLight", (0.88, 0.55, 0.12))
    tip = material("EggAcorn_Tip", (0.3, 0.14, 0.04))
    caps = [material("EggAcorn_Cap", (0.26, 0.12, 0.045)), material("EggAcorn_CapAlt", (0.18, 0.08, 0.03))]
    lip = material("EggAcorn_CapRim", (0.12, 0.055, 0.02))
    cap_l = layer(0.5)
    vox = capped(cap_l, 1.1, lip=(2, 1.2))

    def pick(v):
        c, t = checker(v), tfrac(v)
        if cap_l <= v[2] < cap_l + 2:
            # the two flared rows form a dark, clearly separated rim
            return lip if (v[2] == cap_l or c) else caps[1]
        if v[2] >= cap_l + 2:
            return caps[c]
        if t < 0.08:
            return tip
        if 0.3 < t < 0.42 and c:
            return shell_light
        return shells[c]

    b.shell(vox, pick)
    dec = Decor(vox)
    for v in vox:  # scale bumps on the cap
        a, bb, l = canon(v)
        if v[2] >= cap_l + 2 and (a + bb + l) % 3 == 0:
            for d in exposed(vox, v):
                if d[2] == 0:
                    dec.face(v, d, caps[1])
    dec.build(b)


def enchanted(b):
    emeralds = [material("EggEnchanted_Emerald", (0.006, 0.06, 0.04)),
                material("EggEnchanted_EmeraldAlt", (0.012, 0.09, 0.055))]
    mosses = [material("EggEnchanted_Moss", (0.05, 0.2, 0.02)), material("EggEnchanted_MossAlt", (0.08, 0.27, 0.03))]
    rune = material("EggEnchanted_Rune", (0.5, 0.05, 1.0), studs=False, emit=6.0)
    crystal = material("EggEnchanted_Crystal", (0.03, 0.55, 1.0), studs=False, emit=1.2)
    crystal_l = material("EggEnchanted_CrystalLight", (0.35, 0.9, 1.0), studs=False, emit=1.5)

    def pick(v):
        a, bb, _ = canon(v)
        drip = 0.9 - 0.12 * ((a * 7 + bb * 13) % 5)  # column hash: drips of 0..4 steps
        return mosses[checker(v)] if tfrac(v) > drip else emeralds[checker(v)]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    ring = row(range(0, 3), 0, 0, rune) + row(range(0, 3), 0, 5, rune) + [(2, 0, h, rune) for h in range(1, 5)]
    ring += [(0, 0, h, rune) for h in (2, 3)]
    dec.front(ring, 0, fl(0.36), hug=True)
    dec.front([(u, 0, h, rune) for u in (-1, 0) for h in (0, 1)], 6, fl(0.62), hug=True)
    dec.front(crystal_pat(crystal, crystal_l), 5, fl(0.2))
    dec.front(crystal_pat(crystal, crystal_l, height=4), 8, fl(0.16))
    dec.front(crystal_pat(crystal, crystal_l, height=4), 3, fl(0.6))
    dec.front(crystal_pat(crystal, crystal_l, height=2), 7, fl(0.72))
    dec.build(b)


def crown(vox):
    """Fine layer right above the centre column of vox (the egg top)."""
    return 2 * (max(l for i, j, l in vox if (i, j) == (0, 0)) - LMIN + 1)


def lateral(v):
    """0..5: position around a side, from the side centre (0) to the diagonal (5)."""
    a, bb, _ = canon(v)
    return min(5, int(math.atan2(bb + 0.5, a + 0.5) / (math.pi / 4) * 6))


def rings(dec, vox, layers, m):
    """Raised band: a slab on every side face of the given egg layers."""
    for v in vox:
        if v[2] in layers:
            for d in exposed(vox, v):
                if d[2] == 0:
                    dec.face(v, d, m)


def cactus(b):
    greens = [material("EggCactus_Green", (0.12, 0.36, 0.03)), material("EggCactus_GreenAlt", (0.1, 0.31, 0.025))]
    ribs = [material("EggCactus_Rib", (0.22, 0.52, 0.05)), material("EggCactus_RibAlt", (0.19, 0.47, 0.04))]
    groove = material("EggCactus_Groove", (0.035, 0.15, 0.012))
    spine = material("EggCactus_Spine", (0.85, 0.72, 0.45))
    spine_tip = material("EggCactus_SpineTip", (1.0, 0.92, 0.72))
    pinks = [material("EggCactus_Petal", (1.0, 0.1, 0.36)), material("EggCactus_PetalLight", (1.0, 0.24, 0.52))]
    pollen = material("EggCactus_Pollen", (1.0, 0.72, 0.05))

    def pick(v):
        # main columns under the raised ribs stay green, columns between them are dark grooves
        return greens[checker(v)] if canon(v)[1] % 2 == 0 else groove

    b.shell(BASE, pick)
    dec = Decor(BASE)
    top = LAYERS * 2
    for u0, us, spikes in ((0, (0,), (0.22, 0.5, 0.76)), (4, (0, 1), (0.12, 0.36, 0.63)), (8, (0, 1), (0.25, 0.5))):
        dec.front([(u, 0, h, ribs[(h // 2) % 2]) for u in us for h in range(1, top - 3)], u0, 0, hug=True)
        for t in spikes:
            spike = [(u, 1, h, spine) for u in us for h in (0, 1)] + [(u, 2, 0, spine_tip) for u in us]
            dec.front(spike, u0, fl(t), hug=True)
    # flower on the crown: petal disk, raised light petals, pollen centre
    h = crown(BASE)
    for i in range(-6, 6):
        for j in range(-6, 6):
            r2 = (i + 0.5) ** 2 + (j + 0.5) ** 2
            petal = min(abs(i + 0.5), abs(j + 0.5)) < 1  # four petals along the axes, cupped upward
            if r2 <= 8.5 or petal and r2 <= 26:
                dec.put(i, j, h, pinks[0])
            if petal and 6 < r2 <= 26:
                dec.put(i, j, h + 1, pinks[1])
            if petal and 18 < r2 <= 26:
                dec.put(i, j, h + 2, pinks[1])
            if r2 <= 4.5:
                dec.put(i, j, h + 1, pinks[1] if r2 > 1 else pollen)
            if r2 <= 1:
                dec.put(i, j, h + 2, pollen)
    dec.build(b)


ANKH = [(0, 6), (1, 5), (1, 4), (0, 3), (0, 2), (1, 2), (2, 2), (0, 1), (0, 0)]  # (u, h), u >= 0 half
EYE = [(u, 5) for u in range(6)] + [(u, 3) for u in range(1, 5)] + [(0, 2), (5, 2)]
EYE += [(u, 1) for u in range(1, 5)] + [(2, 0), (4, 0), (5, 0)]


def pharaoh(b):
    golds = [material("EggPharaoh_Gold", (0.85, 0.5, 0.03)), material("EggPharaoh_GoldAlt", (0.72, 0.4, 0.02))]
    tile = material("EggPharaoh_Tile", (1.0, 0.72, 0.2))
    glyph = material("EggPharaoh_Glyph", (0.3, 0.13, 0.01))
    lapis = [material("EggPharaoh_Lapis", (0.02, 0.06, 0.5)), material("EggPharaoh_LapisAlt", (0.015, 0.035, 0.36))]
    turq = material("EggPharaoh_Turquoise", (0.03, 0.62, 0.55))
    ring_l = {LMIN + 4, LMIN + 9, LMIN + 11}
    tile_l = range(LMIN + 5, LMIN + 9)
    inlay_l = {LMIN + 2, LMIN + 10}

    def pick(v):
        c, l = checker(v), v[2]
        if l in ring_l:
            return lapis[c]
        if l in tile_l:
            return tile
        if l in inlay_l and canon(v)[1] % 3 == 1:
            return turq
        return golds[c]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    rings(dec, BASE, ring_l, lapis[0])
    h0 = 2 * 5 + 1  # glyphs centred in the tile band
    dec.front([(u, 0, h, glyph) for u, h in ANKH], 0, h0, hug=True)
    dec.front([(u, 0, h, turq if h == 3 and u in (2, 3) else glyph) for u, h in EYE], 4, h0, hug=True)
    # cobra on the crown, facing front (-Y): coil, thick neck, wide striped hood, head with turquoise eyes
    h = crown(BASE)

    def cob(i, j, dz, m):
        dec.put(i, j, h + dz, m, solo=True)

    for i in (-2, 1):  # eyes first: put keeps the first material of a cell
        cob(i, -4, 10, turq)
    for i in range(-4, 4):
        for j in range(-4, 4):
            r2 = (i + 0.5) ** 2 + (j + 0.5) ** 2
            if 3 <= r2 <= 12.5:
                cob(i, j, 0, golds[(i + j) % 2])
    for dz in range(1, 9):
        for i in range(-2, 2):
            for j in range(0, 3):
                cob(i, j, dz, golds[dz % 2])
    for dz, w in {3: 3, 4: 4, 5: 5, 6: 5, 7: 5, 8: 5, 9: 4, 10: 3}.items():
        for i in range(-w, w):
            cob(i, 3, dz, golds[0])
            if abs(i + 0.5) > 2:
                cob(i, 2, dz, lapis[0] if dz % 2 else golds[1])
    for dz in (9, 10, 11):
        for i in range(-2, 2):
            for j in range(-4, 2):
                if not (dz == 11 and j == -4):
                    cob(i, j, dz, golds[0] if dz < 11 else golds[1])
    dec.build(b)


def snap(x, g):
    return (math.floor(x / g) + 0.5) * g


def sandstorm(b):
    sands = [material("EggSandstorm_Sand", (0.72, 0.47, 0.19)), material("EggSandstorm_SandAlt", (0.62, 0.39, 0.15))]
    clays = [material("EggSandstorm_Clay", (0.42, 0.17, 0.06)), material("EggSandstorm_ClayAlt", (0.34, 0.13, 0.05))]
    grain = material("EggSandstorm_Grain", (0.95, 0.78, 0.48))
    crack = material("EggSandstorm_Crack", (1.0, 0.3, 0.0), studs=False, emit=0.6)

    def pick(v):
        c = checker(v)
        return clays[c] if sym_noise(v, 0.45, 7) > 0.22 else sands[c]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    # thin glowing cracks: zigzag lines (fine height per fine step from the side centre), stair-connected
    for t, path in ((0.2, (0, 1, 2, 3, 3, 2, 1, 1, 2, 3, 4, 4)), (0.48, (3, 2, 1, 1, 0, 0, 1, 2, 3, 3, 2, 1)),
                    (0.72, (0, 0, 1, 2, 3, 3, 2, 1, 0, 0, 1, 2))):
        line = [(u, 0, hh, crack) for u, hh in enumerate(path)]
        line += [(u, 0, path[u - 1], crack) for u in range(1, len(path)) if abs(path[u] - path[u - 1]) > 0]
        dec.front(line, 0, fl(t), hug=True)
    for v in BASE:  # loose sand blocks sticking out
        a, bb, l = canon(v)
        if (a * 7 + bb * 3 + l * 5) % 8 == 0:
            for d in exposed(BASE, v):
                if d[2] == 0:
                    dec.face(v, d, grain if checker(v) else clays[0])
    dec.build(b)
    # whirling ring of floating sand cubes: tilted, so it is placed once (not turned)
    n = 44
    for k in range(n):
        a = 2 * math.pi * k / n
        g = F if k % 2 else S
        x, y, z = 1.3 * math.cos(a), 1.3 * math.sin(a), 1.15 + 0.55 * math.sin(a - 0.7)
        b.box(Vector((snap(x, g), snap(y, g), snap(z, g))), AX, (g / 2,) * 3, grain)


def scorpion(b):
    rusts = [material("EggScorpion_Rust", (0.42, 0.1, 0.025)), material("EggScorpion_RustAlt", (0.34, 0.075, 0.02))]
    darks = [material("EggScorpion_Dark", (0.13, 0.045, 0.02)), material("EggScorpion_DarkAlt", (0.17, 0.06, 0.025))]
    plate = material("EggScorpion_Plate", (0.62, 0.25, 0.06))
    sting = material("EggScorpion_Sting", (0.95, 0.45, 0.02))

    def is_plate(v):
        a, bb, l = canon(v)
        return (a * 5 + bb * 3 + l) % 7 == 0

    def pick(v):
        c = checker(v)
        if (v[2] - LMIN) % 3 == 2 or sym_noise(v, 0.5, 9) > 0.3:  # dark segment seams and patches
            return darks[c]
        return plate if is_plate(v) else rusts[c]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    for v in BASE:  # raised shell plates
        if is_plate(v):
            for d in exposed(BASE, v):
                if d[2] == 0:
                    dec.face(v, d, plate)
    # legs: arch out from the body and hook down to a golden tip
    path = ((0, 0), (0, 1), (1, 1), (1, 2), (2, 2), (2, 3), (3, 3), (3, 4), (4, 4), (5, 4), (6, 4), (6, 3), (7, 3),
            (7, 2), (7, 1))
    leg = [(u, o, h, darks[0] if k in (4, 9) else rusts[0]) for u in (0, 1) for k, (o, h) in enumerate(path)]
    leg += [(u, o, h, sting) for u in (0, 1) for o, h in ((7, 0), (7, -1), (6, -2))]
    dec.front(leg, 7, fl(0.28))
    # tail: chunky segments from the left shoulder over the top, curling down to the stinger on the right
    h = crown(BASE)
    segs = ((-7, -6, 2), (-7, -2, 2), (-6, 2, 2), (-4, 5, 2), (-1, 7, 2), (2, 8, 2), (5, 7, 2), (8, 5, 2), (9, 1, 2))
    for k, (ci, dz, r) in enumerate(segs):
        for i in range(ci - r, ci + r):
            for l in range(h + dz - r, h + dz + r):
                for j in range(-r, r):
                    dec.put(i, j, l, plate if k == len(segs) - 1 else rusts[0] if k % 2 else darks[1], solo=True)
    # stinger: wide golden base under the bulb, narrowing to a hooked tip
    for l, i0, i1, r in ((h - 2, 7, 11, 2), (h - 3, 7, 11, 2), (h - 4, 7, 10, 1), (h - 5, 7, 9, 1), (h - 6, 7, 8, 1)):
        for i in range(i0, i1):
            for j in range(-r, r):
                dec.put(i, j, l, sting, solo=True)
    dec.put(6, -1, h - 7, sting, solo=True)
    dec.put(6, 0, h - 7, sting, solo=True)
    dec.build(b)


def oasis(b):
    sands = [material("EggOasis_Sand", (0.82, 0.62, 0.3)), material("EggOasis_SandAlt", (0.72, 0.52, 0.23))]
    waters = [material("EggOasis_Water", (0.03, 0.5, 0.78)), material("EggOasis_WaterLight", (0.12, 0.72, 0.9))]
    grass = [material("EggOasis_Grass", (0.15, 0.5, 0.03)), material("EggOasis_GrassAlt", (0.22, 0.6, 0.04))]
    trunk = [material("EggOasis_Trunk", (0.3, 0.13, 0.04)), material("EggOasis_TrunkAlt", (0.42, 0.21, 0.07))]
    frond = [material("EggOasis_Frond", (0.2, 0.55, 0.03)), material("EggOasis_FrondDark", (0.08, 0.32, 0.02))]
    crystal = material("EggOasis_Crystal", (0.02, 0.3, 1.0), studs=False, emit=0.4)
    crystal_l = material("EggOasis_CrystalLight", (0.25, 0.7, 1.0), studs=False, emit=0.5)

    def edge(v):
        a, bb, _ = canon(v)
        return 0.62 - 0.1 * ((a * 7 + bb * 13) % 4)  # water spills down some columns

    def pick(v):
        c, t = checker(v), tfrac(v)
        if t > edge(v):
            return waters[c]
        if t > edge(v) - 0.08:
            return grass[c]
        return sands[c]

    b.shell(BASE, pick)
    dec = Decor(BASE)
    for v in BASE:  # moss hanging on the water edge
        a, bb, l = canon(v)
        if pick(v) in grass and (a + bb) % 2 == 0:
            for d in exposed(BASE, v):
                if d[2] == 0:
                    dec.face(v, d, grass[1])
    dec.front(crystal_pat(crystal, crystal_l), 9, fl(0.22))
    dec.front(crystal_pat(crystal, crystal_l, height=4), 6, fl(0.12))
    # palm on the crown: round trunk, coconuts and eight drooping fronds (each frond is turned 4 x 90 degrees)
    h = crown(BASE)
    tl = h + 9
    for l in range(h, tl):
        for i in range(-2, 2):
            for j in range(-2, 2):
                if (i + 0.5) ** 2 + (j + 0.5) ** 2 <= 2.5:
                    dec.put(i, j, l, trunk[(l // 2) % 2])
    for j in (-1, 0):
        dec.put(2, j, tl - 2, trunk[0])
    for i in range(-2, 2):
        for j in range(-2, 2):
            dec.put(i, j, tl, frond[0])
    for i in (-1, 0):
        for j in (-1, 0):
            dec.put(i, j, tl + 1, frond[0])
    droop = (1, 1, 1, 1, 0, 0, -1, -1, -2, -3, -4)
    for d, dl in enumerate(droop):
        for j in (-1, 0):
            dec.put(d, j, tl + dl, frond[0])
        if 2 <= d <= 8:
            for j in (-2, 1):
                dec.put(d, j, tl + dl - 1 + d % 2, frond[1])
    for d, dl in enumerate(droop[:8]):
        dec.put(d, d, tl + dl, frond[0])
        dec.put(d + 1, d, tl + dl - 1, frond[1])
        dec.put(d, d + 1, tl + dl - 1, frond[1])
    dec.build(b)


EGGS = [
    ("Egg01_Moss", moss),
    ("Egg02_Birch", birch),
    ("Egg03_Mushroom", mushroom),
    ("Egg04_Acorn", acorn),
    ("Egg05_Enchanted", enchanted),
]
EGGS_ROW2 = [  # desert pack
    ("Egg06_Cactus", cactus),
    ("Egg07_Pharaoh", pharaoh),
    ("Egg08_Sandstorm", sandstorm),
    ("Egg09_Scorpion", scorpion),
    ("Egg10_Oasis", oasis),
]

for y, eggs in ((0, EGGS), (2 * SPACING, EGGS_ROW2)):
    for k, (name, build) in enumerate(eggs, 1):
        b = Builder()
        build(b)
        b.finish(name, k * SPACING).location.y = y
