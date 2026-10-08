"""Create exactly one named pickaxe, audit contact, render and save a version."""
import ast
import math
import json
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PACK=ROOT/'assets/items/pickaxes/pack'
CONFIG={
 'Hacker':(13, ['202831','44505C','18222A','10171E','283B43','546D76','28333B','79EC26']),
 'UFO':(14, ['15606A','3D9CA2','16414C','102933','9AAEBF','D9EBF2','1D7881','54DE99']),
 'Secret':(15, ['282239','544365','432559','21122D','332740','66517C','332A47','B96AF0']),
 'Cool':(16, ['2462BE','77BDF2','173777','0E2150','ACC7E2','E6F8FF','3D8CCA','B2EEFF']),
 'Galaxy':(17, ['563499','9562DB','402371','22163B','BB852B','FFD773','713BB2','46DDEB']),
 'Celestial':(18, ['F0E2C0','FFF8E8','D7CDAF','9C8761','CB9526','FFE598','F1E9D9','E8B949'])}
key=ASSET_KEY
tier,palette=CONFIG[key]
scene=bpy.context.scene
assert scene.name=='Pickaxe_Pack_Review' and bpy.context.mode=='OBJECT'
collection_name='%02d_%s_Review_v01'%(tier,key)
assert collection_name not in bpy.data.collections
if bpy.data.is_dirty:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/('.tools/before-%s-live-edits.blend'%key.lower())),copy=True,compress=True)
image=bpy.data.images.load(str(PACK/('textures/%s-dark-studs-v01.png'%key.lower())),check_existing=True)
image.pack()
mats=[]
for i in range(8):
    mat=bpy.data.materials['Pack_DarkStuds_%02d'%i].copy()
    mat.name='%s_DarkStuds_%02d'%(key,i)
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE': node.image=image
    shader=mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value=.42
    shader.inputs['Metallic'].default_value=.27 if i in (4,5) else .06
    mats.append(mat)
facets={
 'Hacker': [('Neon',(.22,1,.015,1),1.2),('Neon_Light',(.65,1,.15,1),.7),('Graphite',(.025,.045,.06,1),0),('Screen',(.005,.085,.018,1),0)],
 'UFO':[('Alien',(.08,.95,.28,1),.5),('Alien_Light',(.50,1,.09,1),.4),('Teal',(.012,.20,.24,1),0),('Silver',(.57,.74,.84,1),0)],
 'Secret':[('Void',(.48,.015,.95,1),.8),('Crystal',(.76,.40,1,1),.3),('Armor',(.045,.024,.073,1),0),('Ice',(.93,.76,1,1),.15)],
 'Cool':[('Ice',(.23,.73,1,1),.25),('Ice_Light',(.75,.98,1,1),.2),('Blue',(.025,.13,.48,1),0),('Eyes',(.02,.93,1,1),1.2)],
 'Galaxy':[('Cyan',(.015,.64,.9,1),.35),('Violet',(.36,.065,.75,1),.2),('Gold',(.95,.51,.05,1),0),('Ice',(.26,.91,1,1),.25)],
 'Celestial':[('Star',(.08,.78,1,1),.7),('Star_Light',(.66,.98,1,1),.6),('Gold',(.98,.67,.12,1),0),('Ivory',(.94,.90,.74,1),0)]}
for name,color,emission in facets[key]:
    mat=bpy.data.materials.new(key+'_'+name)
    mat.use_nodes=True;mat.diffuse_color=color
    shader=mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=color
    shader.inputs['Roughness'].default_value=.33
    shader.inputs['Emission Color'].default_value=color
    shader.inputs['Emission Strength'].default_value=emission
    mats.append(mat)
