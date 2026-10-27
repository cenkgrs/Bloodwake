import bpy,math,json
from mathutils import Vector,Matrix,Euler,Quaternion
from pathlib import Path
D=Path(__file__).resolve().parents[1]
TAU=math.tau
r=None;P=None;R=None;s=None

def init():
 global r,P,R,s
 s=bpy.context.scene;r=bpy.data.objects['REV_Rig'];P=r.pose.bones;R={b.name:b.matrix_local.copy() for b in r.data.bones}
 if not r.animation_data:r.animation_data_create()
 r.animation_data.action=None
 for b in P:b.rotation_mode='QUATERNION'

def rot(x=0,y=0,z=0):return Euler(tuple(math.radians(v) for v in (x,y,z)),'XYZ').to_matrix().to_4x4()
def curve(f,keys,kind='cubic',period=None):
 if period:f=(f-1)%period+1
 if f<=keys[0][0]:return keys[0][1]
 if f>=keys[-1][0]:return keys[-1][1]
 for i in range(len(keys)-1):
  a,v=keys[i];b,w=keys[i+1]
  if a<=f<=b:
   t=(f-a)/(b-a)
   if kind=='hold':return v
   if kind=='linear':return v+(w-v)*t
   # Nonuniform Hermite slopes. Different authored knots create distinct accelerations.
   p,q=keys[max(0,i-1)];c,d=keys[min(len(keys)-1,i+2)]
   m0=(w-q)/(b-p) if b!=p else 0;m1=(d-v)/(c-a) if c!=a else 0
   return (2*t**3-3*t*t+1)*v+(t**3-2*t*t+t)*(b-a)*m0+(-2*t**3+3*t*t)*w+(t**3-t*t)*(b-a)*m1

def reset():
 r.animation_data.action=None
 for b in P:b.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
def delta(n,x=0,y=0,z=0):
 b=P[n];m=b.matrix.copy();b.matrix=Matrix.Translation(m.translation)@rot(x,y,z)@Matrix.Translation(-m.translation)@m;bpy.context.view_layer.update()
def place(n,p,q=None):
 m=(q if q is not None else R[n].to_quaternion()).to_matrix().to_4x4();m.translation=Vector(p);P[n].matrix=m;bpy.context.view_layer.update()
def aim(n,target,origin=None):
 b=P[n];h=Vector(origin) if origin is not None else b.head.copy();direction=Vector(target)-h
 q=(R[n].to_3x3()@Vector((0,1,0))).rotation_difference(direction.normalized())@R[n].to_quaternion()
 place(n,h,q)
def limb(a,b,end,target,pole):
 A=P[a].head.copy();T=Vector(target);V=T-A;dist=V.length;L1=(R[b].translation-R[a].translation).length;L2=(R[end].translation-R[b].translation).length
 d=max(.001,min(dist,L1+L2-.0005));v=V.normalized();p=Vector(pole)-A;p=(p-v*p.dot(v)).normalized()
 x=(L1*L1-L2*L2+d*d)/(2*d);h=math.sqrt(max(0,L1*L1-x*x));K=A+v*x+p*h
 aim(a,K);aim(b,T);return (P[end].head-T).length

def foot(side,xyz,pitch=0,yaw=0):
 target=Vector(xyz);err=limb('thigh_'+side,'calf_'+side,'foot_'+side,target,(xyz[0],-1.0,.65))
 place('foot_'+side,P['foot_'+side].head,(rot(pitch,0,yaw)@R['foot_'+side]).to_quaternion());return err

def arm(side,xyz,hand_pitch=0):
 sign=1 if side=='l' else -1
 limb('upperarm_'+side,'lowerarm_'+side,'hand_'+side,xyz,(sign*.85,.48,1.08))
 # Long axis of hand points into a curved downward rake rather than extending the forearm.
 aim('hand_'+side,Vector(xyz)+Vector((sign*.025,-.075,-.12)))
 delta('hand_'+side,hand_pitch,0,sign*6)
 for j,finger in enumerate(['index','middle','ring','pinky','thumb']):
  for k in (1,2,3):delta(f'{finger}_{k:02}_{side}',0,sign*(8+j*2 if k<3 else 4),0)

