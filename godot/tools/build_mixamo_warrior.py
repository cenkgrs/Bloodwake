"""Build the user-supplied knight and two-handed Mixamo clips with a rigid sword.
Run with Blender --background --threads 4 --python godot/tools/build_mixamo_warrior.py.
Original FBX files are preserved under art/warrior/source/.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/warrior/source'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
clips={'Idle':'Great Sword Idle','Run':'Great Sword Run','Attack':'Great Sword Slash','Hit':'Great Sword Impact','Death':'Two Handed Sword Death','Ultimate':'Warrior Ultimate'}
rig=None;actions={}
for name,filename in clips.items():
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=str(SRC/'mixamo'/(filename+'.fbx')))
 imported=set(bpy.data.objects)-before
 arm=next(o for o in imported if o.type=='ARMATURE')
 action=arm.animation_data.action;action.name=name;action.use_fake_user=True
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

 actions[name]=action
 if rig is None:
  rig=arm;body=next(o for o in imported if o.type=='MESH')
 else:
  assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones], 'Incompatible Mixamo skeleton'
  for o in imported:bpy.data.objects.remove(o,do_unlink=True)
# Mixamo exported this character in very small units; normalize the whole rig.
rig.name='WarriorRig';rig.scale*=1.8/.00835069
rig.animation_data.action=actions['Idle']
rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
# Remove planar root motion so game movement remains authoritative.
for action in actions.values():
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     if fc.data_path=='pose.bones["mixamorig:Hips"].location' and fc.array_index in (0,2):
      first=fc.keyframe_points[0].co.y
      for k in fc.keyframe_points:k.co.y=first;k.handle_left.y=first;k.handle_right.y=first

def material(folder,prefix):
 m=bpy.data.materials.new(prefix);m.use_nodes=True
 nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
 for suffix,socket in [('basecolor','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('normal','Normal')]:
  path=next((SRC/folder).glob('*.fbm/*_'+suffix+'.*'))
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
  # Game textures: retain the supplied sources, cap the embedded copies at 2K.
  if max(tex.image.size)>2048:tex.image.scale(2048,2048)
  tex.image.pack()
  if suffix!='basecolor':tex.image.colorspace_settings.name='Non-Color'
  if suffix=='normal':
   normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs[socket])
  else:links.new(tex.outputs['Color'],p.inputs[socket])
 return m
body.name='WarriorArmor';body.data.materials.clear();body.data.materials.append(material('knight','Knight PBR'))
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(next((SRC/'greatsword').glob('*.fbx'))))
sword=next(o for o in set(bpy.data.objects)-before if o.type=='MESH');sword.name='Greatsword'
sword.data.materials.clear();sword.data.materials.append(material('greatsword','Greatsword PBR'))
bpy.context.view_layer.objects.active=sword
bpy.ops.object.select_all(action='DESELECT');sword.select_set(True)
mod=sword.modifiers.new('Game mesh reduction','DECIMATE');mod.ratio=.008
bpy.ops.object.modifier_apply(modifier=mod.name)
# Align the supplied diagonal blade with the two hand grips in the idle pose.
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
r=rig.pose.bones['mixamorig:RightHand'];l=rig.pose.bones['mixamorig:LeftHand']
right=rig.matrix_world@(r.head+(r.tail-r.head)*.55)
left=rig.matrix_world@(l.head+(l.tail-l.head)*.55)
axis=(right-left).normalized();source_axis=Vector((-1,0,-1)).normalized()
rotation=source_axis.rotation_difference(axis).to_matrix().to_4x4()
placement=Matrix.Translation(right)@rotation@Matrix.Scale(1.3,4)@Matrix.Translation(Vector((-.19,0,-.69)))
# Bake vertices into rest-bone space, then bind rigidly to the right-hand bone.
rest=rig.data.bones[r.name].matrix_local
posed=r.matrix
convert=rest@posed.inverted()@rig.matrix_world.inverted()@placement@sword.matrix_world
for v in sword.data.vertices:v.co=convert@v.co
sword.matrix_world=rig.matrix_world.copy()
group=sword.vertex_groups.new(name=r.name);group.add(list(range(len(sword.data.vertices))),1,'REPLACE')
arm=sword.modifiers.new('Right hand attachment','ARMATURE');arm.object=rig
sword.parent=rig;sword.matrix_parent_inverse=Matrix.Identity(4);sword.matrix_basis=Matrix.Identity(4)
# Explicit NLA strips provide stable, separate named glTF clips.
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0]
 track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,body,sword]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
# Export each action without relying on object names imported from other FBXs.
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1.0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath='/tmp/warrior_review.blend')
print('WARRIOR_BUILD',len(body.data.vertices),len(sword.data.vertices),[(n,tuple(a.frame_range)) for n,a in actions.items()])