collection=bpy.data.collections.new(collection_name)
scene.collection.children.link(collection)
root=bpy.data.objects.new(key+'_Grip_v01',None)
collection.objects.link(root)
xpos=-3.25+(tier-1)*6.5
root.location=(xpos,0,1.4)
root['asset_key']=key;root['tier']=tier;root['status']='Ready for user review'
helper=ROOT/'tools/blender/create-iron-review-v01.py'
tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),str(helper),'exec'))
wood=bpy.data.collections['01_Wooden_v04_DarkStuds']
for part in ['Wooden_Shaft','Top_Steel_Brace','Middle_Steel_Band','Bottom_Steel_Cap']:
    source=next(o for o in wood.objects if o.name=='Wooden_'+part)
    obj=source.copy();obj.data=source.data.copy();obj.name=key+'_'+part
    collection.objects.link(obj);obj.parent=root;obj.matrix_parent_inverse.identity()
    for i,mat in enumerate(mats[:8]):obj.data.materials[i]=mat

def extrude(name,outline,depth,base,edge=None,y=0,bevel=0):
    n=len(outline)
    vertices=[(x,y+side*depth/2,z) for side in (-1,1) for x,z in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    colors=[base,base]
    for j in range(n):
        faces.append((j,(j+1)%n,(j+1)%n+n,j+n));colors.append(base if edge is None else edge)
    return finish(mesh(key+'_'+name,vertices,faces,colors),bevel)

def spike(name,base,axis,width,depth,indices=(8,9,8,10)):
    base,axis=Vector(base),Vector(axis)
    tangent=Vector((axis.z,0,-axis.x)).normalized();across=Vector((0,1,0))
    vertices=[]
    for frac,radius in [(0,1),(.67,.72)]:
        center=base+axis*frac
        for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            vertices.append(tuple(center+tangent*(a*width*radius/2)+across*(b*depth*radius/2)))
    vertices.append(tuple(base+axis));faces=[(3,2,1,0)];colors=[indices[0]]
    for j in range(4):
        faces.extend([(j,(j+1)%4,4+(j+1)%4,4+j),(4+j,4+(j+1)%4,8)])
        colors.extend([indices[j],indices[(j+1)%4]])
    return finish(mesh(key+'_'+name,vertices,faces,colors))

def jewel(name,x,z,width,height,y,indices=(8,9,8,9)):
    # Back plane deliberately penetrates its setting by at least .015.
    facing=-1 if y<0 else 1
    vertices=[(x,y,z+height/2),(x+width/2,y,z),(x,y,z-height/2),(x-width/2,y,z),
              (x,y+facing*.13,z)]
    return finish(mesh(key+'_'+name,vertices,[(3,2,1,0),(0,1,4),(1,2,4),(2,3,4),(3,0,4)],
                       [indices[0]]+list(indices)))

def ring(name,center,radius,tube,material,rotation=(0,0,0),segments=32):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=6,
        location=(center[0],center[1],center[2]-1.4),major_radius=radius,minor_radius=tube)
    obj=bpy.context.object;obj.name=key+'_'+name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    collection.objects.link(obj)
    for face in obj.data.polygons:face.material_index=material
    obj.rotation_euler=rotation
    return finish(obj)

def lathe(name,profile,material,segments=16):
    vertices=[]
    for radius,z in profile:
        vertices.extend((radius*math.cos(2*math.pi*j/segments),radius*math.sin(2*math.pi*j/segments),z)
                        for j in range(segments))
    faces=[tuple(reversed(range(segments))),tuple(range((len(profile)-1)*segments,len(profile)*segments))]
    for k in range(len(profile)-1):
        for j in range(segments):
            faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    return finish(mesh(key+'_'+name,vertices,faces,[material]*len(faces)))

def star(name,x,z,size,y,material,points=4,depth=.10):
    outline=[]
    for i in range(points*2):
        angle=math.pi/2+i*math.pi/points
        radius=size if i%2==0 else size*.40
        outline.append((x+math.cos(angle)*radius,z+math.sin(angle)*radius))
    return extrude(name,outline,depth,material,y=y,bevel=.008)

