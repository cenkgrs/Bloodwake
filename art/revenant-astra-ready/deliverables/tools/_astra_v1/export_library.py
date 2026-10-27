import bpy,json,sys
from pathlib import Path
D=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Animated.blend'))
s=bpy.context.scene;r=bpy.data.objects['REV_Rig'];m=bpy.data.objects['REV_Body']
r.animation_data.action=None
for t in list(r.animation_data.nla_tracks):r.animation_data.nla_tracks.remove(t)
for o in list(bpy.data.objects):
 if o not in [r,m]:bpy.data.objects.remove(o,do_unlink=True)
m.animation_data_clear();m.hide_render=False
allowed=set(json.loads((D/'animation_events.json').read_text())['actions']) | {'REV_AgileMove_RootMotion'} | {'REV_HitLight_'+d+'_Additive' for d in ['Front','Left','Right']}
for a in list(bpy.data.actions):
 if a.name not in allowed:bpy.data.actions.remove(a)
for b in r.pose.bones:
 b.location=(0,0,0);b.rotation_quaternion=(1,0,0,0);b.scale=(1,1,1)
bpy.ops.object.select_all(action='DESELECT')
for o in [r,m]:o.select_set(True)
bpy.context.view_layer.objects.active=r
bpy.ops.export_scene.gltf(filepath=str(D/'Revenant_Animated.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True,export_frame_range=False,export_def_bones=False,export_skins=True,export_materials='EXPORT',export_extras=True,export_all_influences=False)
# FBX cannot traverse glTF's Multiply/Separate Color nodes. Bake equivalent
# direct image sockets into a temporary export material; source blend stays intact.
import numpy as np
texdir=D/'textures';texdir.mkdir(exist_ok=True)
for mat in m.data.materials:
 nt=mat.node_tree;p=nt.nodes.get('Principled BSDF')
 base=next(n.image for n in nt.nodes if n.type=='TEX_IMAGE' and 'basecolor' in n.image.name)
 rm=next(n.image for n in nt.nodes if n.type=='TEX_IMAGE' and '_rm' in n.image.name)
 for label,source,channel,factor,socket in [('BaseColor',base,None,.8,'Base Color'),('Roughness',rm,1,1,'Roughness'),('Metallic',rm,2,1,'Metallic')]:
  width,height=source.size;pixels=np.empty(width*height*4,dtype=np.float32);source.pixels.foreach_get(pixels);pixels=pixels.reshape((-1,4))
  if channel is None:pixels[:,:3]*=factor
  else:pixels[:,:3]=pixels[:,channel:channel+1]
  pixels[:,3]=1
  img=bpy.data.images.new('Revenant_'+label,width=width,height=height,alpha=False)
  if channel is not None:img.colorspace_settings.name='Non-Color'
  img.pixels.foreach_set(pixels.ravel());img.filepath_raw=str(texdir/(label+'.png'));img.file_format='PNG';img.save();img.pack()
  node=nt.nodes.new('ShaderNodeTexImage');node.image=img;nt.links.new(node.outputs['Color'],p.inputs[socket])
 normal=next(n.image for n in nt.nodes if n.type=='TEX_IMAGE' and 'normal' in n.image.name)
 normal.filepath_raw=str(texdir/'Normal.png');normal.file_format='PNG';normal.save();normal.pack()
bpy.ops.export_scene.fbx(filepath=str(D/'Revenant_Animated.fbx'),use_selection=True,object_types={'ARMATURE','MESH'},apply_unit_scale=True,global_scale=1,axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_force_startend_keying=True,bake_anim_simplify_factor=0,path_mode='COPY',embed_textures=True)
print('EXPORT_LIBRARY_DONE')
