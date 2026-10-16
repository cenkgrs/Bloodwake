"""Local Bloodhound rig and authored animation workbench. No cloud generation.
Run: blender -b -t 4 --python art/bloodhound_v2/build.py
The supplied GLB is retained verbatim in source/. Outputs stay in work/ until QA.
"""
import bpy, math, json, sys, numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
HERE=Path(__file__).resolve().parent
OUT=HERE/'work';OUT.mkdir(exist_ok=True)
V=Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(HERE/'source/gunslinger_original.glb'))
scene=bpy.context.scene;scene.render.fps=60
mesh=next(o for o in scene.objects if o.type=='MESH');mesh.name='Bloodhound_Body'
mat=mesh.matrix_world.copy();mesh.parent=None;mesh.matrix_world=mat
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True);bpy.context.view_layer.objects.active=mesh
mesh.scale*=1.8/97.83905029296875
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in list(scene.objects):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
for poly in mesh.data.polygons:poly.use_smooth=True

# Rest coordinates in metres. Forward is -Y, world up is Z.
rest={};parents={}
def bone(name,a,b,parent=None):rest[name]=(V(a),V(b));parents[name]=parent
bone('Root',(0,0,0),(0,0,.15))
bone('Pelvis',(0,0,.94),(0,0,1.07),'Root')
bone('Spine',(0,0,1.07),(0,0,1.25),'Pelvis')
bone('Chest',(0,0,1.25),(0,0,1.46),'Spine')
bone('Neck',(0,0,1.46),(0,0,1.57),'Chest')
bone('Head',(0,0,1.57),(0,0,1.76),'Neck')
for side,s in [('L',1),('R',-1)]:
 bone('Clavicle.'+side,(0,0,1.44),(s*.205,0,1.44),'Chest')
 bone('UpperArm.'+side,(s*.205,0,1.44),(s*.425,-.025,1.435),'Clavicle.'+side)
 bone('Forearm.'+side,(s*.425,-.025,1.435),(s*.615,-.035,1.43),'UpperArm.'+side)
 bone('Hand.'+side,(s*.615,-.035,1.43),(s*.715,-.05,1.425),'Forearm.'+side)
 bone('WeaponSocket.'+side,(s*.615,-.035,1.43),(s*.715,-.05,1.425),'Hand.'+side)
 for digit,y in [('Index',-.085),('Middle',-.058),('Ring',-.031),('Pinky',-.006)]:
  bone(digit+'.'+side,(s*.662,y,1.43),(s*.691,y,1.425),'Hand.'+side)
  bone(digit+'Tip.'+side,(s*.691,y,1.425),(s*.726,y,1.421),digit+'.'+side)
 bone('Thigh.'+side,(s*.12,0,.94),(s*.145,-.014,.53),'Pelvis')
 bone('Shin.'+side,(s*.145,-.014,.53),(s*.158,0,.13),'Thigh.'+side)
 bone('Foot.'+side,(s*.158,0,.13),(s*.158,-.16,.055),'Shin.'+side)
 for section,y in [('Back',.14),('Side',.015)]:
  x=s*(.15 if section=='Back' else .225)
  bone('Coat'+section+'.'+side,(x,y,.99),(x+s*.06,y+.045,.64),'Pelvis')
  bone('Coat'+section+'Tip.'+side,(x+s*.06,y+.045,.64),(x+s*.11,y+.08,.31),'Coat'+section+'.'+side)
bone('Scarf',(0,.10,1.51),(.24,.18,1.30),'Chest')
bone('ScarfTip',(.24,.18,1.30),(.44,.29,1.02),'Scarf')
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='Bloodhound_Rig';rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(a,b) in rest.items():
 eb=rig.data.edit_bones.new(name);eb.head=a;eb.tail=b
 eb.align_roll(V((0,-1,0)) if abs((b-a).normalized().z)>.9 else V((0,0,1)))
 if parents[name]:eb.parent=rig.data.edit_bones[parents[name]]
 eb.use_deform=name!='Root'
bpy.ops.object.mode_set(mode='OBJECT')
rig['delivery_status']='IN_REVIEW_NOT_PRODUCTION_READY'
rig['open_items']='Provisional handheld weapons; holstered source geometry; full clothing collision review; high-speed locomotion art review'
rig.animation_data_create()
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'

