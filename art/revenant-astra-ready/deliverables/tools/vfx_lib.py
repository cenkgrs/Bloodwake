import bpy,math
from mathutils import Vector
from pathlib import Path

def material(name,color,emission=0):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.38;p.inputs['Metallic'].default_value=.35;p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission;return m

def build():
 col=bpy.data.collections.get('REV_VFX_PROXY')
 if col:
  for o in list(col.objects):bpy.data.objects.remove(o,do_unlink=True)
 else:col=bpy.data.collections.new('REV_VFX_PROXY');bpy.context.scene.collection.children.link(col)
 red=material('VFX • Crimson',(.63,.006,.023),2);hot=material('VFX • Hot core',(1,.028,.04),4);dark=material('VFX • Obsidian',(.025,.003,.009),.2);tele=material('VFX • Telegraph',(.38,.008,.015),1)
 def move(o):
  for c in list(o.users_collection):c.objects.unlink(o)
  col.objects.link(o);return o
 def line(name,points,width,mat,cyclic=False):
  cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=width;cu.bevel_resolution=2;sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
  for p,co in zip(sp.points,points):p.co=(*co,1)
  sp.use_cyclic_u=cyclic;o=bpy.data.objects.new(name,cu);col.objects.link(o);o.data.materials.append(mat);return o
 ring=lambda radius:[(math.cos(i*math.tau/128)*radius,math.sin(i*math.tau/128)*radius,.015) for i in range(128)]
 line('ULT_Telegraph',ring(2.25),.012,tele,True);line('ULT_Falloff',ring(2.9),.008,dark,True);line('ULT_Shockwave',ring(1),.026,hot,True)
 for i in range(12):
  a=i*math.tau/12;pts=[]
  for j in range(18):
   t=j/17;r=(1-t)*2.5+.09;angle=a+t*.7;pts.append((math.cos(angle)*r,math.sin(angle)*r,.04+.94*t+.13*math.sin(t*math.pi)))
  line(f'ULT_Thread_{i:02}',pts,.004 if i%2 else .007,red)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=.09,location=(-.12,-.31,1.26));o=move(bpy.context.object);o.name='ULT_Core';o.data.materials.append(hot)
 for i in range(8):
  a=i*math.tau/8;verts=[];faces=[]
  for j in range(8):
   t=j/7;rad=.38+2.3*t;angle=a+.10*math.sin(t*5+i);pos=Vector((math.cos(angle)*rad,math.sin(angle)*rad,.1+.95*t+.26*math.sin(t*math.pi)))
   width=(.085*(1-t)+.002)*(1+.3*math.sin(t*13));tangent=Vector((-math.sin(angle),math.cos(angle),0))
   for k in range(5):verts.append(tuple(pos+tangent*math.cos(k*math.tau/5)*width+Vector((0,0,math.sin(k*math.tau/5)*width))))
  for j in range(7):
   for k in range(5):faces.append((j*5+k,j*5+(k+1)%5,(j+1)*5+(k+1)%5,(j+1)*5+k))
  me=bpy.data.meshes.new('Organic spear');me.from_pydata(verts,[],faces);o=bpy.data.objects.new(f'ULT_Spear_{i:02}',me);col.objects.link(o);o.data.materials.append(red)
  for j in range(3):
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.02+.007*j,location=(math.cos(a)*(.6+j*.4),math.sin(a)*(.6+j*.4),.15+j*.16));o=move(bpy.context.object);o.name=f'ULT_Ember_{i:02}_{j}';o.data.materials.append(hot if j%2 else dark)
 line('TP_Crimson_Path',[(0,y,.035) for y in [0,-.3,-.8,-1.2,-2,-3]],.012,hot)
 for i in range(4):line(f'TP_Ribbon_{i}',[(.04*i+.02*math.sin(t*2),-3*t,.06+.045*i+.07*math.sin(t*8+i)) for t in [j/20 for j in range(21)]],.012,dark)
 verts=[];faces=[]
 for j in range(41):
  t=j/40;a=math.pi+t*math.pi;width=.002+.037*math.sin(t*math.pi)
  for rr in [.58-width,.58+width]:verts.append((rr*math.cos(a),-.28+rr*math.sin(a),1.1+.04*math.sin(a)))
 for j in range(40):faces.append((j*2,j*2+1,j*2+3,j*2+2))
 me=bpy.data.meshes.new('Single tapered crescent');me.from_pydata(verts,[],faces);o=bpy.data.objects.new('TP_Slash',me);col.objects.link(o);o.data.materials.append(hot)
 for i in range(6):line(f'TP_Body_Strip_{i}',[(.08*(i-2.5)+.04*math.sin(t*6+i),.09+t*.15,.2+t*1.4) for t in [j/16 for j in range(17)]],.016,red if i%3==0 else dark)
 r=bpy.data.objects['REV_Rig'];inv=r.data.bones['hand_r'].matrix_local.inverted()
 for i,finger in enumerate(['index','middle','ring','pinky']):
  pts=[tuple(inv@r.data.bones[f'{finger}_{j:02}_r'].head_local) for j in (1,2,3)]
  end=Vector(pts[-1])+(Vector(pts[-1])-Vector(pts[-2]))*1.5;pts.append(tuple(end));line(f'CLAW_Glow_{i}',pts,.003,hot)
 # The proxies are deliberately separate from the deform mesh and export rig.
 for o in col.objects:o['proxy_only']=True
 return col

