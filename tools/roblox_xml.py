"""Roblox XML (rbxmx) serializers for snapshot-style nodes: {class, id, properties, attributes, children}."""
import base64
import struct
import xml.etree.ElementTree as ET

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
    if t == 'OptionalCoordinateFrame':
        frame = ET.SubElement(element, 'CFrame')
        for tag, value in zip(tags['CoordinateFrame'], v):
            ET.SubElement(frame, tag).text = str(value)
    elif t in tags:
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