# Shared stepped head: broad inner block, rotated outer block and tapered point.
for side,label in [(-1,'L'),(1,'R')]:
    box(key+'_Inner_Block_'+label,(side*.88,0,4.15),(.94,.76,1.12),6,1,.055)
    outer=box(key+'_Outer_Block_'+label,(side*1.62,0,3.94),(.85,.70,1.06),6,1,.045)
    outer.rotation_euler.y=side*.40
    outline=[(side*x,z) for x,z in [(1.86,4.055),(2.28,3.81),(2.81,3.02),(2.23,3.13),(1.86,3.15)]]
    extrude('Point_'+label,outline,.54,7,1,bevel=.015)
if key=='UFO':
    box(key+'_Center_Socket',(0,0,3.97),(.85,.68,.64),2,2,.04)
elif key=='Galaxy':
    box(key+'_Center_Socket',(0,0,3.92),(.70,.60,.45),2,2,.03)
else:
    box(key+'_Center_Socket',(0,0,4.17),(1.10,.92,1.28),4,5,.055)
    box(key+'_Crown_Collar',(0,0,4.83),(.75,.76,.18),4,5,.02)

if key=='Hacker':
    for facing,label in [(-1,'Front'),(1,'Back')]:
        box(key+'_Screen_Bezel_'+label,(0,facing*.475,4.17),(.78,.12,.86),0,0,.025)
        box(key+'_Screen_'+label,(0,facing*.535,4.17),(.62,.04,.70),11,11,.008)
        # Readable code brackets are inlaid lines, with no loose pixel cubes.
        for side,tag in [(-1,'L'),(1,'R')]:
            extrude('Code_Bracket_'+label+tag,[(side*.19,4.40),(side*.27,4.31),(side*.27,4.04),
                (side*.19,3.95),(side*.16,3.99),(side*.22,4.06),(side*.22,4.29),(side*.16,4.36)],
                .035,8,y=facing*.556)
            box(key+'_Circuit_'+label+tag,(side*.88,facing*.375,4.05),(.55,.03,.06),8,8,.01)
            box(key+'_Circuit_Riser_'+label+tag,(side*1.1,facing*.375,4.25),(.06,.03,.42),8,8,.01)
        for j,height in enumerate([.76,1.40,2.60,3.08]):
            for side,tag in [(-1,'L'),(1,'R')]:
                box(key+'_Shaft_Circuit_'+label+str(j)+tag,(side*.09,facing*.259,height),(.045,.035,.48),8,8,.006)
    for j,z in enumerate([.54,1.02,2.7]):box(key+'_Data_Grip_'+str(j),(0,0,z),(.59,.61,.12),7,7,.02)
    box(key+'_Neon_Pommel',(0,0,.13),(.64,.66,.22),7,7,.045)

elif key=='UFO':
    lathe('Saucer_Hull',[(.38,3.75),(.90,4.03),(1.00,4.18),(.84,4.40),(.57,4.48)],4)
    lathe('Alien_Cockpit',[(.58,4.39),(.57,4.53),(.42,4.78),(.22,4.94),(.045,5.00)],8)
    ring('Saucer_Rim',(0,0,4.18),.94,.09,11)
    for j in range(12):
        angle=2*math.pi*j/12
        obj=box(key+'_Port_%02d'%j,(.87*math.cos(angle),.87*math.sin(angle),4.24),(.22,.10,.09),9,9,.018)
        obj.rotation_euler.z=angle+math.pi/2
    for j,z in enumerate([.6,1.3,2.72]):box(key+'_Alien_Grip_%d'%j,(0,0,z),(.59,.61,.13),7,7,.02)
    lathe('Alien_Pommel',[(.28,.22),(.37,.04),(.20,-.20),(.045,-.32)],8)

