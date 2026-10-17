"""Build the Vesper playable character from the supplied Mixamo FBXs."""

from pathlib import Path
import json
import math

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "art/agile_warrior"
ANIMS = HERE / "source/animations"
OUTPUT = ROOT / "unity/Assets/Bloodwake/Resources/Models/vesper_player/vesper_player.fbx"
OUTPUT_FOLDER = OUTPUT.parent
BLEND = HERE / "vesper_animated.blend"
CLIPS = ["Idle", "Run", "Attack1", "Attack2", "Attack3", "DashAttack", "CastQ", "Ultimate", "Death"]


def new_objects(before):
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def remove_objects(objects):
    for obj in list(objects):
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)


def import_fbx(name):
    before = set(bpy.context.scene.objects)
    old_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(ANIMS / f"{name}.fbx"), use_anim=True)
    objects = new_objects(before)
    rig = next(obj for obj in objects if obj.type == "ARMATURE")
    body = next(obj for obj in objects if obj.type == "MESH")
    action = next(iter(set(bpy.data.actions) - old_actions))
    action.name = f"SOURCE_{name}"
    action.use_fake_user = True
    return rig, body, action, objects


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 60
OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)


def save_basecolor(material, filename):
    image = next(
        node.image for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE" and node.image
    )
    image.save_render(str(OUTPUT_FOLDER / filename), scene=scene)

# Preserve the authored PBR look from the textured character GLB.
bpy.ops.import_scene.gltf(filepath=str(HERE / "source/character/vesper_character.glb"))
reference_objects = list(scene.objects)
reference_mesh = next(obj for obj in reference_objects if obj.type == "MESH")
source_reference_materials = [material for material in reference_mesh.data.materials if material]
save_basecolor(source_reference_materials[0], "Vesper_Armor_Albedo.png")
reference_materials = [material.copy() for material in source_reference_materials]
reference_materials[0].name = "Vesper Armor PBR"
for material in reference_materials:
    if material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image and node.image.has_data:
                node.image.pack()
remove_objects(reference_objects)

# Idle is the canonical source rig. A duplicate becomes the normalized game rig;
# every action is sampled from the untouched source to avoid FBX unit/axis offsets.
source, source_body, idle_source, idle_objects = import_fbx("Idle")
source.name = "VesperSourceRig"
source_rest = {bone.name: source.matrix_world @ bone.matrix_local for bone in source.data.bones}

rig = source.copy()
rig.data = source.data.copy()
rig.animation_data_clear()
rig.name = "VesperRig"
scene.collection.objects.link(rig)
body = source_body.copy()
body.data = source_body.data.copy()
body.animation_data_clear()
body.name = "VesperArmor"
scene.collection.objects.link(body)
body.data.materials.clear()
for material in reference_materials:
    body.data.materials.append(material)

world_points = [source_body.matrix_world @ vertex.co for vertex in source_body.data.vertices]
low = min(point.z for point in world_points)
high = max(point.z for point in world_points)
normalise = Matrix.Scale(1.8 / (high - low), 4) @ Matrix.Translation((0.0, 0.0, -low))
body.data.transform(normalise @ source_body.matrix_world)
body.parent = rig
body.matrix_parent_inverse = Matrix.Identity(4)
body.matrix_world = Matrix.Identity(4)
body.matrix_basis = Matrix.Identity(4)
rig.data.transform(normalise @ source.matrix_world)
rig.matrix_world = Matrix.Identity(4)
for modifier in body.modifiers:
    if modifier.type == "ARMATURE":
        modifier.object = rig

# Collect all source actions. The armatures are structurally identical, so each
# action can be evaluated on the canonical source rig before being baked.
source_actions = {"Idle": idle_source}
donor_objects = []
for name in CLIPS[1:]:
    donor, donor_body, action, objects = import_fbx(name)
    source_actions[name] = action
    donor.animation_data.action = None
    donor_objects.extend(objects)
