"""Render the sequential NLA preview (all actions + VFX proxies) from Revenant_Animated.blend."""
import bpy, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import review as RV
argv = sys.argv[sys.argv.index('--') + 1:]
out = Path(argv[0]); out.mkdir(parents=True, exist_ok=True)
s = bpy.context.scene
RV.setup(s, 720)
cam = bpy.data.objects['CAM_three']
s.camera = cam
for f in range(s.frame_start, s.frame_end + 1):
    p = out / f'{f:04d}.png'
    if p.exists():
        continue
    s.frame_set(f)
    s.render.filepath = str(p)
    bpy.ops.render.render(write_still=True)
print('NLA_DONE')