elif key=='Secret':
    for facing,label in [(-1,'Front'),(1,'Back')]:
        box(key+'_Void_Frame_'+label,(0,facing*.47,4.17),(.83,.12,.87),3,3,.025)
        jewel('Void_Core_'+label,0,4.17,.58,.64,facing*.515)
        for side,tag in [(-1,'L'),(1,'R')]:
            strip=box(key+'_Void_Seam_'+label+tag,(side*.91,facing*.378,4.03),(.055,.035,.70),8,8,.008)
            strip.rotation_euler.y=side*.12
    for side,label in [(-1,'L'),(1,'R')]:
        for j,(x,z) in enumerate([(.87,3.65),(1.38,3.54),(1.92,3.28)]):
            spike('Crystal_Fang_'+label+str(j),(side*x,0,z),(side*.10,0,-.49),.25,.36,(9,11,9,10))
        # Crown blades seat into the armor rather than float above it.
        spike('Mounted_Crown_'+label,(side*.80,0,4.65),(side*.15,0,.50),.35,.36,(10,9,10,10))
    spike('Void_Pommel',(0,0,.20),(0,0,-.50),.60,.62,(10,9,10,10))
    for j,z in enumerate([.72,1.22,2.73]):box(key+'_Violet_Grip_%d'%j,(0,0,z),(.59,.61,.13),7,7,.02)

elif key=='Cool':
    for side,label in [(-1,'L'),(1,'R')]:
        spike('Ice_Horn_'+label,(side*.33,0,4.67),(side*.37,0,.99),.34,.42,(8,9,8,10))
        for j,(x,z) in enumerate([(.86,3.65),(1.37,3.56),(1.88,3.30)]):
            spike('Ice_Tooth_'+label+str(j),(side*x,0,z),(side*.10,0,-.43),.25,.36,(8,9,8,10))
    for facing,label in [(-1,'Front'),(1,'Back')]:
        extrude('Dragon_Mask_'+label,[(-.48,4.57),(-.22,4.66),(0,4.50),(.22,4.66),(.48,4.57),
            (.41,4.03),(0,3.80),(-.41,4.03)],.18,2,1,y=facing*.49,bevel=.015)
        for side,tag in [(-1,'L'),(1,'R')]:
            extrude('Dragon_Eye_'+label+tag,[(side*.11,4.35),(side*.35,4.42),(side*.29,4.26),(side*.15,4.24)],
                    .045,11,y=facing*.587)
        jewel('Ice_Core_'+label,0,3.93,.24,.28,facing*.574,(8,9,8,9))
    for j,z in enumerate([.78,1.29,2.75]):box(key+'_Silver_Grip_%d'%j,(0,0,z),(.59,.61,.13),4,5,.022)
    spike('Ice_Pommel',(0,0,.20),(0,0,-.52),.61,.63,(8,9,8,10))

elif key=='Galaxy':
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.63,location=(0,0,4.20-1.4))
    obj=bpy.context.object;obj.name=key+'_Planet_Core'
    obj.rotation_euler.z=math.pi/2
    for c in list(obj.users_collection):c.objects.unlink(obj)
    collection.objects.link(obj)
    for p in obj.data.polygons:p.material_index=[8,9,11][p.index%3]
    finish(obj)
    ring('Planet_Orbit',(0,0,4.20),.67,.105,10,(math.radians(69),0,0))
    for side,label in [(-1,'L'),(1,'R')]:
        for facing,tag in [(-1,'Front'),(1,'Back')]:
            star('Tip_Star_'+label+tag,side*2.54,3.29,.26,facing*.27,10)
            jewel('Tip_Core_'+label+tag,side*2.54,3.29,.18,.18,facing*.31,(8,11,8,11))
    star('Pommel_Star',0,.10,.46,0,10,depth=.60)
    for facing,label in [(-1,'Front'),(1,'Back')]:jewel('Pommel_Core_'+label,0,.10,.28,.33,facing*.29,(8,11,8,11))
    for j,z in enumerate([.65,1.19,2.75]):box(key+'_Gold_Grip_%d'%j,(0,0,z),(.59,.61,.13),4,5,.025)

