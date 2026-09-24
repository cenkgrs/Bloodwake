"""Higher resolution tailored gunslinger geometry; executed by build.py."""
# Mesh rings let shoulders, waist, jaw and fabric follow designed contours.
def loft(name,rings,mat,bone,n=48):
    verts=[];faces=[]
    for z,x,y,rx,ry in rings:
        for j in range(n):
            a=2*math.pi*j/n
            verts.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    for k in range(len(rings)-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    finish(o,name,mat,bone)
    for p in mesh.polygons:p.use_smooth=len(p.vertices)==4
    return o

def piping(name,points,r,mat,bone):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=r;curve.bevel_resolution=3
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,mat,bone)

cloth=material('Charcoal trousers',(.055,.065,.071))
lining=material('Sand linen shirt',(.32,.26,.18))
sole=material('Boot sole',(.012,.014,.016))
hair=material('Dark umber hair',(.036,.017,.009))
white=material('Eye ivory',(.55,.49,.39))
lips=material('Muted lips',(.28,.105,.065))
coat.diffuse_color=(.022,.048,.055,1)
coat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=coat.diffuse_color
scarf.diffuse_color=(.28,.055,.025,1)
scarf.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=scarf.diffuse_color
loft('Tailored coat bodice',[(1.13,0,0,.275,.155),(1.25,0,0,.255,.16),(1.43,0,0,.29,.18),(1.62,0,0,.34,.19),(1.72,0,0,.35,.15),(1.79,0,0,.22,.125)],coat,'spine')
loft('Linen shirt',[(1.18,0,-.045,.20,.15),(1.48,0,-.045,.21,.158),(1.72,0,-.035,.21,.14),(1.80,0,0,.13,.115)],lining,'spine')
loft('Waist belt',[(1.105,0,0,.28,.17),(1.12,0,0,.284,.174),(1.19,0,0,.278,.17),(1.20,0,0,.273,.168)],leather,'pelvis')
box('Buckle',(0,-.184,1.155),(.102,.025,.073),gold,'pelvis',.009)
box('Buckle inset',(0,-.20,1.155),(.071,.012,.044),leather,'pelvis',.005)
for s in [-1,1]:
    k='L' if s==1 else 'R'
    mesh=bpy.data.meshes.new('Lapel fabric')
    mesh.from_pydata([(s*.10,-.147,1.79),(s*.26,-.182,1.68),(s*.12,-.228,1.43),(s*.15,-.225,1.64),(s*.055,-.18,1.76)],[],[(0,1,2,3,4)])
    ob=bpy.data.objects.new('Tailored lapel',mesh);bpy.context.collection.objects.link(ob);bpy.context.view_layer.objects.active=ob
    finish(ob,'Tailored lapel',coat,'spine')
    mod=ob.modifiers.new('Fabric thickness','SOLIDIFY');mod.thickness=.012;bpy.ops.object.modifier_apply(modifier=mod.name)
    piping('Lapel stitch',[(s*.13,-.152,1.79),(s*.25,-.20,1.68),(s*.13,-.228,1.46)],.0025,lining,'spine')
    box('Chest pocket',(s*.235,-.165,1.52),(.12,.031,.13),coat,'spine',.012)
    piping('Pocket welt',[(s*.18,-.184,1.577),(s*.28,-.168,1.577)],.007,leather,'spine')
    for z in [1.27,1.39,1.51]:ell('Coat button',(s*.09,-.209,z),(.014,.009,.014),gold,'spine')
    loft('Trouser leg',[(.56,s*.18,0,.102,.105),(.65,s*.18,-.012,.117,.125),(.77,s*.18,0,.126,.135),(.94,s*.18,0,.139,.15),(1.10,s*.16,0,.15,.16)],cloth,'thigh.'+k)
    loft('Leather boot',[(.16,s*.18,-.01,.105,.14),(.25,s*.18,0,.102,.12),(.35,s*.18,0,.105,.12),(.51,s*.18,0,.117,.133),(.55,s*.18,0,.12,.136)],black,'shin.'+k)
    ell('Boot foot',(s*.18,-.088,.145),(.113,.232,.095),black,'foot.'+k)
    box('Stacked sole',(s*.18,-.075,.079),(.233,.434,.046),sole,'foot.'+k,.023)
    box('Heel',(s*.18,.061,.052),(.21,.147,.045),black,'foot.'+k,.012)
    for z in [.29,.48]:
        loft('Boot strap',[(z,s*.18,0,.111,.127),(z+.023,s*.18,0,.112,.129)],leather,'shin.'+k)
        box('Strap buckle',(s*.289,-.018,z+.012),(.025,.045,.038),gold,'shin.'+k,.006)
    # Long split skirt with shaped hem and folds.
    loft('Duster skirt',[(.60,s*.228,.13,.154,.17),(.65,s*.23,.13,.155,.174),(.80,s*.218,.11,.148,.17),(1.0,s*.19,.09,.143,.156),(1.15,s*.17,.07,.135,.135)],coat,'coat.'+k)
    piping('Duster hem',[(s*.08,.10,.615),(s*.17,.285,.615),(s*.32,.25,.615),(s*.37,.13,.615)],.005,leather,'coat.'+k)
    ell('Shoulder fabric',(s*.345,0,1.69),(.135,.133,.103),coat,'upper_arm.'+k)
    loft('Jacket sleeve',[(1.36,s*.47,0,.098,.108),(1.43,s*.455,0,.109,.123),(1.55,s*.42,0,.128,.138),(1.68,s*.375,0,.135,.14),(1.73,s*.35,0,.115,.122)],coat,'upper_arm.'+k)
    loft('Forearm sleeve',[(1.09,s*.50,-.08,.079,.085),(1.17,s*.50,-.06,.086,.098),(1.28,s*.49,-.03,.096,.111),(1.39,s*.47,0,.098,.108)],coat,'forearm.'+k)
    for z,x,y in [(1.22,s*.495,-.05),(1.29,s*.488,-.03)]:
        piping('Sleeve crease',[(x-.065,y-.075,z-.012),(x,y-.107,z),(x+.064,y-.076,z+.008)],.006,coat,'forearm.'+k)
    loft('Leather cuff',[(1.07,s*.5,-.08,.083,.092),(1.12,s*.5,-.078,.085,.097)],leather,'forearm.'+k)
    ell('Gloved palm',(s*.5,-.08,1.018),(.077,.051,.084),black,'hand.'+k)
    for i in range(4):
        x=s*.5+(i-1.5)*.034
        ell('Glove finger',(x,-.09,.962),(.02,.033,.051),black,'hand.'+k)
        piping('Glove seam',[(x,-.132,1.045),(x,-.14,.98)],.002,leather,'hand.'+k)
    ell('Glove thumb',(s*.423,-.091,1.014),(.03,.04,.064),black,'hand.'+k)
    box('Leather holster',(s*.30,.015,1.02),(.104,.18,.27),leather,'pelvis',.025)
    for z in [.93,1.10]:ell('Holster rivet',(s*.355,-.047,z),(.008,.01,.008),gold,'pelvis')
