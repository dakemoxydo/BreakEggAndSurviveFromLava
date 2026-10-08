"""Turn the scene-only dependency library into a normally openable blend file."""
import bpy
from pathlib import Path

path=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava\assets\items\pickaxes\01-wooden\models\wooden-pickaxe-studs-v02.blend')
assert bpy.app.background
with bpy.data.libraries.load(str(path),link=False) as (source,target):
    assert 'Wooden_Pickaxe_v02' in source.scenes
    target.scenes=['Wooden_Pickaxe_v02']
scene=target.scenes[0]
bpy.context.window.scene=scene
for other in list(bpy.data.scenes):
    if other!=scene:
        bpy.data.scenes.remove(other)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
temporary=path.with_name(path.stem+'.standalone.blend')
bpy.ops.wm.save_as_mainfile(filepath=str(temporary),compress=True)
temporary.replace(path)
print('SAVED_STANDALONE '+scene.name)
