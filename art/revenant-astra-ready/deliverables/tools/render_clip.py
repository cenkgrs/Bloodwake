"""Render one action to numbered PNGs (crash tolerant: existing frames are skipped).

blender -b <file.blend> --python tools/render_clip.py -- ACTION CAM OUTDIR [key=value ...]
  cycle=24        loop the action every N frames (in-place cycles)
  count=48        number of output frames
  step=1.0        action frames advanced per output frame (0.5 = 50% speed)
  travel=0        m/s: move the rig along -Y and follow with the camera
  start=1         first action frame
  sil=0           1 = flat black silhouette on light background
  res=640
  vfx=0           1 = keep REV_VFX_PROXY visible
"""
import bpy, sys, os
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).parent))
import review as RV

argv = sys.argv[sys.argv.index('--') + 1:]
action, cam, out = argv[0], argv[1], Path(argv[2])
opt = dict(a.split('=') for a in argv[3:])
cycle = int(opt.get('cycle', 0))
count = int(opt.get('count', 48))
step = float(opt.get('step', 1.0))
travel = float(opt.get('travel', 0))
start = float(opt.get('start', 1))
sil = opt.get('sil', '0') == '1'
res = int(opt.get('res', 640))
vfx = opt.get('vfx', '0') == '1'
frames = [float(x) for x in opt['frames'].split(',')] if 'frames' in opt else None
if frames:
    count = len(frames)
out.mkdir(parents=True, exist_ok=True)

s = bpy.context.scene
RV.setup(s, res)
RV.silhouette(sil, s)
rig = bpy.data.objects['REV_Rig']
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.action = bpy.data.actions[action]
for tr in list(rig.animation_data.nla_tracks):
    tr.mute = True
col = bpy.data.collections.get('REV_VFX_PROXY')
if col:
    col.hide_render = not vfx
camobj = bpy.data.objects['CAM_' + cam]
base_cam = camobj.location.copy()
s.camera = camobj
for i in range(count):
    path = out / f'{i:04d}.png'
    if path.exists():
        continue
    af = frames[i] if frames else start + i * step
    if cycle:
        af = 1 + (af - 1) % cycle
    fi = int(af)
    s.frame_set(fi, subframe=af - fi)
    if travel:
        d = -travel * i * step / 60.0
        rig.location.y = d
        camobj.location = base_cam + Vector((0, d, 0))
    s.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
print('RENDER_CLIP_DONE', action, cam, count)
