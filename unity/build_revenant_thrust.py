"""Retarget supplied Upward Thrust; open only right fingers, preserve source timing."""
import bpy, json, math, shutil
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'unity/Assets/Bloodwake/Resources/Animations/RevenantCombat';OUT.mkdir(parents=True,exist_ok=True)
REVIEW=ROOT/'art/revenant-noble/thrust-20261016';REVIEW.mkdir(parents=True,exist_ok=True)
source=Path('/home/cenkargevim/Downloads/Upward Thrust.fbx')
shutil.copy2(source,REVIEW/source.name)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'unity/Assets/Bloodwake/Resources/Models/revenant_noble/revenant_noble.fbx'),use_anim=False)
dst=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.type=='MESH')
dst.animation_data_clear()
for p in dst.pose.bones:p.matrix_basis.identity();p.rotation_mode='QUATERNION'
bpy.context.view_layer.update()
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(source))
fresh=set(bpy.data.objects)-before;src=next(o for o in fresh if o.type=='ARMATURE');action=src.animation_data.action
lo,hi=map(int,action.frame_range);fps=bpy.context.scene.render.fps/bpy.context.scene.render.fps_base
normalize=lambda n:n.split(':')[-1]
src_names={normalize(b.name):b.name for b in src.data.bones}
pairs=[(b.name,src_names[normalize(b.name)]) for b in dst.data.bones if normalize(b.name) in src_names]
pairs.sort(key=lambda pair:len(dst.data.bones[pair[0]].parent_recursive))
rs={d:src.matrix_world@src.data.bones[s].matrix_local for d,s in pairs};rd={d:dst.matrix_world@dst.data.bones[d].matrix_local for d,s in pairs}
offsets={}
for d,s in pairs:
 qs,qd=rs[d].to_quaternion(),rd[d].to_quaternion()
 align=(qd@Vector((0,1,0))).rotation_difference(qs@Vector((0,1,0)))
 offsets[d]=qs.inverted()@align@qd
hip=next(d for d,s in pairs if normalize(d)=='Hips');ratio=rd[hip].translation.z/rs[hip].translation.z
baked=bpy.data.actions.new('REV_ClawThrust');dst.animation_data_create();dst.animation_data.action=baked
frames=int(round((hi-lo)*60/fps))+1;previous={};extension=[];finger_changes=set()
for i in range(frames):
 f=lo+i*fps/60;bpy.context.scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
 # Preserve the wrist, elbow, shoulder and torso. Only release the sword grip.
 for p in src.pose.bones:
  if normalize(p.name).startswith('RightHand') and p.name.endswith(('1','2','3')) and any(digit in p.name for digit in ['Thumb','Index','Middle','Ring','Pinky']):
   p.rotation_mode='QUATERNION'
   p.rotation_quaternion=Quaternion().slerp(p.rotation_quaternion,.22 if 'Thumb' in p.name else .12)
   finger_changes.add(p.name)
 bpy.context.view_layer.update()
 for p in dst.pose.bones:p.matrix_basis.identity()
 bpy.context.view_layer.update()
 for d,s in pairs:
  p=dst.pose.bones[d];world=src.matrix_world@src.pose.bones[s].matrix
  q=world.to_quaternion()@rs[d].to_quaternion().inverted()@rd[d].to_quaternion() if normalize(d) in ['Hips','Spine','Spine1','Spine2','Neck','Head'] else world.to_quaternion()@offsets[d]
  # World-space rotation alone discards the production rig's 1.800879 scale,
  # baking a 0.555 hip scale into the clip. Retain the bind-space scale.
  m=Matrix.LocRotScale((dst.matrix_world@p.matrix).translation,q,rd[d].to_scale())
  if d==hip:m.translation=rd[d].translation+Vector((0,0,(world.translation.z-rs[d].translation.z)*ratio))
  p.matrix=dst.matrix_world.inverted()@m;bpy.context.view_layer.update()
 for p in dst.pose.bones:
  q=p.rotation_quaternion.copy()
  if p.name in previous and q.dot(previous[p.name])<0:q.negate()
  assert max(abs(v-1) for v in p.scale)<.0001,(p.name,list(p.scale))
  p.scale=(1,1,1)
  p.rotation_quaternion=q;previous[p.name]=q.copy();p.keyframe_insert('rotation_quaternion',frame=i+1)
  if p.name==hip:p.keyframe_insert('location',frame=i+1)
 hand=next(p for p in dst.pose.bones if normalize(p.name)=='RightHand')
 extension.append(-(dst.matrix_world@hand.head).y)
