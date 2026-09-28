"""Render a contact sheet straight off a source FBX, before any processing.

Cut points for a combo cannot be chosen from a speed curve alone - a clip can be
perfectly still because the character is lying on the floor. This renders frames
across the full range against a grid so the motion can be looked at.

    blender -b -P godot/tools/fbx_contact_sheet.py -- <shots> <file.fbx> ...
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
shots = int(argv[0])
OUT = Path('/tmp/fbx_sheets')
OUT.mkdir(exist_ok=True)

for path in argv[1:]:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.actions):
        bpy.data.actions.remove(block)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    action = arm.animation_data.action
    lo, hi = (int(v) for v in action.frame_range)

    # Mixamo FBXs import at centimetre scale, so the rig is normalised to roughly
    # 1.8 units before anything is framed against it.
    bpy.context.scene.frame_set(lo)
    bpy.context.view_layer.update()
    heads = [arm.matrix_world @ b.head for b in arm.pose.bones]
    height = max(h.z for h in heads) - min(h.z for h in heads)
    if height > 1e-9:
        arm.scale *= 1.8 / height
    bpy.context.view_layer.update()

    # A floor plane at z=0 makes a clip that sinks obvious at a glance, and the
    # camera pulls back far enough to keep a travelling character in shot.
    bpy.ops.mesh.primitive_plane_add(size=24, location=(0, 0, 0))
    bpy.ops.object.camera_add(location=(2.6, -2.6, 1.7))
    cam = bpy.context.object
    cam.data.lens = 40
    OFFSET = Vector((2.6, -2.6, 1.7))
    scene = bpy.context.scene
    scene.camera = cam
    # Cycles rather than Workbench/EEVEE: those need a GL context, which a
    # background Blender does not have.
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 6
    scene.cycles.use_denoising = False
    scene.world.color = (0.18, 0.2, 0.24)
    bpy.ops.object.light_add(type='SUN', location=(3, -3, 6))
    bpy.context.object.data.energy = 4.0
    scene.render.resolution_x = 300
    scene.render.resolution_y = 380
    scene.render.film_transparent = False

    stem = Path(path).stem.replace(' ', '_')
    hips = arm.pose.bones['mixamorig:Hips']
    for i in range(shots):
        frame = lo + round((hi - lo) * i / max(shots - 1, 1))
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        # Follow the body. These clips travel several metres, and a fixed camera
        # loses the pose - which is the thing a cut point is chosen from.
        focus = arm.matrix_world @ hips.head
        focus.z = 0.9
        cam.location = focus + OFFSET
        cam.rotation_euler = (focus - cam.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(OUT / ('%s_%02d_f%03d.png' % (stem, i, frame)))
        bpy.ops.render.render(write_still=True)
    print('FBX_SHEET %s frames %d-%d' % (stem, lo, hi), flush=True)
print('FBX_SHEET_DONE', flush=True)
