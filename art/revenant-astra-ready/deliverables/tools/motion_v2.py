"""Revenant motion definitions (v2). Every action is a pose function
pose(rig, frame, phase) -> anim_core.Body, built from layered channels:

  blocking  - key poses only (held/stepped)
  breakdown - key poses + breakdowns (held/stepped)
  spline    - the same knot set, Bezier interpolated
  polish    - every frame evaluated: drag, overlap, asymmetric left/right,
              per-channel easing, secondary motion on hair/coat/claw.

The pose functions are deterministic so the QA scripts can re-evaluate the
exact matrices that were keyed.
"""
import math
from mathutils import Vector, Quaternion
from anim_core import Body, qrot, curve, cyc, window, lerp, smooth, rad

COAT_COLS = 5
HAIR = ['l', 'c', 'r']

# Rest landmarks used as anchors (armature space, metres)
PELVIS_REST = Vector((-0.015, 0.17, 1.105))
BALL_Z = 0.041           # left ball joint height when the forefoot is on the ground
BALL_ZS = {'l': 0.041, 'r': 0.034}   # the source mesh models each boot sole differently


# ----------------------------------------------------------------------------
# shared secondary motion
# ----------------------------------------------------------------------------

def coat(body, f, sig, stream=0.0, spread=0.0, legs=None, settle=None):
    """sig(t) -> (surge, sway, lift) body signal; each column samples it with its
    own lag so the chains never start or stop together.
    stream: degrees the coat is swept back (aerodynamic wedge when moving)
    spread: lateral opening; legs: (left_thigh_back_deg, right_thigh_back_deg)
    settle: optional extra pitch per link (used by death/ultimate)."""
    p = body.p
    for j in range(COAT_COLS):
        lag = (2, 4, 3, 4, 2)[j]
        side = (j - 2) / 2.0                # -1 right column .. +1 left column
        surge, sway, lift = sig(f - lag)
        surge2, sway2, lift2 = sig(f - lag - 1.5)
        for k in (1, 2, 3):
            w = (1.0, 0.55, 0.38)[k - 1]
            pitch = stream * (0.62 if k == 1 else 0.35) + surge * w * 9 + lift * w * 5
            pitch += (surge2 - surge) * 6 * (k - 1)          # whip down the chain
            if legs:
                # outer columns are pushed by the thigh on their side, the middle by both
                lw = max(0.0, side) * legs[0] + max(0.0, -side) * legs[1] + (1 - abs(side)) * 0.5 * (legs[0] + legs[1])
                pitch += lw * (0.9 if k == 1 else 0.15)
            if settle:
                pitch += settle[k - 1]
            roll = sway * w * 7 * (1 if k < 3 else 1.4) + spread * side * (1.0 if k == 1 else 0.5)
            yaw = sway2 * 4 * side
            p.add(f'coat_{j}_{k}', qrot(pitch, roll, yaw))
    for j in range(COAT_COLS):
        body.ground_chain([f'coat_{j}_1', f'coat_{j}_2'], 0.07)
        body.ground_chain([f'coat_{j}_3'], 0.12)   # the hem hangs ~8 cm below the last bone tip


def hair(body, f, sig, stream=0.0, settle=0.0):
    p = body.p
    for i, s in enumerate(HAIR):
        lag = (3, 2, 4)[i]
        surge, sway, lift = sig(f - lag)
        surge2, sway2, lift2 = sig(f - lag - 2)
        for k in (1, 2):
            pitch = stream * (0.7 if k == 1 else 0.45) + surge * (6 if k == 1 else 8) + lift * 6 + settle * (1 if k == 1 else .6)
            pitch += (surge2 - surge) * 5 * (k - 1)
            roll = sway * (5 if k == 1 else 7) + sway2 * 2
            p.add(f'hair_{s}_{k}', qrot(pitch, roll, 0))
    for s in HAIR:
        body.ground_chain([f'hair_{s}_1', f'hair_{s}_2'], 0.03)


def thigh_back(body, side):
    """How far (deg) the thigh swings behind vertical, for coat collision."""
    v = body.p.axis('thigh_' + side)
    ang = math.degrees(math.atan2(v.y, -v.z))   # +Y is behind
    return max(0.0, ang)


def thigh_fwd(body, side):
    v = body.p.axis('thigh_' + side)
    return max(0.0, math.degrees(math.atan2(-v.y, -v.z)))


# ----------------------------------------------------------------------------
# LOCOMOTION
# ----------------------------------------------------------------------------

def pc(p, keys):
    """Periodic channel keyed in cycle phase (0..1, first knot == last knot)."""
    return curve(p, keys, period=1.0)


