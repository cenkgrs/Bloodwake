"""Revenant authoring core: pure-math FK/IK over the REV_Rig rest pose.

Conventions (Blender armature space, character faces -Y):
  pitch = rotation about +X (positive tips the top of a bone forward, toward -Y)
  yaw   = rotation about +Z (positive turns toward the character's left, +X)
  roll  = rotation about +Y (positive drops the character's left shoulder... see tilt())
Every pose is computed here without touching the depsgraph, then written as
matrix_basis keys. The same matrices drive all QA measurements.
"""
import bpy, math
from mathutils import Matrix, Vector, Quaternion, Euler

TAU = math.tau
FPS = 60


def rad(d):
    return math.radians(d)


def qrot(pitch=0.0, roll=0.0, yaw=0.0):
    """World-axis rotation, applied pitch then roll then yaw (degrees)."""
    return (Quaternion((0, 0, 1), rad(yaw)) @ Quaternion((0, 1, 0), rad(roll)) @ Quaternion((1, 0, 0), rad(pitch)))


# ----------------------------------------------------------------------------
# Curves. A channel is a list of (frame, value[, ease]) knots. ease:
#   'a' auto  - nonuniform Catmull-Rom slope (flows through the knot)
#   'f' flat  - zero slope (settle/hold, a real ease)
#   's' snap  - leaves the knot with 1.8x the auto slope (impact, whip)
#   'l' linear into the next knot
# Each knot owns its tangent, so two channels with the same poses but different
# ease letters get visibly different accelerations in the Graph Editor.
# ----------------------------------------------------------------------------

def _norm(keys):
    return [(k[0], k[1], k[2] if len(k) > 2 else 'a') for k in keys]


def curve(f, keys, period=None):
    keys = _norm(keys)
    if period:
        f = (f - keys[0][0]) % period + keys[0][0]
    if f <= keys[0][0]:
        return keys[0][1]
    if f >= keys[-1][0]:
        return keys[-1][1]
    n = len(keys)
    for i in range(n - 1):
        a, v, ea = keys[i]
        b, w, eb = keys[i + 1]
        if a <= f <= b:
            t = (f - a) / (b - a)
            if ea == 'l':
                return v + (w - v) * t

            def slope(j, e):
                if e == 'f':
                    return 0.0
                if period:
                    # cyclic neighbours (first and last knot are the same pose)
                    pj = keys[j - 1] if j > 0 else (keys[-2][0] - period, keys[-2][1])
                    nj = keys[j + 1] if j < n - 1 else (keys[1][0] + period, keys[1][1])
                else:
                    pj = keys[max(0, j - 1)]
                    nj = keys[min(n - 1, j + 1)]
                if nj[0] == pj[0]:
                    return 0.0
                m = (nj[1] - pj[1]) / (nj[0] - pj[0])
                return m * (1.8 if e == 's' else 1.0)

            m0 = slope(i, ea) * (b - a)
            m1 = slope(i + 1, eb) * (b - a)
            t2, t3 = t * t, t * t * t
            return (2 * t3 - 3 * t2 + 1) * v + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * w + (t3 - t2) * m1
    return keys[-1][1]


def cyc(f, keys, period):
    return curve(f, keys, period)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def window(f, a, b):
    """0 before a, 1 after b, smoothstep in between."""
    return smooth((f - a) / (b - a)) if b != a else float(f >= a)


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return Vector(a).lerp(Vector(b), t)


# ----------------------------------------------------------------------------
# Rig model
# ----------------------------------------------------------------------------

class Rig:
    def __init__(self, obj):
        self.obj = obj
        self.rest = {}
        self.parent = {}
        self.order = []
        for b in obj.data.bones:
            self.rest[b.name] = b.matrix_local.copy()
            self.parent[b.name] = b.parent.name if b.parent else None

        def visit(b):
            self.order.append(b.name)
            for c in b.children:
                visit(c)
        for b in obj.data.bones:
            if b.parent is None:
                visit(b)
        self.rest_q = {n: m.to_quaternion() for n, m in self.rest.items()}
        self.head = {n: m.translation.copy() for n, m in self.rest.items()}
        self.tail = {b.name: Vector(b.tail_local) for b in obj.data.bones}
        self.length = {n: (self.tail[n] - self.head[n]).length for n in self.rest}