remove_objects(donor_objects)

source.animation_data_create()
rig.animation_data_create()
root_name = "mixamorig:Hips"
# Pose locations are stored in armature-local FBX units. Convert those channels
# by the combined FBX object scale and our height-normalisation scale.
ratio = (1.8 / (high - low)) * source.matrix_world.to_scale().x
matched = [bone for bone in rig.pose.bones if bone.name in source.pose.bones]
baked = {}
report = {}
for name in CLIPS:
    old = source_actions[name]
    source.animation_data.action = old
    if hasattr(old, "slots") and len(old.slots):
        source.animation_data.action_slot = old.slots[0]
    new = bpy.data.actions.new(name)
    rig.animation_data.action = new
    start, end = old.frame_range
    count = int(math.ceil(end - start))
    for frame in range(count + 1):
        time = min(start + frame, end)
        scene.frame_set(int(time), subframe=time - int(time))
        bpy.context.view_layer.update()
        # Every supplied FBX uses the same Mixamo rest skeleton. Copy local pose
        # channels directly; only translations need the canonical scale ratio.
        # Reconstructing world matrices here twists parent/child rotations.
        for bone in matched:
            donor = source.pose.bones[bone.name]
            bone.rotation_mode = "QUATERNION"
            bone.location = donor.location * ratio
            bone.rotation_quaternion = donor.rotation_quaternion.copy()
            bone.scale = donor.scale.copy()
        # In place: everything but the locomotion loops keeps the Hips at their
        # standing ground position, so lunges no longer snap back at the end.
        # Vertical travel (crouch, jump, fall) is kept.
        # Anchored to Idle's opening stance so blends in and out of idle don't shift either.
        hips = rig.pose.bones[root_name]
        rest = rig.data.bones[root_name].matrix_local.to_3x3()
        planar = rest @ hips.location
        if name == "Idle" and frame == 0:
            anchor = planar.copy()
        if name not in ("Idle", "Run"):
            planar.x, planar.y = anchor.x, anchor.y
            hips.location = rest.inverted() @ planar
        bpy.context.view_layer.update()
        for bone in matched:
            bone.rotation_mode = "QUATERNION"
            bone.keyframe_insert("rotation_quaternion", frame=time - start)
            bone.keyframe_insert("location", frame=time - start)
            bone.keyframe_insert("scale", frame=time - start)
    new.use_fake_user = True
    baked[name] = new
    report[name] = {"seconds": (end - start) / 60.0, "frames": count + 1}

source.animation_data.action = None
rig.animation_data.action = None
remove_objects(idle_objects)
for old in source_actions.values():
    old.use_fake_user = False
    if old.users == 0:
        bpy.data.actions.remove(old)

# Create explicit grip/mid/tip bones. They make the sword bind deterministic and
# give Unity exact anchors for the flame ribbon instead of guessing renderer bounds.
hand_name = "mixamorig:RightHand"
# The grip comes from the rest skeleton, not from one hand-tuned idle frame:
# the handle sits inside the closed fingers (62% from wrist to knuckles) and
# runs along the fist's pinky-to-index axis, so it holds in every clip.
rest_bones = rig.data.bones
def rest_head(name):
    return rest_bones["mixamorig:" + name].head_local.copy()
knuckles = (rest_head("RightHandIndex1") + rest_head("RightHandMiddle1") + rest_head("RightHandRing1")) / 3
hand_axis = (knuckles - rest_head("RightHand")).normalized()
blade_direction = (rest_head("RightHandIndex1") - rest_head("RightHandPinky1"))
blade_direction = (blade_direction - hand_axis * blade_direction.dot(hand_axis)).normalized()
grip_position = rest_head("RightHand").lerp(knuckles, .62)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
edit=rig.data.edit_bones
grip=edit.new('VesperSwordGrip');grip.head=grip_position;grip.tail=grip_position+blade_direction*.16;grip.parent=edit[hand_name];grip.use_connect=False
mid=edit.new('VesperSwordMid');mid.head=grip_position+blade_direction*.78;mid.tail=mid.head+blade_direction*.07;mid.parent=grip;mid.use_connect=False
tip=edit.new('VesperSwordTip');tip.head=grip_position+blade_direction*1.48;tip.tail=tip.head+blade_direction*.07;tip.parent=grip;tip.use_connect=False
bpy.ops.object.mode_set(mode='OBJECT')

