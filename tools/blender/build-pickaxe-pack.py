"""Build the eighteen-tier asset pack from the approved Wooden scene.

Run through Blender MCP with BUILD_TIERS=[...] to build sequential batches.
Creates a new scene; original Wooden scene and file remain intact.
"""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, kdtree

ROOT=Path(r'C:\Users\dakem\Documents\RobloxGames\BreakEggAndSurviveFromLava')
PICKS=ROOT/'assets/items/pickaxes'
PACK=PICKS/'pack'
CATALOG=json.loads((PICKS/'catalog.json').read_text(encoding='utf-8'))['items']
PALETTE=json.loads((PACK/'textures/palette-v01.json').read_text())
INDEX={name:i for i,name in enumerate(PALETTE)}
SCENE_NAME='Pickaxe_Asset_Pack_v01'
MODEL_COLLECTION='Pickaxes_Editable_18'
EXPORT_COLLECTION='Pickaxes_Export_18_Meshes'
for directory in ['models','exports','previews']:
 (PACK/directory).mkdir(exist_ok=True)

def init_scene():
 if SCENE_NAME in bpy.data.scenes:
  scene=bpy.data.scenes[SCENE_NAME]
  bpy.context.window.scene=scene
  return scene
 assert bpy.context.mode=='OBJECT'
 assert 'Wooden_Pickaxe_v02' in bpy.data.scenes, 'Open the approved Wooden v02 file.'
 backup=ROOT/'.tools/blender-before-pickaxe-pack.blend'
 if not backup.exists(): bpy.ops.wm.save_as_mainfile(filepath=str(backup),copy=True)
 scene=bpy.data.scenes.new(SCENE_NAME)
 bpy.context.window.scene=scene
 scene.unit_settings.system='NONE'
 for name in [MODEL_COLLECTION,EXPORT_COLLECTION,'Pickaxe_Pack_Preview_Studio']:
  scene.collection.children.link(bpy.data.collections.new(name))
 image=bpy.data.images.load(str(PACK/'textures/pickaxes-studs-atlas-v01.png'),check_existing=False)
 image.name='Pickaxe_Pack_Studs_Atlas'
 image.pack()
 for name,color in PALETTE.items():
  mat=bpy.data.materials.new('Pack_'+name)
  mat.use_nodes=True
  mat.diffuse_color=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))+(1,)
  bsdf=mat.node_tree.nodes.get('Principled BSDF')
  bsdf.inputs['Roughness'].default_value=.62
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
  tex.image=image
  tex.interpolation='Linear'
  mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 scene['pack_version']='v01'
 scene['studs']='Approved flat alpha overlay; no raised square studs.'
 scene['units']='1 Blender unit is 1 intended Roblox stud; each mesh pivot at grip.'
 scene['order']='01 Wooden through 18 Celestial, left to right in preview rows.'
 return scene

SCENE=init_scene()
MATERIALS=[bpy.data.materials['Pack_'+name] for name in PALETTE]
ITEM=None
PARTS=[]
COLLECTION=None
GRIP=None
COUNTER=0

def begin(tier):
 global ITEM,PARTS,COLLECTION,GRIP,COUNTER
 ITEM=CATALOG[tier-1]
 name='%02d_%s'%(tier,ITEM['key'])
 assert name not in bpy.data.collections, 'Already built: '+name
 COLLECTION=bpy.data.collections.new(name)
 bpy.data.collections[MODEL_COLLECTION].children.link(COLLECTION)
 GRIP=bpy.data.objects.new(name+'_Grip',None)
 COLLECTION.objects.link(GRIP)
 GRIP.empty_display_type='PLAIN_AXES'
 GRIP['key']=ITEM['key']
 GRIP['tier']=tier
 GRIP['symmetry']='X=0 in local geometry'
 GRIP['reference']=ITEM['referenceImage']
 PARTS=[]
 COUNTER=0