# Anatomical jaw, cheek, forehead and neck silhouettes.
loft('Neck',[(1.76,0,.015,.10,.10),(1.90,0,.01,.103,.10),(1.96,0,0,.115,.12)],skin,'head')
loft('Head',[(1.91,0,-.025,.067,.074),(1.94,0,-.025,.114,.109),(2.0,0,-.01,.151,.136),(2.09,0,0,.167,.151),(2.17,0,.006,.164,.149),(2.25,0,.016,.156,.14),(2.31,0,.022,.125,.116),(2.34,0,.022,.054,.057)],skin,'head')
for s in [-1,1]:
    ell('Ear',(s*.166,.004,2.095),(.034,.022,.064),skin,'head')
    ell('Ear inner',(s*.182,-.016,2.095),(.013,.008,.033),lips,'head')
    ell('Cheek',(s*.097,-.103,2.072),(.052,.018,.042),skin,'head')
    ell('Eye socket',(s*.066,-.129,2.164),(.049,.024,.023),hair,'head')
    ell('Eye white',(s*.066,-.148,2.161),(.034,.010,.012),white,'head')
    ell('Iris',(s*.066,-.157,2.161),(.012,.004,.011),eye,'head')
    piping('Upper eyelid',[(s*.03,-.148,2.165),(s*.066,-.158,2.177),(s*.10,-.132,2.165)],.006,skin,'head')
    piping('Eyebrow',[(s*.029,-.142,2.194),(s*.062,-.153,2.203),(s*.11,-.122,2.19)],.009,hair,'head')
    ell('Nostril',(s*.025,-.166,2.09),(.023,.023,.016),skin,'head')
