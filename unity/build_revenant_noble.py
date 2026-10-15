"""Local-only import of user-supplied noble Revenant + six Mixamo clips.
Keeps source mesh/UV/texture; retargets old attacks provisionally, never edits sources.
Run: blender -b -t 2 --python unity/build_revenant_noble.py
"""
import bpy,json,math,statistics,shutil,subprocess
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'art/revenant-noble/source-20261015'
OUT=ROOT/'unity/Assets/Bloodwake/Resources/Models/revenant_noble';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(SRC/'Idle.fbx'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=next(o for o in bpy.data.objects if o.type=='MESH')
rig.name='RevenantNobleRig';body.name='RevenantNobleBody'
rig.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
for p in rig.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
coords=[body.matrix_world@v.co for v in body.data.vertices];height=max(p.z for p in coords)-min(p.z for p in coords)
rig.scale*=1.8/height;bpy.context.view_layer.update()
actions={};report={'source_triangles':len(body.data.polygons),'source_height':height,'normalized_height':1.8,'clips':{}}
for filename,name in [('Idle','REV_NeutralIdle'),('Run','REV_StandardRun'),('Sneak Walk','REV_SwaggerWalk'),('Dying','REV_Death'),('Standing 2H Magic Attack 05','REV_BloodClap'),('Standing 2H Magic Area Attack 02','REV_BloodBurst')]:
 before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(SRC/(filename+'.fbx')))
 fresh=set(bpy.data.objects)-before;src=next(o for o in fresh if o.type=='ARMATURE');a=src.animation_data.action
 assert [b.name for b in rig.data.bones]==[b.name for b in src.data.bones],filename
 a.name=name;a.use_fake_user=True
 for fc in a.fcurves:
  if fc.data_path=='pose.bones["mixamorig:Hips"].location' and fc.array_index in (0,2):
   # Controller owns planar travel; preserve authored vertical body motion.
   first=fc.keyframe_points[0].co.y
   for k in fc.keyframe_points:k.co.y=k.handle_left.y=k.handle_right.y=first
 actions[name]=a
 report['clips'][name]={'source':filename+'.fbx','frames':list(a.frame_range),'fps':60,'temporary':False}
 for obj in fresh:bpy.data.objects.remove(obj,do_unlink=True)

# Retain the existing combat kit as a temporary fallback on the new proportions.
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(ROOT/'unity/Assets/Bloodwake/Resources/Models/revenant_player/revenant_player.fbx'))
fresh=set(bpy.data.objects)-before;src=next(o for o in fresh if o.type=='ARMATURE')
mapping={'pelvis':'Hips','spine_01':'Spine','spine_02':'Spine1','spine_03':'Spine2','neck_01':'Neck','head':'Head'}
for side,label in [('l','Left'),('r','Right')]:
 for a,b in [('clavicle','Shoulder'),('upperarm','Arm'),('lowerarm','ForeArm'),('hand','Hand'),('thigh','UpLeg'),('calf','Leg'),('foot','Foot'),('ball','ToeBase')]:mapping[a+'_'+side]=label+b
 for finger in ['Thumb','Index','Middle','Ring','Pinky']:
  for i in range(1,4):mapping[finger.lower()+'_%02d_'%i+side]=label+'Hand'+finger+str(i)
pairs=[('mixamorig:'+v,k) for k,v in mapping.items() if k in src.data.bones and 'mixamorig:'+v in rig.data.bones]
# Parents must be placed before their descendants.
pairs.sort(key=lambda pair:len(rig.data.bones[pair[0]].parent_recursive))
rs={d:src.matrix_world@src.data.bones[s].matrix_local for d,s in pairs};rd={d:rig.matrix_world@rig.data.bones[d].matrix_local for d,s in pairs}
offset={}
for d,s in pairs:
 qs,qd=rs[d].to_quaternion(),rd[d].to_quaternion();align=(qd@Vector((0,1,0))).rotation_difference(qs@Vector((0,1,0)));offset[d]=qs.inverted()@align@qd