# Smooth region-constrained weights. Cloth is deliberately excluded from legs
# and arms: nearest-bone weighting alone pulls the coat through the thighs.
groups={n:mesh.vertex_groups.new(name=n) for n in rest if n!='Root'}
def segment_dist(p,a,b):
 t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared));return (p-(a+t*(b-a))).length
def assign(index,weights):
 total=sum(weights.values())
 for n,w in weights.items():
  if w/total>.001:groups[n].add([index],w/total,'REPLACE')
regions={}
for vert in mesh.data.vertices:
 x,y,z=vert.co;side='L' if x>0 else 'R';ax=abs(x)
 scarf=(x>.19 and y>.10 and 0.88<z<1.43) or (y>.135 and z>1.38)
 coat=(.27<z<.995 and (y>.098 or ax>.215+(.99-z)*.125))
 if scarf:
  names=['Scarf','ScarfTip'];region='scarf'
 elif coat:
  part='Back' if y>.105 else 'Side'
  names=['Coat'+part+'.'+side,'Coat'+part+'Tip.'+side,'Pelvis'];region='coat'
 elif z>1.545:names=['Head','Neck'];region='head'
 elif ax>.66 and z>1.32:
  digit=min([('Index',-.085),('Middle',-.058),('Ring',-.031),('Pinky',-.006)],key=lambda pair:abs(y-pair[1]))[0]
  names=['Hand.'+side,digit+'.'+side,digit+'Tip.'+side];region='finger'
 elif ax>.22 and z>1.32:names=['UpperArm.'+side,'Forearm.'+side,'Hand.'+side];region='arm'
 elif z<.96:names=['Thigh.'+side,'Shin.'+side,'Foot.'+side,'Pelvis'];region='leg'
 else:names=['Pelvis','Spine','Chest','Neck','Clavicle.'+side];region='torso'
 # Exponential weights avoid tiny influences stretching remote cloth points.
 dist={n:segment_dist(vert.co,*rest[n]) for n in names};minimum=min(dist.values())
 softness=.065 if region in ['arm','leg'] else .085
 weights={n:math.exp(-(d-minimum)/softness*3) for n,d in dist.items()}
 if region=='head' and z>1.62:weights={'Head':1}
 assign(vert.index,weights);regions[vert.index]=region
# Smooth weights across the actual surface (including UV-duplicated vertices).
# This removes abrupt region boundaries without altering mesh/UV topology.
coords=np.array([v.co[:] for v in mesh.data.vertices])
_,inverse=np.unique(np.round(coords,5),axis=0,return_inverse=True)
edges=np.array([[inverse[e.vertices[0]],inverse[e.vertices[1]]] for e in mesh.data.edges])
edges=np.unique(np.sort(edges,axis=1),axis=0)
count=int(inverse.max())+1;names=list(groups);weights=np.zeros((count,len(names)),dtype=np.float32)
counts=np.bincount(inverse,minlength=count).astype(np.float32)
for v in mesh.data.vertices:
 for g in v.groups:weights[inverse[v.index],g.group]+=g.weight
weights/=counts[:,None]
degree=np.bincount(edges.ravel(),minlength=count).astype(np.float32)
for _ in range(24):
 sums=np.zeros_like(weights)
 np.add.at(sums,edges[:,0],weights[edges[:,1]]);np.add.at(sums,edges[:,1],weights[edges[:,0]])
 weights=weights*.45+sums/np.maximum(1,degree[:,None])*.55
weights/=np.maximum(weights.sum(axis=1,keepdims=True),.000001)
for g in mesh.vertex_groups:g.remove(list(range(len(mesh.data.vertices))))
for v in mesh.data.vertices:
 row=weights[inverse[v.index]];indices=np.argsort(row)[-4:];total=sum(row[i] for i in indices)
 for i in indices:
  if row[i]>.001:groups[names[i]].add([v.index],float(row[i]/total),'REPLACE')
