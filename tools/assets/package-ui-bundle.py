import json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
tree=json.loads((root/'assets/exports/ui/sourcemap.json').read_text())
def fill(n):
 for f in n.get('filePaths',[]):
  if f.endswith(('.lua','.luau')): n['source']=(root/f).read_text(encoding='utf-8-sig')
 for c in n.get('children',[]):fill(c)
fill(tree)
(root/'assets/exports/ui/bundle.json').write_text(json.dumps(tree),encoding='utf-8')
