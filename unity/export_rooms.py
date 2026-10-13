import bpy, json, struct, tempfile, sys, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from material_manifest import write_manifest
for source in (ROOT/'RoomSources').glob('*.glb'):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 raw=source.read_bytes();length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length])
 doc['extensionsRequired']=[e for e in doc.get('extensionsRequired',[]) if e!='KHR_node_visibility']
 payload=json.dumps(doc).encode();payload+=b' '*((-len(payload))%4)
 rest=raw[20+length:];converted=struct.pack('<III',0x46546c67,2,20+len(payload)+len(rest))+struct.pack('<II',len(payload),kind)+payload+rest
 with tempfile.TemporaryDirectory(prefix='bloodwake-room-') as temp:
  intermediate=Path(temp)/source.name;intermediate.write_bytes(converted)
  bpy.ops.import_scene.gltf(filepath=str(intermediate))
 output=ROOT/'Assets/Bloodwake/Resources/Rooms'/source.stem;output.mkdir(parents=True,exist_ok=True)
 if source.with_suffix('.json').exists():shutil.copy2(source.with_suffix('.json'),output/'collision.json')
 for image in bpy.data.images:
  if image.packed_file or image.has_data:
   dest=str(output/(bpy.path.clean_name(image.name)+'.png'));image.filepath_raw=dest;image.file_format='PNG';image.save();image.filepath=dest
 write_manifest(output,source)
 # Godot's world-triplanar material is not represented by glTF UVs. Bake
 # world-projected UV coordinates into procedural room meshes before FBX export.
 surfaces={'cobble','ashlar','flagstone','wood','crate','timber','slate','iron','cloth'}
 mapped=set()
 for i,mat in enumerate(doc.get('materials',[])):
  tex=mat.get('pbrMetallicRoughness',{}).get('baseColorTexture')
  if tex is not None:
   im=doc['images'][doc['textures'][tex['index']]['source']]
   if im.get('name','').split('_')[0] in surfaces:mapped.add(mat.get('name','Material_'+str(i)))
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH' or not any(m and m.name in mapped for m in obj.data.materials):continue
  obj.data=obj.data.copy();mesh=obj.data;uv=mesh.uv_layers.active or mesh.uv_layers.new()
  normal_matrix=obj.matrix_world.to_3x3().inverted().transposed()
  for polygon in mesh.polygons:
   mat=mesh.materials[polygon.material_index]
   if mat is None or mat.name not in mapped:continue
   n=normal_matrix@polygon.normal;axis=max(range(3),key=lambda a:abs(n[a]))
   for loop_index in polygon.loop_indices:
    p=obj.matrix_world@mesh.vertices[mesh.loops[loop_index].vertex_index].co
    uv.data[loop_index].uv=(p.y,p.z) if axis==0 else (p.x,p.z) if axis==1 else (p.x,p.y)
 bpy.ops.export_scene.fbx(filepath=str(output/(source.stem+'.fbx')),object_types={'MESH','EMPTY','LIGHT'},add_leaf_bones=False,bake_anim=False,path_mode='COPY',axis_forward='-Z',axis_up='Y')
 print('UNITY_ROOM_FBX',source.stem,flush=True)