mesh.parent=rig
mod=mesh.modifiers.new('Bloodhound skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True

# Evaluation helper: set global bone transforms from anatomical joint targets.
# Use a shortest-arc swing from rest, which preserves authored bone roll.
def aim_matrix(name,a,b):
 ra,rb=rest[name];q=(rb-ra).rotation_difference(b-a)
 m=q.to_matrix().to_4x4()@rig.data.bones[name].matrix_local
 m.translation=a;return m
def ik(a,c,l1,l2,pole):
 delta=c-a;d=min(max(delta.length,.001),l1+l2-.0001);axis=delta.normalized()
 t=(l1*l1-l2*l2+d*d)/(2*d);h=math.sqrt(max(0,l1*l1-t*t))
 bend=pole-axis*pole.dot(axis)
 if bend.length<.001:bend=V((0,-1,0))
 return a+axis*t+bend.normalized()*h
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def interp(f,keys):
 for i in range(len(keys)-1):
  a,v=keys[i];b,w=keys[i+1]
  if f<=b:return v+(w-v)*smooth((f-a)/(b-a))
 return keys[-1][1]
def pose(f,name):
 # Low, stable stance; ankles remain on their targets while the pelvis breathes.
 length={'BH_Idle':72,'BH_Walk_InPlace':32,'BH_GetHit':18,'BH_Death':60,'BH_FiveShot':42,'BH_BombThrow':50,'BH_Ultimate_BloodWake':108}[name]
 phase=math.tau*(f-1)/(length-1)
 hip=V((0,0,.90));lean=.025;turn=0;drop=0;fall=0
 feet={s:V((sg*.17,-.015,.13)) for s,sg in [('L',1),('R',-1)]}
 hands={s:V((sg*.265,-.075,1.0)) for s,sg in [('L',1),('R',-1)]}
 dirs={s:V((0,-.2,-1)).normalized() for s in ['L','R']}
 if name=='BH_Idle':hip.z+=.004*math.sin(phase);lean+=.003*math.sin(phase)
 if name=='BH_Walk_InPlace':
  hip.z-=.012*(1-math.cos(2*phase));lean=.055
  for s,sg in [('L',1),('R',-1)]:
   t=((f-1)/(length-1)+(0 if s=='L' else .5))%1
   feet[s].y=-.16+.64*t if t<.5 else .16-.32*smooth((t-.5)*2)
   feet[s].z+=.07*math.sin(math.pi*(t-.5)*2) if t>=.5 else 0
   hands[s].y+=sg*.025*math.sin(phase)
 if name=='BH_GetHit':
  recoil=interp(f,[(1,0),(3,.055),(7,.09),(15,.01),(18,0)])
  lean-=recoil;hip.y-=recoil*.25;hip.z-=recoil*.2
 if name=='BH_Death':
  drop=interp(f,[(1,0),(5,.025),(22,.30),(35,.48),(42,.64),(52,.65),(60,.65)])
  hip.z-=drop;fall=interp(f,[(1,0),(22,.1),(35,.7),(42,1.5),(50,1.57),(60,1.57)])
  lean=-.10*min(1,drop*5)
 if name in ['BH_FiveShot','BH_Ultimate_BloodWake']:
  ready=interp(f,[(1,0),(8,1),(30,1),(42,0)]) if name=='BH_FiveShot' else interp(f,[(1,0),(24,1),(30,1),(82,1),(92,1),(108,0)])
  for s,sg in [('L',1),('R',-1)]:
   hands[s]=hands[s].lerp(V((sg*.23,-.37,1.38)),ready)
   dirs[s]=dirs[s].lerp(V((0,-1,0)),ready).normalized()
  if name=='BH_Ultimate_BloodWake':
   crossed=interp(f,[(1,0),(14,1),(24,1),(30,0),(108,0)])
   for s,sg in [('L',1),('R',-1)]:
    hands[s]=hands[s].lerp(V((-sg*.105,-.22 if s=='L' else -.29,1.37)),crossed)
    dirs[s]=dirs[s].lerp(V((-sg*.55,-.65,.5)).normalized(),crossed).normalized()
  fire=[10,14,18,22,26] if name=='BH_FiveShot' else list(range(30,83,6))
  for i,event in enumerate(fire):
   r=max(0,1-abs(f-event)/2.0)
   for s in (['L','R'] if name=='BH_FiveShot' and i==4 else ['R' if i%2==0 else 'L']):
    power=1.25 if name=='BH_FiveShot' and i==4 else 1
    hands[s].y+=r*.035*power;hands[s].z+=r*.024*power
   lean-=r*.012
  if name=='BH_Ultimate_BloodWake':turn=math.tau*max(0,min(1,(f-30)/52))
 if name=='BH_BombThrow':
  stages=[(1,V((.265,-.075,1.0))),(8,V((.10,-.17,1.0))),(14,V((.23,.16,1.68))),(20,V((.20,-.34,1.56))),(28,V((.12,-.22,1.55))),(38,V((.16,-.24,1.40))),(50,V((.265,-.075,1.0)))]
  for (a,p),(b,q) in zip(stages,stages[1:]):
   if a<=f<=b:hands['L']=p.lerp(q,smooth((f-a)/(b-a)));break
  dirs['L']=V((0,-1,.2)).normalized()
  lean+=interp(f,[(1,0),(14,-.07),(20,.07),(28,.045),(50,0)])
 pts={'Pelvis':(hip,hip+V((0,-lean*.25,.13))),'Spine':(hip+V((0,-lean*.25,.13)),hip+V((0,-lean*.6,.31))),'Chest':(hip+V((0,-lean*.6,.31)),hip+V((0,-lean,.52)))}
 neck=hip+V((0,-lean,.52));head=neck+V((0,0,.11))
 pts['Neck']=(neck,head);pts['Head']=(head,head+V((0,0,.19)))
 for side,s in [('L',1),('R',-1)]:
  shoulder=hip+V((s*.205,-lean,.50));pts['Clavicle.'+side]=(hip+V((0,-lean,.50)),shoulder)
  wrist=hands[side]
  if name=='BH_Death':wrist=hip+V((s*.30,-.07,.02))
  elbow=ik(shoulder,wrist,.22,.19,V((s*.5,.3,-1)))
  pts['UpperArm.'+side]=(shoulder,elbow);pts['Forearm.'+side]=(elbow,wrist);pts['Hand.'+side]=(wrist,wrist+dirs[side]*.1)
  thigh=hip+V((s*.12,0,0));ankle=feet[side]
  knee=ik(thigh,ankle,.4109,.401,V((0,-1,0)))
  pts['Thigh.'+side]=(thigh,knee);pts['Shin.'+side]=(knee,ankle);pts['Foot.'+side]=(ankle,ankle+V((0,-.16,-.075)))
 for n in rest:
  if n.startswith('Coat'):
   ra,rb=rest[n];s=1 if n.endswith('L') else -1
   shift=hip-V((0,0,.94))
   # Cloth moves away from the legs, with a small delayed flutter.
   flutter=.015*math.sin(phase-.7) if name in ['BH_Idle','BH_Walk_InPlace'] else .014*math.sin(f*.18)*math.sin(math.pi*(f-1)/(length-1))
   spread=.065 if name=='BH_Walk_InPlace' else .035
   if name=='BH_Ultimate_BloodWake':spread+=.06*math.sin(math.pi*max(0,min(1,(f-24)/68)))
   pts[n]=(ra+shift+V((s*spread*.3,.025,0)),rb+shift+V((s*spread,.055+flutter,.015)))
  if n.startswith('Scarf'):
   ra,rb=rest[n];shift=hip-V((0,0,.94));flutter=.018*math.sin(phase-.9) if name in ['BH_Idle','BH_Walk_InPlace'] else .03*math.sin(f*.16)*math.sin(math.pi*(f-1)/(length-1))
   pts[n]=(ra+shift,rb+shift+V((flutter,.045,flutter*.5)))
 # Whole-body turn occurs on the root in world Z; root translation stays fixed.
 world=Matrix.Rotation(turn,4,'Z')
 if name=='BH_Ultimate_BloodWake':world=Matrix.Translation(V((.17,-.015,0)))@world@Matrix.Translation(V((-.17,.015,0)))
 if name=='BH_Death':
  pivot=hip;world=Matrix.Translation(pivot)@Matrix.Rotation(fall,4,'Y')@Matrix.Translation(-pivot)
 matrices={n:aim_matrix(n,*pts[n]) for n in pts}
 if name=='BH_Idle':
  pivot=matrices['Head'].translation.copy()
  matrices['Head']=Matrix.Translation(pivot)@Matrix.Rotation(.035*math.sin(phase),4,'Z')@Matrix.Translation(-pivot)@matrices['Head']
 matrices['Root']=rig.data.bones['Root'].matrix_local.copy()
 for n in matrices:matrices[n]=world@matrices[n]
 if name=='BH_Death':
  settle=smooth((f-30)/16)
  for n in list(matrices):
   if not n.startswith(('Coat','Scarf')):continue
   a=matrices[n].translation.copy();b=matrices[n]@V((0,(rest[n][1]-rest[n][0]).length,0))
   # Cloth tails settle beside the body rather than propping it above the floor.
   a.z=max(a.z,.28*settle);b.z=b.z*(1-settle)+.28*settle
   matrices[n]=aim_matrix(n,a,b)
 matrices['Root']=rig.data.bones['Root'].matrix_local.copy()
 return matrices

def set_pose(matrices):
 for b in rig.pose.bones:
  if b.name in matrices:b.matrix=matrices[b.name]
  bpy.context.view_layer.update()
 # Curl the fingers around a rigid grip, preserving the imported glove surface.
 for side,s in [('L',1),('R',-1)]:
  hand=rig.pose.bones['Hand.'+side]
  hand_delta=hand.matrix@rig.data.bones[hand.name].matrix_local.inverted()
  for digit in ['Index','Middle','Ring','Pinky']:
   parent_matrix=hand_delta
   for suffix,angle in [('',55 if digit=='Index' else 72),('Tip',68)]:
    name=digit+suffix+'.'+side;a,b=rest[name]
    curl=Matrix.Translation(a)@Matrix.Rotation(math.radians(s*angle),4,'Y')@Matrix.Translation(-a)
    m=parent_matrix@curl@rig.data.bones[name].matrix_local
    rig.pose.bones[name].matrix=m;bpy.context.view_layer.update()
    parent_matrix=m@rig.data.bones[name].matrix_local.inverted()
  rig.pose.bones['WeaponSocket.'+side].matrix=hand.matrix.copy();bpy.context.view_layer.update()

# Rigid socket props. Grip and barrel are in hand bone coordinates, so there is
# no skin stretch or per-frame drift between the hand and the revolver.
def material(name,color,metallic):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=.38
 return m
steel=material('BH blued steel',(.035,.043,.049),.85);brass=material('BH aged brass',(.33,.19,.055),.75);wood=material('BH walnut grips',(.085,.025,.014),0)
def weapon(side):
 parts=[]
 def part(name,loc,size,mat,cylinder=False):
  if cylinder:
   bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=size[0],depth=size[1]);o=bpy.context.object;o.rotation_euler.x=math.pi/2
  else:
   bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.scale=size
  # Offset measured in posed glove coordinates; the source palm is not centred
  # on the wrist joint. Both handed offsets are needed for physical grip contact.
  o.location=V(loc)+V((.068 if side=='L' else -.073,.035,-.033));o.data.materials.append(mat);o.name=name
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);parts.append(o)
 part('Frame',(0,.07,.055),(.034,.083,.045),brass)
 part('Cylinder',(0,.083,.063),(.028,.051),steel,True)
 part('Barrel',(0,.168,.068),(.012,.125),steel,True)
 part('Grip',(0,.037,.003),(.03,.037,.080),wood)
 part('Sight',(0,.216,.085),(.006,.012,.009),brass)
 part('Hammer',(0,.027,.075),(.012,.018,.020),steel)
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name='Revolver.'+side
 transform=rig.data.bones['Hand.'+side].matrix_local
 for v in o.data.vertices:v.co=transform@v.co
 g=o.vertex_groups.new(name='WeaponSocket.'+side);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 mod=o.modifiers.new('Rigid hand socket','ARMATURE');mod.object=rig;o.parent=rig
 return o
