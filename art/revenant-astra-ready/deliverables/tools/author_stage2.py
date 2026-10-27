"""Stage 2: light hits (+ upper-body additive), death, teleport attack, blood burst,
and the two game claw attacks. Builds on Revenant_Stage1.blend.

blender -b deliverables/Revenant_Stage1.blend --python tools/author_stage2.py [-- ACTION ...]
"""
import bpy, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import anim_core as A
import combat_v2 as C
import floor_fix as FF

D = Path(__file__).resolve().parents[1]
only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
rig_obj = bpy.data.objects['REV_Rig']
R = A.Rig(rig_obj)
scene = bpy.context.scene
names = [n for n in C.ACTIONS if not only or n in only]


class Fixed:
    def __init__(self, b):
        self.b = b

    def basis(self):
        return self.b


def build(name, phase):
    spec = C.ACTIONS[name]
    L = spec['length']
    if phase == 'polish':
        frames = list(range(1, L + 1))
        interp = 'LINEAR'
    else:
        frames = C.keys_for(name, phase)
        interp = 'BEZIER' if phase == 'spline' else 'CONSTANT'
    bodies = [C.pose(R, name, f, phase) for f in frames]
    act = A.write_action(rig_obj, name, [b.p for b in bodies], frames, interp, loop=False,
                         meta={'authoring_phase': phase, 'length_frames': L})
    act.frame_range = (1, L)
    A.add_markers(act, spec['markers'])
    if phase == 'polish':
        n = FF.fix_action(rig_obj, bpy.data.objects['REV_Body'], act)
        print('FLOORFIX', name, n)
    if phase == 'polish' and name.startswith('REV_HitLight'):
        # Upper-body additive layer: local delta from the clip's first frame.
        b0 = bodies[0].p.basis()
        deltas = []
        for b in bodies:
            bb = b.p.basis()
            deltas.append(Fixed({n: b0[n].inverted() @ bb[n] for n in bb}))
        add = A.write_action(rig_obj, name + '_Additive', deltas, frames, 'LINEAR', bones=C.UPPER, loop=False,
                             meta={'authoring_phase': 'polish', 'additive': True, 'reference_frame': 1, 'length_frames': L})
        add.frame_range = (1, L)
        A.add_markers(add, spec['markers'])
    return act


for phase in ('blocking', 'breakdown', 'spline'):
    for n in names:
        build(n, phase)
    if not only:
        bpy.ops.wm.save_as_mainfile(filepath=str(D / 'workfiles' / f'Stage2_{phase}.blend'), copy=True)
for n in names:
    build(n, 'polish')
if not only:
    bpy.ops.wm.save_as_mainfile(filepath=str(D / 'workfiles' / 'Stage2_polish.blend'), copy=True)
bpy.ops.wm.save_as_mainfile(filepath=str(D / 'Revenant_Stage2.blend'))
print('STAGE2_DONE', names)
