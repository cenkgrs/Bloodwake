import json,sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

folder=Path(sys.argv[1]);rows=json.loads((folder/'measured_curves.json').read_text());metrics=json.loads((folder/'numeric_gate.json').read_text())
f=np.array([r['frame'] for r in rows]);hip=np.array([r['hip_z'] for r in rows]);head=np.array([r['head_z'] for r in rows])
fig,axes=plt.subplots(3,1,figsize=(10,9),sharex=True,layout='constrained')
axes[0].plot(f,(hip-hip.min())*100,label='Pelvis');axes[0].plot(f,(head-head.min())*100,label='Head')
axes[0].set_ylabel('Vertical range (cm)');axes[0].legend();axes[0].set_title('Measured deformed-rig motion / '+folder.name)
axes[1].plot(f,np.degrees([r['Pelvis_yaw'] for r in rows]),label='Hip yaw');axes[1].plot(f,np.degrees([r['Chest_yaw'] for r in rows]),label='Shoulder yaw')
axes[1].set_ylabel('Yaw (degrees)');axes[1].legend()
speed=5/(2.05/1.8)
for side in ['L','R']:
 axes[2].plot(f,[r['toe'][side][1]-speed*(r['frame']-1)/60 for r in rows],label=side+' toe world Y')
for start,end in [(1,10),(21,31)]:
 for ax in axes:ax.axvspan(start,end,alpha=.10,color='green');ax.grid(alpha=.2)
axes[2].set_ylabel('Forward coordinate (m)');axes[2].set_xlabel('Source frame (60 FPS)');axes[2].legend()
fig.savefig(folder/'curve_review.png',dpi=150)
print(folder/'curve_review.png')