weapons=[weapon('L'),weapon('R')]

# Preview-only grenade objects are separate from the character export. A keyed
# rig property drives the held/flight preview when the BombThrow action is chosen.
rig['bomb_phase']=0.0
vfx=bpy.data.collections.new('BH_VFX_Preview');scene.collection.children.link(vfx)
def driver(obj,path,index,expression):
 fc=obj.driver_add(path,index);d=fc.driver;var=d.variables.new();var.name='phase'
 var.targets[0].id=rig;var.targets[0].data_path='["bomb_phase"]';d.expression=expression
def grenade(name):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.035)
 o=bpy.context.object;o.name=name;o.data.materials.append(brass)
 for c in list(o.users_collection):c.objects.unlink(o)
 vfx.objects.link(o);return o
held=grenade('BH_Bomb_Held')
for v in held.data.vertices:v.co=rig.data.bones['Hand.L'].matrix_local@(v.co+V((.068,.072,-.03)))
g=held.vertex_groups.new(name='Hand.L');g.add(list(range(len(held.data.vertices))),1,'REPLACE')
held.parent=rig;mod=held.modifiers.new('Held bomb socket','ARMATURE');mod.object=rig
for i in range(3):driver(held,'scale',i,'1 if phase>=8 and phase<20 else 0')
flight=grenade('BH_Bomb_Flight')
for i in range(3):driver(flight,'scale',i,'1 if phase>=20 and phase<=50 else 0')
driver(flight,'location',0,'.26')
driver(flight,'location',1,'-.4-2.6*max(0,phase-20)/30')
driver(flight,'location',2,'1.5+1.4*max(0,phase-20)/30-2.85*(max(0,phase-20)/30)**2')

