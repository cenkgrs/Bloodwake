"""Retarget the supplied knight; preserve original assets."""
import bpy, math, json
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/warrior_v2'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.fps=60
bpy.ops.import_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_player.glb'))
source=next(o for o in scene.objects if o.type=='ARMATURE')
source.name='SourceRig';source_objects=set(scene.objects);actions=list(bpy.data.actions)
for track in source.animation_data.nla_tracks:track.mute=True
source.animation_data.action=None
source_rest={b.name:source.matrix_world@b.matrix_local for b in source.data.bones}
sword=bpy.data.objects['Greatsword'];sword_world=sword.matrix_world.copy()
before=set(scene.objects)
bpy.ops.import_scene.fbx(filepath=str(next((OUT/'source').glob('*.fbx'))))
target=next(o for o in set(scene.objects)-before if o.type=='ARMATURE')
body=next(o for o in set(scene.objects)-before if o.type=='MESH')
scene.render.fps=60;target.name='WarriorRig';body.name='WarriorArmorV2'
points=[body.matrix_world@v.co for v in body.data.vertices]
low,high=min(p.z for p in points),max(p.z for p in points)
normalise=Matrix.Scale(1.8/(high-low),4)@Matrix.Translation((0,0,-low))
body.data.transform(normalise@body.matrix_world);body.parent=None;body.matrix_world=Matrix.Identity(4)
target.data.transform(normalise@target.matrix_world);target.matrix_world=Matrix.Identity(4)
body.parent=target;body.matrix_parent_inverse=Matrix.Identity(4)
for mod in body.modifiers:
 if mod.type=='ARMATURE':mod.object=target
for image in bpy.data.images:
 if image.source=='FILE' and image.has_data:image.pack()
hand='mixamorig:RightHand'
hand_map=target.data.bones[hand].matrix_local@source_rest[hand].inverted()
sword.data.transform(hand_map@sword_world);sword.parent=target
sword.matrix_parent_inverse=Matrix.Identity(4);sword.matrix_world=Matrix.Identity(4)
for mod in sword.modifiers:
 if mod.type=='ARMATURE':mod.object=target