GAITS = {
    # Spec gait: 24 frames, 2.45 m/s, no flight phase, long forefoot strides.
    'glide': dict(frames=24, speed=2.45, stance=14, y_strike=-0.28, hip_z=0.925, hip_y=0.09,
                  bob=0.010, lean=14.0, spine=15.0, pump=1.5, yaw=7.0, sh_yaw=12.0, roll=3.0,
                  arm_fwd=38.0, arm_back=42.0, reach_front=0.42, flight=0.0,
                  swing=dict(y=[(0.0, 'off'), (0.18, 'off+0.035'), (0.55, 'mid-0.05'), (0.86, 'strike-0.045')],
                             z=[(0, 0), (0.22, 0.094), (0.42, 0.12, 'f'), (0.75, 0.05), (0.93, 0.012), (1.0, 0, 'f')],
                             heel=[(0, 34), (0.2, 42), (0.5, 4), (0.8, -6), (1.0, 11, 'f')],
                             toe=[(0, 26), (0.25, 4), (0.6, -6), (1.0, 0, 'f')]),
                  stance_heel=[(0, 11, 'a'), (0.18, 5.5, 'f'), (0.55, 7, 'a'), (0.82, 17, 'a'), (1.0, 34, 'a')]),
    # Game gait: Bloodwake moves the Revenant at 6 m/s. A long bounding predator
    # stride: 36-frame cycle (3.3 steps/s), 1.8 m per step, knee drive in front,
    # heel kicked up behind, a real flight phase between contacts.
    'run': dict(frames=36, speed=6.0, stance=11, y_strike=-0.54, hip_z=0.885, hip_y=0.05,
                bob=0.021, lean=17.0, spine=12.0, pump=4.5, yaw=11.0, sh_yaw=18.0, roll=5.0,
                arm_fwd=72.0, arm_back=58.0, reach_front=0.33, flight=1.0,
                swing=dict(y=[(0.0, 'off'), (0.16, 'off+0.08'), (0.40, 0.30), (0.62, -0.18), (0.84, 'strike-0.12')],
                           z=[(0, 0), (0.15, 0.19), (0.33, 0.37, 'f'), (0.55, 0.30), (0.78, 0.16), (0.93, 0.04), (1.0, 0, 'f')],
                           heel=[(0, 55), (0.2, 96), (0.38, 72), (0.6, 12), (0.85, -10), (1.0, 9, 'f')],
                           toe=[(0, 30), (0.3, 10), (0.6, -5), (1.0, 0, 'f')]),
                stance_heel=[(0, 9, 'a'), (0.2, 4, 'f'), (0.55, 11, 'a'), (0.8, 30, 'a'), (1.0, 55, 'a')]),
}


def _yval(v, off, strike):
    if isinstance(v, (int, float)):
        return float(v)
    base, _, d = v.replace('-', '+-').partition('+')
    ref = {'off': off, 'strike': strike, 'mid': (off + strike) * 0.5}[base]
    return ref + (float(d) if d else 0.0)


def gait_foot(g, side, f, phase):
    """Returns (ball position, heel lift, toe bend or None, planted)."""
    N = g['frames']
    S = g['stance']
    v = g['speed'] / 60.0
    contact = 1 if side == 'r' else 1 + N // 2
    u = (f - contact) % N
    x0 = (-0.118, 0.108)[side == 'l']
    lr = 1.0 if side == 'l' else 0.0
    ys = g['y_strike'] + (0.012 if side == 'l' else 0.0)     # left lands a touch further out
    y_off = ys + v * S
    if u <= S:
        # Planted: the ball travels backward at exactly the move speed (zero world slip).
        y = ys + v * u
        heel = curve(u / S, g['stance_heel']) + 2 * lr
        return Vector((x0, y, BALL_ZS[side])), heel, None, True
    s = (u - S) / (N - S)
    W = g['swing']
    yk = [(k[0], _yval(k[1], y_off, ys), 'a') for k in W['y']] + [(1.0, ys, 'f')]
    y = curve(s, yk)
    z = BALL_ZS[side] + curve(s, W['z']) * (1.06 if side == 'l' else 1.0)
    heel = curve(s, W['heel']) + 2 * lr * (1 - s)
    toe = curve(s, W['toe'])
    x = x0 + curve(s, [(0, 0), (0.5, 0.022 if side == 'l' else -0.028), (1, 0)])
    return Vector((x, y, z)), heel, toe, False