actions={};ranges={'BH_Idle':72,'BH_Walk_InPlace':32,'BH_GetHit':18,'BH_Death':60,'BH_FiveShot':42,'BH_BombThrow':50,'BH_Ultimate_BloodWake':108}
for name,end in ranges.items():
 action=bpy.data.actions.new(name);action.use_fake_user=True
 samples=[];rig.animation_data.action=None
 for frame in range(1,end+1):
  set_pose(pose(frame,name))
  if name=='BH_Death':
   dg=bpy.context.evaluated_depsgraph_get();evaluated=mesh.evaluated_get(dg)
   floor=min(v.co.z for v in evaluated.data.vertices if regions.get(v.index) not in ['coat','scarf'])
   if floor<0:
    corrected={b.name:b.matrix.copy() for b in rig.pose.bones}
    for n,m in corrected.items():
     if n!='Root':m.translation.z-=floor
    for b in rig.pose.bones:b.matrix=corrected[b.name];bpy.context.view_layer.update()
   # Contact correction is local to cloth bones, not a lift of the whole body.
   # Detect actual deformed cloth points during the kneeling transition too.
   for _ in range(6):
    evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());lift={}
    for vertex in evaluated.data.vertices:
     if vertex.co.z>=.001:continue
     source=mesh.data.vertices[vertex.index]
     if not source.groups:continue
     group=max(source.groups,key=lambda g:g.weight);bn=mesh.vertex_groups[group.group].name
     if bn.startswith(('Coat','Scarf')):lift[bn]=max(lift.get(bn,0),min(.06,(.001-vertex.co.z)/max(.2,group.weight)))
    if not lift:break
    corrected={b.name:b.matrix.copy() for b in rig.pose.bones}
    for bn,delta in lift.items():corrected[bn].translation.z+=delta
    for b in rig.pose.bones:b.matrix=corrected[b.name];bpy.context.view_layer.update()
  rig.pose.bones['WeaponSocket.L'].scale=V((.001,)*3) if name=='BH_BombThrow' else V((1,)*3)
  samples.append({b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones})
 rig.animation_data.action=action
 previous={}
 for f,sample in enumerate(samples,1):
  rig['bomb_phase']=float(f) if name=='BH_BombThrow' else 0.0
  rig.keyframe_insert(data_path='["bomb_phase"]',frame=f,group='Preview Events')
  for b in rig.pose.bones:
   b.location,q,b.scale=sample[b.name]
   if b.name in previous and q.dot(previous[b.name])<0:q=-q
   b.rotation_quaternion=q;previous[b.name]=q.copy()
   b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
   if b.name.startswith('WeaponSocket'):b.keyframe_insert('scale',frame=f,group=b.name)
 actions[name]=action
 print('BAKED',name,flush=True)
