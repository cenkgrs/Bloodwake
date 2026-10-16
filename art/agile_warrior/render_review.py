"""Render a quick front-frame QA image from the built Vesper blend."""
from pathlib import Path
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(HERE/'vesper_game_preview.png')
if scene.world is None:scene.world=bpy.data.worlds.new('ReviewWorld')
scene.world.color=(0.012,0.009,0.012)
rig=bpy.data.objects['VesperRig'];action=bpy.data.actions.get('Idle')
rig.animation_data.action=action
if action and hasattr(action,'slots') and len(action.slots):rig.animation_data.action_slot=action.slots[0]
scene.frame_set(1)
camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data);scene.collection.objects.link(camera)
camera.location=(0,-5.2,1.0);camera_data.type='ORTHO';camera_data.ortho_scale=2.45
def look(obj,point):obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
look(camera,(0,0,0.95));scene.camera=camera
for location,energy,size in [((-3,-4,5),1300,4),((3,-2,3),850,3),((0,3,4),1000,3)]:
 data=bpy.data.lights.new('ReviewLight','AREA');data.energy=energy;data.shape='DISK';data.size=size
 lamp=bpy.data.objects.new('ReviewLight',data);lamp.location=location;scene.collection.objects.link(lamp);look(lamp,(0,0,0.9))
bpy.ops.render.render(write_still=True)
