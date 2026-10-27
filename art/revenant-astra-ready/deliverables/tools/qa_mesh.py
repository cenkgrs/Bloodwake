"""Mesh-level QA on the evaluated (skinned) body for every action:
lowest vertex per frame (ground penetration) and the bone that owns it.
blender -b X.blend --python tools/qa_mesh.py -- [ACTION ...]   -> qa/mesh_ground.json
"""
import bpy, sys, json, numpy as np
from pathlib import Path
D = Path(__file__).resolve().parents[1]
only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
s = bpy.context.scene
rig = bpy.data.objects['REV_Rig']; body = bpy.data.objects['REV_Body']
names = [g.name for g in body.vertex_groups]
N = len(body.data.vertices)
dom = np.zeros(N, dtype=int)
for v in body.data.vertices:
    if v.groups:
        dom[v.index] = max(v.groups, key=lambda g: g.weight).group
out = {}
acts = [a for a in bpy.data.actions if a.name.startswith('REV_') and not a.name.endswith('_Additive') and (not only or a.name in only)]
for act in acts:
    rig.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    rows = []
    for f in range(f0, f1 + 1):
        s.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = body.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(N * 3); me.vertices.foreach_get('co', co); co = co.reshape(N, 3)
        ev.to_mesh_clear()
        z = co[:, 2]
        low = np.argsort(z)[:40]
        under = z < -0.01
        owners = {}
        for i in np.where(under)[0]:
            owners[names[dom[i]]] = owners.get(names[dom[i]], 0) + 1
        rows.append({'frame': f, 'min_z': float(z.min()), 'min_owner': names[dom[low[0]]], 'below_1cm': int(under.sum()), 'owners': owners})
    worst = min(rows, key=lambda r: r['min_z'])
    out[act.name] = {'worst_min_z': worst['min_z'], 'worst_frame': worst['frame'], 'frames_with_penetration': sum(r['below_1cm'] > 0 for r in rows), 'rows': rows}
    bad = [(r['frame'], round(r['min_z'], 3), r['owners']) for r in rows if r['below_1cm']]
    print('MESHQA', act.name, 'worst', round(worst['min_z'], 3), '@', worst['frame'], 'frames_pen', len(bad), bad[:6])
p = D / 'qa' / 'mesh_ground.json'
old = json.loads(p.read_text()) if p.exists() and only else {}
old.update(out)
p.write_text(json.dumps(old, indent=1))