ratio=rd['mixamorig:Hips'].translation.z/rs['mixamorig:Hips'].translation.z
for name in ['REV_ClawAttack_1','REV_ClawAttack_2','REV_ClawAttack_3','REV_TeleportAttack','REV_HitLight_Front']:
 a=next(a for a in bpy.data.actions if a.name.split('|')[-1]==name);src.animation_data.action=a;src.animation_data.action_slot=a.slots[0]
 lo,hi=map(int,a.frame_range);rig.animation_data_clear();rig.animation_data_create();baked=bpy.data.actions.new(name);rig.animation_data.action=baked;previous={}
 for f in range(lo,hi+1):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
  for p in rig.pose.bones:p.matrix_basis.identity();p.rotation_mode='QUATERNION'
  bpy.context.view_layer.update()
  for d,s in pairs:
   p=rig.pose.bones[d];world=src.matrix_world@src.pose.bones[s].matrix
   q=world.to_quaternion()@rs[d].to_quaternion().inverted()@rd[d].to_quaternion() if s in ('pelvis','spine_01','spine_02','spine_03','neck_01','head') else world.to_quaternion()@offset[d]
   m=q.to_matrix().to_4x4();m.translation=(rig.matrix_world@p.matrix).translation
   if s=='pelvis':m.translation=rd[d].translation+Vector((0,0,(world.translation.z-rs[d].translation.z)*ratio))
   p.matrix=rig.matrix_world.inverted()@m;bpy.context.view_layer.update()
  for p in rig.pose.bones:
   q=p.rotation_quaternion.copy()
   if p.name in previous and q.dot(previous[p.name])<0:q.negate()
   p.rotation_quaternion=q;previous[p.name]=q.copy();p.keyframe_insert('rotation_quaternion',frame=f-lo+1)
   if p.name=='mixamorig:Hips':p.keyframe_insert('location',frame=f-lo+1)
 actions[name]=baked;report['clips'][name]={'source':'previous production rig','frames':[1,hi-lo+1],'fps':60,'temporary':True}
 print('RETARGET_NOBLE',name,flush=True)
for obj in fresh:bpy.data.objects.remove(obj,do_unlink=True)
rig.animation_data_clear();rig.animation_data_create()
for a in list(bpy.data.actions):
 if a not in actions.values():bpy.data.actions.remove(a)
for name,a in actions.items():
 # Blender 4.5's all-actions exporter switches actions without assigning slots.
 # Mixed imported/custom slot identifiers silently bake later actions as rest pose.
 for slot in a.slots:slot.identifier='OB'+rig.name
 a.name=name;tr=rig.animation_data.nla_tracks.new();tr.name=name;strip=tr.strips.new(name,1,a);strip.action_slot=a.slots[0];tr.mute=True
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis.identity()
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1
texture=next((SRC/'tripo').rglob('*.jpg'));shutil.copy2(texture,OUT/'Noble_BaseColor_8K.jpg')
mat=bpy.data.materials.new('Noble Original Color');mat.use_nodes=True
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'Noble_BaseColor_8K.jpg'))
mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
body.data.materials.clear();body.data.materials.append(mat)
# Measure in-place planted-foot travel for controller/animation speed matching.
for name in ['REV_SwaggerWalk','REV_StandardRun']:
 a=actions[name];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];pts={n:[] for n in ['LeftFoot','RightFoot']}
 for f in range(int(a.frame_range[0]),int(a.frame_range[1])+1):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
  for n in pts:pts[n].append(rig.matrix_world@rig.pose.bones['mixamorig:'+n].head)
 speeds=[]
 for n,pp in pts.items():
  floor=min(p.z for p in pp)
  speeds.extend(abs(b.y-a.y)*60 for a,b in zip(pp,pp[1:]) if max(a.z,b.z)<floor+.055)
 report['clips'][name]['stride_mps']=statistics.median(speeds)
rig.animation_data.action=None
for p in rig.pose.bones:p.matrix_basis.identity()
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'RevenantNoble_Integrated.blend'))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.fbx(filepath=str(OUT/'revenant_noble.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,axis_forward='-Z',axis_up='Y',path_mode='STRIP')
(OUT/'materials.json').write_text(json.dumps({'Noble Original Color':{'color':[1,1,1,1],'alpha':1,'metallic':0,'roughness':.75,'albedo':'Noble_BaseColor_8K.jpg','preserveOriginal':True}},indent=2))
(SRC/'integration-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
subprocess.run([bpy.app.binary_path,'-b','-t','2','--python',str(ROOT/'unity/test_revenant_noble_motion.py')],check=True)
