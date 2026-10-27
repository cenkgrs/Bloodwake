"""Stage 1: Idle + AgileMove (spec glide) + AgileRun (game speed) + root-motion variant.

blender -b deliverables/Revenant_Rigged.blend --python tools/author_stage1.py
Writes workfiles/Stage1_<phase>.blend for every authoring phase,
Revenant_Stage1.blend, and qa/stage1_metrics.json.
"""
import bpy, sys, json, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import anim_core as A
import motion_v2 as MV
import review as RV

D = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(D / 'Revenant_Rigged.blend'))
scene = bpy.context.scene
scene.render.fps = 60
rig_obj = bpy.data.objects['REV_Rig']
R = A.Rig(rig_obj)
RV.setup(scene)
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
(D / 'workfiles').mkdir(exist_ok=True)


def build(name, fn, frames, interp, loop, meta=None, **kw):
    poses = [fn(R, f, **kw).p for f in frames]
    return A.write_action(rig_obj, name, poses, frames, interp, loop=loop, meta=meta)


# --- staged authoring passes ------------------------------------------------
for phase in ('blocking', 'breakdown', 'spline'):
    interp = 'BEZIER' if phase == 'spline' else 'CONSTANT'
    build('REV_Idle', MV.idle, MV.IDLE_KEYS[phase], interp, True, {'authoring_phase': phase}, phase=phase)
    build('REV_AgileMove_InPlace', MV.agile, MV.GLIDE_KEYS[phase], interp, True, {'authoring_phase': phase}, phase=phase)
    rig_obj.animation_data.action = bpy.data.actions['REV_AgileMove_InPlace']
    scene.frame_start, scene.frame_end = 1, 24
    bpy.ops.wm.save_as_mainfile(filepath=str(D / 'workfiles' / f'Stage1_{phase}.blend'), copy=True)

# --- polish: every frame evaluated (loop closure key on the frame after the cycle)
build('REV_Idle', MV.idle, list(range(1, 92)), 'LINEAR', True, {'authoring_phase': 'polish', 'cycle_frames': 90})
build('REV_AgileMove_InPlace', MV.agile, list(range(1, 26)), 'LINEAR', True,
      {'authoring_phase': 'polish', 'cycle_frames': 24, 'speed_mps': MV.GAITS['glide']['speed']}, gait='glide')
build('REV_AgileMove_RootMotion', MV.agile, list(range(1, 26)), 'LINEAR', False,
      {'authoring_phase': 'polish', 'cycle_frames': 24, 'speed_mps': MV.GAITS['glide']['speed']}, gait='glide', root_motion=True)
NR = MV.GAITS['run']['frames']
build('REV_AgileRun_InPlace', MV.agile, list(range(1, NR + 2)), 'LINEAR', True,
      {'authoring_phase': 'polish', 'cycle_frames': NR, 'speed_mps': MV.GAITS['run']['speed']}, gait='run')
for name in ('REV_Idle', 'REV_AgileMove_InPlace', 'REV_AgileRun_InPlace'):
    act = bpy.data.actions[name]
    act.frame_range = (1, act['cycle_frames'] + 1)

rig_obj.animation_data.action = bpy.data.actions['REV_AgileMove_InPlace']
scene.frame_start, scene.frame_end = 1, 24
bpy.ops.wm.save_as_mainfile(filepath=str(D / 'workfiles' / 'Stage1_polish.blend'), copy=True)

# --- measurements (from the exact matrices that were keyed) -----------------
def vec(v):
    return [round(c, 5) for c in v]


def yaw_of(q_axis_x):
    return math.degrees(math.atan2(q_axis_x.y, q_axis_x.x))


