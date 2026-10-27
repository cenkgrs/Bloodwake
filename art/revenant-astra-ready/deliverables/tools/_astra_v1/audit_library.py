import bpy,json,sys,math
from pathlib import Path
D=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Animated.blend'));r=bpy.data.objects['REV_Rig'];s=bpy.context.scene;m=bpy.data.objects['REV_Body']
for t in r.animation_data.nla_tracks:t.mute=True
info=json.loads((D/'animation_events.json').read_text())['actions'];out={'actions':{},'failures':[]}
for name,data in info.items():
 a=bpy.data.actions[name];r.animation_data.action=a
 got={x.name:x.frame for x in a.pose_markers};scale_tracks=[fc.data_path for fc in a.fcurves if fc.data_path.endswith('scale')]
 bones=set(fc.data_path.split('"')[1] for fc in a.fcurves if fc.data_path.startswith('pose.bones'))
 entry={'frame_range':list(a.frame_range),'markers':got,'scale_channels':len(scale_tracks),'keyed_bones':sorted(bones),'min_mesh_z':1e9,'max_root_ground_error':0}
 for f in range(1,data['end']+1):
  s.frame_set(f);ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();entry['min_mesh_z']=min(entry['min_mesh_z'],min(v.co.z for v in me.vertices));ev.to_mesh_clear();entry['max_root_ground_error']=max(entry['max_root_ground_error'],abs(r.pose.bones['root'].head.z))
 if list(a.frame_range)!=[1,data['end']]:out['failures'].append(name+' range')
 if got!=data['events']:out['failures'].append(name+' markers')
 if scale_tracks:out['failures'].append(name+' deform scale')
 if not name.startswith('REV_Hit') and entry['min_mesh_z']<-.003:out['failures'].append(name+' mesh below ground')
 if entry['max_root_ground_error']>.001:out['failures'].append(name+' root altitude')
 if name.startswith('REV_Hit') and any(n.startswith(('thigh','calf','foot','pelvis','root')) for n in bones):out['failures'].append(name+' lower body tracks')
 out['actions'][name]=entry
out['vfx_collection_separate']=bpy.data.collections.get('REV_VFX_PROXY') is not None and m.name not in bpy.data.collections['REV_VFX_PROXY'].objects
out['fps']=s.render.fps;out['height_rest_m']=1.9;out['rig_bones']=len(r.data.bones)
(D/'qa/library_audit.json').write_text(json.dumps(out,indent=2));print(json.dumps({k:v for k,v in out.items() if k!='actions'},indent=2));print([(k,round(v['min_mesh_z'],4)) for k,v in out['actions'].items()])
