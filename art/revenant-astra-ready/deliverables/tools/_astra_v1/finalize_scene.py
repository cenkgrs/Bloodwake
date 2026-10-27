import bpy,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M;import vfx_lib as V
D=M.D;bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Stage2.blend'));M.init();M.review_setup();s=M.s;r=M.r
V.build()
info=json.loads((D/'animation_events.json').read_text());order=list(info['actions']);intervals=[];cursor=1
for name in order:
 bpy.data.actions[name]['events_json']=json.dumps(info['actions'][name]['events']);end=info['actions'][name]['end'];intervals.append((name,cursor,end));cursor+=end+12
for t in list(r.animation_data.nla_tracks):r.animation_data.nla_tracks.remove(t)
track=r.animation_data.nla_tracks.new();track.name='REV • All Actions sequential preview'
for name,start,length in intervals:
 a=bpy.data.actions[name];strip=track.strips.new(name,start,a);strip.extrapolation='HOLD_FORWARD';strip.blend_type='REPLACE';strip.use_auto_blend=False
r.animation_data.action=None;s.name='REV_NLA_Preview';s.frame_start=1;s.frame_end=cursor-13
s.timeline_markers.clear()
for name,start,length in intervals:
 s.timeline_markers.new(name,frame=start)
 for event,f in info['actions'][name]['events'].items():s.timeline_markers.new(name+' / '+event,frame=start+f-1)
# Key the independent VFX on the global NLA demonstration timeline.
for name,start,length in intervals:
 for local in range(1,length+13):
  frame=start+local-1;s.frame_set(frame)
  V.apply(name if local<=length else '',min(local,length),keyframe=frame)
  for o in bpy.data.collections['REV_VFX_PROXY'].objects:
   if o.name.startswith('CLAW'):
    o.keyframe_insert('location',frame=frame);o.rotation_mode='QUATERNION';o.keyframe_insert('rotation_quaternion',frame=frame)
for a in bpy.data.actions:
 if not a.name.startswith('REV_'):
  a.name='VFX_'+a.name
  for fc in a.fcurves:
   for k in fc.keyframe_points:k.interpolation='CONSTANT' if 'hide' in fc.data_path else 'LINEAR'
# NLA camera expands only for the radial ultimate, with a readable character before and after.
cam=bpy.data.objects['CAM_three'];s.camera=cam
for name,start,length in intervals:
 for f,scale in [(start,2.7),(start+length-1,2.7)]:
  cam.data.ortho_scale=7.0 if name=='REV_BloodBurst' else scale;cam.data.keyframe_insert('ortho_scale',frame=f)
for a in bpy.data.actions:
 if a.name.startswith('Camera'):
  for fc in a.fcurves:
   for k in fc.keyframe_points:k.interpolation='CONSTANT'
s.render.fps=60;s.render.resolution_x=960;s.render.resolution_y=960;s.frame_set(1)
r['animation_library']='8 main actions + root-motion diagnostic + 3 upper-body additive actions. Mute NLA track before selecting an action in Action Editor.'
r['locomotion_speed_mps']=2.45;r['height_m']=1.90;r['forward_axis']='-Y Blender / +Z glTF';r['root_ground_plane']='Z=0'
for im in bpy.data.images:
 if im.has_data:im.pack()
(D/'qa/nla_timeline.json').write_text(json.dumps([{'action':n,'start':st,'end':st+ln-1,'local_end':ln} for n,st,ln in intervals],indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Animated.blend'));print('FINAL_SCENE_SAVED',s.frame_end)
