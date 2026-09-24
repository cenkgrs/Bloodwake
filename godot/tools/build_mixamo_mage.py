"""Build the supplied unarmed Mage and six Mixamo clips locally in Blender."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/mage/source'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rig=None;actions={}
for name,filename in {'Idle':'idle','Run':'walk','Attack':'attack','Hit':'hit','Death':'death','Ultimate':'ulti'}.items():
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=str(SRC/'mixamo'/('mage '+filename+'.fbx')))
 imported=set(bpy.data.objects)-before
 arm=next(o for o in imported if o.type=='ARMATURE')
 action=arm.animation_data.action;action.name=name;action.use_fake_user=True;actions[name]=action
 # FBX imports can change the scene FPS (these packs mix 30 and 60 FPS).
 # Convert keys to a common 60 FPS timeline before importing the next file.
 source_fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
 ratio=60.0/source_fps
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for key in fc.keyframe_points:
      key.co.x=1+(key.co.x-1)*ratio
      key.handle_left.x=1+(key.handle_left.x-1)*ratio
      key.handle_right.x=1+(key.handle_right.x-1)*ratio

 print('SOURCE_CLIP',name,tuple(action.frame_range),'fps',bpy.context.scene.render.fps)
 if rig is None:
  rig=arm;meshes=[o for o in imported if o.type=='MESH']
 else:
  assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones], 'Incompatible Mixamo skeleton'
  for o in imported:bpy.data.objects.remove(o,do_unlink=True)
rig.name='MageRig'
# Remove planar travel from every clip; movement belongs to the game controller.
for action in actions.values():
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     if fc.data_path=='pose.bones["mixamorig:Hips"].location' and fc.array_index in (0,2):
      value=fc.keyframe_points[0].co.y
      for k in fc.keyframe_points:k.co.y=value;k.handle_left.y=value;k.handle_right.y=value
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
def bounds():
 deps=bpy.context.evaluated_depsgraph_get()
 points=[o.matrix_world@v.co for mesh in meshes for o in [mesh.evaluated_get(deps)] for v in o.data.vertices]
 return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
lo,hi=bounds();rig.scale*=1.8/(hi.z-lo.z);bpy.context.view_layer.update();lo,hi=bounds()
rig.location-=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));bpy.context.view_layer.update()
mat=bpy.data.materials.new('Mage PBR');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
textures=next((SRC/'model').glob('*.fbm'))
for pattern,socket in [('Color.jpg','Base Color'),('*roughness*','Roughness'),('*metallic*','Metallic'),('Normal.png','Normal')]:
 path=next(textures.glob(pattern));tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
 if max(tex.image.size)>2048:tex.image.scale(2048,2048)
 tex.image.pack()
 if socket!='Base Color':tex.image.colorspace_settings.name='Non-Color'
 if socket=='Normal':
  normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
 else:links.new(tex.outputs['Color'],p.inputs[socket])
for i,mesh in enumerate(meshes):
 mesh.name='MageBody' if i==0 else 'MageBody'+str(i);mesh.data.materials.clear();mesh.data.materials.append(mat)
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,*meshes]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1.0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/mage_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath='/tmp/mage_review.blend')
print('MAGE_BUILD',sum(len(m.data.vertices) for m in meshes),'vertices',bounds())
