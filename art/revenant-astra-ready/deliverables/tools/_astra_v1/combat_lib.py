from motion_lib import *
import motion_lib as M

CONTACT_IDS={}
def contact_ids(m):
 if not CONTACT_IDS:
  names={g.index:g.name for g in m.vertex_groups}
  prefixes=['coat_'+str(j)+'_' for j in range(5)]+['hair_'+j+'_' for j in ['l','c','r']]
  CONTACT_IDS['body']=[]
  for p in prefixes:CONTACT_IDS[p]=[]
  for v in m.data.vertices:
   weights={names[g.group]:g.weight for g in v.groups}
   if sum(w for n,w in weights.items() if n.startswith(('coat','hair')))<.25:CONTACT_IDS['body'].append(v.index)
   for p in prefixes:
    if sum(w for n,w in weights.items() if n.startswith(p))>.4:CONTACT_IDS[p].append(v.index)
 return CONTACT_IDS

def floor_secondary():
 m=bpy.data.objects['REV_Body'];ids=contact_ids(m)
 for iteration in range(3):
  bpy.context.view_layer.update();ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();changes=[]
  for prefix in [k for k in ids if k!='body']:
   if not ids[prefix]:continue
   low=min(me.vertices[i].co.z for i in ids[prefix])
   if low<.002:changes.append((prefix+'1',.004-low))
  ev.to_mesh_clear()
  if not changes:break
  for n,dz in changes:
   mm=M.P[n].matrix.copy();mm.translation.z+=dz;M.P[n].matrix=mm
 bpy.context.view_layer.update()

def vcurve(f,keys):return Vector([curve(f,[(a,b[i]) for a,b in keys]) for i in range(3)])
def hit(f,phase='polish',direction='Front',additive=False):
 idle(1,phase);base={b.name:(b.location.copy(),b.rotation_quaternion.copy()) for b in M.P}
 a=curve(f,[(1,0),(2,0),(3,.76),(4,1),(5,.93),(6,.58),(8,.20),(9,-.07),(10,-.025),(12,0)])
 # 12-degree total rib rotation distributed along the spine; no leg/root track.
 sign=-1 if direction=='Left' else 1
 twist=12*a*sign if direction!='Front' else 10.5*a
 delta('spine_01',-2*a,0,twist*.22);delta('spine_02',-3*a,0,twist*.42);delta('spine_03',-2*a,0,twist*.36)
 h=curve(f,[(1,0),(2,0),(3,.45),(4,1),(5,.9),(7,.25),(9,-.08),(12,0)])
 delta('neck_01',5*h,0,-twist*.1);delta('head',4*h,0,-twist*.35)
 delta('clavicle_r',-3*a,2*a,-2*a*sign);delta('clavicle_l',-2*a,-a,-a*sign)
 if additive:
  for b in M.P:
   loc,q=base[b.name];b.location-=loc;b.rotation_quaternion=q.inverted()@b.rotation_quaternion
  bpy.context.view_layer.update()