def secondary(f,move=0,energy=0):
 # Each chain samples the torso driver at its own delayed time; no shared start/stop keys.
 for j in range(5):
  lag=2+(j%3);q=curve(f-lag,[(1,-1.8),(6,2.7),(11,.5),(14,-2.2),(19,1.8),(25,-1.8)],period=24)*move
  for k in (1,2,3):delta(f'coat_{j}_{k}',(6+move*16+q*move)*(1 if k==1 else .32)+energy*(.55 if k==1 else .25),(-1 if j<2 else 1)*(j-2)*.7, q*.28*(k/3))
 for j,side in enumerate(['l','c','r']):
  q=curve(f-(2+j),[(1,-1),(5,2),(12,-2),(18,1.3),(25,-1)],period=24)*move
  for k in (1,2):delta(f'hair_{side}_{k}',3+move*15+q*move*(.7 if k==1 else 1.2)+energy*.3,0,q*.3)

def posture(hip_z=.98,lean=10,hip_y=.12,yaw=0,shoulder_yaw=0,roll=0):
 p=R['pelvis'].translation.copy();p.y=hip_y;p.z=hip_z
 place('pelvis',p,(rot(0,roll,yaw)@R['pelvis']).to_quaternion())
 delta('spine_01',lean*.42,0,shoulder_yaw*.25-yaw*.25)
 delta('spine_02',lean*.33,0,shoulder_yaw*.35-yaw*.35)
 delta('spine_03',lean*.25,0,shoulder_yaw*.4-yaw*.4)
 delta('neck_01',-lean*.40,0,-shoulder_yaw*.25);delta('head',-lean*.43,0,-shoulder_yaw*.2)

def idle(f,phase='polish'):
 reset();b=curve(f,[(1,0),(20,.45),(38,1),(57,.62),(75,-.1),(90,0)])
 posture(.986+b*.003,9+b*.5,.13,-1,1)
 foot('l',(.16,-.055,.132));foot('r',(-.235,.21,.141))
 arm('l',(.35,-.14,1.08),-7);arm('r',(-.34,.02,.90),4)
 scan=curve(f,[(1,0),(34,0),(39,-6),(44,-4),(48,0),(90,0)])
 delta('head',0,0,scan)
 claw=curve(f,[(1,0),(51,0),(55,-13),(60,-18),(64,0),(90,0)])
 delta('blood_claw',0,0,claw*.15)
 for finger in ['index','middle','ring','pinky']:
  delta(f'{finger}_01_r',0,claw,0)
 if phase=='polish':secondary(f,0,b*.7)
 # guarantee periodic rest values of secondary channels

