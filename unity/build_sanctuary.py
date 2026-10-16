import bpy, json, struct, shutil
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'Assets/Bloodwake/Resources/Sanctuary'
REVIEW=ROOT.parent/'art/sanctuary/integration-20261016'
OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)

SOURCES=[
 ('Hall',Path('/home/cenkargevim/Downloads/medieval hall 3d model.glb'),14.0,(0,2,0)),
 ('Training',Path('/home/cenkargevim/Downloads/medieval castle interior 3d model.glb'),12.0,(0,-11.5,0)),
 ('Study',Path('/home/cenkargevim/Downloads/medieval study 3d model.glb'),8.0,(8.7,-2.0,0)),
 ('Shop',Path('/home/cenkargevim/Downloads/medieval shop interior 3d model.glb'),8.0,(-8.7,-2.0,0)),
]

def glb_doc(path):
 raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 return raw,json.loads(raw[20:20+length]),length

def extract_manifest(alias,path,rows):
 raw,doc,length=glb_doc(path);binary=raw[28+length:];images=[]
 for i,image in enumerate(doc.get('images',[])):
  suffix='.jpg' if image.get('mimeType')=='image/jpeg' else '.png'
  name=f'{alias}_SourceImage_{i}{suffix}';view=doc['bufferViews'][image['bufferView']]
  start=view.get('byteOffset',0);(OUT/name).write_bytes(binary[start:start+view['byteLength']]);images.append(name)
 for index,material in enumerate(doc.get('materials',[])):
  original=material.get('name','Material_'+str(index));name=alias+'_'+original
  pbr=material.get('pbrMetallicRoughness',{});color=pbr.get('baseColorFactor',[1,1,1,1])
  row={'color':color,'alpha':color[3],'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1)}
  for key,texture in [('albedo',pbr.get('baseColorTexture')),('normal',material.get('normalTexture')),('metallicRoughness',pbr.get('metallicRoughnessTexture'))]:
   if texture is not None:row[key]=images[doc['textures'][texture['index']]['source']]
  rows[name]=row
 return [alias+'_'+m.get('name','Material_'+str(i)) for i,m in enumerate(doc.get('materials',[]))]

bpy.ops.wm.read_factory_settings(use_empty=True)
manifest={};audit=[];all_meshes=[]
for alias,path,target_longest,position in SOURCES:
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(path));objects=list(set(bpy.context.scene.objects)-before)
 meshes=[o for o in objects if o.type=='MESH'];points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));size=hi-lo
 scale=target_longest/max(size.x,size.y);centre=(lo+hi)*.5
 root=bpy.data.objects.new('Sanctuary '+alias,None);bpy.context.collection.objects.link(root);root.location=position
 for o in objects:
  if o.parent not in objects:o.parent=root
 for o in meshes:
  o.name=alias+' Geometry';o.data.name=alias+' Mesh'
  for material in o.data.materials:
   if material:material.name=alias+'_'+material.name
 root.scale=(scale,scale,scale);root.location.x-=centre.x*scale;root.location.y-=centre.y*scale;root.location.z-=lo.z*scale
 material_names=extract_manifest(alias,path,manifest)
 audit.append({'name':alias,'source':str(path),'source_size':list(size),'scale':scale,'world_size':[size.x*scale,size.y*scale,size.z*scale],'position':list(position),'triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'materials':material_names})
 all_meshes.extend(meshes)

(OUT/'materials.json').write_text(json.dumps(manifest,indent=2));(REVIEW/'audit.json').write_text(json.dumps(audit,indent=2))
for alias,path,_,_ in SOURCES:shutil.copy2(path,REVIEW/path.name)

# Export exactly the four imported room meshes; lighting below is review-only.
bpy.ops.object.select_all(action='DESELECT')
for o in all_meshes:o.select_set(True)
bpy.context.view_layer.objects.active=all_meshes[0]
bpy.ops.export_scene.fbx(filepath=str(OUT/'sanctuary_rooms.fbx'),use_selection=True,object_types={'MESH','EMPTY'},add_leaf_bones=False,bake_anim=False,path_mode='STRIP',axis_forward='-Z',axis_up='Y')

# Neutral isometric review of the actual combined geometry.
bpy.ops.object.select_all(action='DESELECT')
world=bpy.context.scene.world or bpy.data.worlds.new('World');bpy.context.scene.world=world;world.color=(.035,.035,.045)
for location,energy,size in [((-12,-8,20),1900,10),((14,8,14),1300,8)]:
 light=bpy.data.lights.new('Review area','AREA');light.energy=energy;light.shape='DISK';light.size=size
 obj=bpy.data.objects.new('Review area',light);bpy.context.collection.objects.link(obj);obj.location=location
camdata=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',camdata);bpy.context.collection.objects.link(cam)
cam.location=(27,-34,31);target=Vector((0,-4,1.5));cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=35;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(REVIEW/'sanctuary-combined.png');scene.view_settings.look='AgX - Medium High Contrast';bpy.ops.render.render(write_still=True)
print('SANCTUARY_BUILT',json.dumps(audit))
