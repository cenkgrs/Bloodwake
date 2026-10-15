"""Export existing production models without retargeting or altering their rigs."""
import bpy, json, shutil, sys, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'unity'))
from material_manifest import write_manifest
OUT=ROOT/'unity/Assets/Bloodwake/Resources'
models=['warrior_player','revenant_player','bloodhound_player','mage_player','assassin_player','enemy_warrior','enemy_archer','enemy_assassin','enemy_mage','enemy_healer','enemy_tank','enemy_commander','enemy_boss']
report={}
for name in models:
 source_name=name
 folder=OUT/'Models'/name;folder.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.scene.render.fps=60
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'godot/assets/models'/(source_name+'.glb')))
 export_objects=[o for o in bpy.context.scene.objects if not any(c.name=='glTF_not_exported' for c in o.users_collection)]
 for image in bpy.data.images:
  if image.packed_file or image.has_data:
   dest=str(folder/(bpy.path.clean_name(image.name)+'.png'))
   image.filepath_raw=dest;image.file_format='PNG';image.save();image.filepath=dest
 write_manifest(folder,ROOT/'godot/assets/models'/(source_name+'.glb'))
 bpy.ops.object.select_all(action='DESELECT')
 for obj in export_objects:obj.select_set(True)
 bpy.ops.export_scene.fbx(filepath=str(folder/(name+'.fbx')),use_selection=True,object_types={'ARMATURE','MESH','EMPTY'},add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0.0,path_mode='COPY',embed_textures=False,axis_forward='-Z',axis_up='Y')
 report[name]=[a.name for a in bpy.data.actions]
 print('UNITY_MODEL_EXPORTED',name,report[name],flush=True)
# Runtime GLBs may predate the lossless policy. Restore from original art,
# never from a decoded low-resolution JPEG, on every Unity asset rebuild.
subprocess.run(['python3',str(ROOT/'unity/restore_character_textures.py')],check=True)
for category in ['audio','ui','textures','fonts','vfx','art']:
 for source in (ROOT/'godot/assets'/category).rglob('*'):
  if not source.is_file() or source.suffix.lower() not in ['.wav','.ogg','.mp3','.png','.jpg','.jpeg','.ttf','.otf']:continue
  dest=OUT/category/source.relative_to(ROOT/'godot/assets'/category);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
print('UNITY_ASSET_EXPORT_COMPLETE',json.dumps(report),flush=True)

from export_vfx import export as export_vfx
export_vfx()
