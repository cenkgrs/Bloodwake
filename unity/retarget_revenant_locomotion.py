"""Bake the supplied Mixamo locomotion onto the existing production skeleton.
blender -b -t 2 --python unity/retarget_revenant_locomotion.py
Only new animation assets are exported; the production mesh/rig is untouched.
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parent.parent
SRC=ROOT/'art/revenant/source/locomotion_20261015'
OUT=ROOT/'unity/Assets/Bloodwake/Resources/Animations/RevenantLocomotion'
OUT.mkdir(parents=True,exist_ok=True)
MAP={'pelvis':'Hips','spine_01':'Spine','spine_02':'Spine1','spine_03':'Spine2','neck_01':'Neck','head':'Head'}
for side,label in [('l','Left'),('r','Right')]:
 for dest,source in [('clavicle','Shoulder'),('upperarm','Arm'),('lowerarm','ForeArm'),('hand','Hand'),('thigh','UpLeg'),('calf','Leg'),('foot','Foot'),('ball','ToeBase')]:MAP[dest+'_'+side]=label+source
 for finger in ['Thumb','Index','Middle','Ring','Pinky']:
  for i in range(1,4):MAP[finger.lower()+'_%02d_'%i+side]=label+'Hand'+finger+str(i)
report={}
for source,name in [('Neutral Idle','REV_NeutralIdle'),('Swagger Walk','REV_SwaggerWalk'),('Standard Run','REV_StandardRun')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.fbx(filepath=str(ROOT/'unity/Assets/Bloodwake/Resources/Models/revenant_player/revenant_player.fbx'))
 dst=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
 target_objects=list(bpy.context.scene.objects)
 dst.animation_data_clear()
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 for p in dst.pose.bones:p.matrix_basis.identity();p.rotation_mode='QUATERNION'
 before=set(bpy.context.scene.objects)
 bpy.ops.import_scene.fbx(filepath=str(SRC/(source+'.fbx')))
 fresh=set(bpy.context.scene.objects)-before
 src=next(o for o in fresh if o.type=='ARMATURE')
 action=src.animation_data.action
 lo,hi=map(int,action.frame_range);fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
 pairs=[(b.name,'mixamorig:'+MAP[b.name]) for b in dst.data.bones if b.name in MAP]
 rest_s={d:src.matrix_world@src.data.bones[s].matrix_local for d,s in pairs}
 rest_d={d:dst.matrix_world@dst.data.bones[d].matrix_local for d,s in pairs}
 # Match the source's anatomical axes: its bind pose has lowered arms whereas
 # the production rig has outstretched arms. Rest-delta alone would leave a T pose.
 offsets={}
 for d,s in pairs:
  qs,qd=rest_s[d].to_quaternion(),rest_d[d].to_quaternion()
  align=(qd@Vector((0,1,0))).rotation_difference(qs@Vector((0,1,0)))
  offsets[d]=qs.inverted()@align@qd
 ratio=rest_d['pelvis'].translation.z/rest_s['pelvis'].translation.z
 baked=bpy.data.actions.new(name);dst.animation_data_create();dst.animation_data.action=baked
 feet=[];pelvis=[];previous={}
 frames=int(round((hi-lo)*60/fps))+1
 for i in range(frames):
  f=lo+i*fps/60;bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
  for p in dst.pose.bones:p.matrix_basis.identity()
  bpy.context.view_layer.update()
  for d,s in pairs:
   p=dst.pose.bones[d];world=src.matrix_world@src.pose.bones[s].matrix
   if d in ('pelvis','spine_01','spine_02','spine_03','neck_01','head'):
    q=world.to_quaternion()@rest_s[d].to_quaternion().inverted()@rest_d[d].to_quaternion()
   else:q=world.to_quaternion()@offsets[d]
   placed=q.to_matrix().to_4x4()
   placed.translation=(dst.matrix_world@p.matrix).translation
   if d=='pelvis':
    placed.translation=rest_d[d].translation+Vector((0,0,(world.translation.z-rest_s[d].translation.z)*ratio))
   p.matrix=dst.matrix_world.inverted()@placed
   bpy.context.view_layer.update()
  # Ground the lowest foot/toe while retaining the source's airborne run phase.
  names=['foot_l','ball_l','foot_r','ball_r']
  low=min((dst.matrix_world@dst.pose.bones[n].head).z for n in names)
  source_low=min((src.matrix_world@src.pose.bones['mixamorig:'+s].head).z for s in ['LeftFoot','LeftToeBase','RightFoot','RightToeBase'])
  target_floor=.045+max(0,source_low-.04)*ratio
  p=dst.pose.bones['pelvis'];m=p.matrix.copy();m.translation.z+=target_floor-low;p.matrix=m
  bpy.context.view_layer.update()
  for p in dst.pose.bones:
   q=p.rotation_quaternion.copy()
   if p.name in previous and q.dot(previous[p.name])<0:q.negate()
   p.rotation_quaternion=q;previous[p.name]=q.copy()
   p.keyframe_insert('rotation_quaternion',frame=i+1)
   if p.name=='pelvis':p.keyframe_insert('location',frame=i+1)
  feet.append([round((dst.matrix_world@dst.pose.bones[n].head).z,5) for n in names])
  pelvis.append(list(dst.pose.bones['pelvis'].location))
 # Close the loop over the last four frames, without stretching the source tempo.
 curves=list(baked.fcurves)
 for fc in curves:
  first=fc.evaluate(1)
  for k in fc.keyframe_points:
   if k.co.x>=frames-3:
    blend=max(0,(k.co.x-(frames-3))/3);k.co.y=k.co.y*(1-blend)+first*blend
   k.interpolation='LINEAR'
  fc.update()
 bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1
 bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=frames
 bpy.context.scene.frame_set(1)
 # Keep a review .blend with the production body and baked motion.
 for o in fresh:bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 bpy.ops.object.select_all(action='DESELECT');dst.select_set(True);bpy.context.view_layer.objects.active=dst
 bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y')
 report[name]={'source':source+'.fbx','source_fps':fps,'frames':frames,'duration':(frames-1)/60,'mapped_bones':len(pairs),'foot_min':min(min(v) for v in feet),'foot_max':max(max(v) for v in feet)}
 print('RETARGET',json.dumps(report[name]),flush=True)
(SRC/'retarget_report.json').write_text(json.dumps(report,indent=2)+'\n')