def gait_signals(g, f):
    """Body drivers keyed in cycle phase (hand-placed knots, no sines).
    Right contact at phase 0, left contact at 0.5."""
    N = g['frames']
    p = ((f - 1) % N) / N
    b = g['bob']
    if g['flight']:
        # low at mid-stance compression, high in flight after toe-off
        z = pc(p, [(0, -0.3 * b), (0.13, -1.0 * b, 'f'), (0.30, 0.4 * b), (0.41, 1.0 * b, 'f'), (0.5, -0.25 * b),
                   (0.63, -0.95 * b, 'f'), (0.80, 0.45 * b), (0.91, 0.95 * b, 'f'), (1.0, -0.3 * b)])
    else:
        z = pc(p, [(0, -0.35 * b), (0.083, -1.0 * b, 'f'), (0.21, -0.1 * b), (0.29, 0.9 * b, 'f'), (0.42, 0.35 * b),
                   (0.5, -0.25 * b), (0.58, -0.92 * b, 'f'), (0.71, 0.0), (0.79, 1.0 * b, 'f'), (0.92, 0.3 * b), (1.0, -0.35 * b)])
    Y = g['yaw']
    yaw = pc(p, [(0, Y * 0.92), (0.08, Y, 'f'), (0.25, Y * 0.2), (0.40, -Y * 0.7), (0.5, -Y * 0.95), (0.58, -Y * 1.02, 'f'),
                 (0.75, -Y * 0.15), (0.90, Y * 0.72), (1.0, Y * 0.92)])
    R = g['roll']
    roll = pc(p, [(0, -0.15 * R), (0.12, R, 'f'), (0.35, 0.2 * R), (0.5, 0.1 * R), (0.63, -1.05 * R, 'f'), (0.85, -0.25 * R), (1.0, -0.15 * R)])
    sway = pc(p, [(0, 0.004), (0.17, -0.011, 'f'), (0.46, -0.002), (0.5, -0.004), (0.67, 0.012, 'f'), (0.96, 0.002), (1.0, 0.004)])
    surge = pc(p, [(0, 0.006), (0.12, -0.006, 'f'), (0.36, 0.003), (0.5, 0.005), (0.62, -0.007, 'f'), (0.86, 0.004), (1.0, 0.006)])
    P = g['pump']
    pump = pc(p, [(0, 0.0), (0.25, P, 'f'), (0.42, -0.4 * P), (0.5, 0.0), (0.76, P * 0.9, 'f'), (0.92, -0.45 * P), (1.0, 0.0)])
    S = g['sh_yaw']
    # Shoulders counter-rotate, peaking ~2 frames after the pelvis (drag).
    sh = pc(p, [(0, -S * 0.75), (0.12, -S, 'f'), (0.30, -S * 0.2), (0.45, S * 0.6), (0.55, S * 0.9), (0.63, S * 0.98, 'f'),
                (0.80, S * 0.2), (0.95, -S * 0.55), (1.0, -S * 0.75)])
    return dict(z=z, yaw=yaw, roll=roll, sway=sway, surge=surge, sh=sh, pump=pump, p=p)


def arm_swing(g, side, p):
    """Sagittal swing angle (deg, + forward) for one arm; the arm opposes its leg:
    the right arm is back at right contact. Eases at the extremes, fast through
    the bottom, with a small overshoot-and-settle after each reversal."""
    F, B = g['arm_fwd'], g['arm_back']
    if side == 'l':
        p = (p + 0.5) % 1.0
        F, B = F * 0.86, B * 0.8
    return pc(p, [(0, -B * 0.97), (0.05, -B, 'f'), (0.11, -B * 0.93), (0.30, F * 0.15), (0.47, F * 0.96), (0.53, F, 'f'),
                  (0.60, F * 0.9), (0.80, -B * 0.25), (1.0, -B * 0.97)])


