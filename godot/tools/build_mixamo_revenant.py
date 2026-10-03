"""Build Revenant from its own Mixamo-rigged FBXs and original Tripo materials.
Run: blender -b -t 4 --python godot/tools/build_mixamo_revenant.py
"""
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/revenant/source'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Import the original material graph, preserving roughness and normal maps.
bpy.ops.import_scene.gltf(filepath=str(SRC/'revenant_original.glb'))
original=next(o for o in bpy.context.scene.objects if o.type=='MESH')
material=original.data.materials[0];material.name='Revenant PBR';material.use_fake_user=True
for node in material.node_tree.nodes:
 if node.type=='TEX_IMAGE' and node.image:
  if max(node.image.size)>2048:node.image.scale(2048,2048)
  node.image.pack()
for obj in list(bpy.context.scene.objects):bpy.data.objects.remove(obj,do_unlink=True)
clips={'Idle':('Mutant Breathing Idle',None),'Run':('Mutant Run',None),
 'Attack1':('Mutant Swiping',(29,61)),'Attack2':('Mutant Punch',(5,29)),
 'Dash':('Dodging',(1,26)),'Hit':('Standing React Small From Front',(1,22)),
 'Death':('Mutant Dying',None)}
rig=None;meshes=[];actions={}
for name,(source,span) in clips.items():
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=str(SRC/'mixamo'/(source+'.fbx')))
 imported=set(bpy.data.objects)-before
 arm=next(o for o in imported if o.type=='ARMATURE')
 act=arm.animation_data.action;act.name=name;act.use_fake_user=True
 fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
 start,end=span or act.frame_range
 # Bake the selected interval to a uniform 30 fps timeline.
 for layer in act.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     samples=[(1+(f-start)*30/fps,fc.evaluate(f)) for f in range(int(start),int(end)+1)]
     fc.keyframe_points.clear()
     for frame,value in samples:fc.keyframe_points.insert(frame,value,options={'FAST'})
     fc.update()
 actions[name]=act
 if rig is None:
  rig=arm;meshes=[o for o in imported if o.type=='MESH']
 else:
  assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones]
  for obj in imported:bpy.data.objects.remove(obj,do_unlink=True)
rig.name='RevenantRig'
# Pin all clips to the idle root in the two horizontal axes. Keep vertical bob.
def curves(action):
 return [fc for layer in action.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
root_path='pose.bones["mixamorig:Hips"].location'
anchor={fc.array_index:fc.evaluate(1) for fc in curves(actions['Idle']) if fc.data_path==root_path}
for action in actions.values():
 for fc in curves(action):
  if fc.data_path==root_path and fc.array_index in (0,2):
   for key in fc.keyframe_points:key.co.y=anchor[fc.array_index];key.handle_left.y=key.co.y;key.handle_right.y=key.co.y
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
def bounds():
 deps=bpy.context.evaluated_depsgraph_get()
 pts=[o.matrix_world@v.co for mesh in meshes for o in [mesh.evaluated_get(deps)] for v in o.data.vertices]
 return Vector(tuple(min(v[i] for v in pts) for i in range(3))),Vector(tuple(max(v[i] for v in pts) for i in range(3)))
lo,hi=bounds();rig.scale*=1.8/(hi.z-lo.z);bpy.context.view_layer.update();lo,hi=bounds()
rig.location-=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));bpy.context.view_layer.update()
for i,m in enumerate(meshes):
 m.name='RevenantBody'+str(i);m.data.materials.clear();m.data.materials.append(material)
 # Keep the supplied skin weights; reduce the dense body for runtime only.
 bpy.context.view_layer.objects.active=m
 mod=m.modifiers.new('Runtime reduction','DECIMATE');mod.ratio=0.40
 bpy.ops.object.modifier_apply(modifier=mod.name)
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,*meshes]:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.scene.render.fps=30;bpy.context.scene.render.fps_base=1.0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/revenant_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
print('REVENANT_BUILD',len(rig.data.bones),'bones',list(actions),bounds())
