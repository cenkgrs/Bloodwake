"""Mesh-aware floor pass for the coat and hair chains.

Bone-tip clamping cannot see the cloth: the outer coat panels reach sideways past
their bones, so a deep crouch still pushes the hem through the floor. This pass
evaluates the skinned mesh frame by frame and, for each chain that owns
penetrating vertices, swings that chain's lower links outward/up around their
heads until the mesh clears the floor. Results are re-keyed into the action.
"""
import bpy, math
import numpy as np
from mathutils import Vector, Quaternion, Matrix

FLOOR = 0.004


def _chains(rig):
    out = {}
    for b in rig.pose.bones:
        n = b.name
        if n.startswith('coat_') or n.startswith('hair_'):
            key = n.rsplit('_', 1)[0]
            out.setdefault(key, []).append(n)
    for k in out:
        out[k].sort()
    return out


def fix_action(rig, body, act, max_iter=16, verbose=False):
    scene = bpy.context.scene
    rig.animation_data.action = act
    names = [g.name for g in body.vertex_groups]
    N = len(body.data.vertices)
    dom = np.zeros(N, dtype=int)
    for v in body.data.vertices:
        if v.groups:
            dom[v.index] = max(v.groups, key=lambda g: g.weight).group
    chains = _chains(rig)
    chain_of = {}
    for key, bones in chains.items():
        for b in bones:
            chain_of[b] = key
    vchain = np.array([chain_of.get(names[d], '') for d in dom])
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    fixed = 0
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        # Work on the evaluated pose: override with explicit keys on this frame.
        for it in range(max_iter):
            dg = bpy.context.evaluated_depsgraph_get()
            ev = body.evaluated_get(dg)
            me = ev.to_mesh()
            co = np.empty(N * 3)
            me.vertices.foreach_get('co', co)
            ev.to_mesh_clear()
            z = co.reshape(N, 3)[:, 2]
            bad = z < FLOOR
            if not bad.any():
                break
            hit = {}
            for key in set(vchain[bad]) - {''}:
                m = bad & (vchain == key)
                hit[key] = float(FLOOR - z[m].min())
            if not hit:
                break
            centre = rig.pose.bones['pelvis'].head.copy()
            for key, depth in hit.items():
                bones = chains[key]
                links = bones[1:] if len(bones) > 2 and it < 5 else bones
                for i, bn in enumerate(links):
                    pb = rig.pose.bones[bn]
                    M = pb.matrix.copy()
                    h = M.translation.copy()
                    d = (pb.tail - pb.head).normalized()
                    out = Vector((h.x - centre.x, h.y - centre.y, 0.0))
                    if out.length < 1e-4:
                        out = Vector((0, 1, 0))
                    out.normalize()
                    axis = d.cross(out)
                    if axis.length < 1e-5:
                        continue
                    ang = min(math.radians(14), math.radians(4) + depth * 3.0) * (1.0 if i == len(links) - 1 else 0.6)
                    R = Quaternion(axis.normalized(), ang).to_matrix().to_4x4()
                    Mn = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M
                    pb.matrix = Mn
                    bpy.context.view_layer.update()
                    pb.keyframe_insert('rotation_quaternion', frame=f, group=bn)
            fixed += 1
        if verbose and it:
            print('FLOORFIX', act.name, f, it)
    # keep quaternion keys on one hemisphere so interpolation never takes the long way
    groups = {}
    for fc in act.fcurves:
        if fc.data_path.endswith('rotation_quaternion'):
            groups.setdefault(fc.data_path, [None] * 4)[fc.array_index] = fc
    for path, fcs in groups.items():
        if None in fcs:
            continue
        prev = None
        for i in range(len(fcs[0].keyframe_points)):
            q = [fc.keyframe_points[i].co[1] for fc in fcs]
            if prev is not None and sum(a * b for a, b in zip(q, prev)) < 0:
                q = [-c for c in q]
                for fc, c in zip(fcs, q):
                    fc.keyframe_points[i].co[1] = c
            prev = q
    for fc in act.fcurves:
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
        fc.update()
    rig.animation_data.action = None
    return fixed