def add(obj,name,color,bevel=0):
 global COUNTER
 COUNTER+=1
 obj.name='%02d_%s_%03d_%s'%(ITEM['tier'],ITEM['key'],COUNTER,name)
 for col in list(obj.users_collection): col.objects.unlink(obj)
 COLLECTION.objects.link(obj)
 for mat in MATERIALS: obj.data.materials.append(mat)
 for p in obj.data.polygons: p.material_index=INDEX[color]
 bpy.ops.object.select_all(action='DESELECT')
 obj.select_set(True)
 bpy.context.view_layer.objects.active=obj
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  modifier=obj.modifiers.new('Planar_Edge','BEVEL')
  modifier.width=bevel
  modifier.segments=1
  bpy.ops.object.modifier_apply(modifier=modifier.name)
 PARTS.append(obj)
 return obj

def box(name,center,size,color,bevel=.02):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center)
 obj=bpy.context.object
 obj.dimensions=size
 return add(obj,name,color,bevel)

def mesh(name,vertices,faces,color,bevel=0):
 data=bpy.data.meshes.new(name)
 data.from_pydata(vertices,[],faces)
 data.update()
 bm=bmesh.new();bm.from_mesh(data)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(data);bm.free()
 obj=bpy.data.objects.new(name,data)
 COLLECTION.objects.link(obj)
 return add(obj,name,color,bevel)

def prism(name,outline,depth,color,y=0,bevel=.016):
 n=len(outline)
 vertices=[(x,y+sign*depth/2,z) for sign in [-1,1] for x,z in outline]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
 faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,vertices,faces,color,bevel)

def pair_prism(name,outline,depth,color,y=0,bevel=.016):
 return [prism(name+suffix,[(side*x,z) for x,z in outline],depth,color,y,bevel) for side,suffix in [(-1,'_L'),(1,'_R')]]

def loft(name,stations,color,side=1,facet=False):
 vertices=[]
 for x,top,bottom,depth in stations:
  vertices += [(side*x,-depth,top),(side*x,depth,top),(side*x,depth,bottom),(side*x,-depth,bottom)]
 n=len(stations)
 faces=[(3,2,1,0),tuple(range((n-1)*4,n*4))]
 for k in range(n-1):
  for j in range(4): faces.append((k*4+j,k*4+(j+1)%4,(k+1)*4+(j+1)%4,(k+1)*4+j))
 obj=mesh(name,vertices,faces,color,.016)
 if facet:
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
  modifier=obj.modifiers.new('Crystal_Planes','TRIANGULATE')
  bpy.ops.object.modifier_apply(modifier=modifier.name)
  for p in obj.data.polygons:
   if abs(p.normal.y)>.9 and p.center.z>3.8: p.material_index=INDEX['cyanLight']
 return obj

def wings(stations,color,facet=False):
 for side in [-1,1]: loft('Blade',stations,color,side,facet)

def gem(name,center,size,color):
 x,y,z=center;sx,sy,sz=size
 vertices=[(x+sx,y,z),(x-sx,y,z),(x,y+sy,z),(x,y-sy,z),(x,y,z+sz),(x,y,z-sz)]
 faces=[(4,0,2),(4,2,1),(4,1,3),(4,3,0),(5,2,0),(5,1,2),(5,3,1),(5,0,3)]
 return mesh(name,vertices,faces,color)

def star(name,center,outer,inner,color,points=8,depth=.13):
 x,y,z=center
 outline=[]
 for i in range(points*2):
  angle=math.pi/2+i*math.pi/points
  radius=outer if i%2==0 else inner
  outline.append((x+math.cos(angle)*radius,z+math.sin(angle)*radius))
 return prism(name,outline,depth,color,y,0)

