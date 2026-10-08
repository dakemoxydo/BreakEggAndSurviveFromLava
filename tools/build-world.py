"""Convert the Studio snapshot to reusable Roblox XML assets and a complete place."""
import base64
import copy
import json
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

project=Path(__file__).resolve().parents[1]
roots=json.loads((project/'.tools/world-snapshot.json').read_text(encoding='utf-8'))

def attribute_blob(attributes):
    if not attributes:
        return ''
    data=bytearray(struct.pack('<I',len(attributes)))
    for name,entry in sorted(attributes.items()):
        encoded=name.encode('utf-8');data+=struct.pack('<I',len(encoded))+encoded
        t,v=entry['type'],entry['value']
        if t=='string':
            encoded=v.encode('utf-8');data+=b'\x02'+struct.pack('<I',len(encoded))+encoded
        elif t=='bool':data+=b'\x03'+bytes([int(v)])
        elif t=='float':data+=b'\x06'+struct.pack('<d',v)
        elif t=='Vector3':data+=b'\x11'+struct.pack('<fff',*v)
        elif t=='Color3':data+=b'\x0f'+struct.pack('<fff',*v)
        else:raise ValueError(f'Unsupported attribute type: {t}')
    return base64.b64encode(data).decode('ascii')

def property_element(name,entry):
    t,v=entry['type'],entry['value']
    element=ET.Element(t,{'name':name})
    tags={'CoordinateFrame':['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'], 'Vector3':['X','Y','Z'], 'Vector2':['X','Y'], 'Color3':['R','G','B'], 'UDim2':['XS','XO','YS','YO'], 'UDim':['S','O']}
    if t in tags:
        for tag,value in zip(tags[t],v):ET.SubElement(element,tag).text=str(value)
    elif t=='Content':ET.SubElement(element,'url').text=v
    elif t=='bool':element.text='true' if v else 'false'
    elif t=='NumberRange':element.text=' '.join(map(str,v))
    elif t=='float' and isinstance(v,dict):element.text=v['v']
    elif t=='float' and v is None:element.text='inf'
    else:element.text=str(v)
    return element

def item(node):
    result=ET.Element('Item',{'class':node['class'],'referent':node['id']})
    properties=ET.SubElement(result,'Properties')
    for name,entry in node['properties'].items():properties.append(property_element(name,entry))
    if node['attributes']:
        ET.SubElement(properties,'BinaryString',{'name':'AttributesSerialize'}).text=attribute_blob(node['attributes'])
    for child in node['children']:result.append(item(child))
    return result

output_paths = {
    'ReferenceMap.rbxmx': 'assets/environment/maps/exports/ReferenceMap.rbxmx',
    'AssetTemplates.rbxmx': 'assets/exports/roblox/AssetTemplates.rbxmx',
    'HDStudsMaterial.rbxmx': 'assets/environment/materials/hd-studs/HDStudsMaterial.rbxmx',
    'ReferenceLighting.rbxmx': 'assets/environment/lighting/exports/ReferenceLighting.rbxmx',
    'ReferenceClouds.rbxmx': 'assets/environment/lighting/exports/ReferenceClouds.rbxmx',
    'LavaBat.rbxmx': 'assets/items/bats/lava-bat/exports/LavaBat.rbxmx',
}

def model_file(filename,nodes):
    root=ET.Element('roblox',{'version':'4'})
    for node in nodes:root.append(item(node))
    path=project/output_paths[filename]
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(path,encoding='utf-8',xml_declaration=True)
    return path

model_file('ReferenceMap.rbxmx',[roots[0]])
model_file('AssetTemplates.rbxmx',[roots[1]])
model_file('HDStudsMaterial.rbxmx',[roots[2]])
model_file('ReferenceLighting.rbxmx',[roots[3]])
model_file('ReferenceClouds.rbxmx',[roots[4]])
model_file('LavaBat.rbxmx',[roots[5]])

# Merge canonical Rojo code with the captured scene, preserving XML referents.
place=ET.parse(project/'.tools/reference-game.rbxlx')
root=place.getroot()
def service(name):
    for node in root.findall('Item'):
        if node.attrib['class']==name:return node
    node=ET.SubElement(root,'Item',{'class':name,'referent':'SERVICE_'+name})
    props=ET.SubElement(node,'Properties');ET.SubElement(props,'string',{'name':'Name'}).text=name
    return node
service('Workspace').append(item(roots[0]))
service('ServerStorage').append(item(roots[1]))
service('MaterialService').append(item(roots[2]))
root.append(item(roots[3]))
terrain=ET.SubElement(service('Workspace'),'Item',{'class':'Terrain','referent':'WORLD_TERRAIN'})
props=ET.SubElement(terrain,'Properties');ET.SubElement(props,'string',{'name':'Name'}).text='Terrain'
terrain.append(item(roots[4]))
service('StarterPack').append(item(roots[5]))
props=service('Workspace').find('Properties')
ET.SubElement(props,'bool',{'name':'StreamingEnabled'}).text='false'
target=project/'BreakEggReference.rbxlx'
place.write(target,encoding='utf-8',xml_declaration=True)
print(f'World saved; complete place: {target.name} ({target.stat().st_size} bytes)')
