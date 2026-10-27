import bpy,math,json
from mathutils import Matrix,Vector
from pathlib import Path
D=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Source.blend'))
s=bpy.context.scene;r=bpy.data.objects['root'];m=bpy.data.objects['tripo_node_67e3196c'];m.name='REV_Body';r.name='REV_Rig'
for b in r.pose.bones:b.matrix_basis=Matrix.Identity(4);b.custom_shape=None
for o in list(bpy.data.objects):
 if o not in [r,m]:bpy.data.objects.remove(o,do_unlink=True)
r.parent=None;m.parent=r;r.matrix_world=Matrix.Identity(4);m.matrix_world=Matrix.Identity(4)
S=1.9/(max(v.co.y for v in m.data.vertices)-min(v.co.y for v in m.data.vertices));Z=-min(v.co.y for v in m.data.vertices)*S
for v in m.data.vertices:
 x,y,z=v.co;v.co=(x*S,-z*S,Z+y*S)
# The input skin contains identity joint nodes with incompatible inverse-bind matrices.
# Recover a useful anatomical skeleton in the mesh coordinate system, then align joint heads.
bpy.context.view_layer.objects.active=r;r.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for b in r.data.edit_bones:
 h=b.head.copy();t=b.tail.copy();b.head=(h.y*S,-h.x*S+.13,Z+(h.z+.576)*S);b.tail=(t.y*S,-t.x*S+.13,Z+(t.z+.576)*S)
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
s.world=bpy.data.worlds.new('Review world');s.world.color=(.045,.045,.045)
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100
sh=s.display.shading;sh.light='STUDIO';sh.color_type='TEXTURE';sh.show_shadows=True;sh.show_cavity=True;sh.background_type='WORLD'
for name,dir in [('front',(0,-1,.04)),('side',(1,0,.04)),('back',(0,1,.04)),('three',(1,-2,.5))]:
 center=Vector((0,.08,.96));bpy.ops.object.camera_add(location=center+Vector(dir)*4)
 c=bpy.context.object;c.name='CAM_'+name;c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=2.25;s.camera=c
 s.render.filepath=str(D/'qa'/('normalized_'+name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Normalized.blend'))