assert len(finger_changes)==15,len(finger_changes)
for curve in baked.fcurves:
 for key in curve.keyframe_points:key.interpolation='LINEAR'
# Keep the forward arm stroke readable; remove only the initial idle preparation.
trim_frames=6
peak=max(extension[trim_frames:]);contact=(next(i for i,x in enumerate(extension) if i>=trim_frames and x>=peak*.96)-trim_frames)/60
for curve in baked.fcurves:
 for key in list(curve.keyframe_points):
  if key.co.x<trim_frames+1:curve.keyframe_points.remove(key,fast=True)
 for key in curve.keyframe_points:
  key.co.x-=trim_frames;key.handle_left.x-=trim_frames;key.handle_right.x-=trim_frames
 curve.update()
frames-=trim_frames
for obj in fresh:bpy.data.objects.remove(obj,do_unlink=True)
for a in list(bpy.data.actions):
 if a!=baked:bpy.data.actions.remove(a)
dst.animation_data.action=baked;dst.animation_data.action_slot=baked.slots[0]
for slot in baked.slots:slot.identifier='OB'+dst.name
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=frames
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');dst.select_set(True);bpy.context.view_layer.objects.active=dst
bpy.ops.export_scene.fbx(filepath=str(OUT/'REV_ClawThrust.fbx'),use_selection=True,object_types={'ARMATURE'},add_leaf_bones=False,
 bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y')
report={'source':str(source),'source_fps':fps,'source_frames':[lo,hi],'trim_start_seconds':trim_frames/60,'duration':(frames-1)/60,'contact':contact,'peak_hand_extension':peak,'bone_scale_validated':True,
 'finger_only_edit':sorted(finger_changes),'grip_retained':.12,'thumb_grip_retained':.22,'root_motion':'planar hips fixed; original vertical and body rotations retained','target':'actual in-game noble skeleton'}
(OUT/'thrust.json').write_text(json.dumps(report,indent=2));(REVIEW/'report.json').write_text(json.dumps(report,indent=2))
# Render the actual game mesh with the retargeted contact pose and opened claw.
mat=bpy.data.materials.new('Original Noble 8K');mat.use_nodes=True
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'unity/Assets/Bloodwake/Resources/Models/revenant_noble/Noble_BaseColor_8K.jpg'))
mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.6
body.data.materials.clear();body.data.materials.append(mat)
scene=bpy.context.scene;scene.frame_set(round(contact*60)+1)
bpy.ops.wm.save_as_mainfile(filepath=str(REVIEW/'Revenant_ClawThrust.blend'))
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.1,.11,.13,1)
for loc,power in [((2,-3,4),500),((-2,-1,2),300),((0,3,3),450)]:
 bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.size=3
 light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-3,-4,2.3));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.4;scene.camera=cam
scene.render.filepath=str(REVIEW/'contact.png');bpy.ops.render.render(write_still=True)
hand=next(p for p in dst.pose.bones if normalize(p.name)=='RightHand');at=dst.matrix_world@hand.head
cam.location=at+Vector((-.35,-.55,.35));cam.rotation_euler=(at-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.6
scene.render.filepath=str(REVIEW/'claw.png');bpy.ops.render.render(write_still=True)
print('THRUST_BAKED',json.dumps(report))
