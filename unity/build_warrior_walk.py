"""Bake supplied walk on the existing enemy rig; retain production mesh/materials.
blender -b -t 2 --python unity/build_warrior_walk.py
"""
import bpy,json,statistics
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art/enemies/mixamo/warrior/walk-20261015'
OUT=ROOT/'unity/Assets/Bloodwake/Resources/Animations/WarriorLocomotion';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'unity/Assets/Bloodwake/Resources/Models/enemy_warrior/enemy_warrior.fbx'))
dst=next(o for o in bpy.data.objects if o.type=='ARMATURE');dst.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
for p in dst.pose.bones:p.matrix_basis.identity();p.rotation_mode='QUATERNION'
bpy.context.view_layer.update()
before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(SRC/'in-place.fbx'));fresh=set(bpy.data.objects)-before
src=next(o for o in fresh if o.type=='ARMATURE');action=src.animation_data.action
fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base;lo,hi=map(int,action.frame_range)
assert set(dst.data.bones.keys())==set(src.data.bones.keys())
names=sorted(dst.data.bones.keys(),key=lambda n:len(dst.data.bones[n].parent_recursive))
sr={n:src.matrix_world@src.data.bones[n].matrix_local for n in names};dr={n:dst.matrix_world@dst.data.bones[n].matrix_local for n in names}
def leg_length(rest):return sum((rest['mixamorig:'+a].translation-rest['mixamorig:'+b].translation).length for a,b in [('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')])
ratio=leg_length(dr)/leg_length(sr)
offset={}
for n in names:
 qs,qd=sr[n].to_quaternion(),dr[n].to_quaternion();align=(qd@Vector((0,1,0))).rotation_difference(qs@Vector((0,1,0)));offset[n]=qs.inverted()@align@qd
baked=bpy.data.actions.new('Warrior_ShieldWalk');dst.animation_data_create();dst.animation_data.action=baked
previous={};foot_samples=[];hip_samples=[]
for frame in range(lo,hi+1):
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
 for p in dst.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 for n in names:
  p=dst.pose.bones[n];world=src.matrix_world@src.pose.bones[n].matrix
  central=n.split(':')[-1] in ('Hips','Spine','Spine1','Spine2','Neck','Head','HeadTop_End')
  q=world.to_quaternion()@sr[n].to_quaternion().inverted()@dr[n].to_quaternion() if central else world.to_quaternion()@offset[n]
  # Keep the target's world scale: a unit rotation matrix would cancel the
  # armature's 1.846 scale and shorten every leg segment during the bake.
  m=Matrix.LocRotScale((dst.matrix_world@p.matrix).translation,q,dr[n].to_scale())
  if n=='mixamorig:Hips':m.translation=dr[n].translation+(world.translation-sr[n].translation)*ratio
  p.matrix=dst.matrix_world.inverted()@m;bpy.context.view_layer.update()
 for p in dst.pose.bones:
  q=p.rotation_quaternion.copy()
  if p.name in previous and q.dot(previous[p.name])<0:q.negate()
  p.rotation_quaternion=q;previous[p.name]=q.copy();p.keyframe_insert('rotation_quaternion',frame=frame-lo+1)
  if p.name=='mixamorig:Hips':p.keyframe_insert('location',frame=frame-lo+1)
 foot_samples.append([list(dst.matrix_world@dst.pose.bones['mixamorig:'+n].head) for n in ['LeftFoot','RightFoot','LeftToeBase','RightToeBase']])
 hip_samples.append(list(dst.matrix_world@dst.pose.bones['mixamorig:Hips'].head))
for obj in fresh:bpy.data.objects.remove(obj,do_unlink=True)
before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(SRC/'travel.fbx'));fresh=set(bpy.data.objects)-before
travel=next(o for o in fresh if o.type=='ARMATURE');root=[]
for frame in [lo,hi]:
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();root.append(travel.matrix_world@travel.pose.bones['mixamorig:Hips'].head)
delta=root[1]-root[0];delta.z=0;duration=(hi-lo)/fps;stride=delta.length*ratio;speed=stride/duration
contact_errors=[]
for toe in [2,3]:
 floor=min(row[toe][2] for row in foot_samples)
 assert floor>-.025,('Foot below floor',toe,floor)
 velocities=[(b[toe][1]-a[toe][1])*fps for a,b in zip(foot_samples,foot_samples[1:]) if max(a[toe][2],b[toe][2])<floor+.02]
 error=statistics.median(abs(v-speed) for v in velocities);contact_errors.append(error)
 assert error<.15,('Planted foot slides',toe,error)
for obj in fresh:bpy.data.objects.remove(obj,do_unlink=True)
for a in list(bpy.data.actions):
 if a!=baked:bpy.data.actions.remove(a)
dst.animation_data.action=baked;dst.animation_data.action_slot=baked.slots[0]
bpy.context.scene.render.fps=round(fps);bpy.context.scene.render.fps_base=1;bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=hi-lo+1;bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'Warrior_ShieldWalk.blend'))
bpy.ops.object.select_all(action='DESELECT');dst.select_set(True);bpy.context.view_layer.objects.active=dst
bpy.ops.export_scene.fbx(filepath=str(OUT/'Warrior_ShieldWalk.fbx'),use_selection=True,object_types={'ARMATURE'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y')
report={'referenceHeight':1.8,'referenceSpeed':speed,'cycleDistance':stride,'duration':duration,'sourceFps':fps,'sourceScaleToTarget':ratio,'plantedFootMedianErrorMps':contact_errors,'travelSource':'Sword And Shield Walk(1).fbx','inPlaceSource':'Sword And Shield Walk.fbx','footSamples':foot_samples,'hipSamples':hip_samples}
(SRC/'walk-report.json').write_text(json.dumps(report,indent=2))
(OUT/'stride.json').write_text(json.dumps({k:report[k] for k in ['referenceHeight','referenceSpeed','cycleDistance','duration']},indent=2))
assert stride>1 and max(Vector(p[0]).y for p in foot_samples)-min(Vector(p[0]).y for p in foot_samples)>.2
print('WARRIOR_WALK_BUILT',json.dumps({k:v for k,v in report.items() if not k.endswith('Samples')}),flush=True)
