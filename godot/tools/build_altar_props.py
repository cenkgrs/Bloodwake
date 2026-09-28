"""Convert supplied altar props locally; preserve originals, export one grounded mesh per GLB.
Run: blender -b -t 4 --python godot/tools/build_altar_props.py
"""
import bpy,json,zipfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/environment/altar'
OUT=ROOT/'godot/assets/models/environment/altar'
manifest=[]
for name,source in [('pillar','gothic+pillar+3d+model.zip'),('brazier','iron+brazier+3d+model.zip'),('bones','bone pile 3d model.glb'),('urn','fired clay urn 3d model.glb'),('altar','stone altar 3d model.glb')]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 path=BASE/'source'/source
 if path.suffix=='.zip':
  dest=Path('/tmp/altar_prop_sources')/name;dest.mkdir(parents=True,exist_ok=True)
  with zipfile.ZipFile(path) as z:
   for info in z.infolist():
    assert not Path(info.filename).is_absolute() and '..' not in Path(info.filename).parts
   z.extractall(dest)
  path=next(dest.glob('*.fbx'));bpy.ops.import_scene.fbx(filepath=str(path))
  mat=bpy.data.materials.new(name+'_PBR');mat.use_nodes=True
  p=mat.node_tree.nodes.get('Principled BSDF')
  for pattern,socket in [('Color.jpg','Base Color'),('*roughness*','Roughness'),('*metallic*','Metallic'),('Normal.png','Normal')]:
   tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(next(path.with_suffix('.fbm').glob(pattern))),check_existing=True)
   if socket!='Base Color':tex.image.colorspace_settings.name='Non-Color'
   if socket=='Normal':
    normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],p.inputs[socket])
   else:mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
  for o in bpy.context.scene.objects:
   if o.type=='MESH':o.data.materials.clear();o.data.materials.append(mat)
 else:bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 bpy.ops.object.join();obj=bpy.context.object;obj.name=name
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 lo=Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
 pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 for v in obj.data.vertices:v.co=(v.co-pivot)/(hi.z-lo.z)
 triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
 if triangles>8000:
  mod=obj.modifiers.new('Prop triangle budget','DECIMATE');mod.ratio=8000/triangles;bpy.ops.object.modifier_apply(modifier=mod.name)
 for m in obj.data.materials:
  if not m or not m.use_nodes:continue
  for n in m.node_tree.nodes:
   if n.type=='TEX_IMAGE' and n.image:
    if max(n.image.size)>1024:n.image.scale(1024,1024)
    n.image.pack()
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
 manifest.append({'id':name,'source':source,'original_triangles':triangles,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'height':1.0,'texture_limit':1024})
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.world.color=(.3,.3,.3)
 bpy.ops.object.camera_add(location=(1.7,-2.5,2.4));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=max(1.6,max(hi.x-lo.x,hi.y-lo.y)/(hi.z-lo.z)*1.5);scene.camera=cam
 for loc in [(2,-3,4),(-2,-1,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=170;l.data.size=3;l.rotation_euler=(Vector((0,0,.5))-l.location).to_track_quat('-Z','Y').to_euler()
 scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100
 scene.render.filepath=str(BASE/(name+'_preview.png'));bpy.ops.render.render(write_still=True)
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ALTAR_BUILD_COMPLETE',manifest,flush=True)
