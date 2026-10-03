import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'art/revenant/source/revenant_original.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
pts=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
lo=Vector(tuple(min(v[i] for v in pts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in pts) for i in range(3)))
for o in meshes:
 mat=o.matrix_world.copy();o.parent=None;o.matrix_world=mat
 factor=1.8/(hi.z-lo.z)
 o.location=(o.location-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*factor;o.scale*=factor
 bpy.context.view_layer.objects.active=o
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mod=o.modifiers.new('Rigging mesh reduction','DECIMATE');mod.ratio=min(1,35000/len(o.data.polygons));bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(root/'art/revenant/mixamo_upload/revenant_clean.fbx'),use_selection=True,object_types={'MESH'},bake_anim=False,path_mode='COPY',embed_textures=True,add_leaf_bones=False)
