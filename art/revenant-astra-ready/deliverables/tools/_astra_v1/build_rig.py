import bpy, math, json, bmesh
from mathutils import Vector,Matrix
from pathlib import Path
D=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Normalized.blend'))
r=bpy.data.objects['REV_Rig'];m=bpy.data.objects['REV_Body'];s=bpy.context.scene
G=json.load(open('/tmp/rev_groups.json'))
# Retain source UVs and material. Weld coincident seams without dissolving UV loops.
bm=bmesh.new();bm.from_mesh(m.data);before=len(bm.verts)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000008)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(m.data);bm.free()
for p in m.data.polygons:p.use_smooth=True
for b in r.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.objects.active=r;bpy.ops.object.mode_set(mode='EDIT');E=r.data.edit_bones
# Anatomical pivots fitted to the actual supplied, slightly asymmetric T-pose.
points={'pelvis':((-.015,.17,1.105),(.015,.16,1.23)), 'spine_01':((.015,.16,1.23),(.037,.15,1.36)), 'spine_02':((.037,.15,1.36),(.051,.15,1.47)), 'spine_03':((.051,.15,1.47),(.060,.15,1.62)), 'neck_01':((.060,.15,1.62),(.067,.135,1.72)), 'head':((.067,.135,1.72),(.072,.13,1.89)),
'clavicle_l':((.051,.15,1.53),(.257,.19,1.54)), 'upperarm_l':((.257,.19,1.54),(.523,.215,1.48)), 'lowerarm_l':((.523,.215,1.48),(.772,.254,1.435)), 'hand_l':((.772,.254,1.435),(.856,.263,1.413)),
'clavicle_r':((.051,.15,1.55),(-.193,.151,1.586)), 'upperarm_r':((-.193,.151,1.586),(-.447,.087,1.566)), 'lowerarm_r':((-.447,.087,1.566),(-.658,-.014,1.557)), 'hand_r':((-.658,-.014,1.557),(-.749,-.045,1.546)),
'thigh_l':((.133,.16,1.052),(.190,.135,.618)), 'calf_l':((.190,.135,.618),(.149,.187,.131)), 'foot_l':((.149,.187,.131),(.155,-.033,.042)), 'ball_l':((.155,-.033,.042),(.157,-.11,.034)),
'thigh_r':((-.144,.156,1.058),(-.217,.11,.655)), 'calf_r':((-.217,.11,.655),(-.258,.162,.167)), 'foot_r':((-.258,.162,.167),(-.280,-.067,.075)), 'ball_r':((-.280,-.067,.075),(-.285,-.14,.065))}
for n,(h,t) in points.items():E[n].head=h;E[n].tail=t
# Source twist weights are merged into their corresponding limb (no detached twist pivots).
twistmap={}
for b in list(E):
 if 'twist' in b.name:
  twistmap[b.name]=b.name.split('_twist')[0]+'_'+b.name[-1];E.remove(b)
# Fit fingers around measured texture-mesh positions; retain independent three-joint chains.
for side in ['l','r']:
 for finger in ['thumb','index','middle','ring','pinky']:
  names=[f'{finger}_{i:02}_{side}' for i in (1,2,3)];centers=[]
  for i,n in enumerate(names):
   centers.append(Vector(G[n]['center']) if n in G else centers[-1]+Vector((.012 if side=='l' else -.012,0,-.003)))
  prev=E['hand_'+side].tail.copy()
  for i,n in enumerate(names):
   h=centers[i].lerp(prev,.32) if i==0 else E[names[i-1]].tail.copy()
   t=centers[i].lerp(centers[i+1],.5) if i<2 else centers[i]+(centers[i]-centers[i-1])*.60
   if (t-h).length<.006:t=h+Vector((.008 if side=='l' else -.008,0,0))
   E[n].head=h;E[n].tail=t
root=E.new('root');root.head=(0,0,0);root.tail=(0,0,.18);E['pelvis'].parent=root;root.use_deform=False
for side,x in [('l',.14),('c',.035),('r',-.1)]:
 for i,(z1,z2) in enumerate([(1.80,1.59),(1.59,1.40)],1):
  b=E.new(f'hair_{side}_{i}');b.head=(x,.25,z1);b.tail=(x,.30,z2);b.parent=E['head'] if i==1 else E[f'hair_{side}_1']
