"""Quantitative stage gate. No automatic visual approval."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector as V
import numpy as np

root=Path(bpy.data.filepath).parent;rig=bpy.data.objects['Bloodhound_Rig'];mesh=bpy.data.objects['Bloodhound_Body'];scene=bpy.context.scene
speed=float(rig['locomotion_source_speed_mps']);period=int(rig['locomotion_cycle_frames'])
report={'status':'AWAITING_VISUAL_REVIEW','stage':rig['delivery_status'],'actions':{},'failures':[]}
samples=[];rest_foot={}
for side,s in [('L',1),('R',-1)]:
 rest_foot[side]=[v.index for v in mesh.data.vertices if s*v.co.x>.08 and v.co.z<.016]
for name in ['BH_Idle','BH_AgileMove']:
 action=bpy.data.actions[name];rig.animation_data.action=action;poses=[];frames=[];floor=1e9
 for f in range(1,int(action.frame_range[1])+1):
  scene.frame_set(f);bpy.context.view_layer.update();evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
  lowest=min(evaluated.data.vertices,key=lambda v:v.co.z)
  if lowest.co.z<floor:
   floor=lowest.co.z;source=mesh.data.vertices[lowest.index]
   low_detail={'frame':f,'vertex':lowest.index,'weights':{mesh.vertex_groups[g.group].name:g.weight for g in source.groups}}
  poses.append({b.name:b.matrix.copy() for b in rig.pose.bones})
  row={'frame':f,'hip_z':rig.pose.bones['Pelvis'].head.z,'head_z':rig.pose.bones['Head'].head.z,'feet':{},'toe':{}}
  for part in ['Pelvis','Chest']:
   delta=rig.pose.bones[part].matrix@rig.data.bones[part].matrix_local.inverted();row[part+'_yaw']=delta.to_euler('XYZ').z
  for side in ['L','R']:
   row['feet'][side]=[list(evaluated.data.vertices[i].co) for i in rest_foot[side]]
   bone=rig.data.bones['Foot.'+side];local=bone.matrix_local.inverted()@(bone.head_local+V((0,float(rig['sole_toe_y_'+side]),-.13)))
   row['toe'][side]=list(rig.pose.bones[bone.name].matrix@local)
  frames.append(row)
 seam=max(abs(a-b) for key in poses[0] for ra,rb in zip(poses[0][key],poses[-1][key]) for a,b in zip(ra,rb))
 report['actions'][name]={'loop_matrix_error':seam,'min_mesh_z':floor,'lowest_vertex':low_detail,'root_max_horizontal':max(math.hypot(p['Root'].translation.x,p['Root'].translation.y) for p in poses)}
 if seam>1e-4:report['failures'].append(name+' loop seam')
 if floor<-.005:report['failures'].append(name+' ground penetration >5mm')
 if name=='BH_AgileMove':
  samples=frames
  a=report['actions'][name];a['pelvis_vertical_range']=np.ptp([x['hip_z'] for x in frames]);a['head_vertical_range']=np.ptp([x['head_z'] for x in frames])
  a['pelvis_shoulder_yaw_correlation']=float(np.corrcoef([x['Pelvis_yaw'] for x in frames],[x['Chest_yaw'] for x in frames])[0,1])
  if a['head_vertical_range']>=a['pelvis_vertical_range']*.6:report['failures'].append('Head bounce exceeds 60% of pelvis bounce')
  if a['pelvis_shoulder_yaw_correlation']>-.5:report['failures'].append('Insufficient hip/shoulder opposition')
  for side,start in [('L',0),('R',20)]:
   planted=[]
   for i in range(start,start+4):
    xyz=np.array(frames[i]['feet'][side]);xyz[:,1]-=speed*i/60
    planted.append(xyz)
   error=float(max(np.linalg.norm(x-planted[0],axis=1).max() for x in planted))
   a[side+'_contact_4_frame_max_vertex_drift']=error
   if error>.005:report['failures'].append(side+' sole slip during 4-frame contact')
   toe=[]
   for i in range(start,start+(10 if side=='L' else 11)):
    xyz=np.array(frames[i]['toe'][side]);xyz[1]-=speed*i/60;toe.append(xyz)
   a[side+'_stance_toe_max_world_drift']=float(max(np.linalg.norm(x-toe[0]) for x in toe))
   if a[side+'_stance_toe_max_world_drift']>.005:report['failures'].append(side+' toe slip during entire support phase')
report['numeric_pass']=len(report['failures'])==0
(root/'numeric_gate.json').write_text(json.dumps(report,indent=2))
(root/'measured_curves.json').write_text(json.dumps([{k:v for k,v in x.items() if k!='feet'} for x in samples],indent=2))
print('STAGE1_GATE',json.dumps(report),flush=True)