def cylinder(name,center,radius,depth,color,vertices=12,axis='Z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=center)
 obj=bpy.context.object
 if axis=='Y': obj.rotation_euler.x=math.pi/2
 return add(obj,name,color,.012)

def ring(name,center,radius,tube,color,axis='Y',tilt=0):
 bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,major_radius=radius,minor_radius=tube,location=center)
 obj=bpy.context.object
 if axis=='Y': obj.rotation_euler.x=math.pi/2+tilt
 return add(obj,name,color)

def sphere(name,center,size,color):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=center)
 obj=bpy.context.object;obj.scale=size
 return add(obj,name,color)

def shaft(color,band,pommel=None,width=.44):
 obj=box('Shaft',(0,0,2.2),(width,.48,4.4),color,.035)
 for z in [.60,2.9]: box('Grip_Collar',(0,0,z),(width+.14,.63,.28),band,.028)
 box('Socket',(0,0,4.00),(.68,.78,.72),band,.04)
 box('Top_Cap',(0,0,4.45),(.47,.52,.25),band,.02)
 if pommel: gem('Pommel',(0,0,.15),(.35,.33,.39),pommel)
 return obj

def core(color,width=.28,z=4.05,y=-.45):
 for side in [-1,1]: gem('Core',(0,side*abs(y),z),(width,.13,width*1.15),color)

def build_wooden():
 original=bpy.data.collections['Wooden_Pickaxe_Model_v02']
 for obj in original.objects:
  if obj.type!='MESH': continue
  clone=bpy.data.objects.new(obj.name+'_Pack',obj.data.copy())
  clone.data.transform(obj.matrix_world)
  COLLECTION.objects.link(clone)
  PARTS.append(clone)