for j,x in enumerate([-.33,-.18,0,.18,.33]):
 for i,(z1,z2) in enumerate([(1.10,.80),(.80,.48),(.48,.16)],1):
  b=E.new(f'coat_{j}_{i}');b.head=(x,.29+(1.1-z1)*.15,z1);b.tail=(x,.29+(1.1-z2)*.15,z2);b.parent=E['pelvis'] if i==1 else E[f'coat_{j}_{i-1}']
b=E.new('blood_claw');b.head=E['hand_r'].head;b.tail=E['hand_r'].tail;b.parent=E['hand_r']
for side in ['l','r']:
 b=E.new('armor_'+side);b.head=E['upperarm_'+side].head;b.tail=b.head+Vector((0,0,.1));b.parent=E['clavicle_'+side]
bpy.ops.object.mode_set(mode='OBJECT')
# Merge twist groups, normalized sparse influences. Reassign coat/hair to dedicated chains.
oldnames={g.index:g.name for g in m.vertex_groups};oldweights=[{twistmap.get(oldnames[g.group],oldnames[g.group]):0 for g in v.groups} for v in m.data.vertices]
for v,w in zip(m.data.vertices,oldweights):
 for g in v.groups:w[twistmap.get(oldnames[g.group],oldnames[g.group])]+=g.weight
for g in list(m.vertex_groups):m.vertex_groups.remove(g)
for b in r.data.bones:
 if b.use_deform:m.vertex_groups.new(name=b.name)
# Geodesic semantic segmentation keeps neighboring cloth vertices on one surface.
import heapq
N=len(m.data.vertices);adj=[[] for _ in range(N)]
for e in m.data.edges:
 a,b=e.vertices
 if max(m.data.vertices[a].co.z,m.data.vertices[b].co.z)<1.04:
  length=(m.data.vertices[a].co-m.data.vertices[b].co).length;adj[a].append((b,length));adj[b].append((a,length))
def section(z,side):
 knots=[(0,.155 if side=='l' else -.27,.075,.10,.16),(.3,.12 if side=='l' else -.23,.145 if side=='l' else .11,.054,.067),(.5,.20 if side=='l' else -.20,.15 if side=='l' else .11,.067,.087),(.7,.18 if side=='l' else -.21,.105 if side=='l' else .085,.070,.087),(.85,.11 if side=='l' else -.11,.12 if side=='l' else .10,.082,.10),(1.12,.08 if side=='l' else -.075,.13,.115,.13)]
 for a,b in zip(knots,knots[1:]):
  if a[0]<=z<=b[0]:
   t=(z-a[0])/(b[0]-a[0]);return [a[k]+(b[k]-a[k])*t for k in range(1,5)]
 return knots[-1][1:]
labels=[-1]*N;dist=[1e9]*N;queue=[]
for v in m.data.vertices:
 x,y,z=v.co
 if z>=1.04:continue
 side='l' if x>0 else 'r';cx,cy,rx,ry=section(z,side);d=math.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)
 label=-1
 if d<1.2 and y<cy-.01:label=0
 if d>1.65 or y>.285:label=1
 if z<.15 and d<1.3 and y<.19:label=0
 if label!=-1:labels[v.index]=label;dist[v.index]=0;heapq.heappush(queue,(0,v.index,label))
while queue:
 d,i,label=heapq.heappop(queue)
 if d>dist[i]:continue
 for j,cost in adj[i]:
  nd=d+cost
  if nd<dist[j]:dist[j]=nd;labels[j]=label;heapq.heappush(queue,(nd,j,label))

