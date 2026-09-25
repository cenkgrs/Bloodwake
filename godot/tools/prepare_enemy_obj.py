"""Create Mixamo-ready static character OBJ packages and separate weapon OBJs.
blender -b -t 4 --python godot/tools/prepare_enemy_obj.py
Preserves all supplied FBXs and PBR textures; upload packages contain diffuse only.
"""
import bpy,json,shutil,zipfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/enemies'
entries=[]
for label in ['Warrior','Healer','Assasin','Archer','Tank','Commander','Boss']:
 identifier='assassin' if label=='Assasin' else label.lower()
 for kind in ['character','weapon']:
  bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
  source=next(p for p in (BASE/'source'/label).glob('*/*.fbx') if kind in p.parent.name.lower())
  bpy.ops.import_scene.fbx(filepath=str(source))
  meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
  assert meshes,'No meshes: '+str(source)
  # Apply authored transforms before centering; no skeleton or weapon is added to a character.
  bpy.ops.object.select_all(action='DESELECT')
  for o in meshes:o.select_set(True)
  bpy.context.view_layer.objects.active=meshes[0]
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  coords=[v.co for o in meshes for v in o.data.vertices]
  lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
  factor=1.8/(hi.z-lo.z) if kind=='character' else 1.0
  pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
  for o in meshes:
   o.name=identifier+'_'+kind
   for v in o.data.vertices:v.co=(v.co-pivot)*factor
  dest=BASE/('mixamo_upload' if kind=='character' else 'weapons_obj')/identifier
  dest.mkdir(parents=True,exist_ok=True)
  texture=next(source.with_suffix('.fbm').glob('Color.jpg'))
  color=dest/(identifier+'_color.jpg');shutil.copy2(texture,color)
  mat=bpy.data.materials.new(identifier+'_'+kind);mat.use_nodes=True
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(color),check_existing=True)
  principled=mat.node_tree.nodes.get('Principled BSDF');principled.inputs['Roughness'].default_value=.75
  mat.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
  for o in meshes:o.data.materials.clear();o.data.materials.append(mat)
  filepath=dest/(identifier+('_weapon' if kind=='weapon' else '')+'.obj')
  bpy.ops.wm.obj_export(filepath=str(filepath),export_selected_objects=True,forward_axis='NEGATIVE_Z',up_axis='Y',export_uv=True,export_normals=True,export_materials=True,apply_modifiers=True,path_mode='RELATIVE')
  package=dest.parent/(identifier+('_weapon' if kind=='weapon' else '_mixamo')+'.zip')
  with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
   for f in sorted(dest.iterdir()):z.write(f,f.name)
  entry={'id':identifier,'kind':kind,'source':str(source.relative_to(ROOT)),'obj':str(filepath.relative_to(ROOT)),'zip':str(package.relative_to(ROOT)),'vertices':sum(len(o.data.vertices) for o in meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'uv':all(bool(o.data.uv_layers) for o in meshes),'scale_applied':factor,'rigged':False}
  entries.append(entry);print('ENEMY_OBJ',json.dumps(entry),flush=True)
  if kind=='character':
   # Frontal visual inspection of the exact static geometry exported for rigging.
   scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.world.color=(.25,.25,.25)
   bpy.ops.object.camera_add(location=(0,-4,1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.5;scene.camera=cam
   for loc in [(2,-3,4),(-2,-2,2)]:
    bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=180;light.data.size=3;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
   scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100;scene.render.filepath=str(BASE/'preview'/(identifier+'_obj.png'));bpy.ops.render.render(write_still=True)
(BASE/'manifest.json').write_text(json.dumps(entries,indent=2)+'\n')
print('ENEMY_OBJ_COMPLETE',len(entries),flush=True)
