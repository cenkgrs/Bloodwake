"""Replace armor only. Keep the working skeleton, sword and clips unchanged."""
import bpy
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/warrior_v2'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.fps=60
bpy.ops.import_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_player.glb'))
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.name='WarriorRig'
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
sword=bpy.data.objects['Greatsword']
old_body=next(o for o in scene.objects if o.type=='MESH' and o!=sword)
original_actions=list(bpy.data.actions)
before=set(scene.objects)
bpy.ops.import_scene.fbx(filepath=str(next((OUT/'source').glob('*.fbx'))))
incoming=set(scene.objects)-before
donor=next(o for o in incoming if o.type=='ARMATURE')
body=next(o for o in incoming if o.type=='MESH');body.name='WarriorArmorV2'
scene.render.fps=60
points=[body.matrix_world@v.co for v in body.data.vertices]
low,high=min(p.z for p in points),max(p.z for p in points)
normalize=Matrix.Scale(1.8/(high-low),4)@Matrix.Translation((0,0,-low))
body_world=normalize@body.matrix_world
donor_rest={b.name:normalize@donor.matrix_world@b.matrix_local for b in donor.data.bones}
rig_rest={b.name:rig.matrix_world@b.matrix_local for b in rig.data.bones}
maps={}
for name,rest in donor_rest.items():
 if name not in rig_rest:continue
 children=[b.name for b in donor.data.bones[name].children if b.name in rig_rest]
 # Bone roll is a file-format convention, not an anatomical rotation.
 # Align matching joints with the shortest arc, without twisting the skin.
 rotation=Matrix.Identity(4)
 if children:
  child=children[0]
  a=donor_rest[child].translation-rest.translation
  b=rig_rest[child].translation-rig_rest[name].translation
  if a.length>0.00001 and b.length>0.00001:
   rotation=a.rotation_difference(b).to_matrix().to_4x4()
 elif donor.data.bones[name].parent:
  parent=donor.data.bones[name].parent.name
  a=rest.translation-donor_rest[parent].translation
  b=rig_rest[name].translation-rig_rest[parent].translation
  if a.length>0.00001 and b.length>0.00001:rotation=a.rotation_difference(b).to_matrix().to_4x4()
 maps[name]=rig.matrix_world.inverted()@Matrix.Translation(rig_rest[name].translation)@rotation@Matrix.Translation(-rest.translation)
groups={g.index:g.name for g in body.vertex_groups}
# Fit the new skin into the ORIGINAL bind pose; never retarget animation keys.
for vertex in body.data.vertices:
 point=body_world@vertex.co
 weights=[(maps[groups[g.group]],g.weight) for g in vertex.groups if groups[g.group] in maps]
 total=sum(w for _,w in weights)
 vertex.co=sum((m@point*w for m,w in weights),Vector())/total if total else rig.matrix_world.inverted()@point
body.parent=rig;body.matrix_parent_inverse=Matrix.Identity(4);body.matrix_basis=Matrix.Identity(4)
for mod in body.modifiers:
 if mod.type=='ARMATURE':mod.object=rig
bpy.data.objects.remove(old_body,do_unlink=True)
for obj in incoming:
 if obj!=body:bpy.data.objects.remove(obj,do_unlink=True)
for image in bpy.data.images:
 if image.source=='FILE' and image.has_data:image.pack()
scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,body,sword]:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'warrior_animated.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_v2_player.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('ORIGINAL_RIG_PRESERVED',len(rig.data.bones),'CLIPS',[a.name for a in original_actions],flush=True)