counts={'coat':0,'hair':0,'armor':0}
def ramp(x,a,b):return max(0,min(1,(x-a)/(b-a)))
for v,w in zip(m.data.vertices,oldweights):
 x,y,z=v.co
 # Cloth lies behind or outside the two fitted leg envelopes; preserve leg surfaces.
 if z<1.12:
  side='l' if x>0 else 'r'
  cx,cy,rx,ry=section(z,side)
  legdist=math.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)
  cloth=(float(labels[v.index]==1) if z<1.04 else ramp(legdist,1.1,1.3))*(1-ramp(z,.97,1.12))
  # Repaint the legs: the supplied skin incorrectly weighted shin/boot vertices to thigh.
  knee=.618 if side=='l' else .655
  thigh=ramp(z,knee-.08,knee+.10);ankle=.131 if side=='l' else .167
  ankleblend=1-ramp(z,ankle+.015,ankle+.10)
  w={'thigh_'+side:thigh,'calf_'+side:(1-thigh)*(1-ankleblend),'foot_'+side:(1-thigh)*ankleblend}
  # Smooth attachment to pelvis above the hip crease.
  hipblend=ramp(z,.99,1.12)
  w={n:a*(1-hipblend) for n,a in w.items()};w['pelvis']=hipblend
  if cloth>0:
   counts['coat']+=1;w={n:a*(1-cloth) for n,a in w.items()}
   jf=max(0,min(4,(x+.33)/.165));ja=int(jf);jb=min(4,ja+1);jw=jf-ja
   kf=max(0,min(2,(1.02-z)/.32));ka=int(kf)+1;kb=min(3,ka+1);kw=kf-int(kf)
   for j,a in [(ja,1-jw),(jb,jw)]:
    for k,b in [(ka,1-kw),(kb,kw)]:w[f'coat_{j}_{k}']=w.get(f'coat_{j}_{k}',0)+cloth*a*b
 # Rear hair only; retain face/neck deformation in front.
 hair=ramp(y,.22,.285)*ramp(z,1.36,1.46)*(1-ramp(z,1.79,1.88))*(1-ramp(abs(x-.05),.14,.22))
 if hair>0:
  counts['hair']+=1;w={n:a*(1-hair) for n,a in w.items()};side='l' if x>.09 else 'r' if x<-.04 else 'c';t=ramp(1.64-z,0,.13)
  w[f'hair_{side}_1']=hair*(1-t);w[f'hair_{side}_2']=hair*t
 # Tiny rigid pauldron islands, with a soft attachment boundary.
 if 1.55<z<1.70 and -.36<x<-.13:
  a=ramp(z,1.55,1.59)*.75;w={n:q*(1-a) for n,q in w.items()};w['armor_r']=a;counts['armor']+=1
 if x<-.72 and z>1.45:
  a=.12;w={n:q*(1-a) for n,q in w.items()};w['blood_claw']=a
 w=sorted([(n,a) for n,a in w.items() if a>1e-5 and n in m.vertex_groups],key=lambda a:-a[1])[:4];total=sum(a for n,a in w)
 for n,a in w:m.vertex_groups[n].add([v.index],a/total,'REPLACE')
bm=bmesh.new();bm.from_mesh(m.data);bm.verts.ensure_lookup_table()
bridges=[]
for face in bm.faces:
 ids=[v.index for v in face.verts]
 if max(v.co.z for v in face.verts)<.96 and {labels[i] for i in ids}=={0,1}:bridges.append(face)
bmesh.ops.delete(bm,geom=bridges,context='FACES');bm.to_mesh(m.data);bm.free()
print('LOCAL_CLOTH_BRIDGES_REMOVED',len(bridges))
r.show_in_front=True
for b in r.pose.bones:b.rotation_mode='QUATERNION'
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1;s.render.fps=60
s.camera=bpy.data.objects['CAM_three']
for b in r.data.bones:b.select=False
bpy.context.view_layer.update()
audit={'vertices_before_weld':before,'vertices_after_weld':len(m.data.vertices),'triangles':sum(len(p.vertices)-2 for p in m.data.polygons),'bones':len(r.data.bones),'reassigned_vertices':counts,'max_influences':max(len(v.groups) for v in m.data.vertices),'zero_weight_vertices':sum(not v.groups for v in m.data.vertices),'height_m':float(m.dimensions.z),'source_skin_repair':'Rebuilt anatomical rest pivots; cleared incompatible identity-node poses; retained mesh UVs, material and normalized source weights; replaced detached twist weights.'}
(D/'qa/rig_audit.json').write_text(json.dumps(audit,indent=2))
s.render.filepath=str(D/'qa/rig_rest.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(D/'Revenant_Rigged.blend'));print(audit)
