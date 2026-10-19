# Builds the player Mage from the delivered sorceress (19 Oct 2026):
#   sorceress-20261019/sorceress_mixamo_rigged.fbx  Mixamo auto-rig, no materials
#   sorceress-20261019/sorceress_basecolor.jpg / _normal.png  Tripo 4K maps (same UVs)
#   source/mixamo/mage *.fbx  the Mage's Mixamo clips, copied across by bone name, plus the enemy mage's
#   one-hand bolt and two-hand ground cast (art/enemies/mixamo/mage) for the R1/R2 kit
# Output: unity/Assets/Bloodwake/Resources/Models/mage_sorceress/ (fbx + maps + materials.json),
# then Unity menu Bloodwake -> Import Mage Sorceress.
#   blender -b --factory-startup --python art/mage/build_sorceress.py
import bpy, os, json, shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "sorceress-20261019")
CLIPS = os.path.join(HERE, "source", "mixamo")
KIT = os.path.normpath(os.path.join(HERE, "..", "enemies", "mixamo", "mage"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "unity", "Assets", "Bloodwake", "Resources", "Models", "mage_sorceress"))
TAKES = {os.path.join(CLIPS, "mage idle.fbx"): "Idle", os.path.join(CLIPS, "mage walk.fbx"): "Run",
         os.path.join(CLIPS, "mage attack.fbx"): "Attack", os.path.join(CLIPS, "mage hit.fbx"): "Hit",
         os.path.join(CLIPS, "mage death.fbx"): "Death", os.path.join(CLIPS, "mage ulti.fbx"): "Ultimate",
         os.path.join(KIT, "Standing 1H Magic Attack 01.fbx"): "Mage_Backhand",
         os.path.join(KIT, "Standing 2H Magic Area Attack 01.fbx"): "Mage_GroundCast"}
HEIGHT = 1.8

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 60

def imported(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    return [o for o in bpy.data.objects if o not in before]

def world_height(mesh):
    zs = [(mesh.matrix_world @ Vector(c)).z for c in mesh.bound_box]
    return min(zs), max(zs)

new = imported(os.path.join(SRC, "sorceress_mixamo_rigged.fbx"))
rig = next(o for o in new if o.type == "ARMATURE")
body = next(o for o in new if o.type == "MESH")
for o in new:
    if o.animation_data: o.animation_data_clear()
rig.name = rig.data.name = "MageRig"
body.name = body.data.name = "MageBody"
if not body.data.uv_layers: raise SystemExit("rigged mesh has no UVs")

# Stand at 1.8 m with the feet on the origin; bake the scale into the rig.
bpy.context.view_layer.update()
low, high = world_height(body)
factor = HEIGHT / (high - low)
rig.scale = rig.scale * factor
bpy.context.view_layer.update()
low, _ = world_height(body)
rig.location.z -= low
bpy.context.view_layer.update()
for o in (rig, body):
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
low, high = world_height(body)
print(f"SORCERESS_HEIGHT {high - low:.3f} m (scale x{factor:.4f})")

# One material, named for materials.json.
material = bpy.data.materials.new("Mage Sorceress")
material.use_nodes = True
nodes = material.node_tree.nodes
bsdf = nodes["Principled BSDF"]
color = nodes.new("ShaderNodeTexImage"); color.image = bpy.data.images.load(os.path.join(SRC, "sorceress_basecolor.jpg"))
normal = nodes.new("ShaderNodeTexImage"); normal.image = bpy.data.images.load(os.path.join(SRC, "sorceress_normal.png")); normal.image.colorspace_settings.name = "Non-Color"
bump = nodes.new("ShaderNodeNormalMap")
links = material.node_tree.links
links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
links.new(normal.outputs["Color"], bump.inputs["Color"]); links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
body.data.materials.clear(); body.data.materials.append(material)

def hips_height(armature):
    bone = next(b for b in armature.data.bones if b.name.endswith("Hips"))
    return (armature.matrix_world @ bone.head_local).z

target_hips = hips_height(rig)
rig.animation_data_create()
for file, take in TAKES.items():
    objs = imported(file)
    source = next(o for o in objs if o.type == "ARMATURE")
    action = source.animation_data.action
    # Hip travel in the source rig's own bone units -> the sorceress's.
    src_bone = next(b for b in source.data.bones if b.name.endswith("Hips"))
    dst_bone = next(b for b in rig.data.bones if b.name.endswith("Hips"))
    ratio = dst_bone.head_local.length / max(1e-6, src_bone.head_local.length)
    out = bpy.data.actions.new(take)
    copied = 0
    for curve in action.fcurves:
        path = curve.data_path
        if not path.startswith('pose.bones["'): continue
        bone = path.split('"')[1]
        if bone not in rig.pose.bones: continue
        is_location = path.endswith(".location")
        if is_location and not bone.endswith("Hips"): continue  # would stretch the limbs
        if path.endswith(".scale"): continue
        new_curve = out.fcurves.new(path, index=curve.array_index, action_group=bone)
        points = [(k.co.x, k.co.y) for k in curve.keyframe_points]
        if is_location:
            # Planar travel removed (x/z of the Mixamo hip bone), height kept; all scaled to this body.
            first = points[0][1]
            points = [(x, (y if curve.array_index == 1 else first) * ratio) for x, y in points]
        new_curve.keyframe_points.add(len(points))
        for k, (x, y) in zip(new_curve.keyframe_points, points):
            k.co = (x, y); k.interpolation = "LINEAR"
        copied += 1
    start, end = action.frame_range
    print(f"SORCERESS_CLIP {take} from '{os.path.basename(file)}' curves={copied} frames={start:.0f}-{end:.0f} hipRatio={ratio:.4f}")
    if copied < 40: raise SystemExit(f"too few curves for {take}")
    out.use_fake_user = True
    track = rig.animation_data.nla_tracks.new(); track.name = take
    track.strips.new(take, int(start), out)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.name not in TAKES.values(): bpy.data.actions.remove(a)
for o in list(bpy.data.objects):
    if o not in (rig, body): bpy.data.objects.remove(o, do_unlink=True)

os.makedirs(OUT, exist_ok=True)
shutil.copyfile(os.path.join(SRC, "sorceress_basecolor.jpg"), os.path.join(OUT, "sorceress_basecolor.jpg"))
# The normal map is left out of the game: with it URP Lit shaded the skinned body invisible (tangents); see git log.
with open(os.path.join(OUT, "materials.json"), "w") as f:
    json.dump({"Mage Sorceress": {"color": [1, 1, 1, 1], "alpha": 1, "metallic": 0, "roughness": .62,
                                  "albedo": "sorceress_basecolor.jpg"}}, f, indent=2)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "mage_sorceress.fbx"), use_selection=False, object_types={"ARMATURE", "MESH"},
                         add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=True,
                         bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0, path_mode="STRIP", embed_textures=False,
                         apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True, armature_nodetype="NULL")
print("SORCERESS_BUILD_DONE", OUT)