def arm_pose(g, side, p, N):
    """Wrist offset from the shoulder (character axes) plus hand/finger values.
    The swing angle, the elbow fold and the hand each read the cycle with their
    own delay, so the arm whips rather than swinging as one rigid pendulum."""
    sgn = 1 if side == 'l' else -1
    a = arm_swing(g, side, (p - 1.0 / N) % 1.0)
    a_elbow = arm_swing(g, side, (p - 3.0 / N) % 1.0)       # elbow folds late
    F, B = g['arm_fwd'], g['arm_back']
    fwd = max(0.0, a_elbow) / F
    back = max(0.0, -a_elbow) / B
    if side == 'r':
        # blood claw: carried low and out, opens behind, rakes forward
        reach = 0.49 - 0.13 * smooth(fwd) - 0.02 * back
        out = 0.15 + 0.07 * back - 0.06 * fwd
        lift = -0.02
    else:
        # free hand: compact, elbow stays folded, crosses toward the sternum in front
        reach = 0.44 - 0.16 * smooth(fwd) + 0.03 * back
        out = 0.09 + 0.04 * back - 0.10 * fwd
        lift = 0.0
    r = math.radians(a)
    off = Vector((sgn * out, -reach * math.sin(r), -reach * math.cos(r) + lift))
    a_hand = arm_swing(g, side, (p - 4.5 / N) % 1.0)          # hand flops behind the forearm
    k = a_hand / F if a_hand > 0 else a_hand / B
    hand_pitch = -26 * k                                      # trails: flexed behind, cocked back in front
    hand_yaw = sgn * (8 - 10 * k)
    twist = sgn * 14 * (fwd - back)                           # forearm rolls palm-in at the front
    if side == 'r':
        curl = 18 + 24 * max(0.0, k)
        spread = 6 + 14 * max(0.0, -k)
        thumb = 16
    else:
        curl = 30 + 14 * max(0.0, k)
        spread = 0.0
        thumb = 12
    return off, (hand_pitch, twist, hand_yaw), curl, spread, thumb


def agile(rig, f, phase='polish', gait='glide', root_motion=False):
    g = GAITS[gait]
    N = g['frames']
    fc = (f - 1) % N + 1
    body = Body(rig)
    sig = gait_signals(g, fc)
    p = sig['p']
    pz = g['hip_z'] + sig['z']
    py = g['hip_y'] + sig['surge']
    px = -0.006 + sig['sway']
    body.pelvis((px, py, pz), pitch=g['lean'], roll=sig['roll'], yaw=sig['yaw'])
    # The spine pumps with the push-off and absorbs part of the bob, so the head
    # travels less than the hips; it bends against the pelvis roll.
    absorb = sig['z'] / max(g['bob'], 1e-6) * (4.2 if g['flight'] else 2.2)
    body.spine(pitch=g['spine'] + absorb + sig['pump'], roll=-sig['roll'] * 1.1, yaw=-sig['yaw'] + sig['sh'])
    ar = arm_swing(g, 'r', (p - 1.5 / N) % 1.0)
    al = arm_swing(g, 'l', (p - 1.0 / N) % 1.0)
    body.clavicle('r', lift=2.0 + max(0.0, ar) * 0.05 - max(0.0, -ar) * 0.03, fwd=ar * 0.10)
    body.clavicle('l', lift=-1 + max(0.0, al) * 0.05 - max(0.0, -al) * 0.03, fwd=al * 0.09)
    hy = pc((p - 2.0 / N) % 1.0, [(0, 1.0), (0.5, -1.0), (1.0, 1.0)])
    body.head_world(pitch=3 + sig['z'] * 50 - sig['pump'] * 0.3, roll=-sig['roll'] * 0.25, yaw=hy + sig['sh'] * 0.15)

    planted = {}
    for side in 'lr':
        ball, heel, toe, on = gait_foot(g, side, fc, phase)
        yaw = 4 if side == 'l' else -5
        body.leg(side, ball, heel=heel, yaw=yaw, toe=toe, knee_out=0.03 if side == 'l' else 0.05)
        planted[side] = on

    # Arms: loose arcs from the shoulder; elbow, hand and fingers each lag the swing.
    for side in 'rl':
        sgn = 1 if side == 'l' else -1
        sh = body.p.headp('upperarm_' + side)
        off, hand, curl, spread, thumb = arm_pose(g, side, p, N)
        body.arm(side, sh + off, pole=sh + Vector((sgn * 0.3, 0.5, -0.3)), hand=hand,
                 curl=curl, spread=spread, thumb=thumb)

    if phase == 'polish':
        def s(t):
            k = gait_signals(g, (t - 1) % N + 1)
            return (k['surge'] * 60 + k['z'] * 25 + k['pump'] * 0.15, k['roll'] / 3.0, k['z'] * 40)
        legs = (thigh_back(body, 'l') * 0.55, thigh_back(body, 'r') * 0.55)
        coat(body, fc, s, stream=26 + 12 * g['flight'], spread=6 + 6 * g['flight'], legs=legs)
        hair(body, fc, s, stream=22 + 12 * g['flight'])
        body.p.add('blood_claw', qrot(0, 0, pc((p - 3.0 / N) % 1.0, [(0, 0), (0.45, -6), (0.62, 4), (1.0, 0)])))
    if root_motion:
        body.p.pos['root'] = Vector((0, -g['speed'] * (f - 1) / 60.0, 0))
        body.p.pos['pelvis'] = body.p.pos['pelvis'] + Vector((0, -g['speed'] * (f - 1) / 60.0, 0))
    body.p.solve()
    body.planted = planted
    return body


