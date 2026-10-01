"""Build a downloaded Mixamo enemy with original PBR textures and rigid equipment.
Blender -b -t 4 --python godot/tools/build_mixamo_enemy.py -- warrior
Animation selection lives in art/enemies/mixamo/<id>/clips.json.
"""
import bpy, bmesh, json, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/enemies'
identifier=sys.argv[sys.argv.index('--')+1]
folder=BASE/'mixamo'/identifier
config=json.loads((folder/'clips.json').read_text())
manifest=json.loads((BASE/'manifest.json').read_text())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(folder/config['model']))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
bodies=[o for o in bpy.context.scene.objects if o.type=='MESH']
rig.name=identifier.title()+'EnemyRig'
rig.animation_data_clear()
bpy.context.view_layer.update()
coords=[o.matrix_world@v.co for o in bodies for v in o.data.vertices]
height=max(v.z for v in coords)-min(v.z for v in coords)
rig.scale*=1.8/height
bpy.context.view_layer.update()
actions={}
for name,filename in config['clips'].items():
 before=set(bpy.data.objects)
 bpy.ops.import_scene.fbx(filepath=str(folder/filename))
 imported=set(bpy.data.objects)-before
 arm=next(o for o in imported if o.type=='ARMATURE')
 assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones],filename
 action=arm.animation_data.action;action.name=name;action.use_fake_user=True
 ratio=60/(bpy.context.scene.render.fps/bpy.context.scene.render.fps_base)
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     if not fc.keyframe_points:continue
     planar=fc.data_path=='pose.bones["mixamorig:Hips"].location' and fc.array_index in (0,2)
     first=fc.keyframe_points[0].co.y
     for key in fc.keyframe_points:
      for point in [key.co,key.handle_left,key.handle_right]:
       point.x=1+(point.x-1)*ratio
       if planar:point.y=first
 actions[name]=action
 for obj in imported:bpy.data.objects.remove(obj,do_unlink=True)

# With-skin downloads may carry an unused mesh action; export only selected clips.
for unused in list(bpy.data.actions):
 if unused not in actions.values():bpy.data.actions.remove(unused)

def material(kind):
 source=ROOT/next(e['source'] for e in manifest if e['id']==identifier and e['kind']==kind)
 textures=source.with_suffix('.fbm')
 mat=bpy.data.materials.new(identifier+'_'+kind+'_PBR');mat.use_nodes=True
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
 for pattern,socket in [('Color.jpg','Base Color'),('*roughness*','Roughness'),('*metallic*','Metallic'),('Normal.png','Normal')]:
  path=next(textures.glob(pattern))
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
  if max(tex.image.size)>2048:tex.image.scale(2048,2048)
  if socket!='Base Color':tex.image.colorspace_settings.name='Non-Color'
  tex.image.pack()
  if socket=='Normal':
   normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs[socket])
  else:links.new(tex.outputs['Color'],p.inputs[socket])
 return mat
mat=material('character')
for body in bodies:body.name=identifier+'_body';body.data.materials.clear();body.data.materials.append(mat)
attachment_action=actions[config.get('attachment_pose','Idle')]
rig.animation_data_create();rig.animation_data.action=attachment_action;rig.animation_data.action_slot=attachment_action.slots[0]
bpy.context.scene.frame_set(config.get('attachment_frame',1));bpy.context.view_layer.update()
weapons=[]
for settings in config.get('weapons',[config.get('weapon')]):
 before=set(bpy.data.objects)
 bpy.ops.wm.obj_import(filepath=str(BASE/'weapons_obj'/identifier/(identifier+'_weapon.obj')))
 weapon=next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
 weapon.name='Equipment_'+settings.get('hand','RightHand');weapon.data.materials.clear();weapon.data.materials.append(material('weapon'))
 if 'half' in settings:
  mesh=bmesh.new();mesh.from_mesh(weapon.data)
  bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if v.co.x*settings['half']<0],context='VERTS')
  mesh.to_mesh(weapon.data);mesh.free()
 if 'x_range' in settings:
  # Some source props contain a bow and a separate arrow in the same object.
  lo,hi=settings['x_range']
  mesh=bmesh.new();mesh.from_mesh(weapon.data)
  bmesh.ops.delete(mesh,geom=[v for v in mesh.verts if not lo<=v.co.x<=hi],context='VERTS')
  mesh.to_mesh(weapon.data);mesh.free()
 # Author placement in world space relative to the posed hand. Grip and blade axis
 # are stored explicitly so attachments remain reproducible for every source mesh.
 hand=rig.pose.bones['mixamorig:'+settings.get('hand','RightHand')]
 point=rig.matrix_world@(hand.head+(hand.tail-hand.head)*.55)
 source_axis=Vector(settings['axis']).normalized()
 target_axis=Vector(settings['direction']).normalized()
 rotation=source_axis.rotation_difference(target_axis).to_matrix().to_4x4()
 rotation=Matrix.Rotation(math.radians(settings.get('roll',0)),4,target_axis)@rotation
 placement=Matrix.Translation(point)@rotation@Matrix.Scale(settings['scale'],4)@Matrix.Translation(-Vector(settings['grip']))
 convert=rig.data.bones[hand.name].matrix_local@hand.matrix.inverted()@rig.matrix_world.inverted()@placement
 # OBJ local coordinates are Y-up, matching the recorded source grip.
 for vertex in weapon.data.vertices:vertex.co=convert@vertex.co
 weapon.parent=rig;weapon.matrix_parent_inverse=Matrix.Identity(4);weapon.matrix_basis=Matrix.Identity(4)
 group=weapon.vertex_groups.new(name=hand.name);group.add(list(range(len(weapon.data.vertices))),1,'REPLACE')
 modifier=weapon.modifiers.new('Rigid hand attachment','ARMATURE');modifier.object=rig
 weapons.append(weapon)
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0];track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig,*bodies,*weapons]:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models'/('enemy_'+identifier+'.glb')),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath='/tmp/enemy_'+identifier+'.blend')
print('ENEMY_BUILD',identifier,[(n,tuple(a.frame_range)) for n,a in actions.items()],flush=True)
