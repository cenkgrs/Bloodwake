"""Render the CC0 rigged Warrior from a fixed 3/4 game camera.

Run with Blender in background mode and the source .blend as the main file:
blender --background source/Quaternius_Warrior.blend --python render_preview.py
"""

from pathlib import Path
import os

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
scene = bpy.context.scene
rig = bpy.data.objects["CharacterArmature"]
rig.animation_data_create()
rig.animation_data.action = bpy.data.actions["Idle"]
scene.frame_set(15)

# Prototype a closed helmet using the CC0 Animated Knight accessory pack.
helmet_name = os.environ.get("BLOODWAKE_HELMET", "Helmet2")
helmet_path = HERE / "source" / "animated_knight" / f"{helmet_name}.blend"
with bpy.data.libraries.load(str(helmet_path), link=False) as (source, target_data):
    object_name = "Helmet" if helmet_name == "Helmet1" else helmet_name
    target_data.objects = [name for name in source.objects if name == object_name]
helmet = target_data.objects[0]
scene.collection.objects.link(helmet)
helmet.parent = rig
helmet.parent_type = "BONE"
helmet.parent_bone = "Head"
helmet.location = (0, 0, 0)
helmet.rotation_euler = (0, 0, 0)
helmet.scale = (0.42, 0.42, 0.42)
steel = bpy.data.materials.new("BloodwakeDarkSteel")
steel.diffuse_color = (0.025, 0.035, 0.055, 1)
steel.use_nodes = True
bsdf = steel.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.025, 0.035, 0.055, 1)
bsdf.inputs["Metallic"].default_value = 0.7
bsdf.inputs["Roughness"].default_value = 0.42
helmet.data.materials.clear()
helmet.data.materials.append(steel)
bpy.data.objects["Face"].hide_render = True

camera_data = bpy.data.cameras.new("BloodwakeCamera")
camera = bpy.data.objects.new("BloodwakeCamera", camera_data)
scene.collection.objects.link(camera)
camera.location = (4.5, -7.5, 7.5)
target = Vector((0, 0, 1.4))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 5.2
scene.camera = camera

def area_light(name, location, power, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


area_light("CoolKey", (2, -4, 7), 750, (0.72, 0.82, 1.0), 5)
area_light("CrimsonRim", (-3, 3, 5), 550, (1.0, 0.20, 0.16), 3)
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = str(HERE / "preview" / f"warrior_{helmet_name.lower()}.png")
(HERE / "preview").mkdir(parents=True, exist_ok=True)
if os.environ.get("BLOODWAKE_MOTION_TEST"):
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    for action_name, frames in {
        "Idle": [0, 12, 24, 36, 48, 60],
        "Run": [0, 3, 6, 9, 12, 15, 18, 21],
        "Sword_Attack": [0, 3, 6, 9, 12, 15, 18, 20],
        "RecieveHit": [0, 2, 4, 6, 8, 10],
        "Death": [0, 4, 8, 12, 16, 20, 24, 28],
    }.items():
        rig.animation_data.action = bpy.data.actions[action_name]
        for index, frame in enumerate(frames):
            scene.frame_set(frame)
            scene.render.filepath = str(HERE / "preview" / "motion" / action_name.lower() / f"{index:02d}.png")
            Path(scene.render.filepath).parent.mkdir(parents=True, exist_ok=True)
            bpy.ops.render.render(write_still=True)
else:
    bpy.ops.render.render(write_still=True)