for name,events in {'BH_FiveShot':[(f'FIRE_{i+1:02}',f) for i,f in enumerate([10,14,18,22,26])],'BH_BombThrow':[('THROW_RELEASE',20)],'BH_Ultimate_BloodWake':[(f'ULT_FIRE_{i+1:02}',f) for i,f in enumerate(range(30,83,6))]}.items():
 for label,f in events:actions[name].pose_markers.new(label).frame=f
rig.animation_data.action=actions['BH_Idle'];scene.frame_set(1);scene.frame_start=1;scene.frame_end=72
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.25,.25,.25)
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
center=V((0,0,.9))
for pos in [(-3,-4,5),(3,-2,3),(0,3,4)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=350;o.data.size=4;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.5,-5,2.1));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.3;scene.camera=cam
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Bloodhound_Rig_WIP.blend'))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True)
for o in weapons:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'Bloodhound_Rig_WIP.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
for name,frame in [('BH_Idle',1),('BH_Walk_InPlace',9),('BH_FiveShot',18),('BH_BombThrow',14),('BH_Death',60),('BH_Ultimate_BloodWake',54)]:
 if '--skip-render' in sys.argv:break
 rig.animation_data.action=actions[name];scene.frame_set(frame)
 scene.render.filepath=str(HERE/'qa'/f'{name}_{frame:03}.png');bpy.ops.render.render(write_still=True)
print('RIG_WIP_READY',flush=True)
