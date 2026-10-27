from pathlib import Path
import subprocess,json,numpy as np
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
D=Path(__file__).resolve().parents[1];P=D/'previews'
def enc(name,out,fps=60,extra=[]):
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate',str(fps),'-i',str(P/'frames'/name/'%04d.png'),*extra,'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(P/out)],check=True)
enc('move_world','Stage1_Locomotion_Normal_2.45mps.mp4')
enc('move_world','Stage1_Locomotion_HalfSpeed.mp4',30)
enc('move_world','Stage1_Locomotion_Target_2.60mps.mp4',60, ['-vf','setpts=PTS*2.45/2.6','-r','60'])
enc('move_side','Stage1_Locomotion_Side.mp4')
enc('move_silhouette','Stage1_Locomotion_Silhouette.mp4')
enc('idle','Stage1_Idle.mp4')
j=json.loads((D/'qa/locomotion_measurements.json').read_text());fig,axes=plt.subplots(3,1,figsize=(10,8),sharex=True);f=[r['frame'] for r in j]
for key in ['pelvis_z','head_z']:
 v=np.array([r[key] for r in j]);axes[0].plot(f,(v-v.mean())*1000,label=key)
axes[0].set_ylabel('Vertical offset (mm)');axes[0].legend()
for key in ['hip_yaw','shoulder_yaw']:
 v=np.array([r[key] for r in j]);axes[1].plot(f,np.degrees(v-v.mean()),label=key)
axes[1].set_ylabel('Yaw from mean (deg)');axes[1].legend()
for side,a,b in [('l',0,12),('r',12,24)]:
 v=np.array([r['world_ball_'+side] for r in j[a:b]]);axes[2].plot(f[a:b],np.linalg.norm(v-v[0],axis=1)*1000,label='stance '+side)
axes[2].set_ylabel('World contact drift (mm)');axes[2].set_xlabel('Frame at 60 fps');axes[2].legend()
for ax in axes:ax.grid(alpha=.2)
fig.tight_layout();fig.savefig(D/'qa/locomotion_curves.png',dpi=150)
print('STAGE1_ENCODE_COMPLETE')
