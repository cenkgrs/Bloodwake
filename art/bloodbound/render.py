"""Import user animation GLB, normalize names, render fixed-camera frames.
blender -b --python art/bloodbound/render.py [-- --preview]
"""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
preview='--preview' in sys.argv
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(HERE/'source/bloodbound_animated.glb'))
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
for o in list(scene.objects):
    if o.type=='MESH' and o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
for track in rig.animation_data.nla_tracks:track.mute=True
for a in bpy.data.actions:
    if a.name.startswith('Create a short hit'):a.name='hit'
    if a.name=='fall':a.name='death'
    if a.name.startswith('Create a short rifle'):a.name='attack'
actions={a.name:a for a in bpy.data.actions}
assert set(actions)=={'idle','run','hit','death','attack'}

def pose(name,frame):
    rig.animation_data.action=actions[name]
    rig.animation_data.action_slot=actions[name].slots[0]
    scene.frame_set(int(frame),subframe=frame-int(frame))
    bpy.context.view_layer.update()

rig.animation_data.action=actions['idle'];rig.animation_data.action_slot=actions['idle'].slots[0];scene.frame_set(0)
hip=rig.pose.bones['mixamorig:Hips']
# Convert each keyed local translation through the rest-bone basis, flatten
# world-horizontal travel, then convert back. Preserve vertical footfall.
rest=rig.data.bones[hip.name].matrix_local
origin=hip.matrix.translation.copy()
for clip_name in ('run','death'):
    a=actions[clip_name]
    for layer in a.layers:
        for strip in layer.strips:
            bag=strip.channelbag(a.slots[0])
            curves={fc.array_index:fc for fc in bag.fcurves if fc.data_path=='pose.bones["mixamorig:Hips"].location'}
            keys=sorted({kp.co.x for fc in curves.values() for kp in fc.keyframe_points})
            values={}
            for f in keys:
                p=rest@Vector(tuple(curves[i].evaluate(f) for i in range(3)))
                p.x=origin.x;p.y=origin.y
                values[f]=rest.inverted()@p
            for i,fc in curves.items():
                for kp in fc.keyframe_points:
                    delta=values[kp.co.x][i]-kp.co.y
                    kp.co.y+=delta;kp.handle_left.y+=delta;kp.handle_right.y+=delta

def vertices():
    dg=bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        evaluated=o.evaluated_get(dg)
        for v in evaluated.data.vertices:yield evaluated.matrix_world@v.co
pts=list(vertices());lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
height=hi.z-lo.z
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z+height*.49))
bpy.ops.object.camera_add(location=center+Vector((-4,-7,5)).normalized()*height*5)
cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';scene.camera=cam
# Fit one consistent camera to every sampled pose, including death.
max_extent=0
for name,a in actions.items():
    start,end=a.frame_range
    clip_extent=0
    for i in range(17):
        pose(name,start+(end-start)*i/16)
        inv=cam.matrix_world.inverted()
        for p in vertices():
            q=inv@p;max_extent=max(max_extent,abs(q.x),abs(q.y));clip_extent=max(clip_extent,abs(q.x),abs(q.y))
    print('CLIP_EXTENT',name,clip_extent,flush=True)
print('CAMERA_FIT',height,max_extent)
cam.data.ortho_scale=max_extent*2.16

def aim(o):o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
for loc,power,color in [((-3,-4,6),500,(1,.9,.8)),((4,-2,3),350,(.7,.82,1)),((1,3,5),600,(1,.65,.45))]:
    bpy.ops.object.light_add(type='AREA',location=center+Vector(loc)*height*.65)
    o=bpy.context.object;o.data.energy=power*height*height;o.data.shape='DISK';o.data.size=height*3;aim(o)
scene.world.color=(.2,.2,.2)
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
metadata={}
for name,a in actions.items():
    start,end=map(float,a.frame_range);duration=(end-start)/scene.render.fps
    rate={'idle':12,'run':16,'hit':24,'death':16,'attack':24}[name]
    count=8 if preview else max(2,math.ceil(duration*rate))
    loop=name in ('idle','run')
    metadata[name]={'frames':count,'duration':duration,'stepTime':duration/count,'loop':loop,'sourceFrames':[start,end]}
    folder=HERE/('review' if preview else 'frames')/name;folder.mkdir(parents=True,exist_ok=True)
    for i in range(count):
        f=start+(end-start)*i/(count if loop else count-1)
        output=folder/f'{i:03}.png'
        if not preview and output.exists(): continue
        pose(name,f);scene.render.filepath=str(output);bpy.ops.render.render(write_still=True)
(HERE/('review' if preview else 'frames')/'animations.json').write_text(json.dumps(metadata,indent=2))
if not preview:
    pose('idle',0)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for mesh in meshes:mesh.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(HERE/'source/bloodbound_game.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'source/bloodbound_render.blend'))
print('BLOODBOUND_RENDER_COMPLETE',metadata)
