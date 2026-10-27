import bpy,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M;from combat_lib import death,teleport,burst
D=M.D;bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Stage2.blend'));M.init();M.review_setup()
info=json.loads((D/'animation_events.json').read_text())['actions']
for name,length,fn,frames,tag in [('REV_Death',72,death,[24,52,72],'death_final'),('REV_TeleportAttack',42,teleport,[6,15,26,34],'teleport_final'),('REV_BloodBurst',120,burst,[18,59,60,108,115],'burst_final')]:
 a=M.key_action(name,length,fn)
 for n,f in info[name]['events'].items():a.pose_markers.new(n).frame=f
 M.render_stills(name,frames,tag)
M.r.animation_data.action=bpy.data.actions['REV_Idle'];M.s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(D/'workfiles/Stage2_polish.blend'));bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Stage2.blend'))
print('SECONDARY_COLLISIONS_POLISHED')
