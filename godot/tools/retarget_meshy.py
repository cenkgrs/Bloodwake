"""Retarget a Meshy/rigify animation onto the project's mixamorig skeleton.

Meshy hands back a 28-bone rig whose bone names line up with Mixamo's but whose
rest pose does not, so an animation cannot simply be dropped onto the game rig.
This bakes the source's world-space rotation delta from its own rest onto the
target's rest, which is the part that transfers; bone lengths and rest orientation
stay the target's own.

The output is an ordinary Mixamo-shaped FBX, so build_mixamo_warrior.py consumes
it like any other clip and the pipeline keeps a single contract.

    blender -b -P godot/tools/retarget_meshy.py -- <source.fbx> <out.fbx>
"""
import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index('--') + 1:]
SOURCE, TARGET_FBX = argv[0], argv[1]
ROOT = Path(__file__).resolve().parents[2]
# Any Mixamo clip will do: it is imported only to borrow the game skeleton's rest.
RIG = ROOT / 'art/warrior/source/mixamo/Great Sword Idle.fbx'

# Meshy's names match Mixamo's apart from the prefix and a couple of spellings.
# Fingers and the *_End tips have no counterpart worth driving.
PAIRS = [
    ('Hips', 'Hips'), ('Spine', 'Spine'), ('Spine01', 'Spine1'), ('Spine02', 'Spine2'),
    ('neck', 'Neck'), ('Head', 'Head'),
    ('LeftShoulder', 'LeftShoulder'), ('LeftArm', 'LeftArm'),
    ('LeftForeArm', 'LeftForeArm'), ('LeftHand', 'LeftHand'),
    ('RightShoulder', 'RightShoulder'), ('RightArm', 'RightArm'),
    ('RightForeArm', 'RightForeArm'), ('RightHand', 'RightHand'),
    ('LeftUpLeg', 'LeftUpLeg'), ('LeftLeg', 'LeftLeg'),
    ('LeftFoot', 'LeftFoot'), ('LeftToeBase', 'LeftToeBase'),
    ('RightUpLeg', 'RightUpLeg'), ('RightLeg', 'RightLeg'),
    ('RightFoot', 'RightFoot'), ('RightToeBase', 'RightToeBase'),
]


def span(arm):
    heads = [arm.matrix_world @ b.head for b in arm.pose.bones]
    return max(h.z for h in heads) - min(h.z for h in heads)


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

bpy.ops.import_scene.fbx(filepath=SOURCE)
src = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
# Meshy ships the real motion alongside a two-frame stub, and the stub is what the
# importer leaves assigned. Take the longest action instead.
clip = max(bpy.data.actions, key=lambda a: a.frame_range[1] - a.frame_range[0])
src.animation_data.action = clip
src.animation_data.action_slot = clip.slots[0]
lo, hi = int(clip.frame_range[0]), int(clip.frame_range[1])
print('RETARGET source=%s action=%s frames=%d-%d' % (Path(SOURCE).name, clip.name[:36], lo, hi), flush=True)

before = set(bpy.context.scene.objects)
bpy.ops.import_scene.fbx(filepath=str(RIG))
fresh = set(bpy.context.scene.objects) - before
dst = next(o for o in fresh if o.type == 'ARMATURE')
for o in fresh:
    if o.type == 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)

missing = [s for s, _ in PAIRS if s not in src.pose.bones] + \
          [d for _, d in PAIRS if 'mixamorig:' + d not in dst.pose.bones]
assert not missing, 'unmapped bones: %s' % missing

ratio = span(dst) / max(span(src), 1e-9)
print('RETARGET height src=%.4f dst=%.4f ratio=%.3f' % (span(src), span(dst), ratio), flush=True)

dst.animation_data_clear()
dst.animation_data_create()
baked = bpy.data.actions.new('Retargeted')
baked.use_fake_user = True
dst.animation_data.action = baked

rest_src = {s: src.matrix_world @ src.data.bones[s].matrix_local for s, _ in PAIRS}
rest_dst = {d: dst.matrix_world @ dst.data.bones['mixamorig:' + d].matrix_local for _, d in PAIRS}

scene = bpy.context.scene
for frame in range(lo, hi + 1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    # PAIRS is in hierarchy order: a parent must be posed before its child, or the
    # child is placed against a stale parent and the whole limb drifts.
    for s_name, d_name in PAIRS:
        s_pose = src.matrix_world @ src.pose.bones[s_name].matrix
        delta = (s_pose @ rest_src[s_name].inverted()).to_quaternion()
        pbone = dst.pose.bones['mixamorig:' + d_name]
        placed = (delta @ rest_dst[d_name].to_quaternion()).to_matrix().to_4x4()
        if d_name == 'Hips':
            # Only the root carries translation; every other bone hangs off its parent.
            offset = (s_pose.to_translation() - rest_src[s_name].to_translation()) * ratio
            placed.translation = rest_dst[d_name].to_translation() + offset
        else:
            placed.translation = (dst.matrix_world @ pbone.matrix).to_translation()
        pbone.matrix = dst.matrix_world.inverted() @ placed
        bpy.context.view_layer.update()
    for _, d_name in PAIRS:
        pbone = dst.pose.bones['mixamorig:' + d_name]
        pbone.keyframe_insert('rotation_quaternion', frame=frame)
        if d_name == 'Hips':
            pbone.keyframe_insert('location', frame=frame)

bpy.ops.object.select_all(action='DESELECT')
dst.select_set(True)
bpy.context.view_layer.objects.active = dst
scene.frame_start, scene.frame_end = lo, hi
scene.render.fps = 60
scene.render.fps_base = 1.0
bpy.ops.export_scene.fbx(filepath=TARGET_FBX, use_selection=True, object_types={'ARMATURE'},
                         add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False,
                         bake_anim_use_nla_strips=False, bake_anim_step=1.0)
print('RETARGET_DONE %s frames=%d' % (TARGET_FBX, hi - lo + 1), flush=True)
