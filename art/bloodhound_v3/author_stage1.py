"""Stage 1 only. Authored control curves -> IK solve -> export bake.
Run against the preserved v2 blend, with -- --stage blocking|breakdown|spline|polish.
Control actions remain editable; the dense deform action is an export cache.
"""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector as V, Matrix as M

HERE=Path(__file__).resolve().parent
STAGE=sys.argv[sys.argv.index('--stage')+1] if '--stage' in sys.argv else 'blocking'
OUT=HERE/'stage1'/STAGE;OUT.mkdir(parents=True,exist_ok=True)
rig=bpy.data.objects['Bloodhound_Rig'];body=bpy.data.objects['Bloodhound_Body'];scene=bpy.context.scene
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
for name in ['BH_Bomb_Held','BH_Bomb_Flight']:
 obj=bpy.data.objects.get(name)
 if obj:bpy.data.objects.remove(obj,do_unlink=True)
scene.render.fps=60
rest={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in rig.data.bones}
sole_pivots={}
for side,s in [('L',1),('R',-1)]:
 sole=[v.co for v in body.data.vertices if s*v.co.x>.08 and v.co.z<.016]
 sole_pivots[side]=(min(v.y for v in sole),max(v.y for v in sole))
 rig['sole_toe_y_'+side]=sole_pivots[side][0]
# Boots need a rigid sole. The earlier smooth all-over skin let the shin drag
# sole vertices even when the ankle bone was perfectly planted.
for vertex in body.data.vertices:
 if vertex.co.z>=.19:continue
 side='L' if vertex.co.x>0 else 'R';foot=body.vertex_groups['Foot.'+side]
 amount=min(1.0,max(0.0,(.19-vertex.co.z)/.115))
 old={g.group:g.weight for g in vertex.groups};weights={index:value*(1-amount) for index,value in old.items()}
 weights[foot.index]=weights.get(foot.index,0)+amount
 for index in old:body.vertex_groups[index].remove([vertex.index])
 for index,value in weights.items():
  if value>.00001:body.vertex_groups[index].add([vertex.index],value,'REPLACE')
controls=bpy.data.collections.new('STAGE1_EDITABLE_CONTROLS');scene.collection.children.link(controls)
PERIOD=38;SPEED=5.0/(2.05/1.8);RATE=SPEED/60
curves={};authoring={}

