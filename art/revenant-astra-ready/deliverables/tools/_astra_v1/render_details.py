import bpy,sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M
D=M.D;bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Stage2.blend'));M.init();M.review_setup();r=M.r;s=M.s
r.animation_data.action=bpy.data.actions['REV_Idle'];s.frame_set(1);cam=bpy.data.objects['CAM_three'];s.camera=cam;s.render.resolution_x=900;s.render.resolution_y=900
for name,bone,offset,direction,zoom in [('Face','head',(0,-.02,.06),(0,-1,.04),.52),('BloodClaw','hand_r',(0,-.04,-.06),(-.6,-1,.3),.42),('Armor','clavicle_r',(-.06,0,.04),(-.6,-1,.3),.56),('Hair','head',(0,.12,-.03),(.4,1,.2),.70),('Coat','coat_2_2',(0,.05,-.1),(.4,1,.1),1.18)]:
 center=r.pose.bones[bone].head+Vector(offset);cam.location=center+Vector(direction)*3;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=zoom;s.render.filepath=str(D/'qa'/f'Detail_{name}.png');bpy.ops.render.render(write_still=True)
