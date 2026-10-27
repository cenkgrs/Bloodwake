import bpy,json
from pathlib import Path
D=Path(__file__).resolve().parents[1];results={}
expected=set(json.loads((D/'animation_events.json').read_text())['actions'])
for ext in ['glb','fbx']:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=60
 if ext=='glb':bpy.ops.import_scene.gltf(filepath=str(D/'Revenant_Animated.glb'))
 else:bpy.ops.import_scene.fbx(filepath=str(D/'Revenant_Animated.fbx'),use_anim=True)
 rigs=[o for o in bpy.data.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.modifiers];actions=[a.name for a in bpy.data.actions]
 names={n.split('|')[-1] for n in actions};missing=expected-names
 info={'rig_count':len(rigs),'deform_mesh_count':len(meshes),'bone_count':len(rigs[0].data.bones) if rigs else 0,'actions':actions,'missing_main_actions':sorted(missing),'materials':[m.name for m in bpy.data.materials],'images':[{'name':im.name,'size':list(im.size),'has_data':im.has_data} for im in bpy.data.images],'ranges':{a.name:list(a.frame_range) for a in bpy.data.actions}}
 info['passed']=len(rigs)==1 and info['bone_count']>=77 and not missing and all(im['has_data'] for im in info['images']) and len(info['materials'])>=1 and len(info['images'])>=(3 if ext=='glb' else 4)
 results[ext]=info
 bpy.ops.wm.save_as_mainfile(filepath=str(D/'qa'/f'Reimport_{ext}.blend'))
(D/'qa/export_roundtrip.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
