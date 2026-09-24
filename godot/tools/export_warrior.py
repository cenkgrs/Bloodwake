"""Export existing CC0 warrior with self-contained PBR armor and helmet.
blender -b art/warrior/source/Quaternius_Warrior.blend -t 4 --python godot/tools/export_warrior.py
"""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
rig=bpy.data.objects['CharacterArmature']
def mat(name,color,metal):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.55
 return m
steel=mat('Night iron',(.10,.13,.17),.65)
bronze=mat('Tarnished bronze',(.23,.16,.095),.6)
sword=mat('Blade steel',(.30,.34,.39),.8)
for o in list(bpy.context.scene.objects):
 if o.name=='Face':bpy.data.objects.remove(o,do_unlink=True);continue
 if o.type=='MESH':
  o.data.materials.clear();o.data.materials.append(sword if 'Sword' in o.name else bronze if 'Shoulder' in o.name else steel)
with bpy.data.libraries.load(str(ROOT/'art/warrior/source/animated_knight/Helmet2.blend'),link=False) as (source,target):
 target.objects=[n for n in source.objects if n=='Helmet2']
helmet=target.objects[0];bpy.context.scene.collection.objects.link(helmet)
helmet.parent=rig;helmet.parent_type='BONE';helmet.parent_bone='Head';helmet.location=(0,0,0);helmet.rotation_euler=(0,0,0);helmet.scale=(.42,.42,.42)
helmet.data.materials.clear();helmet.data.materials.append(steel)
rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ('MESH','ARMATURE'):o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS')
