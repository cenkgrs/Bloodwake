"""Read PBR factors from glTF, not Blender's derived shader graph defaults."""
import bpy, json, struct

def write_manifest(folder, source):
 raw=source.read_bytes()
 length=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+length])
 binary=raw[28+length:]
 image_paths=[]
 for i,image in enumerate(doc.get('images',[])):
  suffix='.jpg' if image.get('mimeType')=='image/jpeg' else '.png'
  name='SourceImage_'+str(i)+suffix
  view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
  (folder/name).write_bytes(binary[start:start+view['byteLength']])
  image_paths.append(name)
 rows={}
 for index, material in enumerate(doc.get('materials',[])):
  pbr=material.get('pbrMetallicRoughness',{})
  color=pbr.get('baseColorFactor',[1,1,1,1])
  row={'color':color,'alpha':color[3], 'metallic':pbr.get('metallicFactor',1), 'roughness':pbr.get('roughnessFactor',1)}
  for key,texture in [('albedo',pbr.get('baseColorTexture')),('normal',material.get('normalTexture')),('metallicRoughness',pbr.get('metallicRoughnessTexture'))]:
   if texture is None:continue
   row[key]=image_paths[doc['textures'][texture['index']]['source']]
   if key=='albedo':
    transform=texture.get('extensions',{}).get('KHR_texture_transform',{})
    scale=transform.get('scale',[1,1]);offset=transform.get('offset',[0,0])
    row['tiling']=scale
    row['offset']=[offset[0],1-offset[1]-scale[1]]
  rows[material.get('name','Material_'+str(index))]=row
 (folder/'materials.json').write_text(json.dumps(rows,indent=2))