def death(f,phase='polish'):
 reset()
 hz=curve(f,[(1,.986),(5,.975),(8,.956),(12,.87),(18,.77),(24,.50),(31,.46),(38,.40),(45,.34),(52,.235),(59,.214),(65,.202),(72,.20)])
 lean=curve(f,[(1,9),(5,5),(9,17),(15,28),(24,33),(38,41),(46,37),(52,17),(65,12),(72,12)])
 roll=curve(f,[(1,0),(12,-3),(24,-11),(38,-27),(45,-52),(52,-81),(59,-87),(65,-89),(72,-89)])
 posture(hz,lean,.14,curve(f,[(1,-1),(24,4),(38,8),(52,-3),(72,-3)]),3,roll)
 delta('neck_01',0,-35*max(0,min(1,(f-45)/20)),0);delta('head',0,-12*max(0,min(1,(f-50)/18)),0)
 # Grounded kneeling leg before the lateral collapse; knees follow curved arcs.
 targets={
 'l':vcurve(f,[(1,(.16,-.055,.132)),(24,(.21,-.18,.132)),(38,(.25,-.25,.132)),(52,(.65,-.22,.105)),(65,(.69,-.22,.055)),(72,(.69,-.22,.055))]),
 'r':vcurve(f,[(1,(-.235,.21,.141)),(24,(-.22,.40,.15)),(38,(-.10,.46,.15)),(52,(.43,.19,.13)),(65,(.48,.16,.065)),(72,(.48,.16,.065))])}
 for side in ['l','r']:
  t=targets[side];pole=(t.x,-.7,.12) if f<42 else (.40,-.30,.30)
  limb('thigh_'+side,'calf_'+side,'foot_'+side,t,pole)
  q=(rot(0,curve(f,[(1,0),(38,10),(52,75),(65,87),(72,87)]),0)@M.R['foot_'+side]).to_quaternion();place('foot_'+side,M.P['foot_'+side].head,q)
 left=vcurve(f,[(1,(.35,-.14,1.08)),(8,(.25,-.22,1.14)),(24,(.31,-.28,.69)),(38,(.04,-.36,.12)),(46,(-.20,-.32,.11)),(52,(-.45,-.22,.115)),(65,(-.48,-.24,.10)),(72,(-.48,-.24,.10))])
 right=vcurve(f,[(1,(-.34,.02,.90)),(7,(-.12,-.20,1.30)),(12,(-.17,-.25,1.17)),(24,(-.28,-.34,.55)),(38,(-.40,-.33,.18)),(52,(-.55,.12,.115)),(65,(-.61,.06,.11)),(72,(-.61,.06,.11))])
 arm('l',left,-8);arm('r',right,8)
 hand_settle=max(0,min(1,(f-38)/14))
 for side in ['l','r']:
  b=M.P['hand_'+side];old=b.matrix.to_quaternion();h=b.head.copy();aim('hand_'+side,h+Vector((-.14,-.035,-.004)))
  place('hand_'+side,h,old.slerp(b.matrix.to_quaternion(),hand_settle))
 if phase=='polish':
  for j in range(5):
   lag=2+j%3
   for k in (1,2,3):
    a=curve(f-lag,[(1,6),(12,9),(24,16),(38,25),(49,38),(55,26),(62,12),(67,8),(72,8)])
    delta(f'coat_{j}_{k}',a*(1 if k==1 else .25),0,(j-2)*curve(f-lag,[(1,0),(42,1),(53,3),(66,1),(72,1)]))
  for j,side in enumerate(['l','c','r']):
   for k in (1,2):delta(f'hair_{side}_{k}',curve(f-2-j,[(1,3),(12,5),(38,13),(51,26),(56,12),(64,4),(68,2),(72,2)]),0,0)
 # Settle cloth with a floor-oriented cape fan, independently of body contact.
 fold=max(0,min(1,(.986-hz)/.60));settle=max(0,min(1,(f-42)/16))
 for j in range(5):
  n=f'coat_{j}_1';delta(n,fold*60,0,0)
  if settle:
   b=M.P[n];mm=b.matrix.copy();q=mm.to_quaternion().slerp((rot(87,0,0)@M.R[n]).to_quaternion(),settle)
   target=Vector((-.015+(j-2)*.125,.19,.105));pos=mm.translation.lerp(target,settle);place(n,pos,q)
 # Ground the body using body vertices, not dangling cloth or hair.
 m=bpy.data.objects['REV_Body'];bpy.context.view_layer.update();ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
 bodyids=contact_ids(m)['body']
 low=min(me.vertices[i].co.z for i in bodyids);ev.to_mesh_clear()
 pm=M.P['pelvis'].matrix.copy();pm.translation.z+=.004-low;M.P['pelvis'].matrix=pm;bpy.context.view_layer.update()
 # Lift each independently weighted secondary strip only as much as its contact requires.
 for family,roots in [('coat',[f'coat_{j}_1' for j in range(5)]),('hair',[f'hair_{j}_1' for j in ['l','c','r']])]:
  ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
  for n in roots:
   prefix=n.rsplit('_',1)[0]+'_';ids=contact_ids(m)[prefix]
   if ids:
    low=min(me.vertices[i].co.z for i in ids)
    if low<.008:
     mm=M.P[n].matrix.copy();mm.translation.z+=.008-low;M.P[n].matrix=mm
  ev.to_mesh_clear();bpy.context.view_layer.update()

 if phase=='polish':floor_secondary()

def teleport(f,phase='polish'):
 reset()
 hz=curve(f,[(1,.986),(6,.82),(10,.80),(15,.745),(21,.745),(22,.80),(25,.855),(26,.89),(28,.915),(34,.92),(42,.986)])
 lean=curve(f,[(1,9),(6,29),(10,31),(15,37),(21,37),(22,29),(26,23),(28,17),(34,17),(42,9)])
 yaw=curve(f,[(1,-1),(6,-14),(10,-20),(15,-12),(21,-12),(22,-20),(25,-27),(26,16),(28,55),(34,50),(42,-1)],'cubic')
 posture(hz,lean,.13,yaw,-yaw*.28)
 foot('l',(.19,-.19,.132),0,curve(f,[(1,0),(24,0),(28,25),(34,22),(42,0)]))
 foot('r',(-.25,.26,.141),0,curve(f,[(1,0),(24,0),(28,32),(34,30),(42,0)]))
 right=vcurve(f,[(1,(-.34,.02,.90)),(6,(-.39,-.13,.72)),(7,(-.40,-.23,.87)),(10,(-.12,-.44,.95)),(15,(-.11,-.19,1.00)),(21,(-.11,-.19,1.00)),(22,(-.33,.09,.85)),(25,(-.43,-.12,1.08)),(26,(.10,-.43,1.15)),(28,(.17,-.22,1.17)),(34,(.14,-.21,1.15)),(38,(-.22,-.05,1.0)),(42,(-.34,.02,.90))])
 left=vcurve(f,[(1,(.35,-.14,1.08)),(6,(.34,-.32,.94)),(15,(.15,-.18,1.03)),(21,(.15,-.18,1.03)),(22,(.33,-.24,.92)),(26,(.37,.12,.99)),(28,(.32,.23,1.01)),(34,(.34,.18,1.02)),(42,(.35,-.14,1.08))])
 arm('r',right,curve(f,[(1,4),(10,-12),(15,6),(22,12),(25,-16),(26,9),(28,15),(42,4)]));arm('l',left,-7)
 if phase=='polish':secondary(f,0,curve(f,[(1,0),(6,5),(15,16),(22,21),(26,-12),(29,16),(35,4),(42,0)]))

 if phase=='polish':
  crouch=max(0,min(1,(.986-hz)/.24))
  for j in range(5):delta(f'coat_{j}_1',crouch*30,0,0)
  floor_secondary()

