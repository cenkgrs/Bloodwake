"""Export the animated Revenant.

blender -b Revenant_Animated.blend --python tools/export_game.py -- OUT.glb [game|full]
  game: runtime clip set, original-resolution PNG textures (Bloodwake asset)
  full: every REV_ action, original textures (deliverable)
The scene is reduced to REV_Rig + REV_Body in memory only; the .blend is not saved.
"""
import bpy, sys
from pathlib import Path

argv = sys.argv[sys.argv.index('--') + 1:]
out = Path(argv[0]).resolve()
mode = argv[1] if len(argv) > 1 else 'full'

GAME = ['REV_Idle', 'REV_AgileRun_InPlace', 'REV_AgileMove_InPlace',
        'REV_HitLight_Front', 'REV_HitLight_Left', 'REV_HitLight_Right',
        'REV_HitLight_Front_Additive', 'REV_HitLight_Left_Additive', 'REV_HitLight_Right_Additive',
        'REV_Death', 'REV_TeleportAttack', 'REV_BloodBurst', 'REV_ClawAttack_1', 'REV_ClawAttack_2', 'REV_ClawAttack_3']

rig = bpy.data.objects['REV_Rig']
body = bpy.data.objects['REV_Body']
for o in list(bpy.data.objects):
    if o not in (rig, body):
        bpy.data.objects.remove(o, do_unlink=True)
rig.location = (0, 0, 0)
body.animation_data_clear()
if rig.animation_data:
    rig.animation_data.action = None
    for t in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(t)
keep = GAME if mode == 'game' else [a.name for a in bpy.data.actions if a.name.startswith('REV_')]
for a in list(bpy.data.actions):
    if a.name not in keep:
        bpy.data.actions.remove(a)
    else:
        # Only bone channels: object-level channels would override the engine's transform.
        for fc in list(a.fcurves):
            if not fc.data_path.startswith('pose.bones'):
                a.fcurves.remove(fc)
# Every action must be reachable by the ACTIONS export mode: stash on NLA tracks.
for name in keep:
    act = bpy.data.actions[name]
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, int(act.frame_range[0]), act)
    tr.mute = True
for b in rig.pose.bones:
    b.matrix_basis.identity()
bpy.context.scene.render.fps = 60
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(out), export_format='GLB', use_selection=False,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_step=1, export_anim_single_armature=True, export_reset_pose_bones=True,
    export_optimize_animation_size=False, export_def_bones=False, export_skins=True,
    export_image_format='PNG',
    export_cameras=False, export_lights=False, export_yup=True, export_apply=False,
    export_morph=False, export_anim_slide_to_zero=True)
print('EXPORTED', out, mode, len(keep))
