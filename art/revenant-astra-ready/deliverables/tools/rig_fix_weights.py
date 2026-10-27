"""Rig repair pass (backup: workfiles/Revenant_Rigged_backup_astra_v1.blend).

The first rig segmented cloth and legs with a hard label: connected vertices 5 mm
apart were 100% thigh on one side and 100% coat on the other, so any stride tore
long triangles between them. Weights are diffused over the mesh graph instead,
more strongly on the hip/coat band than on the arms, and hands/feet stay sharp.
"""
import bpy,numpy as np
from pathlib import Path
D=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(D/'workfiles/Revenant_Rigged_backup_astra_v1.blend'))
m=bpy.data.objects['REV_Body'];me=m.data;N=len(me.vertices)
names=[g.name for g in m.vertex_groups];B=len(names)
W=np.zeros((N,B))
for v in me.vertices:
    for g in v.groups:W[v.index,g.group]=g.weight
co=np.array([v.co for v in me.vertices]);E=np.array([e.vertices for e in me.edges])
L=np.linalg.norm(co[E[:,0]]-co[E[:,1]],axis=1);w=1.0/np.maximum(L,.002)
deg=np.zeros(N);np.add.at(deg,E[:,0],w);np.add.at(deg,E[:,1],w)
x,y,z=co[:,0],co[:,1],co[:,2]
def ramp(v,a,b):return np.clip((v-a)/(b-a),0,1)
# Strength per vertex: hip/coat band strongest, arms/shoulder moderate, hands/feet/face none.
hip=ramp(z,.25,.45)*(1-ramp(z,1.20,1.32))
arm=(ramp(np.abs(x-.03),.16,.24))*(1-ramp(np.abs(x-.03),.56,.66))*ramp(z,1.3,1.4)
alpha=np.maximum(hip*.9,arm*.6)
alpha[z<.2]=0
iters=np.where(hip>.5,42,np.where(arm>.3,14,6))
for k in range(int(iters.max())):
    acc=np.zeros_like(W);np.add.at(acc,E[:,0],W[E[:,1]]*w[:,None]);np.add.at(acc,E[:,1],W[E[:,0]]*w[:,None])
    avg=acc/np.maximum(deg,1e-9)[:,None]
    a=(alpha*(k<iters))[:,None]
    W=W*(1-a)+avg*a
# Toes: the source skin gave the ball bones nothing, so the whole forefoot pivoted
# with the ankle and dug into the floor whenever the heel lifted. Hand the region
# ahead of the ball joint to ball_*, blended over 4 cm.
gidx={n:i for i,n in enumerate(names)}
rig=bpy.data.objects['REV_Rig']
for side in 'lr':
    bh=rig.data.bones['ball_'+side].head_local
    fi,bi=gidx['foot_'+side],gidx['ball_'+side]
    near=(np.abs(x-bh.x)<0.09)&(z<bh.z+0.07)
    t=ramp(-(y-(bh.y+0.015)),0,0.04)*near
    move=W[:,fi]*t
    W[:,fi]-=move;W[:,bi]+=move
# top-4, normalized
idx=np.argsort(-W,axis=1)[:,:4]
for g in m.vertex_groups:g.remove(range(N))
for i in range(N):
    ws=W[i,idx[i]];ws=np.where(ws>0.01,ws,0);s=ws.sum()
    if s<=0:continue
    for gi,val in zip(idx[i],ws/s):
        if val>0:m.vertex_groups[int(gi)].add([i],float(val),'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Rigged.blend'))
print('WEIGHTS_DIFFUSED',N,B)
