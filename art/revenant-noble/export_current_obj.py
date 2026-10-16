"""Export the actual Unity Noble mesh, never the older Revenant character."""
import bpy, json, hashlib, zipfile
from pathlib import Path
from mathutils import Vector

root=Path('/home/cenkargevim/Desktop/Cenk/roughlike')
source=root/'unity/Assets/Bloodwake/Resources/Models/revenant_noble/revenant_noble.fbx'
texture=source.parent/'Noble_BaseColor_8K.jpg'
out=root/'art/revenant-noble/mixamo-current-20261016'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source),use_anim=False)
for obj in bpy.context.scene.objects:
    if obj.type=='ARMATURE': obj.data.pose_position='REST'
bpy.context.view_layer.update()
graph=bpy.context.evaluated_depsgraph_get()
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
source_faces=sum(len(o.data.polygons) for o in objects)
for obj in objects:
    world=obj.matrix_world.copy()
    mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),depsgraph=graph)
    mesh.transform(world)
    obj.parent=None
    obj.modifiers.clear()
    obj.data=mesh
    obj.matrix_world.identity()
points=[v.co.copy() for o in objects for v in o.data.vertices]
lo=Vector(tuple(min(v[i] for v in points) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
scale=1.8/(hi.z-lo.z)
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
image=bpy.data.images.load(str(texture),check_existing=True)
mat=bpy.data.materials.new('Revenant_Noble_Original_8K')
mat.use_nodes=True
nodes=mat.node_tree.nodes
bsdf=nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.6
tex=nodes.new('ShaderNodeTexImage');tex.image=image
mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
for obj in objects:
    for vertex in obj.data.vertices: vertex.co=(vertex.co-center)*scale
    obj.data.materials.clear();obj.data.materials.append(mat)
    for poly in obj.data.polygons: poly.material_index=0
bpy.ops.object.select_all(action='DESELECT')
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
objpath=out/'Revenant_Noble_Current.obj'
bpy.ops.wm.obj_export(filepath=str(objpath),export_selected_objects=True,
    export_materials=True,path_mode='COPY',forward_axis='NEGATIVE_Z',up_axis='Y')
# Reimport the deliverable to detect empty meshes, absent UVs, or scale errors.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=str(objpath),forward_axis='NEGATIVE_Z',up_axis='Y')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
height=max(v.z for v in points)-min(v.z for v in points)
faces=sum(len(o.data.polygons) for o in meshes)
assert faces==source_faces and faces>1000,(faces,source_faces)
assert abs(height-1.8)<.001,height
assert all(len(o.data.uv_layers)>0 for o in meshes)
assert (out/texture.name).read_bytes()==texture.read_bytes(),'Texture changed during export'
report={'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_faces':source_faces,'exported_faces':faces,'height_metres':height,
        'pose':'original rig REST bind pose','texture':'unaltered 8192x8192 original JPEG; no recompression',
        'uv_preserved':True,'obj_reimport_passed':True}
(out/'validation.json').write_text(json.dumps(report,indent=2))
with zipfile.ZipFile(out/'Revenant_Noble_Current_Mixamo.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for path in [objpath,objpath.with_suffix('.mtl'),out/texture.name]: archive.write(path,path.name)
# Preview the reimported OBJ, not the FBX source.
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=600;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.13,.15,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.ops.object.camera_add(location=(0,-4,1.02))
camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,.94))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=2.35;scene.camera=camera
for location,power,size in [((-3,-4,4),500,4),((3,-2,2.5),300,3),((0,3,3),400,3)]:
    bpy.ops.object.light_add(type='AREA',location=location)
    light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(out/'preview.png');bpy.ops.render.render(write_still=True)
print('CURRENT_REVENANT_OBJ_VALIDATED',json.dumps(report))
