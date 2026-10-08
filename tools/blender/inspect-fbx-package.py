"""Read binary FBX contents without importing or modifying any scene."""
import struct
import zlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/items/pickaxes/pack/exports/roblox-import-v03'

def read_fbx(path):
    data=path.read_bytes()
    assert data.startswith(b'Kaydara FBX Binary  \x00\x1a\x00')
    version=struct.unpack_from('<I',data,23)[0]
    wide=version>=7500;head='<QQQB' if wide else '<IIIB';length=25 if wide else 13
    def prop(offset):
        code=chr(data[offset]);offset+=1
        formats={'Y':'h','C':'?','I':'i','F':'f','D':'d','L':'q'}
        if code in formats:
            fmt='<'+formats[code];value=struct.unpack_from(fmt,data,offset)[0]
            return value,offset+struct.calcsize(fmt)
        if code in ('S','R'):
            size=struct.unpack_from('<I',data,offset)[0];offset+=4
            return data[offset:offset+size],offset+size
        count,encoding,size=struct.unpack_from('<III',data,offset);offset+=12
        raw=data[offset:offset+size]
        if encoding:raw=zlib.decompress(raw)
        fmt={'f':'f','d':'d','i':'i','l':'q','b':'b','c':'b'}[code]
        return struct.unpack('<'+str(count)+fmt,raw),offset+size
    def node(offset):
        end,count,size,nlen=struct.unpack_from(head,data,offset)
        if end==0:return None,offset+length
        offset+=length;name=data[offset:offset+nlen].decode('utf-8');offset+=nlen
        properties=[]
        for _ in range(count):
            value,offset=prop(offset);properties.append(value)
        children=[]
        while offset<end-length:
            child,offset=node(offset)
            if child is None:break
            children.append(child)
        return {'id':name,'props':properties,'children':children},end
    nodes=[];offset=27
    while offset<len(data)-length:
        item,offset=node(offset)
        if item is None:break
        nodes.append(item)
    return nodes

def child(node,name):return next(n for n in node['children'] if n['id']==name)
def name(node):return node['props'][1].split(b'\x00')[0].decode('utf-8')
def properties(node):
    return {n['props'][0].decode('utf-8'):n['props'][4:] for n in child(node,'Properties70')['children']}

manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
records={r['name']:r for r in manifest['models']}
report={'method':'Read-only binary FBX inspection; no game tests or round-trip import executed.','files':[]}
for path in [OUT/'Pickaxes_Pack.fbx']+[OUT/r['fbx'] for r in records.values()]:
    nodes=read_fbx(path);objects=next(n for n in nodes if n['id']=='Objects')['children']
    geometries=[n for n in objects if n['id']=='Geometry']
    models=[n for n in objects if n['id']=='Model']
    materials=[n for n in objects if n['id']=='Material']
    videos=[n for n in objects if n['id']=='Video']
    expected=18 if path.name=='Pickaxes_Pack.fbx' else 1
    assert len(geometries)==len(models)==len(materials)==len(videos)==expected
    assert all(n['props'][2]==b'Mesh' for n in models)
    file_report={'file':str(path.relative_to(OUT)),'meshes':[],'embeddedTextures':len(videos)}
    for geometry,model in zip(geometries,models):
        model_name=name(model);assert model_name in records
        record=records[model_name]
        coordinates=child(geometry,'Vertices')['props'][0]
        indices=child(geometry,'PolygonVertexIndex')['props'][0]
        triangle_count=sum(i<0 for i in indices)
        assert triangle_count==record['triangles'] and len(indices)==triangle_count*3
        dims=[max(coordinates[a::3])-min(coordinates[a::3]) for a in range(3)]
        assert all(abs(a-b)<.0001 for a,b in zip(dims,record['sizeStuds']))
        uv=child(geometry,'LayerElementUV')
        coords=child(uv,'UV')['props'][0]
        assert all(-.0001<=v<=1.0001 for v in coords)
        p=properties(model)
        assert all(abs(s-1)<.00001 for s in p.get('Lcl Scaling',[1,1,1]))
        if expected==1:assert all(abs(s)<.00001 for s in p.get('Lcl Translation',[0,0,0]))
        file_report['meshes'].append({'name':model_name,'triangles':triangle_count,'sizeStuds':dims,'singleUVSet':True})
    for video in videos:
        content=child(video,'Content')['props'][0]
        assert content.startswith(b'\x89PNG\r\n\x1a\n')
    report['files'].append(file_report)
report['passed']=True
(OUT/'export-inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'filesInspected':len(report['files']),'packMeshes':len(report['files'][0]['meshes']),'passed':True}))