# Rear red cloth only: remove accidental leg influences and use a cape chain.
import numpy as np
image=next(n.image for m in body.data.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
w,h=image.size;pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels);pixels=pixels.reshape(h,w,4)
uvs=body.data.uv_layers.active.data;cape_vertices=set()
for poly in body.data.polygons:
 center=sum((body.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
 if center.y<0.015 or center.z>1.48:continue
 uv=sum((uvs[i].uv for i in poly.loop_indices),Vector((0,0)))/len(poly.loop_indices)
 r,g,b=pixels[int(uv.y*h)%h,int(uv.x*w)%w,:3]
 # The cape lining is nearly black, so color-only selection leaves its back
 # surface attached to the arms. Include the whole rear garment envelope.
 if center.y>0.075 or (r>0.06 and r>g*1.55 and r>b*1.4):cape_vertices.update(poly.vertices)
print('CAPE_VERTICES',len(cape_vertices),flush=True)
bpy.context.view_layer.objects.active=target;bpy.ops.object.mode_set(mode='EDIT')
parent=target.data.edit_bones['mixamorig:Spine2']
for i in range(3):
 bone=target.data.edit_bones.new('Cape_%d'%i)
 bone.head=(0,0.12+i*.02,1.45-i*.32);bone.tail=(0,0.14+i*.02,1.13-i*.32);bone.parent=parent;parent=bone
bpy.ops.object.mode_set(mode='OBJECT')
groups=[body.vertex_groups.new(name='Cape_%d'%i) for i in range(3)]
for index in cape_vertices:
 vertex=body.data.vertices[index]
 for group in body.vertex_groups:group.remove([index])
 t=max(0.0,min(2.0,(1.45-vertex.co.z)/.32));a=int(t);b=min(2,a+1);fraction=t-a
 groups[a].add([index],1-fraction,'REPLACE')
 if b!=a and fraction>0:groups[b].add([index],fraction,'REPLACE')

target.animation_data_create()
matched=[b for b in target.pose.bones if b.name in source_rest]
target_rest={b.name:b.matrix_local.copy() for b in target.data.bones}
root_name='mixamorig:Hips'
ratio=target_rest[root_name].translation.z/source_rest[root_name].translation.z
baked=[];report={}
for old in actions:
 name=old.name;old.name='SOURCE_'+name
 source.animation_data.action=old;source.animation_data.action_slot=old.slots[0]
 new=bpy.data.actions.new(name);target.animation_data.action=new
 start,end=old.frame_range;count=int(math.ceil(end-start))
 for frame in range(count+1):
  time=min(start+frame,end);scene.frame_set(int(time),subframe=time-int(time));bpy.context.view_layer.update()
  for bone in matched:
   rest=target_rest[bone.name];src_pose=source.matrix_world@source.pose.bones[bone.name].matrix
   delta=src_pose.to_quaternion()@source_rest[bone.name].to_quaternion().inverted()
   desired=(delta@rest.to_quaternion()).to_matrix().to_4x4()
   if bone.parent:desired.translation=bone.parent.matrix@(target_rest[bone.parent.name].inverted()@rest.translation)
   else:desired.translation=rest.translation+(src_pose.translation-source_rest[bone.name].translation)*ratio
   bone.matrix=desired;bpy.context.view_layer.update()
  if name!='Death':
   floor=min(target.pose.bones['mixamorig:'+n].head.z for n in ['LeftToeBase','RightToeBase','LeftFoot','RightFoot'])
   if floor<0.035:
    matrix=target.pose.bones[root_name].matrix.copy();matrix.translation.z+=0.035-floor;target.pose.bones[root_name].matrix=matrix
  for i in range(3):
   bone=target.pose.bones['Cape_%d'%i];bone.rotation_mode='XYZ'
   phase=2*math.pi*frame/max(1,count)
   bone.rotation_euler=(0.06+(0.07 if name=='Run' else 0.018)*math.sin(phase+i*.65),0,0)
   if i==0 and name!='Death':
    # Follow the shoulder attachment, but let gravity keep the cloth down
    # instead of inheriting the combat stance's forward lean and torso twist.
    rest=target_rest[bone.name]
    matrix=rest.copy()
    matrix.translation=bone.parent.matrix@(target_rest[bone.parent.name].inverted()@rest.translation)
    bone.matrix=matrix
   bpy.context.view_layer.update()
  for bone in target.pose.bones:
   if bone.name.startswith('Cape_'):
    bone.keyframe_insert('rotation_euler',frame=time-start)
    bone.keyframe_insert('location',frame=time-start)
   else:
    bone.rotation_mode='QUATERNION';bone.keyframe_insert('rotation_quaternion',frame=time-start);bone.keyframe_insert('location',frame=time-start)
 new.use_fake_user=True;baked.append(new);report[name]={'seconds':(end-start)/60,'frames':count+1}
 print('RETARGET',name,report[name],flush=True)
target.animation_data.action=None
for old in actions:old.use_fake_user=False
for obj in source_objects:
 if obj!=sword:bpy.data.objects.remove(obj,do_unlink=True)
for old in actions:
 if old.users==0:bpy.data.actions.remove(old)
for action in baked:
 track=target.animation_data.nla_tracks.new();track.name=action.name
 strip=track.strips.new(action.name,0,action);strip.action_slot=action.slots[0];track.mute=True
scene.frame_set(0);bpy.ops.object.select_all(action='DESELECT')
for obj in [target,body,sword]:obj.select_set(True)
bpy.context.view_layer.objects.active=target
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'warrior_animated.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_v2_player.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
print('BUILD_REPORT',json.dumps(report),flush=True)