metrics = {}
for gait, action in (('glide', 'REV_AgileMove_InPlace'), ('run', 'REV_AgileRun_InPlace')):
    g = MV.GAITS[gait]
    N = g['frames']
    rows = []
    for f in range(1, 2 * N + 2):
        b = MV.agile(R, f, gait=gait)
        p = b.p
        t = (f - 1) / 60.0
        travel = A.Vector((0, -g['speed'] * t, 0))
        row = {'frame': f, 'pelvis_z': p.headp('pelvis').z, 'head_z': p.headp('head').z,
               'hip_yaw': yaw_of(p.headp('thigh_l') - p.headp('thigh_r')),
               'shoulder_yaw': yaw_of(p.headp('upperarm_l') - p.headp('upperarm_r')),
               'planted': b.planted}
        for s in 'lr':
            row['ball_world_' + s] = vec(p.headp('ball_' + s) + travel)
            row['toe_world_' + s] = vec(p.tailp('ball_' + s) + travel)
            row['knee_' + s] = vec(p.headp('calf_' + s))
            row['ankle_' + s] = vec(p.headp('foot_' + s))
            row['elbow_' + s] = vec(p.headp('lowerarm_' + s))
            row['wrist_' + s] = vec(p.headp('hand_' + s))
        rows.append(row)
    slip = {}
    for s in 'lr':
        runs, cur = [], []
        for row in rows[:2 * N]:
            if row['planted'][s]:
                cur.append(row)
            elif cur:
                runs.append(cur); cur = []
        if cur:
                runs.append(cur)
        runs = [r for r in runs if r[0]['frame'] > 1 and r[-1]['frame'] < 2 * N]  # complete contacts only
        worst = 0.0
        for run in runs:
            for key in ('ball_world_', 'toe_world_'):
                xs = [A.Vector(r[key + s]) for r in run]
                worst = max(worst, max((x - xs[0]).length for x in xs))
        slip[s] = {'max_slip_m': worst, 'locked_frames': [len(r) for r in runs]}
    pz = [r['pelvis_z'] for r in rows[:N]]
    hz = [r['head_z'] for r in rows[:N]]
    hy = [r['hip_yaw'] for r in rows[:N]]
    sy = [r['shoulder_yaw'] for r in rows[:N]]
    hy0 = sum(hy) / N; sy0 = sum(sy) / N
    corr = sum((a - hy0) * (b - sy0) for a, b in zip(hy, sy))
    seam = 0.0
    b1 = MV.agile(R, 1, gait=gait).p.basis()
    b25 = MV.agile(R, N + 1, gait=gait).p.basis()
    for n in b1:
        seam = max(seam, max(abs(x - y) for r1, r2 in zip(b1[n], b25[n]) for x, y in zip(r1, r2)))
    metrics[action] = {
        'speed_mps': g['speed'], 'frames': rows[:N + 1], 'foot_slip': slip,
        'pelvis_vertical_range_m': max(pz) - min(pz), 'head_vertical_range_m': max(hz) - min(hz),
        'hip_yaw_range_deg': max(hy) - min(hy), 'shoulder_yaw_range_deg': max(sy) - min(sy),
        'hip_shoulder_covariance': corr, 'counter_rotation': corr < 0, 'loop_seam_max_basis_delta': seam,
        'left_right_identical': False,
    }
    # left/right asymmetry: compare mirrored foot trajectories
    diff = 0.0
    N = g['frames']
    for f in range(1, N // 2 + 1):
        a = rows[f - 1]['ankle_r']; bb = rows[f - 1 + N // 2]['ankle_l']
        diff = max(diff, abs(abs(a[0]) - abs(bb[0])) + abs(a[1] - bb[1]) + abs(a[2] - bb[2]))
    metrics[action]['left_right_max_mirrored_diff_m'] = diff
    metrics[action]['left_right_identical'] = diff < 1e-4
(D / 'qa' / 'stage1_metrics.json').write_text(json.dumps(metrics, indent=1))
for k, v in metrics.items():
    print('METRIC', k, {kk: vv for kk, vv in v.items() if kk != 'frames'})

rig_obj.animation_data.action = bpy.data.actions['REV_AgileMove_InPlace']
bpy.ops.wm.save_as_mainfile(filepath=str(D / 'Revenant_Stage1.blend'))
print('STAGE1_DONE')