def agile(f,phase='polish',rootmotion=False):
 reset();t=(f-1)/60;f=(f-1)%24+1
 hip=curve(f,[(1,.923),(3,.913),(6,.921),(8,.930),(11,.928),(13,.922),(16,.911),(18,.925),(21,.931),(23,.927),(25,.923)])
 yaw=curve(f,[(1,3.6),(4,2.9),(7,.5),(10,-2.8),(13,-3.1),(17,-2.4),(20,1.3),(23,3.2),(25,3.6)])
 sh=curve(f,[(1,-4.2),(5,-3.1),(9,2.5),(13,4.5),(16,3.8),(21,-2.3),(25,-4.2)])
 posture(hip,20,.12,yaw,sh,curve(f,[(1,-1),(7,1.2),(13,1),(19,-1.3),(25,-1)]))
 # Head stabilization is smaller than pelvis translation; neck local translation avoids scaling.
 hd=P['head'].matrix.copy();hd.translation.z+=.924-hip;P['head'].matrix=hd;bpy.context.view_layer.update()
 for side,offset,x,basez in [('l',0,.16,.132),('r',12,-.235,.141)]:
  u=(f-1+offset)%24
  if u<=12:
   y=-.245+2.45*u/60;z=basez;pitch=0;fx=x
  else:
   v=u-12
   y=curve(v,[(0,.245),(2,.285),(5,.18),(8,-.08),(10,-.26),(12,-.245)])
   z=basez+curve(v,[(0,0),(2,.07),(5,.125 if side=='l' else .113),(8,.09),(10,.035),(12,0)])
   pitch=curve(v,[(0,0),(2,17),(5,24),(8,-7),(10,-8),(12,0)])
   fx=x+curve(v,[(0,0),(3,.025 if side=='l' else -.03),(7,.032 if side=='l' else -.018),(12,0)])
  foot(side,(fx,y,z),pitch,-1 if side=='l' else 1)
 # Different hand paths and nonuniform reversals give the claw a weighted arc.
 uy=curve(f,[(1,.09),(4,.025),(8,-.22),(13,-.37),(17,-.22),(21,.02),(25,.09)])
 uz=curve(f,[(1,.90),(6,.94),(10,1.01),(14,1.025),(19,.93),(25,.90)])
 arm('r',(-.36,uy,uz),curve(f,[(1,7),(10,-12),(15,-6),(23,9),(25,7)]))
 arm('l',(.35,-.25-uy*.64,1.12-(uz-.9)*.42),-9)
 if phase=='polish':secondary(f,1,0)
 if rootmotion:
  m=P['root'].matrix.copy();m.translation.y=-2.45*t;P['root'].matrix=m;bpy.context.view_layer.update()

def key_action(name,length,fn,phase='polish',keys=None,upper_only=False):
 old=bpy.data.actions.get(name)
 if old:bpy.data.actions.remove(old)
 act=bpy.data.actions.new(name);act.use_fake_user=True
 frames=keys or list(range(1,length+1));samples=[]
 for f in frames:
  fn(f,phase);samples.append({b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in P})
 r.animation_data.action=act
 prev={}
 for f,pose in zip(frames,samples):
  for b in P:
   if upper_only and b.name not in ['spine_01','spine_02','spine_03','neck_01','head','clavicle_l','clavicle_r']:continue
   loc,q=pose[b.name]
   if b.name in prev and q.dot(prev[b.name])<0:q.negate()
   b.location=loc;b.rotation_quaternion=q;prev[b.name]=q.copy()
   b.keyframe_insert('location',frame=f,group=b.name);b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
 for fc in act.fcurves:
  for k in fc.keyframe_points:
   k.interpolation='CONSTANT' if phase=='blocking' else 'BEZIER' if phase in ['breakdown','spline'] else 'LINEAR'
   if k.interpolation=='BEZIER':k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 act['authoring_phase']=phase;act['fps']=60;act['loop']=name in ['REV_Idle','REV_AgileMove_InPlace'];act['sampled_polish']=phase=='polish'
 r.animation_data.action=None
 return act

def review_setup():
 s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
 sh=s.display.shading;sh.light='STUDIO';sh.studiolight_rotate_z=.5;sh.color_type='TEXTURE';sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.background_type='WORLD';s.world.color=(.055,.055,.06)
 for name,loc in [('front',(0,-5,1.3)),('side',(5,0,1.3)),('three',(3,-5,3.2)),('game',(3.2,-4.8,5.6))]:
  cam=bpy.data.objects.get('CAM_'+name)
  if not cam:
   bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='CAM_'+name
  cam.location=loc;cam.rotation_euler=(Vector((0,0,.85))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.35
 s.camera=bpy.data.objects['CAM_three']
 if not bpy.data.objects.get('Review_Ground'):
  bpy.ops.mesh.primitive_plane_add(size=200);g=bpy.context.object;g.name='Review_Ground';g.location.z=-.004;g.color=(.075,.085,.10,1)

def render_stills(name,frames,prefix):
 if name.startswith('REV_Hit'):idle(1)
 r.animation_data.action=bpy.data.actions[name]
 for angle in ['front','side','three']:
  s.camera=bpy.data.objects['CAM_'+angle]
  for f in frames:
   s.frame_set(f);s.render.filepath=str(D/'qa'/f'{prefix}_{angle}_{f:03}.png');bpy.ops.render.render(write_still=True)
