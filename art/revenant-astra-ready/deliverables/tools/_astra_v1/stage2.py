import bpy,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from motion_lib import *
from combat_lib import *
import motion_lib as M
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Stage1.blend'));init();review_setup()
# Upper-body standard clips and explicit rest-relative additive variants.
clips={
 'REV_HitLight_Front':(12,lambda f,p:hit(f,p,'Front'),[1,3,5,8,12]),
 'REV_HitLight_Left':(12,lambda f,p:hit(f,p,'Left'),[1,3,5,8,12]),
 'REV_HitLight_Right':(12,lambda f,p:hit(f,p,'Right'),[1,3,5,8,12]),
 'REV_Death':(72,death,[1,5,12,24,38,52,65,72]),
 'REV_TeleportAttack':(42,teleport,[1,6,10,15,16,20,22,25,26,28,34,42]),
 'REV_BloodBurst':(120,burst,[1,18,19,32,42,52,59,60,64,70,84,100,108,112,120])}
for phase in ['blocking','breakdown','spline','polish']:
 for name,(length,fn,landmarks) in clips.items():
  keys=landmarks if phase=='blocking' else sorted(set(landmarks)) if phase=='breakdown' else sorted(set(landmarks+[(a+b)//2 for a,b in zip(landmarks,landmarks[1:])])) if phase=='spline' else None
  a=key_action(name,length,fn,phase,sorted(set(keys)) if keys else None,upper_only=name.startswith('REV_Hit'))
 M.r.animation_data.action=bpy.data.actions['REV_BloodBurst'];M.s.frame_set(60)
 bpy.ops.wm.save_as_mainfile(filepath=str(D/'workfiles'/f'Stage2_{phase}.blend'))
 if phase=='blocking':render_stills('REV_Death',[24,52,72],'death_blocking');render_stills('REV_BloodBurst',[18,60,108],'burst_blocking')
for direction in ['Front','Left','Right']:
 key_action('REV_HitLight_'+direction+'_Additive',12,lambda f,p,d=direction:hit(f,p,d,True),upper_only=True)
 bpy.data.actions['REV_HitLight_'+direction+'_Additive']['additive_reference']='Local transform delta relative to REV_Idle frame 1; upper body mask required.'
events=json.loads((D/'animation_events.json').read_text())
for name,info in events['actions'].items():
 a=bpy.data.actions[name]
 for n,f in info['events'].items():a.pose_markers.new(n).frame=f
for name,info in events['actions'].items():
 for n,f in info['events'].items():
  if n not in M.s.timeline_markers:M.s.timeline_markers.new(n,frame=f)
for name,frames,pre in [('REV_HitLight_Front',[1,4,8,12],'hit'),('REV_Death',[5,24,38,52,65,72],'death'),('REV_TeleportAttack',[6,10,15,22,26,28,42],'teleport'),('REV_BloodBurst',[18,42,59,60,70,84,108,120],'burst')]:render_stills(name,frames,pre)
M.r.animation_data.action=bpy.data.actions['REV_Idle'];M.s.frame_set(1);M.s.camera=bpy.data.objects['CAM_three']
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Stage2.blend'));print('STAGE2_AUTHORED')
