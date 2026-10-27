import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent));import motion_lib as M
D=M.D;bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Stage1.blend'));M.init();M.review_setup();s=M.s;r=M.r
# Checker markers at 25 cm intervals make contacts measurable in moving world space.
verts=[];faces=[]
for x in range(-6,7):
 for y in range(-25,7):
  if (x+y)%2:continue
  i=len(verts);verts +=[(x*.25,y*.25,-.002),((x+1)*.25,y*.25,-.002),((x+1)*.25,(y+1)*.25,-.002),(x*.25,(y+1)*.25,-.002)];faces.append((i,i+1,i+2,i+3))
me=bpy.data.meshes.new('Contact grid');me.from_pydata(verts,[],faces);o=bpy.data.objects.new('Contact_Grid',me);s.collection.objects.link(o);o.color=(.18,.20,.23,1)
# Workbench texture mode falls back to material diffuse colors.
mat=bpy.data.materials.new('Contact grid');mat.diffuse_color=(.22,.24,.27,1);o.data.materials.append(mat)
for name,action,frames,angle,travel,sil in [('move_world','REV_AgileMove_InPlace',96,'game',True,False),('move_side','REV_AgileMove_InPlace',24,'side',False,False),('move_silhouette','REV_AgileMove_InPlace',24,'side',False,True),('idle','REV_Idle',90,'game',False,False)]:
 if '--sil-only' in sys.argv and not sil:continue
 folder=D/'previews'/'frames'/name;folder.mkdir(parents=True,exist_ok=True);r.animation_data.action=bpy.data.actions[action];s.camera=bpy.data.objects['CAM_'+angle];camera_origin=s.camera.location.copy()
 bpy.data.objects['Review_Ground'].hide_render=sil;o.hide_render=sil;s.world.color=(.72,.72,.72) if sil else (.055,.055,.06)
 if sil:s.display.shading.color_type='SINGLE';s.display.shading.single_color=(.004,.004,.004);s.display.shading.light='FLAT';s.display.shading.show_shadows=False;s.display.shading.show_cavity=False
 else:s.display.shading.color_type='TEXTURE';s.display.shading.light='STUDIO';s.display.shading.show_shadows=True;s.display.shading.show_cavity=True
 for i in range(frames):
  f=i%24+1 if 'Agile' in action else i+1;s.frame_set(f)
  r.location.y=-2.45*i/60 if travel else 0;s.camera.location=camera_origin+Vector((0,r.location.y,0))
  s.render.filepath=str(folder/f'{i:04}.png');bpy.ops.render.render(write_still=True)
 r.location.y=0;s.camera.location=camera_origin
print('STAGE1_PREVIEWS_RENDERED')