def build(tier):
 begin(tier)
 if tier==1:
  build_wooden()
 elif tier==2:
  shaft('wood','brown')
  wings([(.25,4.24,3.67,.40),(.9,4.26,3.64,.40),(1.55,4.09,3.60,.34),(2.30,3.72,3.63,.10)],'steel')
  pair_prism('Rock_Facet',[(.40,4.17),(1.08,4.16),(1.60,3.95),(1.32,3.75),(.4,3.75)],.018,'silver',-.411,0)
  box('Stone_Socket',(0,0,4.04),(.70,.85,.72),'steelDark',.035)
  box('Wood_End',(0,0,4.46),(.46,.51,.22),'woodLight')
 elif tier==3:
  shaft('walnut','steelDark')
  wings([(.26,4.23,3.76,.32),(.95,4.3,3.79,.31),(1.65,4.14,3.74,.27),(2.46,3.70,3.61,.07)],'silver')
  pair_prism('Forged_Ridge',[(.38,4.32),(1.05,4.40),(1.63,4.21),(1.54,4.12),(.40,4.22)],.48,'steel')
  for z in [1.05,1.25,1.45,1.65]: box('Grip_Wrap',(0,0,z),(.48,.52,.14),'black',.025)
  for z in [.35,2.8]: box('Iron_Band',(0,0,z),(.56,.62,.18),'silver')
 elif tier==4:
  shaft('walnut','gold','goldDark')
  wings([(.28,4.3,3.75,.35),(.8,4.37,3.8,.35),(1.45,4.22,3.74,.30),(2.43,3.78,3.69,.08)],'gold')
  for side in [-1,1]:
   for x,z,w in [(.63,4.38,.55),(1.18,4.25,.44),(1.66,4.05,.33)]:
    box('Stepped_Gold_Plate',(side*x,0,z),(w,.72,.12),'goldLight',.015)
  box('Royal_Socket',(0,0,4.02),(.81,.86,.76),'goldDark')
  core('emerald',.29)
  box('Gold_Pommel',(0,0,.22),(.6,.61,.28),'gold',.025)
 elif tier==5:
  shaft('navy','silver','cyan')
  wings([(.27,4.18,3.67,.36),(.75,4.39,3.80,.37),(1.35,4.33,3.72,.30),(1.93,4.01,3.59,.24),(2.51,3.66,3.61,.03)],'cyan',True)
  for side in [-1,1]:
   gem('Blade_Crystal',(side*1.22,-.32,4.06),(.50,.16,.35),'cyanLight')
   gem('Upper_Facet',(side*.66,0,4.32),(.23,.28,.28),'cyanDeep')
  core('cyanLight',.27)
  for z in [1.0,1.8,2.5]: box('Navy_Armor',(0,0,z),(.51,.56,.33),'navy')
 elif tier==6:
  shaft('red','green','red')
  pair_prism('Berry_Blade',[(.25,4.25),(.85,4.46),(1.6,4.25),(2.37,3.87),(2.54,3.50),(1.61,3.82),(.28,3.75)],.65,'red')
  for side in [-1,1]:
   pair_prism('Leaf_Collar',[(.10,4.50),(.48,4.56),(.89,4.22),(.46,4.27),(.26,3.85)],.68,'greenDark')
   break
  pair_prism('Leaf_Top',[(.08,4.48),(.34,4.92),(.60,4.55),(.38,4.36)],.45,'greenLight')
  for z in [.45,1.15,2.0,2.85]: box('Cream_Wrap',(0,0,z),(.48,.54,.20),'cream')
  core('greenLight',.19)
 elif tier==7:
  shaft('greenDark','copper','copper')
  pair_prism('Cactus_Arm',[(.25,4.32),(.8,4.43),(1.5,4.28),(2.15,4.07),(2.52,3.62),(2.35,3.48),(1.99,3.85),(1.20,3.91),(.27,3.76)],.72,'green')
  for side in [-1,1]:
   for x,z in [(.75,4.44),(1.38,4.3),(1.96,4.09)]:
    prism('Cactus_Spine',[(side*(x-.12),z),(side*x,z+.37),(side*(x+.12),z)],.24,'cream',0,0)
   box('Stem_Rib',(side*.19,-.255,1.9),(.055,.07,1.4),'greenLight',.008)
  core('orange',.22)
  for z in [.8,1.05]: cylinder('Copper_Ring',(0,0,z),.32,.11,'copper',8)
 elif tier==8:
  shaft('navy','yellow','gold')
  pair_prism('Lightning_Bolt',[(.27,4.22),(.96,4.69),(1.29,4.71),(1.10,4.31),(1.88,4.42),(1.51,4.07),(2.47,3.63),(1.86,3.67),(1.57,3.90),(1.08,3.77),(1.19,4.04),(.29,3.81)],.56,'yellow')
  box('Transformer',(0,0,4.1),(.92,.80,.76),'steelDark')
  core('cyanLight',.30,z=4.1)
  for z in [1.05,1.9,2.6]: box('Conductor',(0,0,z),(.55,.56,.20),'gold')
  for side in [-1,1]: box('Energy_Strip',(0,side*.244,1.85),(.12,.018,2.10),'cyan',.004)
 elif tier==9:
  shaft('pink','tealLight','pink')
  path=[(.27,4.12),(.63,4.47),(1.15,4.57),(1.68,4.43),(2.04,4.09),(2.15,3.67),(1.97,3.32),(1.63,3.18)]
  for side in [-1,1]:
   for i,(a,b) in enumerate(zip(path,path[1:])):
    av=Vector(a);bv=Vector(b);direction=(bv-av).normalized();normal=Vector((-direction.y,direction.x))*.19
    shape=[av+normal,bv+normal,bv-normal,av-normal]
    prism('Candy_Stripe',[(side*p.x,p.y) for p in shape],.61,'pink' if i%2==0 else 'white',0,.012)
   for x in [.43]:
    cylinder('Peppermint',(side*x,-.42,4.12),.30,.16,'white',12,'Y')
    gem('Peppermint_Core',(side*x,-.55,4.12),(.21,.04,.21),'pink')
  for z in [.30,2.80]:
   pair_prism('Wrapper_Fin',[(.15,z+.1),(.54,z+.31),(.41,z),(.56,z-.22),(.15,z-.1)],.42,'tealLight')
 elif tier==10:
  shaft('violet','purple','magenta')
  colors=['purple','blue','cyan','green','yellow','red']
  for side in [-1,1]:
   for i,c in enumerate(colors):
    x=.28+i*.365
    top=4.40-.085*i-.03*i*i
    bottom=top-.47
    loft('Rainbow_Step',[(x,top,bottom,.34),(x+.36,top-.06,bottom-.06,.34)],c,side)
   loft('Rainbow_Tip',[(2.46,3.40,3.10,.30),(2.67,3.12,3.05,.035)],'magenta',side)
  for i,c in enumerate(colors): box('Spectrum_Grip',(0,0,.64+i*.38),(.55,.57,.20),c)
  star('Rainbow_Star',(0,-.44,4.0),.32,.15,'white',4)
  gem('Rainbow_Pommel',(0,0,.08),(.39,.33,.36),'cyan')
 elif tier==11:
  shaft('cyanDeep','navy','lavender')
  wings([(.27,4.2,3.76,.4),(.9,4.32,3.71,.4),(1.5,4.22,3.72,.32),(2.52,3.72,3.65,.03)],'cyan',True)
  for side in [-1,1]:
   for x,z,h,c in [(.55,4.25,.82,'lavender'),(1.10,4.15,.59,'cyanLight'),(1.6,4.03,.42,'purple')]:
    gem('Crystal_Spire',(side*x,0,z+.23),(.24,.31,h),c)
   gem('Floating_Shard',(side*.84,0,5.24),(.12,.15,.22),'lavender')
  gem('Floating_Center',(0,0,5.48),(.15,.18,.28),'cyanLight')
  core('lavender',.24)
 elif tier==12:
  shaft('black','redDark','orange')
  shape=[(.28,4.17),(.70,4.62),(1.30,4.67),(2.05,4.46),(2.48,4.01),(2.48,3.62),(2.11,3.19),(2.23,3.77),(1.83,4.06),(1.04,4.18),(.30,3.77)]
  pair_prism('Obsidian_Horn',shape,.66,'black')
  pair_prism('Red_Blade_Edge',[(.53,4.57),(1.31,4.58),(2.04,4.36),(2.40,3.99),(2.14,3.60),(2.2,3.96),(1.8,4.19),(1.0,4.27)],.025,'red',-.345,0)
  for side in [-1,1]:
   prism('Top_Horn',[(side*.20,4.35),(side*.47,4.94),(side*.60,4.35)],.45,'black',0,0)
   prism('Lava_Seam',[(side*.90,4.51),(side*.97,4.53),(side*1.17,4.2),(side*1.1,4.17)],.018,'orange',-.369,0)
  core('orange',.36)
  for z in [1.1,1.8,2.5]: box('Crimson_Armor',(0,0,z),(.5,.56,.28),'redDark')
 elif tier==13:
  shaft('black','neon','neon')
  for side in [-1,1]:
   for i,(x,z,w) in enumerate([(.60,4.12,.54),(1.20,4.13,.45),(1.75,3.98,.40),(2.17,3.69,.32)]):
    box('Pixel_Armor',(side*x,0,z),(w,.65,.49),'black')
    box('Pixel_Edge',(side*x,-.338,z+.28),(w,.05,.11),'neon',.004)
   pair_prism('Digital_Tip',[(2.20,3.90),(2.55,3.94),(2.48,3.66),(2.7,3.50),(2.25,3.58)],.50,'neon')
   break
  # Open frame around the inset reactor, visible gaps between outer pixel blocks.
  for x in [-.40,.40]: box('Circuit_Frame',(x,0,4.12),(.16,.78,.79),'steelDark')
  for z in [3.78,4.46]: box('Circuit_Frame',(0,0,z),(.65,.78,.14),'steelDark')
  box('Reactor',(0,0,4.12),(.44,.56,.44),'neon')
  for side in [-1,1]: box('Circuit_Shaft',(0,side*.245,1.78),(.09,.022,2.0),'neon',.002)
  for side in [-1,1]: box('Floating_Pixel',(side*1.45,0,4.62),(.20,.30,.20),'neon',.008)
 elif tier==14:
  shaft('teal','silver','emerald')
  wings([(.43,4.04,3.72,.35),(.95,4.07,3.70,.31),(1.55,3.95,3.58,.26),(2.38,3.41,3.35,.045)],'silver')
  pair_prism('Alien_Cutting_Edge',[(.55,3.74),(1.55,3.60),(2.4,3.37),(1.75,3.46),(.55,3.59)],.65,'tealLight',0,.01)
  cylinder('Saucer',(0,0,4.14),.87,.22,'steelDark',16)
  ring('Saucer_Rim',(0,0,4.15),.78,.115,'silver','Z')
  sphere('Alien_Dome',(0,0,4.40),(.48,.48,.40),'emerald')
  cylinder('Dome_Base',(0,0,4.26),.58,.13,'tealLight',16)
  for z in [.6,1.3,2.0,2.7]: cylinder('Alien_Collar',(0,0,z),.31,.15,'tealLight',12)
 elif tier==15:
  shaft('violet','black','darkPurple')
  shape=[(.28,4.19),(.77,4.63),(1.56,4.75),(2.3,4.32),(2.61,3.75),(2.34,3.28),(2.35,3.86),(1.89,4.12),(1.1,4.10),(.3,3.75)]
  pair_prism('Void_Jaw',shape,.73,'darkPurple')
  pair_prism('Void_Crest',[(.72,4.64),(1.5,4.75),(2.25,4.33),(2.1,4.20),(1.39,4.52),(.75,4.48)],.77,'purple')
  for side in [-1,1]:
   for x,z in [(.85,4.12),(1.32,4.14),(1.82,4.04),(2.23,3.81)]:
    prism('Void_Fang',[(side*(x-.13),z),(side*x,z-.39),(side*(x+.13),z)],.45,'ivory',0,0)
   box('Floating_Armor',(side*1.78,0,4.93),(.34,.42,.20),'black')
  star('Void_Frame',(0,0,4.07),.61,.44,'black',6,.87)
  core('magenta',.33,z=4.07,y=-.49)
  for z in [1.0,1.65,2.3]: box('Void_Grip',(0,0,z),(.53,.58,.27),'purple')
 elif tier==16:
  shaft('navy','silver','ice',.5)
  pair_prism('Dragon_Wing',[(.26,4.17),(.86,4.52),(1.56,4.55),(2.14,4.26),(2.72,3.70),(2.0,3.92),(1.0,4.05),(.26,3.69)],.75,'blue')
  pair_prism('Ice_Wing_Layer',[(.56,4.21),(1.34,4.47),(1.97,4.22),(2.60,3.76),(1.80,4.04),(.59,3.99)],.045,'cyanLight',-.407,0)
  for side in [-1,1]:
   for x,z in [(.88,4.01),(1.35,4.01),(1.80,3.93),(2.15,3.86)]:
    prism('Ice_Tooth',[(side*(x-.12),z),(side*x,z-.37),(side*(x+.13),z)],.45,'ice',0,0)
   gem('Dragon_Crown',(side*.34,0,4.58),(.22,.31,.53),'cyan')
  core('cyanLight',.31)
  for z in [1.0,1.65,2.3]:
   prism('Scale_Armor',[(-.3,z+.2),(0,z-.13),(.3,z+.2),(.25,z+.34),(-.25,z+.34)],.64,'blue',0,.014)
 elif tier==17:
  shaft('violet','gold','cyan')
  shape=[(.28,4.13),(.82,4.64),(1.53,4.59),(2.29,4.22),(2.67,3.71),(2.23,3.92),(1.32,4.0),(.32,3.67)]
  pair_prism('Cosmic_Blade',shape,.75,'purple')
  pair_prism('Nebula_Inlay',[(.72,4.45),(1.3,4.52),(2.07,4.17),(1.53,4.23),(1.07,4.03),(.63,4.08)],.022,'magenta',-.39,0)
  sphere('Planet_Reactor',(0,0,4.13),(.62,.54,.62),'cyan')
  ring('Golden_Orbit',(0,0,4.13),.84,.08,'gold','Y',math.radians(24))
  for side in [-1,1]: star('Star_Tip',(side*2.45,0,3.83),.26,.12,'gold',4,.60)
  star('Star_Pommel',(0,0,.07),.46,.22,'gold',6,.51)
  core('cyanLight',.22,z=.08,y=-.28)
  for z in [1.0,1.75,2.5]: box('Cosmic_Band',(0,0,z),(.57,.61,.17),'cyan')
 elif tier==18:
  shaft('ivory','gold','gold',.50)
  pair_prism('Golden_Wing',[(.26,4.15),(.75,4.65),(1.48,4.96),(2.20,4.70),(2.75,4.11),(2.54,3.45),(2.38,4.01),(1.59,4.29),(.31,3.75)],.77,'gold')
  for side in [-1,1]:
   for i in range(4):
    x=.50+i*.48;z=4.57-.09*i
    prism('Ivory_Feather',[(side*x,z),(side*(x+.55),z+.27),(side*(x+.95),z-.17),(side*(x+.35),z-.08)],.06,'white',-.427,.012)
  ring('Outer_Halo',(0,.20,4.21),1.05,.065,'gold','Y')
  ring('Inner_Halo',(0,.20,4.21),.78,.057,'goldLight','Y')
  star('Star_Socket',(0,0,4.11),.68,.35,'gold',8,.84)
  star('Celestial_Core',(0,-.47,4.11),.47,.19,'cyan',8,.12)
  star('Celestial_Core_Back',(0,.47,4.11),.47,.19,'cyan',8,.12)
  gem('Star_Gem',(0,-.59,4.11),(.22,.09,.27),'cyanLight')
  star('Ultimate_Pommel',(0,0,.12),.51,.24,'gold',8,.57)
  gem('Pommel_Gem',(0,-.34,.12),(.23,.13,.29),'cyanLight')
 else: raise ValueError(tier)
 return finish_item(tier)

