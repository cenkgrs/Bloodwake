"""Final scene: REV_VFX_PROXY collection, sequential NLA preview, timeline markers,
animation_events.json.  blender -b Revenant_Stage2.blend --python tools/finalize_v2.py"""
import bpy, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import vfx_lib as V
import combat_v2 as C
import review as RV

D = Path(__file__).resolve().parents[1]
s = bpy.context.scene
r = bpy.data.objects['REV_Rig']
RV.setup(s, 960)
V.build()

ORDER = ['REV_Idle', 'REV_AgileMove_InPlace', 'REV_AgileRun_InPlace', 'REV_HitLight_Front', 'REV_HitLight_Left',
         'REV_HitLight_Right', 'REV_ClawAttack_1', 'REV_ClawAttack_2', 'REV_ClawAttack_3', 'REV_Death', 'REV_TeleportAttack', 'REV_BloodBurst']
LOOPS = {'REV_Idle': 2, 'REV_AgileMove_InPlace': 3, 'REV_AgileRun_InPlace': 3}
GAP = 12

events = {'fps': 60, 'event_time_formula': '(frame - 1) / 60.0', 'actions': {}}
for name in [a.name for a in bpy.data.actions if a.name.startswith('REV_')]:
    a = bpy.data.actions[name]
    cyc = a.get('cycle_frames')
    length = int(cyc) if cyc else int(a.frame_range[1])
    entry = {'start': 1, 'end': length, 'loop': bool(a.get('loop', False)),
             'events': {m.name: m.frame for m in sorted(a.pose_markers, key=lambda m: m.frame)}}
    if a.get('speed_mps'):
        entry['speed_mps'] = a['speed_mps']
    if a.get('additive'):
        entry['additive_upper_body'] = True
        entry['bones'] = C.UPPER
    if name.endswith('RootMotion'):
        entry['diagnostic_only'] = True
    events['actions'][name] = entry
events['notes'] = {
    'loops': 'Looping actions carry a closure key one frame after the cycle (frame cycle+1 == frame 1).',
    'REV_AgileMove_InPlace': 'Spec gait, 2.45 m/s. Play at actual_speed / 2.45 to keep zero foot slip.',
    'REV_AgileRun_InPlace': 'Bloodwake gameplay gait, 6.0 m/s (class base speed 300 * 0.02).',
    'teleport': 'In place. Game hides the body at TELEPORT_HIDE, moves it at TELEPORT_MOVE, shows it at TELEPORT_SHOW, resolves damage at DAMAGE.',
    'hits': 'Use *_Additive on the upper-body bones on top of whatever the legs are playing.',
}
(D / 'animation_events.json').write_text(json.dumps(events, indent=1))

# NLA: every action in sequence (loops repeated), markers on the global timeline.
for t in list(r.animation_data.nla_tracks):
    r.animation_data.nla_tracks.remove(t)
r.animation_data.action = None
track = r.animation_data.nla_tracks.new()
track.name = 'REV - all actions sequential preview'
cursor = 1
intervals = []
s.timeline_markers.clear()
for name in ORDER:
    a = bpy.data.actions[name]
    length = events['actions'][name]['end']
    reps = LOOPS.get(name, 1)
    strip = track.strips.new(name, cursor, a)
    strip.action_frame_start = 1
    strip.action_frame_end = length + (1 if reps > 1 else 0)
    strip.repeat = reps
    strip.extrapolation = 'HOLD_FORWARD'
    strip.use_auto_blend = False
    span = int(round(strip.frame_end - strip.frame_start))
    intervals.append((name, cursor, length, reps, span))
    s.timeline_markers.new(name, frame=cursor)
    for ev, f in events['actions'][name]['events'].items():
        s.timeline_markers.new(f'{name} / {ev}', frame=cursor + f - 1)
    cursor += span + GAP
s.frame_start, s.frame_end = 1, cursor - GAP
s.name = 'REV_NLA_Preview'

# VFX proxies keyed on the global timeline, driven by each action's local frame.
for name, start, length, reps, span in intervals:
    for g in range(span + GAP):
        frame = start + g
        local = g % length + 1 if g < span else length
        s.frame_set(frame)
        V.apply(name if g < span else '', local, keyframe=frame)
        for o in bpy.data.collections['REV_VFX_PROXY'].objects:
            if o.name.startswith('CLAW'):
                o.rotation_mode = 'QUATERNION'
                o.keyframe_insert('location', frame=frame)
                o.keyframe_insert('rotation_quaternion', frame=frame)
for a in bpy.data.actions:
    if not a.name.startswith('REV_'):
        if not a.name.startswith('VFX_'):
            a.name = 'VFX_' + a.name
        for fc in a.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = 'CONSTANT' if 'hide' in fc.data_path else 'LINEAR'
cam = bpy.data.objects['CAM_three']
s.camera = cam
cam.data.ortho_scale = 2.8
for name, start, length, reps, span in intervals:
    cam.data.ortho_scale = 7.0 if name == 'REV_BloodBurst' else 3.0
    cam.data.keyframe_insert('ortho_scale', frame=start)
    cam.data.keyframe_insert('ortho_scale', frame=start + span - 1)
for fc in cam.data.animation_data.action.fcurves:
    for k in fc.keyframe_points:
        k.interpolation = 'CONSTANT'
r['animation_library'] = 'Mute the NLA track before choosing an action in the Action Editor.'
r['height_m'] = 1.90
r['forward_axis'] = '-Y Blender / +Z glTF'
r['root_ground_plane'] = 'Z=0'
for im in bpy.data.images:
    if im.has_data:
        im.pack()
(D / 'qa' / 'nla_timeline.json').write_text(json.dumps(
    [{'action': n, 'start': st, 'end': st + sp - 1, 'local_end': ln, 'repeats': rp} for n, st, ln, rp, sp in intervals], indent=1))
s.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(D / 'Revenant_Animated.blend'))
print('FINAL_SCENE_SAVED', s.frame_end)