elif key=='Celestial':
    # Two upright halos intersect the socket and their supporting crown.
    ring('Outer_Halo',(0,.18,4.70),.96,.105,10,(math.pi/2,0,0))
    ring('Inner_Halo',(0,.18,4.58),.65,.075,10,(math.pi/2,0,0))
    spike('Crown_Spear',(0,0,4.78),(0,0,.90),.27,.35,(10,11,10,10))
    for side,label in [(-1,'L'),(1,'R')]:
        for j,(x,z) in enumerate([(.76,3.80),(1.24,3.66),(1.76,3.43)]):
            # Wing feathers are broad ivory blades anchored into each head section.
            extrude('Wing_Feather_'+label+str(j),[(side*(x-.22),z+.20),(side*(x+.24),z+.05),
                    (side*(x+.39),z-.55),(side*(x-.04),z-.27)],.42,6,11,bevel=.02)
    for facing,label in [(-1,'Front'),(1,'Back')]:
        star('Star_Setting_'+label,0,4.17,.54,facing*.49,10,points=6,depth=.16)
        star('Cyan_Star_'+label,0,4.17,.40,facing*.575,8,points=6,depth=.065)
        jewel('Star_Core_'+label,0,4.17,.21,.26,facing*.605,(8,9,8,9))
    star('Pommel_Star',0,.11,.46,0,10,points=6,depth=.63)
    for facing,label in [(-1,'Front'),(1,'Back')]:jewel('Pommel_Core_'+label,0,.11,.27,.31,facing*.30,(8,9,8,9))
    for j,z in enumerate([.68,1.22,2.76]):box(key+'_Gold_Grip_%d'%j,(0,0,z),(.59,.61,.14),4,5,.025)

# Audit this model before progressing to the next one.
audit_path=ROOT/'tools/blender/audit-pickaxe-attachments.py'
audit_tree=ast.parse(audit_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in audit_tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.FunctionDef))],type_ignores=[]),str(audit_path),'exec'))
report=audit_collection(collection)
report_path=PACK/('previews/%s-attachment-audit-v01.json'%key.lower())
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
root['contact_components']=report['contactComponents']
root['attachment_check']='passed' if report['contactComponents']==1 and not report['meshErrors'] else 'needs repair'

# Frame the row and provide an isolated close view for review.
camera=bpy.data.objects['Pack_Review_Camera'];scene.camera=camera
center=Vector(((-3.25+xpos)/2,0,2.7))
camera.location=(center.x+3.6,-27,9.25)
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=tier*6.5+2
for name in ['Review_Key','Review_Fill','Review_Rim']:
    light=bpy.data.objects[name];light.location.x+=3.25
    light.data.size=tier*6.5+7;light.data.energy*=1.05
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
studio=bpy.data.collections['Review_Studio_Do_Not_Export']
data=bpy.data.cameras.new(key+'_Detail_Camera');detail=bpy.data.objects.new(data.name,data);studio.objects.link(detail)
detail.location=(xpos+2.75,-15,7)
detail.rotation_euler=(Vector((xpos,0,2.8))-detail.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=7.4
hidden=[(c,c.hide_render) for c in scene.collection.children if c not in (collection,studio)]
try:
    for c,previous in hidden:c.hide_render=True
    scene.camera=detail;scene.render.resolution_x=1100;scene.render.resolution_y=1100
    scene.render.resolution_percentage=100
    scene.render.filepath=str(PACK/('previews/%s-detail-review-v01.png'%key.lower()))
    bpy.ops.render.render(write_still=True)
finally:
    for c,previous in hidden:c.hide_render=previous
    scene.camera=camera
scene.render.resolution_x=tier*420;scene.render.resolution_y=900
scene.render.filepath=str(PACK/('previews/pack-%02d-slots-review-v01.png'%tier))
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='MATERIAL'
            space.region_3d.view_perspective='ORTHO'
            space.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
            space.region_3d.view_location=center
            space.region_3d.view_distance=camera.data.ortho_scale+.5
output=PACK/('models/pickaxes-asset-pack-review-v%02d.blend'%(tier+1))
bpy.ops.wm.save_as_mainfile(filepath=str(output),compress=True)
result={'file':str(output),'asset':key,'audit':report,'detail':str(PACK/('previews/%s-detail-review-v01.png'%key.lower()))}
