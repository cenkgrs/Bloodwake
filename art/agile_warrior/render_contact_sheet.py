from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
OUT=HERE/'qa_frames';OUT.mkdir(exist_ok=True)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=360;scene.render.resolution_y=450;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
if scene.world is None:scene.world=bpy.data.worlds.new('ReviewWorld')
scene.world.color=(.008,.006,.009)
rig=bpy.data.objects['VesperRig']
camera_data=bpy.data.cameras.new('QA Camera');camera=bpy.data.objects.new('QA Camera',camera_data);scene.collection.objects.link(camera);camera.location=(0,-5.2,1.05);camera_data.type='ORTHO';camera_data.ortho_scale=2.55
def look(obj,point):obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
look(camera,(0,0,.95));scene.camera=camera
for location,energy,size in [((-3,-4,5),1300,4),((3,-2,3),850,3),((0,3,4),1000,3)]:
 data=bpy.data.lights.new('QA Light','AREA');data.energy=energy;data.shape='DISK';data.size=size;lamp=bpy.data.objects.new('QA Light',data);lamp.location=location;scene.collection.objects.link(lamp);look(lamp,(0,0,.9))
samples=[('Idle',.02),('Run',.5),('Attack1',.45),('Attack2',.42),('Attack3',.52),('DashAttack',.55),('CastQ',.48),('Ultimate',.62),('Death',.7)]
for name,phase in samples:
 action=bpy.data.actions[name];rig.animation_data.action=action
 if hasattr(action,'slots') and len(action.slots):rig.animation_data.action_slot=action.slots[0]
 start,end=action.frame_range;scene.frame_set(round(start+(end-start)*phase));scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
print('VESPER_QA_FRAMES',OUT)
