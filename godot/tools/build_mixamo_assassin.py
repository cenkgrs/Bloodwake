"""Build the supplied Assassin and five Mixamo clips with twin rigid daggers.
Run with Blender --background --threads 4 --python godot/tools/build_mixamo_assassin.py.
Original FBX files are preserved under art/assassin/source/. No "Hit" clip was
supplied; the game falls back to a timer-only stun (no animation swap) for it.
"""
import bpy
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/assassin/source'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rig=None;actions={};meshes=[]
for name,filename in {'Idle':'idle','Run':'run','Attack':'attack','Death':'death','Ultimate':'ulti'}.items():
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=str(SRC/'mixamo'/('assassin '+filename+'.fbx')))
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
  assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones],'Incompatible Mixamo skeleton'
  for o in imported:bpy.data.objects.remove(o,do_unlink=True)
rig.name='AssassinRig'
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

def material(name,folder,color_pattern='Color.jpg'):
 mat=bpy.data.materials.new(name);mat.use_nodes=True
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
 textures=next((SRC/folder).glob('*.fbm'))
 for pattern,socket in [(color_pattern,'Base Color'),('*roughness*','Roughness'),('*metallic*','Metallic'),('Normal.png','Normal')]:
  path=next(textures.glob(pattern));tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
  if max(tex.image.size)>2048:tex.image.scale(2048,2048)
  tex.image.pack()
  if socket!='Base Color':tex.image.colorspace_settings.name='Non-Color'
  if socket=='Normal':
   normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
  else:links.new(tex.outputs['Color'],p.inputs[socket])
 return mat

body_mat=material('Assassin PBR','model')
for i,mesh in enumerate(meshes):
 mesh.name='AssassinBody' if i==0 else 'AssassinBody'+str(i);mesh.data.materials.clear();mesh.data.materials.append(body_mat)

# ---- twin daggers, rigidly bound one per hand ----
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(next((SRC/'dagger').glob('*.fbx'))))
dagger_src=next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
dagger_mat=material('Dagger PBR','dagger')
bpy.context.view_layer.objects.active=dagger_src
bpy.ops.object.select_all(action='DESELECT');dagger_src.select_set(True)
mod=dagger_src.modifiers.new('Game mesh reduction','DECIMATE');mod.ratio=.12
bpy.ops.object.modifier_apply(modifier=mod.name)
dagger_src.data.materials.clear();dagger_src.data.materials.append(dagger_mat)
# The source dagger's mesh axes are NOT aligned with local X/Y/Z (it sits at a
# diagonal in the file). Found the true blade axis and the wrapped-grip cylinder
# by PCA + visual inspection (see godot/tools/build_mixamo_assassin_notes.md):
# the long axis runs diagonally through local X and Z, the blade tip is at one
# extreme, the pommel spike at the other, and the actual hand-grip cylinder
# (not the pommel tip - an earlier build anchored the pommel tip and the blade
# ended up sticking out the wrong way) sits at ~78% of the way from blade tip
# to pommel tip.
dagger_pts=np.array([v.co[:] for v in dagger_src.data.vertices])
d_mean=dagger_pts.mean(axis=0);d_centered=dagger_pts-d_mean
eigvals,eigvecs=np.linalg.eigh(np.cov(d_centered.T))
order=np.argsort(eigvals)[::-1]
d_long=Vector(eigvecs[:,order[0]]).normalized();d_thick=Vector(eigvecs[:,order[2]]).normalized()
if d_long.z<0:d_long=-d_long
d_mean_v=Vector(d_mean)
d_proj=[(Vector(p)-d_mean_v).dot(d_long) for p in dagger_pts]
tip_local=d_mean_v+d_long*min(d_proj)      # blade tip: local-axis extreme closest to the blade
pommel_local=d_mean_v+d_long*max(d_proj)   # pommel spike: opposite extreme
GRIP_FRAC=0.78
grip_local=tip_local+(pommel_local-tip_local)*GRIP_FRAC
blade_dir_local=(tip_local-grip_local).normalized()
side_dir_local=blade_dir_local.cross(d_thick).normalized()
up_dir_local=blade_dir_local.cross(side_dir_local).normalized()
local_basis=Matrix((side_dir_local,up_dir_local,blade_dir_local)).transposed()
TARGET_LEN=.34;DSCALE=TARGET_LEN/(pommel_local-tip_local).length

bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
weapons=[]
for side,bone_name,mirror in [('Right','mixamorig:RightHand',1),('Left','mixamorig:LeftHand',-1)]:
 bone=rig.pose.bones[bone_name]
 dup=dagger_src.copy();dup.data=dagger_src.data.copy();dup.name='Dagger'+side;bpy.context.collection.objects.link(dup)
 # Grip point and hand-local axes in world space at the rest/idle pose.
 grip=rig.matrix_world@(bone.head+(bone.tail-bone.head)*.35)
 hand_forward=(rig.matrix_world.to_3x3()@(bone.tail-bone.head)).normalized()
 hand_side=(rig.matrix_world.to_3x3()@Vector((mirror,0,0))).normalized()
 hand_up=hand_forward.cross(hand_side).normalized()
 # Map the dagger's own (side,up,blade) basis onto the hand's (side,up,forward)
 # basis - a proper rotation between two right-handed orthonormal frames, so
 # winding/normals stay intact (no single-axis flip).
 hand_basis=Matrix((hand_side,hand_up,hand_forward)).transposed()
 rotation=(hand_basis@local_basis.transposed()).to_4x4()
 placement=Matrix.Translation(grip)@rotation@Matrix.Scale(DSCALE,4)@Matrix.Translation(-grip_local)
 rest=rig.data.bones[bone.name].matrix_local;posed=bone.matrix
 convert=rest@posed.inverted()@rig.matrix_world.inverted()@placement
 for v in dup.data.vertices:v.co=convert@v.co
 dup.matrix_world=rig.matrix_world.copy()
 group=dup.vertex_groups.new(name=bone.name);group.add(list(range(len(dup.data.vertices))),1,'REPLACE')
 arm_mod=dup.modifiers.new(side+' hand attachment','ARMATURE');arm_mod.object=rig
 dup.parent=rig;dup.matrix_parent_inverse=Matrix.Identity(4);dup.matrix_basis=Matrix.Identity(4)
 weapons.append(dup)
bpy.data.objects.remove(dagger_src,do_unlink=True)

# Explicit NLA strips provide stable, separate named glTF clips.
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,*meshes,*weapons]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1.0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/assassin_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0];bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath='/tmp/assassin_review.blend')
print('ASSASSIN_BUILD',sum(len(m.data.vertices) for m in meshes),'body verts',sum(len(w.data.vertices) for w in weapons),'dagger verts x2',bounds())
