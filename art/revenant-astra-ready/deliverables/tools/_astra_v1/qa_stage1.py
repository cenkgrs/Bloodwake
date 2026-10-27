import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M
bpy.ops.wm.open_mainfile(filepath=str(M.D/'Revenant_Stage1.blend'));M.init();r=M.r;s=M.s;m=bpy.data.objects['REV_Body']
result={};raw=json.loads((M.D/'qa/locomotion_measurements.json').read_text())
for side,a,b in [('l',0,12),('r',12,24)]:
 pts=[Vector(row['world_ball_'+side]) for row in raw[a:b]];result['support_slip_'+side+'_mm']=max((v-pts[0]).length for v in pts)*1000
 pts=pts[:4];result['contact_lock_'+side+'_mm']=max((v-pts[0]).length for v in pts)*1000
result['pelvis_vertical_mm']=(max(row['pelvis_z'] for row in raw)-min(row['pelvis_z'] for row in raw))*1000
result['head_vertical_mm']=(max(row['head_z'] for row in raw)-min(row['head_z'] for row in raw))*1000
x=[row['hip_yaw'] for row in raw];y=[row['shoulder_yaw'] for row in raw];xm=sum(x)/24;ym=sum(y)/24
result['shoulder_hip_correlation']=sum((a-xm)*(b-ym) for a,b in zip(x,y))/math.sqrt(sum((a-xm)**2 for a in x)*sum((b-ym)**2 for b in y))
r.animation_data.action=bpy.data.actions['REV_Idle'];s.frame_set(1);a={b.name:b.matrix.copy() for b in M.P};s.frame_set(90)
result['idle_loop_max_matrix_error']=max(abs(a[b.name][i][j]-b.matrix[i][j]) for b in M.P for i in range(4) for j in range(4))
result['ground_minima']={}
for act,frames in [('REV_Idle',[1,40,58,90]),('REV_AgileMove_InPlace',range(1,25))]:
 r.animation_data.action=bpy.data.actions[act];vals=[]
 for f in frames:
  s.frame_set(f);ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();vals.append(min(v.co.z for v in me.vertices));ev.to_mesh_clear()
 result['ground_minima'][act]=min(vals)
result['passes_numeric_gate']=result['support_slip_l_mm']<2 and result['support_slip_r_mm']<2 and result['head_vertical_mm']<result['pelvis_vertical_mm'] and result['shoulder_hip_correlation']<-.85 and result['idle_loop_max_matrix_error']<.0001
(M.D/'qa/stage1_metrics.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
