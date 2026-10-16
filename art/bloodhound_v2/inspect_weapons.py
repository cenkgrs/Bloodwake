import bpy, math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parent
rig=bpy.data.objects['Bloodhound_Rig'];rig.animation_data_clear()
for bone in rig.pose.bones:
 bone.location=(0,0,0);bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
for name in ['Revolver.L','Revolver.R','BH_Bomb_Held','BH_Bomb_Flight']:
 bpy.data.objects[name].hide_render=True
mesh=bpy.data.objects['Bloodhound_Body']
mat=bpy.data.materials.new('selection');mat.diffuse_color=(0.02,0.8,0.03,1)
mesh.data.materials.append(mat)
selected=[]
for p in mesh.data.polygons:
 c=sum((mesh.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
 if (.225 if c.z>1.02 else .205)<abs(c.x)<.285 and .79<c.z<1.115 and -.20<c.y<-.08:
  p.material_index=1;selected.append(p.index)
print('GUN_SELECTION',len(selected))
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=16
scene.render.resolution_x=800;scene.render.resolution_y=800
cam=scene.camera;center=Vector((.22,-.05,.99));cam.data.ortho_scale=.55
for name,pos in [('front',(.22,-5,1.0)),('side',(5,-.3,1.1)),('oblique',(2,-4,1.5))]:
 cam.location=pos;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(root/'qa'/('gun_selection_'+name+'.png'));bpy.ops.render.render(write_still=True)
