import sys,bpy,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from motion_lib import *
import motion_lib as M
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Rigged.blend'));init();review_setup()
(D/'workfiles').mkdir(exist_ok=True)
phases=[('blocking',[1,13,24],[1,35,52,90]),('breakdown',[1,4,7,10,13,16,19,22,24],[1,20,35,41,48,52,58,64,75,90]),('spline',[1,3,5,7,9,11,13,16,19,21,23,24],[1,12,20,32,35,40,44,48,52,55,59,64,75,84,90]),('polish',None,None)]
for phase,move_keys,idle_keys in phases:
 key_action('REV_Idle',90,idle,phase,idle_keys);key_action('REV_AgileMove_InPlace',24,agile,phase,move_keys)
 M.r.animation_data.action=bpy.data.actions['REV_AgileMove_InPlace'];M.s.frame_set(7);M.s.frame_start=1;M.s.frame_end=24
 bpy.ops.wm.save_as_mainfile(filepath=str(D/'workfiles'/f'Stage1_{phase}.blend'))
 if phase in ['blocking','spline']:render_stills('REV_AgileMove_InPlace',[1,7,13,19],phase)
M.r.animation_data.action=None
key_action('REV_AgileMove_RootMotion',24,lambda f,p:agile(f,p,True))
# Record measured transforms; world contact includes the 2.45 m/s character movement.
act=bpy.data.actions['REV_AgileMove_InPlace'];M.r.animation_data.action=act;rows=[]
for f in range(1,25):
 M.s.frame_set(f);row={'frame':f,'pelvis_z':M.P['pelvis'].head.z,'head_z':M.P['head'].head.z,'hip_yaw':M.P['pelvis'].matrix.to_euler().z,'shoulder_yaw':M.P['spine_03'].matrix.to_euler().z}
 for side in ['l','r']:
  v=M.P['ball_'+side].head.copy();v.y-=2.45*(f-1)/60;row['world_ball_'+side]=list(v)
 rows.append(row)
(D/'qa/locomotion_measurements.json').write_text(json.dumps(rows,indent=2))
render_stills('REV_AgileMove_InPlace',[1,4,7,10,13,16,19,22],'polish');render_stills('REV_Idle',[1,40,58],'idle')
M.r.animation_data.action=act;M.s.frame_set(1);M.s.camera=bpy.data.objects['CAM_game'];bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Stage1.blend'))
print('STAGE1_AUTHORED')
