import bpy,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M;import vfx_lib as V
D=M.D;view=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'three'
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Animated.blend'));M.init();M.review_setup();s=M.s;r=M.r
for t in r.animation_data.nla_tracks:t.mute=True
for o in bpy.data.collections['REV_VFX_PROXY'].objects:o.animation_data_clear()
bpy.data.objects['REV_Body'].animation_data_clear()
for o in bpy.data.objects:
 if o.type=='CAMERA':o.data.animation_data_clear()
s.render.resolution_x=720 if view=='three' else 480;s.render.resolution_y=s.render.resolution_x
s.camera=bpy.data.objects['CAM_'+view]
info=json.loads((D/'animation_events.json').read_text())['actions']
for name,data in info.items():
 folder=D/'previews'/'action_frames'/view/name;folder.mkdir(parents=True,exist_ok=True)
 if name.startswith('REV_Hit'):M.idle(1)
 r.animation_data.action=bpy.data.actions[name]
 s.camera.data.ortho_scale=6.5 if name=='REV_BloodBurst' else 2.7
 for f in range(1,data['end']+1):
  if (folder/f'{f:04}.png').exists():continue
  s.frame_set(f);V.apply(name,f)
  s.render.filepath=str(folder/f'{f:04}.png');bpy.ops.render.render(write_still=True)
print('ACTION_PREVIEWS_COMPLETE',view)