GLIDE_KEYS = {'blocking': [1, 7, 13, 19], 'breakdown': [1, 3, 5, 7, 10, 13, 15, 17, 19, 22],
              'spline': [1, 3, 5, 7, 9, 10, 13, 15, 17, 19, 21, 22, 24]}


# ----------------------------------------------------------------------------
# IDLE (90 frames, seamless)
# ----------------------------------------------------------------------------

def idle_signals(f):
    # Two uneven breaths per loop (inhale shorter than exhale), not a sine.
    br = curve(f, [(1, 0.0), (14, 0.9), (19, 1.0, 'f'), (40, 0.05, 'f'), (55, 0.85), (61, 1.0, 'f'), (84, 0.08), (91, 0.0)])
    sway = curve(f, [(1, 0.0), (23, 0.6), (47, 0.2), (70, -0.55), (91, 0.0)])
    return br, sway


def idle(rig, f, phase='polish'):
    body = Body(rig)
    f = (f - 1) % 90 + 1
    br, sway = idle_signals(f)
    # 60/40 weight to the front (left) foot: pelvis sits forward of the stance midpoint.
    body.pelvis((-0.012 + 0.006 * sway, 0.052 - 0.002 * br, 0.982 + 0.0035 * br), pitch=9, roll=1.2 + 0.4 * sway, yaw=-7 + 0.6 * sway)
    body.spine(pitch=8 - 1.1 * br, roll=-1.0 - 0.3 * sway, yaw=10)
    body.clavicle('r', lift=-3 + 1.4 * br, fwd=4)
    body.clavicle('l', lift=-2 + 1.1 * br, fwd=1)
    scan = curve(f, [(1, 0), (34, 0, 'f'), (38, -9, 'a'), (42, -12, 'f'), (45, -4), (48, 0, 'f'), (91, 0)])
    tilt = curve(f, [(1, 0), (35, 0, 'f'), (40, -2.5), (46, 0.8), (50, 0, 'f'), (91, 0)])
    body.head_world(pitch=-2 + 0.6 * br, roll=tilt, yaw=scan + 2, follow=0.15)
    body.leg('l', Vector((0.122, -0.165, BALL_Z)), heel=6, yaw=6, toe=None, knee_out=0.04)
    body.leg('r', Vector((-0.232, 0.235, BALL_ZS['r'])), heel=22, yaw=-20, toe=None, knee_out=0.06)
    shr = body.p.headp('upperarm_r')
    shl = body.p.headp('upperarm_l')
    claw = curve(f, [(1, 0), (51, 0, 'f'), (55, 0.8, 's'), (58, 1.0, 'f'), (62, 0.25), (66, 0, 'f'), (91, 0)])
    body.arm('r', shr + Vector((-0.11, -0.13 - 0.03 * claw, -0.425 + 0.035 * claw + 0.004 * br)),
             pole=shr + Vector((-0.25, 0.6, -0.2)), hand=(10 - 14 * claw, 0, -6),
             curl=24 + 34 * claw, spread=6 + 10 * claw, thumb=14 + 12 * claw,
             )
    body.arm('l', shl + Vector((0.03, -0.05, -0.475 + 0.004 * br)), pole=shl + Vector((0.05, 0.6, -0.35)),
             hand=(-4, 0, 4), curl=30, thumb=10)
    if phase == 'polish':
        def s(t):
            b2, w2 = idle_signals((t - 1) % 90 + 1)
            return (b2 * 0.12, w2 * 0.18, b2 * 0.1)
        coat(body, f, s, stream=4, spread=3, legs=(thigh_back(body, 'l') * 0.5, thigh_back(body, 'r') * 0.5))
        hair(body, f, lambda t: (s(t)[0] + curve((t - 1) % 90 + 1, [(1, 0), (38, 0), (43, -0.25), (50, 0.1), (56, 0), (91, 0)]) * 1.0, s(t)[1] + curve((t - 1) % 90 + 1, [(1, 0), (37, 0), (42, -0.6), (49, 0.25), (55, 0), (91, 0)]), s(t)[2]), stream=6)
        body.p.add('blood_claw', qrot(0, 0, -10 * curve(f - 2, [(1, 0), (51, 0), (57, 1), (65, 0), (91, 0)])))
    body.p.solve()
    return body


IDLE_KEYS = {'blocking': [1, 35, 42, 52, 58, 90], 'breakdown': [1, 19, 35, 38, 42, 48, 52, 55, 58, 64, 75, 90],
             'spline': [1, 10, 19, 30, 35, 38, 42, 45, 48, 52, 55, 58, 62, 66, 75, 84, 90]}