def apply(kind,f,keyframe=None):
 col=bpy.data.collections['REV_VFX_PROXY']
 def interval(a,b):return a<=f<=b
 for o in col.objects:
  n=o.name;vis=False;scale=1.0
  if n.startswith('CLAW'):
   vis=not (kind=='REV_TeleportAttack' and 16<=f<=21) and not (kind=='REV_Death' and f>=25)
   scale=max(.001,1-(f-12)/13) if kind=='REV_Death' and f>=12 else 1
   o.matrix_world=bpy.data.objects['REV_Rig'].pose.bones['hand_r'].matrix.copy()
  if kind=='REV_BloodBurst':
   if n=='ULT_Telegraph':vis=interval(19,60)
   elif n=='ULT_Falloff':vis=interval(19,100)
   elif n=='ULT_Shockwave':vis=interval(60,84);scale=.25+2.65*max(0,min(1,(f-60)/20))
   elif n.startswith('ULT_Thread'):vis=interval(20,51);scale=max(.10,1-(f-20)/39)
   elif n=='ULT_Core':vis=interval(43,61);scale=.65+max(0,59-f)*.035 if f<60 else 1.1
   elif n.startswith('ULT_Spear'):
    i=int(n[-2:]);vis=interval(60,99);grow=max(.002,min(1,(f-59)/11));fade=1 if f<85 else max(.01,(100-f)/15);scale=grow*fade*(1+.08*math.sin(i*1.8))
   elif n.startswith('ULT_Ember'):
    i=int(n.split('_')[-2]);j=int(n[-1]);vis=interval(83+j*2,101+j*3);scale=max(.01,(110-f)/20)
  if kind=='REV_TeleportAttack':
   if n=='TP_Crimson_Path' or n.startswith('TP_Ribbon'):vis=interval(16,23)
   elif n=='TP_Slash':vis=interval(26,29);scale=1+(f-26)*.07
   elif n.startswith('TP_Body'):vis=interval(11,15) or interval(22,24);scale=.75 if f<16 else 1
  if n.startswith('ULT_Thread'):o.location=Vector((0,-.23,1.2))*(1-scale)
  o.hide_render=not vis;o.hide_viewport=not vis;o.scale=(scale,scale,scale)
  if keyframe is not None:
   o.keyframe_insert('location',frame=keyframe);o.keyframe_insert('hide_render',frame=keyframe);o.keyframe_insert('hide_viewport',frame=keyframe);o.keyframe_insert('scale',frame=keyframe)
 m=bpy.data.objects['REV_Body'];m.hide_render=kind=='REV_TeleportAttack' and 16<=f<=21
 if keyframe is not None:m.keyframe_insert('hide_render',frame=keyframe)
