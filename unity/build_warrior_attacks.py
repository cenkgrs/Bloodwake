"""Retarget the two supplied slashes without changing the approved walk or mesh.
blender -b -t 2 --python-exit-code 1 --python unity/build_warrior_attacks.py
"""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/enemies/mixamo/warrior/slash-20261015'
OUT = ROOT / 'unity/Assets/Bloodwake/Resources/Animations/WarriorCombat'
OUT.mkdir(parents=True, exist_ok=True)
reports = []
directions = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ('outward', 'inward', 'turn')
assert all(d in ('outward', 'inward', 'turn') for d in directions)
for direction in directions:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT / 'unity/Assets/Bloodwake/Resources/Models/enemy_warrior/enemy_warrior.fbx'))
    dst = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    dst.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for bone in dst.pose.bones:
        bone.matrix_basis.identity()
        bone.rotation_mode = 'QUATERNION'
    bpy.context.view_layer.update()
    before = set(bpy.data.objects)
    source_file = {'outward': 'outward-v2.fbx', 'inward': 'inward-v2.fbx', 'turn': 'turn-180.fbx'}[direction]
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / source_file))
    fresh = set(bpy.data.objects) - before
    src = next(o for o in fresh if o.type == 'ARMATURE')
    lo, hi = map(int, src.animation_data.action.frame_range)
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    assert set(src.data.bones.keys()) == set(dst.data.bones.keys())
    names = sorted(dst.data.bones.keys(), key=lambda n: len(dst.data.bones[n].parent_recursive))
    sr = {n: src.matrix_world @ src.data.bones[n].matrix_local for n in names}
    dr = {n: dst.matrix_world @ dst.data.bones[n].matrix_local for n in names}
    def leg_length(rest):
        return sum((rest['mixamorig:' + a].translation - rest['mixamorig:' + b].translation).length
                   for a, b in [('LeftUpLeg', 'LeftLeg'), ('LeftLeg', 'LeftFoot')])
    ratio = leg_length(dr) / leg_length(sr)
    offset = {}
    for n in names:
        qs, qd = sr[n].to_quaternion(), dr[n].to_quaternion()
        align = (qd @ Vector((0, 1, 0))).rotation_difference(qs @ Vector((0, 1, 0)))
        offset[n] = qs.inverted() @ align @ qd
    name = 'Warrior_Turn180' if direction == 'turn' else 'Warrior_' + direction.title() + 'Slash'
    baked = bpy.data.actions.new(name)
    dst.animation_data_create()
    dst.animation_data.action = baked
    previous, samples = {}, []
    for frame in range(lo, hi + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        for p in dst.pose.bones:
            p.matrix_basis.identity()
        bpy.context.view_layer.update()
        for n in names:
            p = dst.pose.bones[n]
            world = src.matrix_world @ src.pose.bones[n].matrix
            central = n.split(':')[-1] in ('Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head', 'HeadTop_End')
            q = world.to_quaternion() @ sr[n].to_quaternion().inverted() @ dr[n].to_quaternion() if central else world.to_quaternion() @ offset[n]
            m = Matrix.LocRotScale((dst.matrix_world @ p.matrix).translation, q, dr[n].to_scale())
            if n == 'mixamorig:Hips':
                m.translation = dr[n].translation + (world.translation - sr[n].translation) * ratio
            p.matrix = dst.matrix_world.inverted() @ m
            bpy.context.view_layer.update()
        for p in dst.pose.bones:
            q = p.rotation_quaternion.copy()
            if p.name in previous and q.dot(previous[p.name]) < 0:
                q.negate()
            p.rotation_quaternion = q
            previous[p.name] = q.copy()
            p.keyframe_insert('rotation_quaternion', frame=frame - lo + 1)
            if p.name == 'mixamorig:Hips':
                p.keyframe_insert('location', frame=frame - lo + 1)
        samples.append({n: list(dst.matrix_world @ dst.pose.bones['mixamorig:' + n].head)
                        for n in ('Hips', 'RightHand', 'RightHandMiddle1', 'LeftFoot', 'RightFoot')})
    for obj in fresh:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        if action != baked:
            bpy.data.actions.remove(action)
    dst.animation_data.action = baked
    dst.animation_data.action_slot = baked.slots[0]
    bpy.context.scene.render.fps = round(fps)
    bpy.context.scene.render.fps_base = 1
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = hi - lo + 1
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + '.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    dst.select_set(True)
    bpy.context.view_layer.objects.active = dst
    bpy.ops.export_scene.fbx(filepath=str(OUT / (name + '.fbx')), use_selection=True,
        object_types={'ARMATURE'}, add_leaf_bones=False, bake_anim=True,
        bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=0, axis_forward='-Z', axis_up='Y')
    travel = max(Vector(s['RightHand']).x for s in samples) - min(Vector(s['RightHand']).x for s in samples)
    assert travel > .3, ('Frozen slash', direction, travel)
    report = dict(name=name, source=source_file, fps=fps, frames=hi-lo+1, duration=(hi-lo)/fps,
                  sourceScaleToTarget=ratio, handTravel=travel, samples=samples)
    reports.append(report)
    print('WARRIOR_SLASH_BUILT', name, report['duration'], 'handTravel', travel, flush=True)
report_path = SOURCE / 'slash-report.json'
old = json.loads(report_path.read_text()) if report_path.exists() else []
updated = {r['name']: r for r in old}
updated.update({r['name']: r for r in reports})
report_path.write_text(json.dumps(list(updated.values()), indent=2))