class Pose:
    """World(armature)-space rotation offsets per bone plus explicit overrides.

    rot[b]   - world-axis quaternion applied at the bone head, inherited by children
    local[b] - bone-local quaternion (fingers, toes) applied after inheritance
    world[b] - absolute world orientation (IK results, planted feet); overrides rot
    pos[b]   - absolute head position (pelvis only in practice)
    """

    def __init__(self, rig):
        self.rig = rig
        self.rot = {}
        self.local = {}
        self.world = {}
        self.pos = {}
        self.M = None

    def add(self, bone, q):
        self.rot[bone] = q @ self.rot.get(bone, Quaternion())
        self.M = None

    def addl(self, bone, q):
        self.local[bone] = self.local.get(bone, Quaternion()) @ q
        self.M = None

    # -- forward kinematics -------------------------------------------------
    def solve(self, upto=None):
        R = self.rig
        M = {}
        for n in R.order:
            p = R.parent[n]
            if p is None:
                inh_q = R.rest_q[n]
                inh_t = R.head[n].copy()
            else:
                pm = M[p]
                rel = R.rest[p].inverted() @ R.rest[n]
                im = pm @ rel
                inh_q = im.to_quaternion()
                inh_t = im.translation.copy()
            if n in self.world:
                q = self.world[n]
            else:
                q = self.rot.get(n, Quaternion()) @ inh_q
            q = q @ self.local.get(n, Quaternion())
            t = self.pos.get(n, inh_t)
            m = q.to_matrix().to_4x4()
            m.translation = t
            M[n] = m
            if upto is not None and n == upto:
                break
        self.M = M
        return M

    def mat(self, n):
        if self.M is None:
            self.solve()
        return self.M[n]

    def headp(self, n):
        return self.mat(n).translation.copy()

    def tailp(self, n):
        m = self.mat(n)
        return m.translation + m.to_quaternion() @ Vector((0, self.rig.length[n], 0))

    def axis(self, n, ax=(0, 1, 0)):
        return self.mat(n).to_quaternion() @ Vector(ax)

    def basis(self):
        """matrix_basis per bone (what Blender keys)."""
        R = self.rig
        M = self.M or self.solve()
        out = {}
        for n in R.order:
            p = R.parent[n]
            if p is None:
                out[n] = R.rest[n].inverted() @ M[n]
            else:
                rel = R.rest[p].inverted() @ R.rest[n]
                out[n] = rel.inverted() @ M[p].inverted() @ M[n]
        return out

    # -- helpers ------------------------------------------------------------
    def aim_world(self, n, direction, up_hint=None):
        """Absolute orientation: bone Y along direction with minimal twist
        relative to the inherited orientation (or the rest when nothing is inherited)."""
        self.solve()
        R = self.rig
        p = R.parent[n]
        if p is None:
            cur = R.rest_q[n]
        else:
            rel = R.rest[p].inverted() @ R.rest[n]
            cur = (self.M[p] @ rel).to_quaternion()
            cur = self.rot.get(n, Quaternion()) @ cur
        y = cur @ Vector((0, 1, 0))
        q = y.rotation_difference(Vector(direction).normalized()) @ cur
        if up_hint is not None:
            # twist about the new axis so the bone's Z points as close as possible to up_hint
            ax = q @ Vector((0, 1, 0))
            z = q @ Vector((0, 0, 1))
            h = Vector(up_hint) - ax * Vector(up_hint).dot(ax)
            if h.length > 1e-6:
                h.normalize()
                ang = math.atan2(ax.dot(z.cross(h)), z.dot(h))
                q = Quaternion(ax, ang) @ q
        self.world[n] = q
        self.M = None

    def two_bone(self, a, b, target, pole, end=None, twist_up=None):
        """Analytic two-bone IK: a (upper) and b (lower) reach target with the
        middle joint bending toward pole. Returns residual distance."""
        self.solve()
        R = self.rig
        A = self.headp(a)
        L1 = (R.head[b] - R.head[a]).length
        L2 = ((R.head[end] if end else R.tail[b]) - R.head[b]).length
        T = Vector(target)
        V = T - A
        d = max(1e-4, min(V.length, L1 + L2 - 1e-4))
        v = V.normalized()
        P = Vector(pole) - A
        P = P - v * P.dot(v)
        if P.length < 1e-6:
            P = Vector((0, -1, 0))
        P.normalize()
        x = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
        h = math.sqrt(max(0.0, L1 * L1 - x * x))
        K = A + v * x + P * h
        self.aim_world(a, K - A, twist_up)
        self.solve()
        self.aim_world(b, (A + v * d) - K, twist_up)
        self.solve()
        tip = self.headp(end) if end else self.tailp(b)
        return (tip - T).length


# ----------------------------------------------------------------------------
# Body-level controls specific to REV_Rig
# ----------------------------------------------------------------------------

SPINE = ['spine_01', 'spine_02', 'spine_03']
PAULDRON_FOLLOW = 0.55
RIGHT_SHOULDER_LEVEL = -8.5
FINGERS = ['index', 'middle', 'ring', 'pinky']


