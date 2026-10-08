"""Audit and refresh an existing single model after a targeted repair."""
import ast
import json
import bpy
from pathlib import Path
ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK=ROOT/'assets/items/pickaxes/pack'
tree=ast.parse((ROOT/'tools/blender/audit-pickaxe-attachments.py').read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.FunctionDef))],type_ignores=[]),'audit','exec'))
collection=bpy.data.collections[COLLECTION_NAME]
key=next(o['asset_key'] for o in collection.objects if o.type=='EMPTY')
report=audit_collection(collection)
(PACK/('previews/%s-attachment-audit-v01.json'%key.lower())).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
scene=bpy.context.scene
camera=scene.camera;res=(scene.render.resolution_x,scene.render.resolution_y);path=scene.render.filepath
hidden=[(c,c.hide_render) for c in scene.collection.children if c.name not in (COLLECTION_NAME,'Review_Studio_Do_Not_Export')]
try:
    for c,old in hidden:c.hide_render=True
    scene.camera=bpy.data.objects[key+'_Detail_Camera']
    scene.render.resolution_x=1100;scene.render.resolution_y=1100
    scene.render.filepath=str(PACK/('previews/%s-detail-review-v01.png'%key.lower()))
    bpy.ops.render.render(write_still=True)
finally:
    for c,old in hidden:c.hide_render=old
    scene.camera=camera
    scene.render.resolution_x,scene.render.resolution_y=res
    scene.render.filepath=path
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
result={'audit':report,'file':bpy.data.filepath}