before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=str(HERE / "source/sword/fiery_sword_v1.glb"))
sword_objects = new_objects(before)
sword = max((obj for obj in sword_objects if obj.type == "MESH"),key=lambda obj:len(obj.data.vertices))
sword.name = "FierySword"
sword_material=next(material for material in sword.data.materials if material)
sword_material.name="Vesper Sword PBR"
save_basecolor(sword_material,"Vesper_Sword_Albedo.png")
sword_points = [sword.matrix_world @ vertex.co for vertex in sword.data.vertices]
sword_length = max(point.z for point in sword_points) - min(point.z for point in sword_points)
wide_x = (max(p.x for p in sword_points) - min(p.x for p in sword_points)) >= (max(p.y for p in sword_points) - min(p.y for p in sword_points))
edge = (hand_axis - blade_direction * hand_axis.dot(blade_direction)).normalized()
side = blade_direction.cross(edge)
x_axis, y_axis = (edge, side) if wide_x else (-side, edge)
blade_rotation = Matrix((x_axis, y_axis, blade_direction)).transposed().to_4x4()
sword_scale=1.58/sword_length
# The mesh origin is the pommel; the actual palm closes roughly 10.5% up the
# authored sword. Move that grip point to the socket rather than the pommel.
sword_world = Matrix.Translation(grip_position) @ blade_rotation @ Matrix.Scale(sword_scale,4) @ Matrix.Translation((0,0,-.105))
sword.data.transform(sword_world @ sword.matrix_world)
sword.parent = rig
sword.parent_type = "OBJECT"
sword.matrix_parent_inverse = Matrix.Identity(4)
sword.matrix_world = Matrix.Identity(4)
sword.matrix_basis = Matrix.Identity(4)
for group in list(sword.vertex_groups):sword.vertex_groups.remove(group)
hand_group=sword.vertex_groups.new(name='VesperSwordGrip')
hand_group.add(list(range(len(sword.data.vertices))),1.0,'REPLACE')
armature=sword.modifiers.new('VesperSwordArmature','ARMATURE');armature.object=rig
for obj in sword_objects:
    if obj != sword and obj.name in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
for image in bpy.data.images:
    if image.source == "FILE" and image.has_data:
        image.pack()

with open(OUTPUT_FOLDER/'materials.json','w',encoding='utf-8') as target:
    json.dump({
        'Vesper Armor PBR': {'color':[1,1,1,1],'alpha':1,'metallic':.2,'roughness':.48,'albedo':'Vesper_Armor_Albedo.png'},
        'Vesper Sword PBR': {'color':[1,1,1,1],'alpha':1,'metallic':.55,'roughness':.32,'albedo':'Vesper_Sword_Albedo.png'},
    },target,indent=2)

for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
for name in CLIPS:
    action = baked[name]
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action)
    if hasattr(action, "slots") and len(action.slots):
        strip.action_slot = action.slots[0]
    # The FBX exporter creates one Unity clip per non-muted NLA strip.
    track.mute = False

scene.render.fps = 60
scene.frame_set(0)
body.matrix_basis = Matrix.Identity(4)
bpy.ops.object.select_all(action="DESELECT")
for obj in (rig, body, sword):
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.fbx(
    filepath=str(OUTPUT), use_selection=True, apply_unit_scale=True,
    bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=True,
    bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0,
    add_leaf_bones=False, path_mode="COPY", embed_textures=True,
)
print("VESPER_BUILD", json.dumps(report), flush=True)