class Body:
    """High level posing on top of Pose. One instance per frame."""

    def __init__(self, rig):
        self.rig = rig
        self.p = Pose(rig)
        R = rig
        # Rest landmarks
        self.pelvis_rest = R.head['pelvis'].copy()
        for s in 'lr':
            pass

    # Pelvis: absolute head position + world rotation.
    def pelvis(self, pos, pitch=0.0, roll=0.0, yaw=0.0):
        self.p.pos['pelvis'] = Vector(pos)
        self.p.rot['pelvis'] = qrot(pitch, roll, yaw)
        self.p.M = None

    def spine(self, pitch=0.0, roll=0.0, yaw=0.0, dist=(.38, .34, .28)):
        for n, w in zip(SPINE, dist):
            self.p.add(n, qrot(pitch * w, roll * w, yaw * w))

    def neck(self, pitch=0.0, roll=0.0, yaw=0.0, head=(0.0, 0.0, 0.0)):
        self.p.add('neck_01', qrot(pitch, roll, yaw))
        self.p.add('head', qrot(*head))

    def head_world(self, pitch=0.0, roll=0.0, yaw=0.0, follow=0.0):
        """Stabilised head: absolute world orientation (relative to rest), with
        `follow` share of the chest rotation leaking through."""
        self.p.solve()
        chest = self.p.mat('spine_03').to_quaternion() @ self.rig.rest_q['spine_03'].inverted()
        base = Quaternion().slerp(chest, follow) if follow else Quaternion()
        self.p.world['head'] = qrot(pitch, roll, yaw) @ base @ self.rig.rest_q['head']
        self.p.M = None

    def clavicle(self, side, lift=0.0, fwd=0.0):
        s = 1 if side == 'l' else -1
        if side == 'r':
            # The source T-pose holds the right arm ~5 cm higher than the left, so the
            # right shoulder joint sits high in every pose. Level it at the clavicle.
            lift += RIGHT_SHOULDER_LEVEL
        # lift: shoulder up (roll about Y), fwd: shoulder forward (yaw about Z)
        self.p.add('clavicle_' + side, qrot(0, -s * lift, s * fwd))

    # Forefoot contact model: ball joint position + heel lift.
    def leg(self, side, ball, heel=0.0, yaw=0.0, toe=None, knee_out=0.0, roll=0.0):
        """ball: world position of the ball joint (toe hinge).
        heel: degrees the heel is lifted around the ball (forefoot contact).
        toe: toe bend; None keeps the toe flat on the ground plane."""
        R = self.rig
        p = self.p
        f, b = 'foot_' + side, 'ball_' + side
        q_foot = qrot(heel, roll, yaw) @ R.rest_q[f]
        # Ankle is the foot head; rest offset ball->ankle rotated by the foot orientation.
        rest_off = R.head[f] - R.head[b]
        off = (qrot(heel, roll, yaw) @ rest_off)
        ankle = Vector(ball) + off
        s = 1 if side == 'l' else -1
        pole = ankle + Vector((s * knee_out + 0.0, -0.9, 0.55))
        pole = Vector(((R.head['thigh_' + side].x + ankle.x) * .5 + s * knee_out, -1.2, .6))
        err = p.two_bone('thigh_' + side, 'calf_' + side, ankle, pole, end=f)
        p.world[f] = q_foot
        if toe is None:
            p.world[b] = qrot(0, 0, yaw) @ R.rest_q[b]
        else:
            p.world[b] = qrot(heel - toe, roll, yaw) @ R.rest_q[b]
        p.M = None
        return err

    def arm(self, side, wrist, pole=None, hand=(0.0, 0.0, 0.0), curl=0.0, spread=0.0, thumb=0.0):
        R = self.rig
        s = 1 if side == 'l' else -1
        sh = self.p.headp('upperarm_' + side)
        if pole is None:
            pole = sh + Vector((s * .35, .55, -.35))
        err = self.p.two_bone('upperarm_' + side, 'lowerarm_' + side, wrist, pole, end='hand_' + side)
        # The pauldron rides the clavicle in the skin; let it follow ~55% of the upper
        # arm's swing so lowering the arm does not leave it jutting up like a hump.
        self.p.solve()
        R = self.rig
        ua = self.p.mat('upperarm_' + side).to_quaternion() @ R.rest_q['upperarm_' + side].inverted()
        cl = self.p.mat('clavicle_' + side).to_quaternion() @ R.rest_q['clavicle_' + side].inverted()
        rel = cl.inverted() @ ua
        self.p.add('armor_' + side, cl @ Quaternion().slerp(rel, PAULDRON_FOLLOW) @ cl.inverted())
        # Hand: rotate relative to the forearm (world-axis offset on top of inherited)
        self.p.add('hand_' + side, qrot(*hand))
        self.fingers(side, curl, spread, thumb)
        return err

    def ground_chain(self, bones, floor=0.03):
        """Pivot each link of a dangling chain (coat, hair) so its tail stays
        above the floor; children inherit the correction."""
        for n in bones:
            self.p.solve()
            h = self.p.headp(n)
            t = self.p.tailp(n)
            if t.z >= floor:
                continue
            L = (t - h).length
            dz = max(-L, min(L, floor - h.z))
            flat = Vector((t.x - h.x, t.y - h.y, 0.0))
            if flat.length < 1e-6:
                flat = Vector((0, 1, 0))
            flat = flat.normalized() * math.sqrt(max(0.0, L * L - dz * dz))
            want = Vector((flat.x, flat.y, dz))
            self.p.add(n, (t - h).rotation_difference(want))
        self.p.solve()

    def curl_axis(self, bone):
        """Local axis that folds a finger toward the palm (rest palms face -Z)."""
        R = self.rig
        n_local = R.rest_q[bone].inverted() @ Vector((0, 0, -1))
        a = Vector((0, 1, 0)).cross(n_local)
        return a.normalized() if a.length > 1e-6 else Vector((1, 0, 0))

    def fingers(self, side, curl=0.0, spread=0.0, thumb=0.0, per=None):
        for j, fg in enumerate(FINGERS):
            c = curl + (per[j] if per else 0.0)
            spr = spread * (j - 1.5)
            for k in (1, 2, 3):
                bone = f'{fg}_{k:02}_{side}'
                ang = c * (0.75 if k == 1 else 1.0 if k == 2 else 0.8)
                q = Quaternion(self.curl_axis(bone), rad(ang))
                if k == 1 and spr:
                    q = Quaternion((0, 0, 1), rad(spr)) @ q
                self.p.addl(bone, q)
        for k in (1, 2, 3):
            bone = f'thumb_{k:02}_{side}'
            self.p.addl(bone, Quaternion(self.curl_axis(bone), rad(thumb * (0.5 if k == 1 else 1.0))))




