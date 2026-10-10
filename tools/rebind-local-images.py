"""Rebind uploaded local images in canonical source, manifests and generated XML."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
manifest = ROOT / "assets/manifests/account-reimport.json"
uploads = json.loads(manifest.read_text(encoding="utf-8"))
mapping = {row["oldId"]: row["newId"] for row in uploads["images"]}
mapping.update({row["previousNewId"]: row["newId"] for row in uploads["images"] if "previousNewId" in row})
pattern = re.compile(r"rbxassetid://(\d+)")

def rebind(text):
    return pattern.sub(lambda match: "rbxassetid://" + mapping.get(match[1], match[1]), text)

changed = []
for path in (ROOT / "src").rglob("*.luau"):
    if "serverPackages" in path.parts:
        continue
    original = path.read_text(encoding="utf-8")
    updated = rebind(original)
    if updated != original:
        path.write_text(updated, encoding="utf-8", newline="\n")
        changed.append(str(path.relative_to(ROOT)))

# Generated Roblox artifacts are regenerated through this tool, never hand-edited.
for path in (ROOT / "assets").rglob("*.rbxmx"):
    tree = ET.parse(path)
    dirty = False
    for node in tree.iter("url"):
        if node.text:
            updated = rebind(node.text)
            if updated != node.text:
                node.text = updated
                dirty = True
    if dirty:
        tree.write(path, encoding="utf-8", xml_declaration=True)
        changed.append(str(path.relative_to(ROOT)))

def update_ids(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "assetId" and str(child) in mapping:
                replacement = mapping[str(child)]
                value[key] = int(replacement) if isinstance(child, int) else replacement
            else:
                update_ids(child)
    elif isinstance(value, list):
        for child in value:
            update_ids(child)

for filename in ("reference-assets.json", "ui-manifest.json"):
    path = ROOT / "assets/manifests" / filename
    data = json.loads(path.read_text(encoding="utf-8"))
    update_ids(data)
    if filename == "ui-manifest.json":
        data["studioPlaceId"] = uploads["placeId"]
        data["delivery"] = "Local images reuploaded; delivery verification pending."
    else:
        data["placeId"] = uploads["placeId"]
    data["date"] = uploads["date"]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    changed.append(str(path.relative_to(ROOT)))

manifest.write_text(json.dumps(uploads, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"images": len(mapping), "changedFiles": changed}, ensure_ascii=False))
