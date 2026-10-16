import bpy, sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
original='--original' in sys.argv
if original:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.context.scene.render.fps=60
 bpy.ops.import_scene.gltf(filepath=str(OUT.parents[1]/'godot/assets/models/warrior_player.glb'))
 next(o for o in bpy.context.scene.objects if o.type=='ARMATURE').name='WarriorRig'
else:bpy.ops.wm.open_mainfile(filepath=str(OUT/'warrior_animated.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['WarriorRig']
for track in rig.animation_data.nla_tracks:track.mute=True
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world.color=(.2,.2,.2)
bpy.ops.object.camera_add(location=(3,-5,2.7));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=3.0;scene.camera=camera
for loc,power,size in [((2,-4,5),700,4),((-3,-1,3),400,3),((0,3,4),600,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size
 lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
for clip,frame in [('Idle',20),('Run',12),('Attack1',25),('Death',140)]:
 action=bpy.data.actions[clip];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 scene.frame_set(frame);scene.render.filepath=str(OUT/(('original_' if original else '')+clip.lower()+'.png'));bpy.ops.render.render(write_still=True)