# ----------------------------------------------------------------------------
# Writing actions
# ----------------------------------------------------------------------------

def write_action(obj, name, poses, frames, interpolation='LINEAR', bones=None, loop=False, meta=None):
    """poses: list of Pose (already solved) aligned with frames."""
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if not obj.animation_data:
        obj.animation_data_create()
    obj.animation_data.action = act
    names = bones or [b.name for b in obj.data.bones]
    fcs = {}
    for n in names:
        pb = obj.pose.bones[n]
        pb.rotation_mode = 'QUATERNION'
        g = act.groups.get(n) or act.groups.new(n)
        for i in range(3):
            fc = act.fcurves.new(f'pose.bones["{n}"].location', index=i, action_group=n)
            fcs[(n, 'l', i)] = fc
        for i in range(4):
            fc = act.fcurves.new(f'pose.bones["{n}"].rotation_quaternion', index=i, action_group=n)
            fcs[(n, 'q', i)] = fc
    prev = {}
    for fr, pose in zip(frames, poses):
        B = pose.basis()
        for n in names:
            loc, q, _ = B[n].decompose()
            if n in prev and q.dot(prev[n]) < 0:
                q.negate()
            prev[n] = q
            for i in range(3):
                fcs[(n, 'l', i)].keyframe_points.insert(fr, loc[i], options={'FAST'})
            for i in range(4):
                fcs[(n, 'q', i)].keyframe_points.insert(fr, q[i], options={'FAST'})
    for fc in act.fcurves:
        for k in fc.keyframe_points:
            k.interpolation = interpolation
            if interpolation == 'BEZIER':
                k.handle_left_type = 'AUTO_CLAMPED'
                k.handle_right_type = 'AUTO_CLAMPED'
        fc.update()
    # Drop channels that never move (keeps the export lean, avoids scale/loc noise).
    for fc in list(act.fcurves):
        vals = [k.co[1] for k in fc.keyframe_points]
        if vals and max(vals) - min(vals) < 1e-6 and fc.data_path.endswith('location') and abs(vals[0]) < 1e-6:
            act.fcurves.remove(fc)
    act.frame_range = (frames[0], frames[-1])
    act.use_frame_range = True
    act['fps'] = FPS
    act['loop'] = loop
    for k, v in (meta or {}).items():
        act[k] = v
    obj.animation_data.action = None
    return act


def add_markers(act, markers):
    for m in list(act.pose_markers):
        act.pose_markers.remove(m)
    for name, fr in markers.items():
        mk = act.pose_markers.new(name)
        mk.frame = fr
