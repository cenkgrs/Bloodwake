"""Build the user-supplied knight and two-handed Mixamo clips with a rigid sword.
Run with Blender --background --threads 4 --python godot/tools/build_mixamo_warrior.py.
Original FBX files are preserved under art/warrior/source/.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/warrior/source'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# clip name -> (source fbx, frame span or None for the whole file).
# 'Great Sword Slash 1-2-3' is one continuous performance holding three swings.
# Cutting it at the frames where the blade is slowest means two consecutive links
# of the chain share a pose exactly, so the combo cannot pop at the seam - which is
# what no amount of crossfading can fix once the poses disagree.
clips={
 'Idle':('Great Sword Idle',None),
 'Run':('Great Sword Run',None),
 'Attack':('Great Sword Slash',None),
 'Attack1':('Great Sword Slash 1-2-3',(13,81)),
 'Attack2':('Great Sword Slash 1-2-3',(81,138)),
 'Attack3':('Great Sword Slash 1-2-3',(138,205)),
 'Attack4':('Great Sword Slash 4 With Animation',[(8,56),(120,196)]),
 'SpinAttack':('Great Sword High Spin Attack',(2,112)),
 # The Whirl skill's own clip, authored in Blender rather than downloaded. It is
 # optional on purpose: the file is Cenk's to make, and a warrior that is missing it
 # should still build - the cast falls back to the plain swing until it lands.
 'Whirl':('Warrior Whirl',None),
 # Retargeted off a Meshy generation by tools/retarget_meshy.py.
 'SunderLeap':('Warrior Sunder Leap',None),
 'Hit':('Great Sword Impact',None),
 'Death':('Two Handed Sword Death',None),
 'Ultimate':('Warrior Ultimate',None),
}
# Files re-exported from Blender rather than downloaded from Mixamo need two
# overrides, and both fail silently without them.
#  ignore_leaf_bones: Blender's FBX exporter appends a '_end' leaf per chain,
#   which lands the rig on 78 bones and trips the skeleton assert. Mixamo's own
#   downloads carry no leaf bones, so the flag must NOT be set for those - it
#   would strip 13 real bones and leave 52.
#  fps: the exporter wrote 24 fps while the source performance is 60. Left alone
#   the 60/source rescale below stretches the keys 2.5x, and the spans above -
#   which are frame numbers - then cut somewhere else entirely.
reexported={
 'Great Sword Slash 4 With Animation':{'ignore_leaf_bones':True,'fps':60.0},
 'Warrior Whirl':{'ignore_leaf_bones':True,'fps':60.0},
}

def sliced(source,name,spans):
 # A span is (first,last). Several spans are welded together in order, which is how
 # a clip's dead middle is dropped: 'Great Sword Slash 4' plants on one knee and
 # then holds there for 1.2 s before standing, and that hold is not an attack.
 if isinstance(spans[0],int):spans=[spans]
 keep={};cursor=1
 for start,end in spans:
  for f in range(int(start),int(end)+1):keep[f]=cursor;cursor+=1
 out=source.copy();out.name=name;out.use_fake_user=True
 for layer in out.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for key in reversed(list(fc.keyframe_points)):
      if int(round(key.co.x)) not in keep:fc.keyframe_points.remove(key)
     for key in fc.keyframe_points:
      shift=keep[int(round(key.co.x))]-key.co.x
      key.co.x+=shift;key.handle_left.x+=shift;key.handle_right.x+=shift
     fc.update()
 return out

rig=None;actions={};sources={};optional=[]
for name,(filename,span) in clips.items():
 if filename in sources:
  actions[name]=sliced(sources[filename],name,span) if span else sources[filename]
  continue
 before=set(bpy.data.objects)
 override=reexported.get(filename,{})
 if not (SRC/'mixamo'/(filename+'.fbx')).exists():
  # Skipped, loudly. A clip silently missing from the rig is the kind of thing that
  # only surfaces mid-fight, so say it here rather than let the glb ship short.
  print('MISSING CLIP %s -> %s.fbx not in art/warrior/source/mixamo'%(name,filename))
  optional.append(name);continue
 bpy.ops.import_scene.fbx(filepath=str(SRC/'mixamo'/(filename+'.fbx')),
                          ignore_leaf_bones=override.get('ignore_leaf_bones',False))
 imported=set(bpy.data.objects)-before
 arm=next(o for o in imported if o.type=='ARMATURE')
 action=arm.animation_data.action;action.use_fake_user=True
 if override:
  # A Blender re-export animates the armature OBJECT as well as its pose, and the
  # Mixamo downloads never do. Those channels are replayed onto the rig the moment
  # plant_feet assigns the action and steps a frame, overwriting the 1.8 m
  # normalisation further down with the authoring file's own scale and rotation -
  # which is what halved the knight, silently, with every clip still correct.
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in [f for f in bag.fcurves if not f.data_path.startswith('pose.bones')]:
      print('DROP object channel %s[%d] from %s'%(fc.data_path,fc.array_index,filename))
      bag.fcurves.remove(fc)
 # FBX imports can change the scene FPS (these packs mix 30 and 60 FPS).
 # Convert keys to a common 60 FPS timeline before importing the next file.
 source_fps=override.get('fps',bpy.context.scene.render.fps/bpy.context.scene.render.fps_base)
 ratio=60.0/source_fps
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for key in fc.keyframe_points:
      key.co.x=1+(key.co.x-1)*ratio
      key.handle_left.x=1+(key.handle_left.x-1)*ratio
      key.handle_right.x=1+(key.handle_right.x-1)*ratio

 sources[filename]=action
 if span:actions[name]=sliced(action,name,span)
 else:action.name=name;actions[name]=action
 if rig is None:
  rig=arm;body=next(o for o in imported if o.type=='MESH')
 else:
  assert [b.name for b in arm.data.bones]==[b.name for b in rig.data.bones], 'Incompatible Mixamo skeleton'
  for o in imported:bpy.data.objects.remove(o,do_unlink=True)
# The glTF exporter writes every action that still has a fake user, so the raw
# imports that were only there to be sliced would ship as junk clips.
for action in list(bpy.data.actions):
 if action not in actions.values():
  action.use_fake_user=False;bpy.data.actions.remove(action)

# Mixamo exported this character in very small units; normalize the whole rig.
rig.name='WarriorRig';rig.scale*=1.8/.00835069
rig.animation_data.action=actions['Idle']
rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
HIPS='pose.bones["mixamorig:Hips"].location'

def hips_curves(action):
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     if fc.data_path==HIPS:yield fc

# Every clip must stand where the idle stands. Pinning each clip to its OWN first
# frame looks right for a whole Mixamo file, but a slice taken from the middle of a
# performance begins wherever the character had walked to by then - which put the
# second and third links of the chain 2.5 m and 5.5 m off the body.
anchor={fc.array_index:fc.keyframe_points[0].co.y for fc in hips_curves(actions['Idle'])}
for action in actions.values():
 for fc in hips_curves(action):
  if fc.array_index in (0,2):
   # Planar motion goes: the game decides where the body is.
   level=anchor.get(fc.array_index,fc.keyframe_points[0].co.y)
   for k in fc.keyframe_points:k.co.y=level;k.handle_left.y=level;k.handle_right.y=level
  else:
   # Vertical motion stays - crouches and lunges need it - but is rebased so the
   # clip opens at standing height instead of wherever the cut happened to land.
   shift=anchor.get(1,fc.keyframe_points[0].co.y)-fc.keyframe_points[0].co.y
   for k in fc.keyframe_points:k.co.y+=shift;k.handle_left.y+=shift;k.handle_right.y+=shift
  fc.update()

# Feet on the floor. A Mixamo clip carries vertical root motion too - a dive, a
# kneel, a lunge - and that descent is meant for a character controller to absorb.
# Here the ground plane is fixed, so any frame whose lowest bone has sunk below it
# lifts the hips by exactly the deficit. Without this the slam in 'Slash 4' buried
# the knight half a metre into the arena.
def plant_feet(rig,actions):
 scale=rig.scale.z
 for name,action in actions.items():
  curve=next((fc for fc in hips_curves(action) if fc.array_index==1),None)
  if curve is None:continue
  rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
  frames=[int(round(k.co.x)) for k in curve.keyframe_points]
  lift={}
  for f in range(min(frames),max(frames)+1):
   bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
   low=min(min((rig.matrix_world@b.head).z,(rig.matrix_world@b.tail).z) for b in rig.pose.bones)
   if low<0:lift[f]=-low/scale
  if not lift:continue
  for k in curve.keyframe_points:
   amount=lift.get(int(round(k.co.x)),0.0)
   k.co.y+=amount;k.handle_left.y+=amount;k.handle_right.y+=amount
  curve.update()
  print('PLANT %s lifted %d frames, max %.3f' % (name,len(lift),max(lift.values())),flush=True)

plant_feet(rig,actions)

def material(folder,prefix):
 m=bpy.data.materials.new(prefix);m.use_nodes=True
 nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
 for suffix,socket in [('basecolor','Base Color'),('roughness','Roughness'),('metallic','Metallic'),('normal','Normal')]:
  path=next((SRC/folder).glob('*.fbm/*_'+suffix+'.*'))
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
  # Game textures: retain the supplied sources, cap the embedded copies at 2K.
  if max(tex.image.size)>2048:tex.image.scale(2048,2048)
  tex.image.pack()
  if suffix!='basecolor':tex.image.colorspace_settings.name='Non-Color'
  if suffix=='normal':
   normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs[socket])
  else:links.new(tex.outputs['Color'],p.inputs[socket])
 return m
body.name='WarriorArmor';body.data.materials.clear();body.data.materials.append(material('knight','Knight PBR'))
before=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(next((SRC/'greatsword').glob('*.fbx'))))
sword=next(o for o in set(bpy.data.objects)-before if o.type=='MESH');sword.name='Greatsword'
sword.data.materials.clear();sword.data.materials.append(material('greatsword','Greatsword PBR'))
bpy.context.view_layer.objects.active=sword
bpy.ops.object.select_all(action='DESELECT');sword.select_set(True)
mod=sword.modifiers.new('Game mesh reduction','DECIMATE');mod.ratio=.008
bpy.ops.object.modifier_apply(modifier=mod.name)
# The grip is authored, not guessed. In art/warrior/source/4slah.blend the sword
# is held by a Child Of constraint on mixamorig:RightHand; GRIP is that constraint's
# offset, read straight out of the file. It is a constant offset, so one matrix
# covers every frame - checked across frames 1/40/80/117/160/196 with zero deviation.
# This has to be carried by hand because FBX export silently drops Child Of: the
# sword arrives unparented at its unevaluated transform, which is why the earlier
# heuristic had to infer a grip from the midpoints of the two hand bones.
GRIP=Matrix(((-0.379822,-0.141915,-0.914109,0.842242),
             (-0.924771, 0.033573, 0.379040,0.046414),
             (-0.023102, 0.989310,-0.143990,0.154829),
             ( 0.0,      0.0,      0.0,     1.0)))
bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
r=rig.pose.bones['mixamorig:RightHand']
# GRIP is metric, measured on a rig whose hand sits at 1.96 m. This rig is
# normalised to 1.8 m, so the grip cannot be pasted on at face value: offset and
# blade both have to follow the body down, or the knight swings a sword sized for
# someone taller. Both rigs are the same skeleton, so one bone length is the ratio.
HAND_LEN_AUTHORED=0.130888  # mixamorig:RightHand in 4slah.blend, metres
bone=rig.matrix_world@r.matrix
# The basis magnitude is the rig's own unit normalisation - measured, not read from
# rig.scale, because the Mixamo FBX arrives pre-scaled and rig.scale compounds it.
unit=bone.to_3x3().col[0].length
bone=bone@Matrix.Scale(1.0/unit,4)@Matrix.Scale(rig.data.bones[r.name].length*unit/HAND_LEN_AUTHORED,4)
# Bake vertices into rest-bone space, then bind rigidly to the right-hand bone.
rest=rig.data.bones[r.name].matrix_local
posed=r.matrix
placed=bone@GRIP@sword.matrix_world
# Tip-to-tip length, which unlike a bounding box does not change with orientation.
# Checked here, before the vertices are baked into rest-bone space - measuring after
# the bake reads rest-space coordinates and silently reports half the real figure.
def _diameter(points):
 far=max(points,key=lambda q:(q-points[0]).length)
 return max((q-far).length for q in points)
_ratio=rig.data.bones[r.name].length*unit/HAND_LEN_AUTHORED
_got=_diameter([placed@v.co for v in sword.data.vertices])
print('SWORD_LENGTH got %.4f want %.4f (body ratio %.4f)'%(_got,1.3627*_ratio,_ratio))
assert abs(_got-1.3627*_ratio)<.02, 'grip transform introduced a scale of its own'
convert=rest@posed.inverted()@rig.matrix_world.inverted()@placed
for v in sword.data.vertices:v.co=convert@v.co
sword.matrix_world=rig.matrix_world.copy()
group=sword.vertex_groups.new(name=r.name);group.add(list(range(len(sword.data.vertices))),1,'REPLACE')
arm=sword.modifiers.new('Right hand attachment','ARMATURE');arm.object=rig
sword.parent=rig;sword.matrix_parent_inverse=Matrix.Identity(4);sword.matrix_basis=Matrix.Identity(4)
# Explicit NLA strips provide stable, separate named glTF clips.
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name
 strip=track.strips.new(name,1,action);strip.action_slot=action.slots[0]
 track.mute=True
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,body,sword]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
# Export each action without relying on object names imported from other FBXs.
bpy.context.scene.render.fps=60;bpy.context.scene.render.fps_base=1.0
bpy.ops.export_scene.gltf(filepath=str(ROOT/'godot/assets/models/warrior_player.glb'),export_format='GLB',use_selection=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_anim_slide_to_zero=True)
rig.animation_data.action=actions['Idle'];rig.animation_data.action_slot=actions['Idle'].slots[0]
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath='/tmp/warrior_review.blend')
if optional:print('BUILT WITHOUT: %s'%', '.join(optional))
print('WARRIOR_BUILD',len(body.data.vertices),len(sword.data.vertices),[(n,tuple(a.frame_range)) for n,a in actions.items()])
