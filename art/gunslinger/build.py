"""Rebuild original stylized gunslinger, skeletal clips, GLB and rendered frames.
Run: blender --background --python art/gunslinger/build.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = .65
    return m

coat = material('Midnight teal wool', (.035,.11,.13))
leather = material('Oxblood leather', (.16,.045,.028))
skin = material('Warm skin', (.56,.30,.16))
steel = material('Blued gun steel', (.055,.075,.095), .75)
gold = material('Aged brass', (.65,.36,.08), .65)
black = material('Boots and gloves', (.025,.03,.035))
scarf = material('Burnt orange scarf', (.8,.19,.025))
eye = material('Eyes', (.008,.012,.013))
parts=[]

def finish(obj,name,mat,bone):
    obj.name=name
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append((obj,bone))
    if 'Sphere' in obj.data.name or 'Cylinder' in obj.data.name:
        for poly in obj.data.polygons: poly.use_smooth=len(poly.vertices)<=4
    return obj

def box(name,loc,size,mat,bone,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object
    o.scale=size
    finish(o,name,mat,bone)
    if bevel:
        mod=o.modifiers.new('Tailored edges','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def ell(name,loc,size,mat,bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=loc)
    o=bpy.context.object; o.scale=size
    return finish(o,name,mat,bone)

def cyl(name,loc,r,depth,mat,bone,scale=(1,1,1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth,location=loc)
    o=bpy.context.object; o.scale=scale
    return finish(o,name,mat,bone)

exec(compile((HERE/'geometry.py').read_text(), str(HERE/'geometry.py'), 'exec'))

# Deformation skeleton, with a root and articulated limbs.
bpy.ops.object.armature_add(enter_editmode=True)
rig=bpy.context.object; rig.name='Gunslinger_Rig'
rig.data.edit_bones.remove(rig.data.edit_bones[0])
def bone(name,a,b,parent=None):
    e=rig.data.edit_bones.new(name);e.head=a;e.tail=b
    if parent:e.parent=rig.data.edit_bones[parent]
bone('root',(0,0,0),(0,0,.3))
bone('pelvis',(0,0,1.08),(0,0,1.25),'root')
bone('spine',(0,0,1.25),(0,0,1.83),'pelvis')
bone('head',(0,0,1.83),(0,0,2.35),'spine')
for s in [-1,1]:
    k='L' if s==1 else 'R'
    bone('thigh.'+k,(s*.19,0,1.08),(s*.19,0,.62),'pelvis')
    bone('shin.'+k,(s*.19,0,.62),(s*.19,0,.22),'thigh.'+k)
    bone('foot.'+k,(s*.19,0,.22),(s*.19,-.28,.14),'shin.'+k)
    bone('upper_arm.'+k,(s*.36,0,1.74),(s*.51,0,1.38),'spine')
    bone('forearm.'+k,(s*.51,0,1.38),(s*.51,-.09,1.10),'upper_arm.'+k)
    bone('hand.'+k,(s*.51,-.09,1.10),(s*.51,-.09,.94),'forearm.'+k)
    bone('coat.'+k,(s*.245,.11,1.12),(s*.245,.11,.70),'pelvis')
bpy.ops.object.mode_set(mode='OBJECT')
for o,b in parts:
    g=o.vertex_groups.new(name=b);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Skeleton','ARMATURE');mod.object=rig
    o.parent=rig
rig.show_in_front=True
rig.animation_data_create()
scene=bpy.context.scene;scene.render.fps=30
clips={'idle':30,'run':20,'attack':12,'hit':10,'death':32,'reload':48}
for name,duration in clips.items():
    action=bpy.data.actions.new(name);action.use_fake_user=True
    rig.animation_data.action=action
    for f in range(duration+1):
        t=f/duration;phase=2*math.pi*t
        for p in rig.pose.bones:
            p.rotation_mode='XYZ';p.rotation_euler=(0,0,0);p.location=(0,0,0)
        def rot(b,x=0,y=0,z=0):rig.pose.bones[b].rotation_euler=(x,y,z)
        if name=='idle':
            rot('spine',.015*math.sin(phase));rot('head',0,.04*math.sin(phase),0)
        elif name=='run':
            rot('spine',.12)
            for sign,k in [(1,'L'),(-1,'R')]:
                swing=sign*math.sin(phase)
                rot('thigh.'+k,.65*swing);rot('shin.'+k,-.65*max(0,-swing))
                rot('upper_arm.'+k,-.4*swing);rot('forearm.'+k,.30)
                rot('coat.'+k,-.25-.20*swing)
        elif name=='attack':
            recoil=math.exp(-((t-.28)/.14)**2)
            rot('upper_arm.R',1.25-.16*recoil);rot('forearm.R',.18);rot('hand.R',-1.43+.10*recoil)
            rot('upper_arm.L',.88,0,.48);rot('forearm.L',.55)
            rot('spine',-.09*recoil);rot('head',.08)
        elif name=='hit':
            a=math.sin(math.pi*t);rot('spine',-.28*a,0,.13*a);rot('head',-.18*a)
        elif name=='death':
            ease=min(1,t*1.5);ease=ease*ease*(3-2*ease)
            rot('root',-math.pi/2*ease)
            rig.pose.bones['root'].location.y=.22*ease
            rig.pose.bones['root'].location.z=.24*ease
            rot('upper_arm.L',0,0,-.55*ease);rot('upper_arm.R',0,0,.4*ease)
            rot('thigh.L',.25*ease)
        elif name=='reload':
            a=math.sin(math.pi*t)
            rot('upper_arm.R',.85*a);rot('forearm.R',.5*a)
            rot('upper_arm.L',.55*a,0,.8*a);rot('forearm.L',.85*a)
            rot('head',.18*a)
        for p in rig.pose.bones:
            p.keyframe_insert('rotation_euler',frame=f+1,group=p.name)
            p.keyframe_insert('location',frame=f+1,group=p.name)
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action);track.mute=True
rig.animation_data.action=bpy.data.actions['idle']
scene.frame_start=1;scene.frame_end=31;scene.frame_set(1)

# Export only mesh + skeleton. NLA tracks retain six independent clips.
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o,_ in parts:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/characters/gunslinger/gunslinger.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')

def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(4,-7,4.1))
cam=bpy.context.object;aim(cam,(0,0,1.2));cam.data.type='ORTHO';cam.data.ortho_scale=4.2;scene.camera=cam
for loc,power,color,size in [((3,-4,6),650,(1,.83,.65),5),((-4,-2,4),500,(.55,.75,1),4),((1,4,5),800,(1,.5,.2),3)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.color=color;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,1.3))
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.world.color=(.16,.16,.16)
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.filepath=str(HERE/'preview/gunslinger.png')
scene.render.image_settings.color_depth='8'
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'source/gunslinger.blend'))
bpy.ops.render.render(write_still=True)
scene.render.resolution_x=128;scene.render.resolution_y=128
for name,duration in clips.items():
    rig.animation_data.action=bpy.data.actions[name]
    folder=HERE/'preview'/name;folder.mkdir(exist_ok=True)
    count=8 if name in ['run','death','reload'] else 6
    for i in range(count):
        frame=1+round(duration*i/(count if name in ['idle','run'] else count-1))
        scene.frame_set(frame)
        scene.render.filepath=str(folder/f'{i:02}.png')
        bpy.ops.render.render(write_still=True)
print('GUNSLINGER_BUILD_COMPLETE')