def channel(name,keys,period=PERIOD):
 """Knots: (frame offset, value, optional authored slope per frame)."""
 obj=bpy.data.objects.new('CTRL_'+name,None);controls.objects.link(obj);obj['value']=0.0
 obj['purpose']='Authored scalar channel; deform rig is baked from these controls'
 obj.animation_data_create();action=bpy.data.actions.new('CTRL_'+name+'_'+STAGE);action.use_fake_user=True
 obj.animation_data.action=action
 fc=action.fcurves.new(data_path='["value"]')
 # Blocking holds the key silhouettes. Breakdown adds contact/down/pass/up.
 selected=keys
 if STAGE=='blocking' and len(keys)>5:selected=[keys[i] for i in sorted(set([0,len(keys)//4,len(keys)//2,3*len(keys)//4,len(keys)-1]))]
 for i,k in enumerate(selected):
  f,value=k[:2];p=fc.keyframe_points.insert(f+1,value)
  p.interpolation='CONSTANT' if STAGE=='blocking' else ('LINEAR' if STAGE=='breakdown' else 'BEZIER')
  if len(k)>2:slope=k[2]
  elif i==0 or i==len(selected)-1:slope=0.0
  else:
   prev=selected[i-1];nxt=selected[i+1]
   incoming=(value-prev[1])/(f-prev[0]);outgoing=(nxt[1]-value)/(nxt[0]-f)
   slope=0.0 if incoming*outgoing<=0 else (incoming+outgoing)*.38
  left=(f-selected[i-1][0])/3 if i else (selected[1][0]-f)/3
  right=(selected[i+1][0]-f)/3 if i<len(selected)-1 else left
  p.handle_left_type='FREE';p.handle_right_type='FREE'
  p.handle_left=(f+1-left,value-slope*left);p.handle_right=(f+1+right,value+slope*right)
 fc.update();curves[name]=(fc,period);authoring[name]=keys
 return obj

def c(name,f):
 fc,period=curves[name]
 return fc.evaluate((f%period)+1)

# Independent left/right foot trajectories. Grounded Y slopes match target speed
# exactly. Swing knots describe heel recovery, knee drive and pre-contact reach.
channel('L_foot_y',[(0,-.34,RATE),(4,-.34+4*RATE,RATE),(9,-.34+9*RATE,RATE),(12,.405,0),(17,.29,-.045),(22,-.04,-.062),(28,-.33,-.029),(34,-.46,0),(36,-.444,.034),(38,-.34,RATE)])
channel('R_foot_y',[(0,-.365,RATE),(4,-.365+4*RATE,RATE),(10,-.365+10*RATE,RATE),(13,.43,0),(18,.265,-.05),(24,-.09,-.056),(30,-.39,-.02),(34,-.48,0),(36,-.46,.045),(38,-.365,RATE)])
channel('L_foot_z',[(0,.13),(4,.13),(9,.13),(12,.22,.035),(17,.365,0),(22,.29,-.019),(28,.22,-.008),(33,.21,-.005),(36,.16,-.014),(38,.13,0)])
channel('R_foot_z',[(0,.13),(4,.13),(10,.13),(13,.255,.036),(18,.35,0),(24,.274,-.012),(30,.218,-.005),(34,.21,-.008),(37,.14,-.012),(38,.13,0)])
channel('L_foot_x',[(0,.168),(9,.168),(14,.187),(21,.21),(29,.181),(35,.168),(38,.168)])
channel('R_foot_x',[(0,-.17),(10,-.17),(15,-.195),(23,-.205),(31,-.183),(36,-.17),(38,-.17)])
channel('L_pitch',[(0,0),(4,0),(6,8),(9,24),(13,32),(19,15),(26,-9),(33,-7),(37,0),(38,0)])
channel('R_pitch',[(0,0),(4,0),(7,10),(10,27),(15,29),(20,12),(27,-11),(34,-5),(37,0),(38,0)])
channel('pelvis_z',[(0,.836,-.004),(3,.807,0),(7,.826,.008),(11,.866,.003),(14,.872,0),(18,.852,-.005),(20,.837,-.006),(23,.801,0),(27,.829,.009),(31,.868,0),(35,.86,-.004),(38,.836,-.004)])
channel('pelvis_x',[(0,.012),(4,.018),(10,.008),(16,-.008),(20,-.015),(24,-.019),(30,-.006),(35,.006),(38,.012)])
channel('pelvis_yaw',[(0,-6),(4,-4.5),(10,0.5),(16,4.3),(20,5.2),(25,3.7),(30,-1.0),(35,-4.8),(38,-6)])
channel('shoulder_yaw',[(0,3.5),(4,5.0),(10,1.0),(17,-3.0),(22,-4.8),(29,-.5),(36,3.2),(38,3.5)])
channel('pelvis_roll',[(0,1.5),(4,2.7),(10,.2),(16,-1.0),(20,-1.8),(24,-2.4),(30,-.3),(35,1.0),(38,1.5)])
channel('chest_pitch',[(0,9),(4,11),(10,8.0),(17,8.7),(23,11.4),(29,8.8),(34,8.2),(38,9)])
channel('head_z',[(0,1.57),(5,1.561),(13,1.58),(20,1.571),(25,1.558),(32,1.578),(38,1.57)])
channel('L_hand_y',[(0,-.23),(5,-.19),(11,-.095),(19,-.07),(26,-.16),(32,-.255),(38,-.23)])
channel('R_hand_y',[(0,-.09),(7,-.16),(13,-.24),(21,-.225),(28,-.11),(34,-.075),(38,-.09)])
channel('L_hand_z',[(0,1.20),(8,1.185),(17,1.175),(24,1.20),(32,1.235),(38,1.20)])
channel('R_hand_z',[(0,1.19),(9,1.225),(18,1.24),(27,1.20),(33,1.18),(38,1.19)])
channel('cloth_sweep',[(0,-.014),(5,-.025),(12,.012),(19,.028),(25,.01),(31,-.018),(38,-.014)])
channel('idle_hip',[(0,.902),(17,.903),(32,.906),(46,.904),(61,.902),(71,.902)],71)
channel('idle_chest',[(0,0),(13,.003),(28,.006),(39,.004),(56,.001),(71,0)],71)
channel('idle_scan',[(0,0),(14,-1.1),(27,-1.2),(41,.5),(53,1.3),(64,.4),(71,0)],71)

if STAGE=='polish':
 # Review correction: the right push-off previously reached its apex too early,
 # while the foot was still supporting weight. Move that apex into flight.
 old=bpy.data.objects.get('CTRL_pelvis_z')
 if old:bpy.data.objects.remove(old,do_unlink=True)
 channel('pelvis_z',[(0,.836,-.004),(3,.807,0),(7,.826,.008),(11,.866,.003),(14,.872,0),(18,.852,-.005),(20,.837,-.006),(23,.801,0),(27,.829,.009),(31,.862,.005),(34,.875,0),(38,.836,-.004)])
 old=bpy.data.objects.get('CTRL_head_z')
 if old:bpy.data.objects.remove(old,do_unlink=True)
 channel('head_z',[(0,1.57),(5,1.561),(13,1.58),(20,1.571),(25,1.558),(34,1.581),(38,1.57)])

def aim(name,a,b):
 ra,rb=rest[name];q=(rb-ra).rotation_difference(b-a)
 matrix=q.to_matrix().to_4x4()@rig.data.bones[name].matrix_local;matrix.translation=a;return matrix
def ik(a,c,l1,l2,pole):
 delta=c-a;distance=min(max(delta.length,.001),l1+l2-.0001);axis=delta.normalized()
 along=(l1*l1-l2*l2+distance*distance)/(2*distance)
 height=math.sqrt(max(0,l1*l1-along*along));bend=pole-axis*pole.dot(axis)
 return a+axis*along+bend.normalized()*height
def rot(degrees,axis):return M.Rotation(math.radians(degrees),4,axis)
def pose(f,idle=False):
 hip=V((0,0,c('idle_hip',f))) if idle else V((c('pelvis_x',f),-.045,c('pelvis_z',f)))
 hy=0 if idle else c('pelvis_yaw',f);sy=0 if idle else c('shoulder_yaw',f)
 roll=0 if idle else c('pelvis_roll',f)
 hiprot=rot(hy,'Z')@rot(roll,'Y')
 pitch=2.0 if idle else c('chest_pitch',f)
 chestrot=rot(sy,'Z')@rot(pitch,'X')
 chestbase=hip+V((0,-.018,.23));shoulder=hip+V((0,-.035 if idle else -.105,.50))
 neck=shoulder+V((0,0,.02));head=neck+V((0,0,.10))
 if not idle:head.z=c('head_z',f)-.075
 points={'Pelvis':(hip,hip+hiprot.to_3x3()@V((0,0,.13))),
 'Spine':(hip+hiprot.to_3x3()@V((0,0,.13)),chestbase),
 'Chest':(chestbase,neck),'Neck':(neck,head),'Head':(head,head+V((0,-.006,.19)))}
 matrices={name:aim(name,*ab) for name,ab in points.items()}
 # Twist around each anatomical segment's up axis, independently authored.
 for name,yaw in [('Pelvis',hy),('Chest',sy),('Head',c('idle_scan',f) if idle else sy*.15)]:
  pivot=matrices[name].translation.copy();matrices[name]=M.Translation(pivot)@rot(yaw,'Z')@M.Translation(-pivot)@matrices[name]
 for side,s in [('L',1),('R',-1)]:
  t=(f-(0 if side=='L' else 20))%PERIOD
  contact=V((s*.17,-.015,.13)) if idle else V((c(side+'_foot_x',t),c(side+'_foot_y',t),c(side+'_foot_z',t)))
  angle=0 if idle else c(side+'_pitch',t)
  footrot=rot(angle,'X')
  footvec=rest['Foot.'+side][1]-rest['Foot.'+side][0]
  # Pivot heel-lift around the toe, so rolling the sole does not slide it.
  sole_pivot=V((0,sole_pivots[side][0 if angle>=0 else 1],-.13))
  ankle=contact+sole_pivot-footrot.to_3x3()@sole_pivot
  thigh=hip+hiprot.to_3x3()@V((s*.12,0,0))
  knee=ik(thigh,ankle,.4109,.401,V((s*.10,-1,.02)))
  matrices['Thigh.'+side]=aim('Thigh.'+side,thigh,knee)
  matrices['Shin.'+side]=aim('Shin.'+side,knee,ankle)
  matrices['Foot.'+side]=aim('Foot.'+side,ankle,ankle+footrot.to_3x3()@footvec)
  clavicle=shoulder+chestrot.to_3x3()@V((s*.205,0,0))
  wrist=V((s*.265,-.075,1.0)) if idle else V((s*(.25+(.008 if side=='L' else -.003)),c(side+'_hand_y',f),c(side+'_hand_z',f)-.10))
  if idle:wrist.z+=c('idle_chest',f)*.3
  elbow=ik(clavicle,wrist,.22,.19,V((s*.12,.35,-1.0)))
  for name,a,b in [('Clavicle',shoulder,clavicle),('UpperArm',clavicle,elbow),('Forearm',elbow,wrist),('Hand',wrist,wrist+V((s*.006,-.04,-.091)))]:matrices[name+'.'+side]=aim(name+'.'+side,a,b)
 for name,(a,b) in rest.items():
  if not name.startswith(('Coat','Scarf')):continue
  lag=4 if name in ['ScarfTip','CoatBackTip.R'] else (3 if 'Tip' in name or name in ['Scarf','CoatSide.R'] else 2)
  sample=f-lag
  follow=V((0,0,c('idle_hip',sample))) if idle else V((c('pelvis_x',sample),-.045,c('pelvis_z',sample)))
  s=1 if name.endswith('L') else -1
  shift=follow-V((0,0,.94));sweep=0 if idle else c('cloth_sweep',sample)
  spread=.035 if idle else .072
  if name.startswith('Scarf'):
   offset=V((.002*c('idle_scan',sample),.015,0)) if idle else V((sweep,.10,.025))
   matrices[name]=aim(name,a+shift,b+shift+offset)
  else:
   offset=V((s*spread,sweep+.035 if idle else .105+sweep,.008))
   current_rot=hiprot.to_3x3();lag_rot=(rot(0 if idle else c('pelvis_yaw',sample),'Z')@rot(0 if idle else c('pelvis_roll',sample),'Y')).to_3x3()
   attachment=hip+current_rot@(a-V((0,0,.94)))
   tail=follow+lag_rot@(b-V((0,0,.94)))
   matrices[name]=aim(name,attachment+offset*.2,tail+offset)
 matrices['Root']=rig.data.bones['Root'].matrix_local.copy()
 return matrices

def apply(matrices):
 for bone in rig.pose.bones:
  bone.location=(0,0,0);bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
 for bone in rig.pose.bones:
  if bone.name in matrices:bone.matrix=matrices[bone.name]
  bpy.context.view_layer.update()
 for side,s in [('L',1),('R',-1)]:
  hand=rig.pose.bones['Hand.'+side];delta=hand.matrix@rig.data.bones[hand.name].matrix_local.inverted()
  for digit in ['Index','Middle','Ring','Pinky']:
   parent=delta
   for suffix,angle in [('',55 if digit=='Index' else 72),('Tip',68)]:
    name=digit+suffix+'.'+side;a,b=rest[name]
    matrix=parent@M.Translation(a)@rot(s*angle,'Y')@M.Translation(-a)@rig.data.bones[name].matrix_local
    rig.pose.bones[name].matrix=matrix;bpy.context.view_layer.update();parent=matrix@rig.data.bones[name].matrix_local.inverted()
  rig.pose.bones['WeaponSocket.'+side].matrix=hand.matrix.copy();bpy.context.view_layer.update()

stages={}
for name,end in [('BH_Idle',72),('BH_AgileMove',39)]:
 rig.animation_data_create();rig.animation_data.action=None
 samples=[]
 for frame in range(1,end+1):
  apply(pose(frame-1,name=='BH_Idle'))
  samples.append({b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in rig.pose.bones})
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 previous={}
 for frame,sample in enumerate(samples,1):
  for b in rig.pose.bones:
   b.location,q=sample[b.name]
   if b.name in previous and q.dot(previous[b.name])<0:q=-q
   b.rotation_quaternion=q;previous[b.name]=q.copy()
   b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
 action['authoring_stage']=STAGE;stages[name]=action
 for fc in action.fcurves:
  for key in fc.keyframe_points:key.interpolation='CONSTANT' if STAGE=='blocking' else 'LINEAR'
 if name=='BH_AgileMove':
  for label,frame in [('L_CONTACT',1),('L_LOAD',4),('L_TOE_OFF',10),('R_CONTACT',21),('R_LOAD',24),('R_TOE_OFF',31)]:action.pose_markers.new(label).frame=frame
rig['delivery_status']='STAGE1_'+STAGE.upper()+'_UNAPPROVED'
rig['locomotion_source_speed_mps']=SPEED;rig['locomotion_cycle_frames']=PERIOD
rig['workflow']='blocking -> breakdown -> spline -> polish; stage2 not started'
rig.animation_data.action=stages['BH_AgileMove'];scene.frame_start=1;scene.frame_end=39;scene.frame_set(1)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Bloodhound_Stage1.blend'))
if '--export' in sys.argv:
 bpy.ops.object.select_all(action='DESELECT')
 for obj in [rig,body,bpy.data.objects['Revolver.L'],bpy.data.objects['Revolver.R']]:obj.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(OUT/'Bloodhound_Stage1.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True,export_extras=True)
(OUT/'authored_controls.json').write_text(json.dumps({'stage':STAGE,'speed_mps_local':SPEED,'cycle_frames':PERIOD,'controls':authoring},indent=2))
if '--no-render' not in sys.argv:
 scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=12
 scene.render.resolution_x=640;scene.render.resolution_y=640
 camera=scene.camera;camera.location=(4,-7,6);center=V((0,0,.8));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=2.4
 bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='Preview Ground'
 material=bpy.data.materials.new('Preview Ground');material.diffuse_color=(.075,.08,.09,1);floor.data.materials.append(material)
 for frame in [1,4,10,15,21,24,31,36]:
  scene.frame_set(frame);scene.render.filepath=str(OUT/f'pose_{frame:02}.png');bpy.ops.render.render(write_still=True)
print('STAGE1_AUTHORED',STAGE,flush=True)