def cleanup_and_uv(obj,wooden=False):
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(obj.data);bm.free();obj.data.update()
 if wooden: return
 for uv in list(obj.data.uv_layers): obj.data.uv_layers.remove(uv)
 uv=obj.data.uv_layers.new(name='StudsUV')
 uv.active_render=True
 for p in obj.data.polygons:
  normal=obj.matrix_world.to_3x3() @ p.normal
  major=max(range(3),key=lambda i:abs(normal[i]))
  axes=[i for i in range(3) if i!=major]
  index=p.material_index
  for loop in p.loop_indices:
   co=obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
   a=(co[axes[0]]+3.0)/6
   b=(co[axes[1]]+.25)/6 if axes[1]==2 else (co[axes[1]]+3)/6
   assert -.001<=a<=1.001 and -.001<=b<=1.001, (obj.name,list(co))
   uv.data[loop].uv=((index%8+(4+504*a)/512)/8,
                    ((4-index//8)+(4+504*b)/512)/5)

def finish_item(tier):
 bpy.context.view_layer.update()
 for obj in PARTS: cleanup_and_uv(obj,tier==1)
 points=[obj.matrix_world @ v.co for obj in PARTS for v in obj.data.vertices]
 tree=kdtree.KDTree(len(points))
 for i,p in enumerate(points): tree.insert(p,i)
 tree.balance()
 error=max(tree.find(Vector((-p.x,p.y,p.z)))[2] for p in points)
 assert error<1e-5, (ITEM['key'],'not symmetric',error)
 for obj in PARTS:
  bm=bmesh.new();bm.from_mesh(obj.data)
  nonmanifold=sum(not e.is_manifold for e in bm.edges)
  assert nonmanifold==0,(obj.name,nonmanifold)
  bm.free()
 # Join duplicates into a separate one-mesh export without damaging editable parts.
 bpy.ops.object.select_all(action='DESELECT')
 clones=[]
 for obj in PARTS:
  clone=bpy.data.objects.new(obj.name+'_Export',obj.data.copy())
  bpy.data.collections[EXPORT_COLLECTION].objects.link(clone)
  clone.data.transform(Matrix.Translation((0,0,-1.45)) @ obj.matrix_world)
  clone.select_set(True);clones.append(clone)
 bpy.context.view_layer.objects.active=clones[0]
 bpy.ops.object.join()
 export=bpy.context.object
 export.name='%02d_%s_Pickaxe'%(tier,ITEM['key'])
 export.data.name=export.name+'_Mesh'
 base=PARTS[0].data.materials[0].copy()
 base.name=export.name+'_Atlas'
 export.data.materials.clear();export.data.materials.append(base)
 for p in export.data.polygons: p.material_index=0
 tri=export.modifiers.new('Export_Triangles','TRIANGULATE')
 bpy.ops.object.modifier_apply(modifier=tri.name)
 export.data.calc_loop_triangles()
 uv=export.data.uv_layers.active
 for t in export.data.loop_triangles:
  a,b,c=[export.data.vertices[i].co for i in t.vertices]
  assert (b-a).cross(c-a).length>1e-9,(export.name,'zero geometry area')
  ua,ub,uc=[uv.data[i].uv for i in t.loops]
  assert abs((ub.x-ua.x)*(uc.y-ua.y)-(ub.y-ua.y)*(uc.x-ua.x))>1e-12,(export.name,'zero UV area')
 folder=PICKS/ITEM['folder']
 stem='%02d-%s-pickaxe-studs-pack-v01'%(tier,ITEM['key'].lower())
 bpy.ops.export_scene.fbx(filepath=str(folder/'exports'/ (stem+'.fbx')),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_unit_scale=False,bake_anim=False,path_mode='COPY',embed_textures=True)
 bpy.ops.export_scene.gltf(filepath=str(folder/'exports'/(stem+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='EXPORT')
 report={'tier':tier,'key':ITEM['key'],'collection':COLLECTION.name,'exportObject':export.name,
         'parts':len(PARTS),'vertices':len(export.data.vertices),'triangles':len(export.data.loop_triangles),
         'maxMirrorError':error,'symmetryPlane':'X=0','closedMeshes':True,
         'degenerateTriangles':0,'degenerateUVTriangles':0,'stem':stem,
         'boundsMin':[min(p[i] for p in points) for i in range(3)],
         'boundsMax':[max(p[i] for p in points) for i in range(3)]}
 (folder/'models/pack-v01-model.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
 export.hide_render=True;export.hide_set(True)
 # Gallery grid: six columns, first six in the highest row.
 col=(tier-1)%6;row=(tier-1)//6
 position=Vector(((col-2.5)*6.9,0,(2-row)*6.3))
 GRIP.location=position+Vector((0,0,1.45))
 for obj in PARTS:
  obj.parent=GRIP
  obj.location.z-=1.45
 export.location=GRIP.location
 export['asset_key']=ITEM['key'];export['tier']=tier
 GRIP['export_object']=export.name
 COLLECTION['tier']=tier;COLLECTION['key']=ITEM['key']
 return report

result={'built':[]}
for tier in globals().get('BUILD_TIERS',[]): result['built'].append(build(tier))
if result['built']:
 bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'models/pickaxes-asset-pack-v01.blend'),compress=True)
