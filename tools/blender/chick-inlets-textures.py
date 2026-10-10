"""Bake one tinted inlets texture per chick colour (Roblox MeshPart holds one texture)."""
from pathlib import Path
from PIL import Image

HD = Path(r'C:\Users\dakem\Documents\RobloxGames\Assets\Textures\HDStuds')
SRC = HD / 'Inlets 2x2 AO Diffuse.png'
OUT = Path(__file__).resolve().parents[2] / 'assets/pets/textures'
COLORS = {'white': 'F4F1F8', 'orange': 'FFA31A', 'red': 'E5194D', 'black': '15141A', 'shine': 'FFFFFF'}
STRENGTH = 0.35  # < 1 fades inlets toward a flat surface (shading and normal relief)

ao = Image.open(SRC).convert('RGBA')
flat = Image.new('RGBA', ao.size, (255, 255, 255, 255))
flat.alpha_composite(ao)  # inlet shading over white, same as the Blender preview material
gray = Image.blend(Image.new('RGB', ao.size, (255, 255, 255)), flat.convert('RGB'), STRENGTH)
normal = Image.open(HD / 'Inlets 2x2 Normal.png').convert('RGB')
Image.blend(Image.new('RGB', normal.size, (128, 128, 255)), normal, STRENGTH).save(OUT / 'inlets-2x2-normal.png')
for name, hex_ in COLORS.items():
    tint = tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4))
    bands = [b.point(lambda v, t=t: v * t // 255) for b, t in zip(gray.split(), tint)]
    Image.merge('RGB', bands).save(OUT / f'chick-{name}-inlets-v01.png')
    print(name)