ell('Nose bridge',(0,-.15,2.134),(.025,.036,.061),skin,'head')
ell('Nose tip',(0,-.183,2.098),(.03,.032,.024),skin,'head')
piping('Upper lip',[(-.049,-.147,2.043),(0,-.164,2.046),(.049,-.147,2.043)],.006,lips,'head')
piping('Lower lip',[(-.042,-.147,2.034),(0,-.161,2.03),(.042,-.147,2.034)],.007,lips,'head')
ell('Chin',(0,-.092,1.978),(.082,.045,.036),skin,'head')
for s in [-1,1]:
    piping('Moustache',[(0,-.173,2.061),(s*.029,-.171,2.06),(s*.059,-.141,2.052)],.011,hair,'head')
    piping('Sideburn',[(s*.153,-.023,2.23),(s*.16,-.031,2.13),(s*.15,-.038,2.077)],.019,hair,'head')
loft('Hair',[(2.22,0,.033,.169,.135),(2.29,0,.035,.146,.132),(2.33,0,.035,.08,.08)],hair,'head')
loft('Scarf',[(1.80,0,0,.132,.133),(1.84,0,0,.143,.14),(1.875,0,0,.138,.132)],scarf,'spine')
ell('Scarf knot',(-.085,-.126,1.835),(.045,.038,.043),scarf,'spine')
box('Scarf end',(-.099,-.186,1.722),(.072,.021,.205),scarf,'spine',.009)
# Curved brim, pinched crown and fine band edging.
verts=[];faces=[];N=96
for r in [.17,.23,.32,.405]:
    for j in range(N):
        a=j*2*math.pi/N
        verts.append((r*math.cos(a),r*.83*math.sin(a),2.33+.085*(r/.405)**3*math.cos(a)**4))
for k in range(3):
    for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
mesh=bpy.data.meshes.new('Curved brim');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Curved brim',mesh);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o
finish(o,'Curved brim',leather,'head')
mod=o.modifiers.new('Brim thickness','SOLIDIFY');mod.thickness=.016;bpy.ops.object.modifier_apply(modifier=mod.name)
for p in mesh.polygons:p.use_smooth=True
loft('Pinched hat crown',[(2.33,0,.015,.21,.181),(2.37,0,.015,.211,.18),(2.49,0,.025,.187,.16),(2.55,0,.026,.174,.14),(2.575,0,.026,.12,.12)],leather,'head',64)
loft('Hat band',[(2.355,0,.015,.214,.183),(2.394,0,.015,.208,.179)],black,'head',64)
box('Hat band clasp',(.13,-.134,2.378),(.057,.025,.035),gold,'head',.006)
# Rifle with distinct wood furniture, lever, trigger, muzzle and barrel bands.
box('Walnut shoulder stock',(-.5,.06,1.01),(.092,.35,.12),leather,'hand.R',.025)
box('Butt plate',(-.5,.225,1.01),(.10,.023,.14),steel,'hand.R',.012)
box('Receiver',(-.5,-.202,1.04),(.095,.20,.104),steel,'hand.R',.009)
box('Wood foregrip',(-.5,-.385,1.033),(.078,.22,.063),leather,'hand.R',.019)
for z,r,name in [(1.076,.022,'Rifle barrel'),(1.026,.015,'Magazine tube')]:
    o=cyl(name,(-.5,-.53,z),r,.52,steel,'hand.R');o.rotation_euler.x=math.pi/2
for y in [-.43,-.66]:
    box('Barrel band',(-.5,y,1.052),(.054,.025,.088),steel,'hand.R',.012)
o=cyl('Muzzle opening',(-.5,-.794,1.076),.015,.004,eye,'hand.R');o.rotation_euler.x=math.pi/2
piping('Lever loop',[(-.5,-.115,1.0),(-.5,-.13,.96),(-.5,-.235,.958),(-.5,-.25,1.0)],.008,steel,'hand.R')
piping('Trigger',[(-.5,-.195,1.0),(-.5,-.19,.969)],.005,steel,'hand.R')
box('Front sight',(-.5,-.749,1.112),(.018,.026,.035),gold,'hand.R',.003)
for y in [-.155,-.24]:ell('Receiver screw',(-.552,y,1.044),(.004,.01,.01),gold,'hand.R')