def burst(f,phase='polish'):
 reset()
 hz=curve(f,[(1,.986),(9,.84),(18,.66),(24,.72),(36,.86),(42,.93),(48,.96),(52,.94),(55,.93),(59,.92),(60,.935),(63,.96),(70,.97),(84,.98),(94,.88),(101,.64),(107,.56),(112,.68),(120,.986)])
 lean=curve(f,[(1,9),(9,24),(18,49),(24,37),(36,19),(42,11),(48,15),(52,18),(59,20),(60,7),(63,-2),(70,4),(84,9),(94,25),(101,36),(107,32),(112,23),(120,9)])
 posture(hz,lean,.13,curve(f,[(1,-1),(18,-9),(42,-7),(52,-8),(59,-8),(60,2),(64,7),(84,2),(108,-4),(120,-1)]),curve(f,[(1,1),(18,4),(42,9),(59,12),(60,-3),(65,-6),(84,1),(120,1)]))
 spread=curve(f,[(1,0),(12,1),(18,1),(94,1),(112,.7),(120,0)])
 for side in ['l','r']:
  x=.16+.12*spread if side=='l' else -.235-.075*spread;y=-.055-.08*spread if side=='l' else .21+.08*spread
  if side=='r':y+=curve(f,[(1,0),(94,0),(104,.18),(109,.16),(120,0)])
  foot(side,(x,y,.132 if side=='l' else .141),0,(-5 if side=='l' else 5)*spread)
 right=vcurve(f,[(1,(-.34,.02,.90)),(10,(-.38,-.23,.69)),(18,(-.32,-.42,.40)),(26,(-.34,-.39,.68)),(36,(-.31,-.36,1.1)),(42,(-.24,-.34,1.34)),(48,(-.13,-.32,1.29)),(52,(-.11,-.31,1.24)),(59,(-.115,-.32,1.22)),(60,(-.34,-.35,1.1)),(63,(-.53,-.13,1.13)),(70,(-.46,-.03,1.03)),(84,(-.40,-.02,.98)),(101,(-.32,-.31,.43)),(108,(-.30,-.33,.40)),(112,(-.32,-.21,.64)),(120,(-.34,.02,.9))])
 left=vcurve(f,[(1,(.35,-.14,1.08)),(18,(.34,-.15,.83)),(36,(.34,-.27,1.19)),(48,(.21,-.33,1.28)),(59,(.18,-.32,1.23)),(60,(.38,-.3,1.10)),(63,(.57,-.06,1.13)),(70,(.50,-.06,1.01)),(84,(.43,-.11,1.04)),(101,(.36,-.25,.58)),(108,(.33,-.28,.57)),(120,(.35,-.14,1.08))])
 arm('r',right,curve(f,[(1,4),(18,-10),(42,-35),(52,-22),(59,-23),(60,12),(66,6),(120,4)]));arm('l',left,-7)
 if phase=='polish':
  secondary(f,0,curve(f,[(1,0),(18,19),(38,9),(46,-8),(52,-10),(59,-10),(60,-9),(62,14),(65,28),(74,13),(86,4),(105,16),(113,7),(120,0)]))
  # The cloth is drawn inward before release, then different strips settle on staggered beats.
  for j in range(5):
   for k in (1,2,3):
    d=curve(f-(2+j%3),[(1,0),(19,9),(42,2),(51,-7),(59,-7),(62,23),(71,17),(88,4),(106,9),(114,4),(120,0)])
    delta(f'coat_{j}_{k}',d*(.6 if k==1 else .22),0,(j-2)*d*.09)
 # Low charge/recovery coat collision correction is on secondary bones only.
 if phase=='polish':
  crouch=max(0,(1.0-hz)/.44)
  for j in range(5):delta(f'coat_{j}_1',crouch*50,0,0)

 if phase=='polish':floor_secondary()
