"""System-python plot of qa/stage1_metrics.json -> qa/locomotion_curves_<action>.png"""
import json, sys
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
D = Path(__file__).resolve().parents[1]
M = json.loads((D / 'qa/stage1_metrics.json').read_text())
for action, m in M.items():
    F = m['frames']
    fr = [r['frame'] for r in F]
    fig, ax = plt.subplots(2, 3, figsize=(16, 9))
    a = ax[0, 0]
    pz = [r['pelvis_z'] for r in F]; hz = [r['head_z'] for r in F]
    a.plot(fr, [v - pz[0] for v in pz], 'o-', label='pelvis z (rel)')
    a.plot(fr, [v - hz[0] for v in hz], 's-', label='head z (rel)')
    a.set_title(f'Vertical: pelvis {m["pelvis_vertical_range_m"]*100:.1f} cm, head {m["head_vertical_range_m"]*100:.1f} cm'); a.legend(); a.grid(alpha=.3)
    a = ax[0, 1]
    a.plot(fr, [r['hip_yaw'] for r in F], 'o-', label='hip line yaw')
    a.plot(fr, [r['shoulder_yaw'] for r in F], 's-', label='shoulder line yaw')
    a.set_title('Counter-rotation (deg)'); a.legend(); a.grid(alpha=.3)
    a = ax[0, 2]
    for s, c in (('l', 'tab:blue'), ('r', 'tab:red')):
        a.plot(fr, [r['ball_world_' + s][1] for r in F], '-', color=c, label=f'ball {s} world Y')
        a.plot(fr, [r['ball_world_' + s][2] * 5 for r in F], '--', color=c, label=f'ball {s} Z x5')
        for r in F:
            if r['planted'][s]:
                a.axvspan(r['frame'] - .5, r['frame'] + .5, color=c, alpha=.06)
    sl = m['foot_slip']
    a.set_title(f'Foot lock (shaded = planted) slip L {sl["l"]["max_slip_m"]*1000:.1f} mm R {sl["r"]["max_slip_m"]*1000:.1f} mm'); a.legend(fontsize=7); a.grid(alpha=.3)
    for i, (title, keys) in enumerate((('Leg arcs (side view, Y/Z)', ('knee', 'ankle')), ('Arm arcs (side view, Y/Z)', ('elbow', 'wrist')))):
        a = ax[1, i]
        for k in keys:
            for s, c in (('l', 'tab:blue'), ('r', 'tab:red')):
                ys = [r[f'{k}_{s}'][1] for r in F]; zs = [r[f'{k}_{s}'][2] for r in F]
                a.plot(ys, zs, '.-', color=c, alpha=.8 if k in ('ankle', 'wrist') else .45, label=f'{k} {s}')
        a.invert_xaxis(); a.set_aspect('equal'); a.set_title(title + ' — forward is left'); a.legend(fontsize=7); a.grid(alpha=.3)
    a = ax[1, 2]
    for s, c in (('l', 'tab:blue'), ('r', 'tab:red')):
        a.plot([r[f'wrist_{s}'][0] for r in F], [r[f'wrist_{s}'][1] for r in F], '.-', color=c, label=f'wrist {s} (top view X/Y)')
    a.set_aspect('equal'); a.invert_yaxis(); a.legend(fontsize=7); a.grid(alpha=.3); a.set_title('Hand paths, top view')
    fig.suptitle(f'{action}  {m["speed_mps"]} m/s   loop seam {m["loop_seam_max_basis_delta"]:.1e}   L/R mirrored diff {m["left_right_max_mirrored_diff_m"]*100:.1f} cm')
    fig.tight_layout(); fig.savefig(D / 'qa' / f'locomotion_curves_{action}.png', dpi=80)
print('PLOTS_OK')
