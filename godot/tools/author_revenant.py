"""Reauthor the supplied vampire motion in Blender 4.5+.

Retimes the complete source swipe, including its anticipation and body drive.
This replaces the rejected analytic IK pose sequence. The source rig and target
have identical rest transforms; rotations/skin deformation are preserved.
blender -b -t 4 --python godot/tools/author_revenant.py
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/revenant/source/revenant_rigged_base.glb'))
rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH']
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action=None
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'art/revenant/source/mixamo/Mutant Swiping.fbx'))
imported=set(bpy.data.objects)-before
source=next(o for o in imported if o.type=='ARMATURE')
source.animation_data.action.name='SourceSwipe'
# Capture matrices before removing the donor. No retarget assumptions: fail if
# rest translations or rotations differ from the skin we are about to export.
for b in rig.data.bones:
    other=source.data.bones[b.name]
    assert (b.head_local-other.head_local).length<.0001,b.name
    assert b.matrix_local.to_quaternion().rotation_difference(other.matrix_local.to_quaternion()).angle<.001,b.name
samples={}
for frame in range(1,82):
    scene.frame_set(frame)
    samples[frame]={b.name:b.matrix.copy() for b in source.pose.bones}
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
P=rig.pose.bones
H='mixamorig:Hips'
S=Matrix.Diagonal(Vector((-1,1,1,1)))
aux={}
for name in ['Run','Hit','Death']:
    action=bpy.data.actions[name];rig.animation_data.action=action
    start,end=action.frame_range
    aux[name]=[]
    for i in range(97):
        frame=start+(end-start)*i/96
        scene.frame_set(int(frame),subframe=frame-int(frame))
        aux[name].append({b.name:b.matrix.copy() for b in P})
rig.animation_data.action=None
def smooth(x):return x*x*(3-2*x)
def sample(frame,mirror=False):
    lo=max(1,min(81,int(frame)));hi=min(81,lo+1);t=frame-lo
    result={}
    for b in P:
        name=b.name
        if mirror:name=name.replace('Left','TEMP').replace('Right','Left').replace('TEMP','Right')
        a=samples[lo][name];c=samples[hi][name]
        m=a.to_quaternion().slerp(c.to_quaternion(),t).to_matrix().to_4x4()
        m.translation=a.translation.lerp(c.translation,t)
        result[b.name]=S@m@S if mirror else m
    return result
ready=sample(1)
anchor=ready[H].translation.copy()
def apply(matrices,commit=0):
    # Preserve 55% of source planar travel rather than erasing it. The former
    # importer pinned these axes on every frame and destroyed the lunge.
    hip=matrices[H].translation
    delta=hip-anchor
    correction=Vector((-delta.x*.45,0,-delta.z*.45))
    for b in P:
        m=matrices[b.name].copy();m.translation+=correction
        b.matrix=m
        bpy.context.view_layer.update()
    # Add a small torso commitment on top of coordinated source rotation. Do
    # not replace wrists, elbows, feet, or fingers with independently aimed poses.
    for name,angle in [('Spine',commit*5),('Spine1',commit*6),('Head',-commit*6)]:
        b=P['mixamorig:'+name]
        q=Matrix.Rotation(math.radians(angle),4,'X')
        b.matrix=Matrix.Translation(b.head)@q@Matrix.Translation(-b.head)@b.matrix
        bpy.context.view_layer.update()
def bake(name,frames,make_pose):
    old=bpy.data.actions.get(name)
    if old:bpy.data.actions.remove(old)
    action=bpy.data.actions.new(name);action.use_fake_user=True
    # Compute each complete pose with animation evaluation detached. Assigning
    # an Action during IK/FK posing can re-evaluate old keys on depsgraph updates.
    keys=[]
    rig.animation_data.action=None
    for f in range(frames+1):
        make_pose(f/frames)
        keys.append({b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in P})
    rig.animation_data.action=action
    for f,pose in enumerate(keys):
        for b in P:
            b.location,b.rotation_quaternion,b.scale=pose[b.name]
            b.keyframe_insert('location',frame=f,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
    for fc in action.fcurves:
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    rig.animation_data.action=None
for b in P:b.rotation_mode='QUATERNION'
def direct(matrices):
    for b in P:
        b.matrix=matrices[b.name].copy();bpy.context.view_layer.update()
def turn(name,axis,angle):
    b=P['mixamorig:'+name];q=Matrix.Rotation(math.radians(angle),4,axis)
    b.matrix=Matrix.Translation(b.head)@q@Matrix.Translation(-b.head)@b.matrix
    bpy.context.view_layer.update()
def blend(a,b,t):
    out={}
    for n,m in a.items():
        q=m.to_quaternion().slerp(b[n].to_quaternion(),t)
        out[n]=q.to_matrix().to_4x4();out[n].translation=m.translation.lerp(b[n].translation,t)
    return out
def auxiliary(name,t):
    x=max(0,min(1,t))*96;i=min(95,int(x))
    return blend(aux[name][i],aux[name][i+1],x-i)
# Reference: upright, arms relaxed, still head. Start from the model's neutral
# stance, not the low combat-ready pose used by the approved claw animation.
direct({b.name:b.bone.matrix_local.copy() for b in P})
turn('LeftArm','Z',-12);turn('RightArm','Z',12)
turn('Spine1','X',5);turn('Head','X',-3)
regal={b.name:b.matrix.copy() for b in P}
def idle(t):
    direct(regal)
    turn('Spine1','X',math.sin(t*math.tau)*.65)
    turn('Neck','X',math.sin(t*math.tau)*-.25)
bake('Idle',96,idle)
for name,frames,contact,mirror in [('Attack1',30,.38,False),('Attack2',31,.42,True)]:
    markers=[(0,1),(.22,29),(contact,41),(.59,49),(.80,65),(1,81)]
    def attack(t):
        for (ta,fa),(tb,fb) in zip(markers,markers[1:]):
            if ta<=t<=tb:
                # Keep source velocity through the strike; ease only recovery.
                u=(t-ta)/(tb-ta)
                if ta>=.59:u=smooth(u)
                mats=sample(fa+(fb-fa)*u,mirror)
                # Both clips share the same exact ready pose at the seams.
                seam=smooth(min(1,t/.14,(1-t)/.14))
                if mirror:
                    for n,m in mats.items():
                        start=ready[n];q=start.to_quaternion().slerp(m.to_quaternion(),seam)
                        p=start.translation.lerp(m.translation,seam)
                        mats[n]=q.to_matrix().to_4x4();mats[n].translation=p
                commit=math.sin(max(0,min(1,(t-.18)/.6))*math.pi)
                apply(mats,commit);break
    bake(name,frames,attack)

def walk(t):
    # Keep the coordinated foot cycle, but reduce the sprint's crouch and arm
    # flailing into a brisk stalking stride. Ground the supporting foot once.
    motion=auxiliary('Run',t if t<1 else 0)
    direct(motion)
    for b in P:
        is_leg=any(n in b.name for n in ['Leg','Foot','Toe'])
        weight=.83 if is_leg else .48 if b.name==H else .24
        q=regal[b.name].to_quaternion().slerp(motion[b.name].to_quaternion(),weight)
        m=q.to_matrix().to_4x4();m.translation=b.head.copy()
        if b.name==H:m.translation=regal[H].translation.lerp(motion[H].translation,.65)
        b.matrix=m;bpy.context.view_layer.update()
    low=min(P['mixamorig:'+s+'Foot'].head.y for s in ['Left','Right'])
    root=P[H];root.matrix=Matrix.Translation(Vector((0,.115-low,0)))@root.matrix
    bpy.context.view_layer.update()
bake('Run',30,walk)
def hit(t):
    motion=auxiliary('Hit',t)
    # Bring both ends back to the upright idle; the source's torso recoil stays.
    weight=smooth(min(1,t/.16,(1-t)/.28))
    direct(blend(regal,motion,weight))
    kick=math.sin(min(1,t/.55)*math.pi)
    turn('Spine1','X',-kick*12);turn('Head','X',-kick*8)
bake('Hit',12,hit)
def death(t):
    motion=auxiliary('Death',t)
    direct(blend(regal,motion,smooth(min(1,t/.16))))
bake('Death',66,death)
def teleport(t):
    # A late claw contact lets the silhouette vanish, travel, then reappear
    # before the landing strike. Normal Attack1/2 are deliberately unchanged.
    markers=[(0,1),(.22,22),(.45,31),(.57,41),(.75,51),(1,81)]
    for (ta,fa),(tb,fb) in zip(markers,markers[1:]):
        if ta<=t<=tb:
            apply(sample(fa+(fb-fa)*smooth((t-ta)/(tb-ta))),.5*math.sin(t*math.pi));break
bake('Teleport',30,teleport)
def ultimate(t):
    direct(regal)
    charge=smooth(min(1,t/.40))
    release=smooth(max(0,min(1,(t-.45)/.12)))
    recover=1-smooth(max(0,min(1,(t-.72)/.28)))
    # Fold inward to gather, then throw both arms wide with the head lifted.
    arm=(-18*charge+70*release)*recover
    turn('LeftArm','Z',arm);turn('RightArm','Z',-arm)
    turn('Spine1','X',(12*charge-22*release)*recover)
    turn('Head','X',(5*charge-20*release)*recover)
    turn('LeftForeArm','X',-12*charge*(1-release)*recover)
    turn('RightForeArm','X',-12*charge*(1-release)*recover)
bake('Ultimate',33,ultimate)
for a in list(bpy.data.actions):
    if a.name not in ['Idle','Run','Attack1','Attack2','Dash','Hit','Death','Teleport','Ultimate']:
        bpy.data.actions.remove(a)
rig.animation_data.action=None
for a in bpy.data.actions:
    a.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=a.name
    track.strips.new(a.name,int(a.frame_range[0]),a);track.mute=True
scene.render.fps=30;scene.frame_start=0;scene.frame_end=96
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,*meshes]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/revenant_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=bpy.data.actions['Idle'];scene.frame_set(0)
for im in bpy.data.images:
    if im.has_data:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/revenant/blender/revenant_authored.blend'))
print('REVENANT_SOURCE_MOTION_REAUTHORED')
