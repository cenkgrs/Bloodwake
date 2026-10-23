# Builds the player Mage from the sorceress (v3, 20 Oct 2026):
#   sorceress-20261020/sorceress_mixamo_rigged.fbx  Mixamo auto-rig of the Tripo body with the separately
#     generated Tripo head swapped in (sorceress_headswap.blend); materials "Body" and "Head"
#   sorceress-20261020/sorceress_* (body: base colour, normal, roughness, metallic, 4K) and head_* (base, normal)
#   source/mixamo-sorceress/*.fbx  her Mixamo clips (falls back to the old source/mixamo/mage *.fbx per clip),
#     copied across by bone name, plus the enemy mage's one-hand bolt and two-hand ground cast for the R1/R2 kit
# Output: unity/Assets/Bloodwake/Resources/Models/mage_sorceress/ (fbx + maps + materials.json),
# then Unity menu Bloodwake -> Import Mage Sorceress.
#   blender -b --factory-startup --python art/mage/build_sorceress.py
import bpy, os, json, shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "sorceress-20261020")
CLIPS = os.path.join(HERE, "source", "mixamo-sorceress")
OLD_CLIPS = os.path.join(HERE, "source", "mixamo")
KIT = os.path.normpath(os.path.join(HERE, "..", "enemies", "mixamo", "mage"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "unity", "Assets", "Bloodwake", "Resources", "Models", "mage_sorceress"))
RAW = os.path.join(CLIPS, "raw")
# Each take: one or more (file, start s, end s) pieces laid end to end (None = whole clip). Cast windows cut the
# long Mixamo lead-ins/tails so the release lands where MageKit fires: R1-1 at 45% of its hold, R1-2 53%,
# R1-3 62%, R2 45%; the comet's arms rise at ~50%; the hurl releases almost at once.
def raw(name): return os.path.join(RAW, name + ".fbx")
TAKES = {
    "Idle": [(raw("Catwalk Idle Twist R"), None, None), (raw("Catwalk Twist R To Twist L"), None, None),
             (raw("Catwalk Twist L To Twist R(1)"), None, None)],          # ends in the pose it starts: loops
    "Run": [(raw("Slow Run"), None, None)],
    "Walk": [(raw("Catwalk Walk Forward Crossed"), None, None)],
    "Attack": [(raw("Standing 1H Magic Attack 01"), .55, 1.50)],           # right hand
    "Mage_Backhand": [(raw("Standing 1H Magic Attack 01(1)"), .47, 1.47)],  # the mirrored take: left hand
    "Mage_GroundCast": [(raw("Standing 2H Magic Area Attack 02(1)"), 1.00, 2.37)],
    "Ultimate": [(raw("Standing 2H Magic Attack 04"), .55, 1.50)],
    "Mage_Comet": [(raw("Standing 2H Magic Attack 05(1)"), 1.35, 2.25)],
    "Mage_Hurl": [(raw("Standing 1H Magic Attack 03"), .70, 1.40)],
    "Hit": [(raw("Light Hit To Head"), None, None)],
    # E (void leap): the fall loop while she is in the air, the landing (feet down at ~0.05 s) when she arrives.
    "Mage_Fall": [(raw("Fall A Loop"), None, None)],
    "Mage_Land": [(raw("Fall A Land To Standing Idle 01"), None, None)],
    # Shift (glide): the airborne stretch of Mixamo's Jump (feet up 0.10-0.65 s, peak 0.35 s); its own rise is
    # flattened since the game lifts her, and the spine/head untwisted to face the way she glides.
    "Mage_Glide": [(raw("Jump"), .12, .62)],
    "Hit2": [(raw("Head Hit"), None, None)],
    "Death": [(os.path.join(CLIPS, "death.fbx") if os.path.exists(os.path.join(CLIPS, "death.fbx"))
               else os.path.join(OLD_CLIPS, "mage death.fbx"), None, None)],
}
HEIGHT = 1.8
# Mage_Glide: limbs eased this far toward the first frame of her idle, so the glide floats instead of flailing.
GLIDE_BLEND = {}  # limb easing toward the idle (used with the fall loop; the jump pose is kept as authored)
GLIDE_POSE = raw("Catwalk Idle Twist R")

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
# The head was joined from a mesh with a differently named UV map, so its UVs sit in a second layer:
# move them into the first (the one Unity reads) and drop the second.
import numpy as np
me = body.data
if len(me.uv_layers) > 1:
    first, second = me.uv_layers[0], me.uv_layers[1]
    a = np.empty(len(me.loops) * 2, np.float32); first.data.foreach_get("uv", a)
    b = np.empty(len(me.loops) * 2, np.float32); second.data.foreach_get("uv", b)
    used = np.any(np.abs(b.reshape(-1, 2)) > 1e-6, axis=1)
    a = a.reshape(-1, 2); a[used] = b.reshape(-1, 2)[used]
    first.data.foreach_set("uv", a.ravel()); me.uv_layers.remove(second)
    print(f"SORCERESS_UV merged {int(used.sum())} head loops into {first.name}")

# The concept gave her short arms (span 0.73 of height, a forearm half the upper arm's length) and Mixamo put
# the elbow and wrist joints below the sleeve. Stretch each arm outward from a quarter of the way down the upper
# arm (shoulder armour and cape stay put) to the wrist, carry the hand out unchanged, and seat the elbow and
# wrist joints in the middle of the stretched sleeve. Each vertex moves by its own arm skin weight, so the arm
# blends into the body without a seam; UVs are untouched.
ARM_STRETCH = 1.45
def stretch_arms():
    bpy.context.view_layer.update()
    mw, aw = body.matrix_world, rig.matrix_world
    world = lambda b, tail=False: aw @ (b.tail_local if tail else b.head_local)
    bones = {b.name.split(":")[-1]: b for b in rig.data.bones}
    verts = body.data.vertices; groups = {g.index: g.name.split(":")[-1] for g in body.vertex_groups}
    co = [mw @ v.co for v in verts]
    moved_bones = {}
    for side in ("Left", "Right"):
        sh, el, wr = world(bones[side + "Arm"]), world(bones[side + "ForeArm"]), world(bones[side + "Hand"])
        sign = 1 if wr.x > sh.x else -1
        xs = sh.x + .25 * (el.x - sh.x)
        def mapped(x):
            d = (x - xs) * sign
            if d <= 0: return x
            span = (wr.x - xs) * sign
            return xs + sign * (d * ARM_STRETCH if d <= span else span * ARM_STRETCH + (d - span))
        chain = {n for n in bones if n.startswith(side) and ("Arm" in n or "Hand" in n)}
        for i, v in enumerate(verts):
            w = sum(g.weight for g in v.groups if groups.get(g.group) in chain)
            if w <= 0: continue
            p = co[i]; dx = (mapped(p.x) - p.x) * min(1.0, w)
            co[i] = Vector((p.x + dx, p.y, p.z))
        # the sleeve's middle at a given x, for seating a joint inside it
        def sleeve_middle(x):
            near = [co[i] for i, v in enumerate(verts) if abs(co[i].x - x) < .012 and
                    sum(g.weight for g in v.groups if groups.get(g.group) in chain) > .5]
            if len(near) < 6: return None
            return Vector((x, sum(q.y for q in near) / len(near), sum(q.z for q in near) / len(near)))
        for n in chain:
            b = bones[n]; head, tail = world(b), world(b, True)
            nh = Vector((mapped(head.x), head.y, head.z)); nt = Vector((mapped(tail.x), tail.y, tail.z))
            moved_bones[b.name] = [nh, nt]
        for n in (side + "ForeArm", side + "Hand"):
            name = bones[n].name; mid = sleeve_middle(moved_bones[name][0].x)
            if mid:
                delta = mid - moved_bones[name][0]
                for other in chain:  # the joint and everything hanging from it follow
                    on = bones[other].name
                    if bones[other] == bones[n] or bones[other].parent_recursive.count(bones[n]):
                        moved_bones[on] = [moved_bones[on][0] + delta, moved_bones[on][1] + delta]
                parent = bones[n].parent.name; moved_bones[parent][1] = moved_bones[name][0]
        print(f"SORCERESS_ARM {side}: stretched {xs:.3f}->{wr.x:.3f} x{ARM_STRETCH}")
    inv = mw.inverted()
    for i, v in enumerate(verts): v.co = inv @ co[i]
    bpy.context.view_layer.objects.active = rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT"); ainv = aw.inverted()
    for name, (h, t) in moved_bones.items():
        eb = rig.data.edit_bones[name]; eb.head = ainv @ h; eb.tail = ainv @ t
    bpy.ops.object.mode_set(mode="OBJECT"); rig.select_set(False)
    bpy.context.view_layer.update()
    lo_x = min((mw @ v.co).x for v in verts); hi_x = max((mw @ v.co).x for v in verts)
    zs = [(mw @ v.co).z for v in verts]
    print(f"SORCERESS_ARM span/height {(hi_x - lo_x) / (max(zs) - min(zs)):.2f}")
stretch_arms()

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

# Tripo left the back open where the concept's ponytail hid it: a slit down the spine (z 1.23-1.50 m) and a few
# smaller holes beside it, through which the inside of the chest shows from behind. Cap every open body loop on
# the back (not the neck opening the head sits in) from its own rim vertices, so the rig weights carry over, and
# texture the cap with one texel of the leather beside it rather than stretching atlas islands across the gap.
def fill_back_holes():
    import bmesh
    me = body.data
    bm = bmesh.new(); bm.from_mesh(me); uv = bm.loops.layers.uv.active
    body_slot = next(i for i, s in enumerate(body.material_slots) if s.material and s.material.name.startswith("Body"))
    seen, filled = set(), 0
    for edge in [e for e in bm.edges if e.is_boundary]:
        if edge in seen: continue
        stack, rim = [edge], []
        while stack:
            e = stack.pop()
            if e in seen: continue
            seen.add(e); rim.append(e)
            stack += [x for v in e.verts for x in v.link_edges if x.is_boundary and x not in seen]
        verts = {v for e in rim for v in e.verts}
        if len(rim) < 8 or any(f.material_index != body_slot for e in rim for f in e.link_faces): continue
        centre = sum((v.co for v in verts), Vector()) / len(verts)
        if centre.y < .02 or not 1.1 < centre.z or max(v.co.z for v in verts) > 1.535: continue
        texel = LEATHER_UV
        new = bmesh.ops.holes_fill(bm, edges=rim, sides=0)["faces"]
        new = bmesh.ops.triangulate(bm, faces=new, quad_method="BEAUTY", ngon_method="BEAUTY")["faces"]
        for f in new:
            f.material_index = body_slot; f.smooth = True
            for l in f.loops: l[uv].uv = texel
        bmesh.ops.recalc_face_normals(bm, faces=list({g for f in new for e in f.edges for g in e.link_faces}))
        filled += 1
    bm.to_mesh(me); bm.free(); me.update()
    print(f"SORCERESS_HOLES filled {filled} back openings")

# The swapped-out Tripo ponytail had its hair colour painted on the upper back beneath it: once the hair was
# cut away those faces showed as blocky light-brown patches. Faces on the upper back whose texture reads as that
# hair brown are pointed at one texel of the dark leather around them instead (the hole caps use it too), and the
# gold filigree and straps keep their own texture since only whole faces of hair brown are moved.
def back_leather():
    import numpy as np, colorsys
    img = bpy.data.images.load(os.path.join(SRC, "sorceress_basecolor.jpg"))
    w, h = img.size; px = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(h, w, 4)
    bpy.data.images.remove(img)
    me, mw = body.data, body.matrix_world; uv = me.uv_layers.active.data
    body_slot = next(i for i, s in enumerate(body.material_slots) if s.material and s.material.name.startswith("Body"))
    def colour(u, v):
        x, y = int(u % 1 * (w - 1)), int(v % 1 * (h - 1)); patch = px[max(0, y - 2):y + 3, max(0, x - 2):x + 3, :3]
        return patch.reshape(-1, 3).mean(axis=0)
    faces, hair = [], []
    for p in me.polygons:
        c = mw @ p.center
        if p.material_index != body_slot or not (c.y > 0 and 1.1 < c.z < 1.58 and abs(c.x) < .17): continue
        us = [uv[l].uv for l in p.loop_indices]; u = sum(a[0] for a in us) / len(us); v = sum(a[1] for a in us) / len(us)
        r, g, b = colour(u, v); hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
        (hair if 10 / 360 < hh < 38 / 360 and ss > .35 and .16 < vv < .62 else faces).append((p, (u, v), vv, ss))
    dark = sorted((f for f in faces if f[3] < .4 and .05 < f[2] < .3), key=lambda f: f[2])
    pick = dark[len(dark) // 6] if dark else faces[0]
    for p, _, _, _ in hair:
        for l in p.loop_indices: uv[l].uv = pick[1]
    me.update()
    print(f"SORCERESS_BACK {len(hair)} hair-brown faces of {len(hair) + len(faces)} -> leather texel {pick[1][0]:.3f},{pick[1][1]:.3f}")
    return Vector(pick[1])
LEATHER_UV = back_leather()
fill_back_holes()

# Two materials, named for materials.json: the Tripo body and the swapped-in head (slot order kept from the rig).
names = {"Body": "Mage Sorceress Body", "Head": "Mage Sorceress Head"}
for slot in body.material_slots:
    if slot.material and slot.material.name.split(".")[0] in names: slot.material.name = names[slot.material.name.split(".")[0]]
found = sorted(s.material.name for s in body.material_slots if s.material)
if found != sorted(names.values()): raise SystemExit(f"rig materials {found}, expected Body and Head")

def hips_height(armature):
    bone = next(b for b in armature.data.bones if b.name.endswith("Hips"))
    return (armature.matrix_world @ bone.head_local).z

# Blender 4.4+ keeps an action's curves in layered channel bags (5.x has no Action.fcurves); support both.
def action_curves(action):
    if hasattr(action, "fcurves"): return list(action.fcurves)
    return [c for layer in action.layers for strip in layer.strips for bag in strip.channelbags for c in bag.fcurves]
def new_curve_for(action, path, index, group):
    if hasattr(action, "fcurves"): return action.fcurves.new(path, index=index, action_group=group)
    return action.fcurve_ensure_for_datablock(rig, path, index=index, group_name=group)

# The fall loop turns her body to the right and tips her head down. For the glide: take the twist about the
# spine's own axis out of the hips and spine (she faces where she glides) and lift the chin a little.
GLIDE_UNTWIST = ("Hips", "Spine", "Spine1", "Spine2", "Neck", "Head")  # head too: the loop looks off to the left
GLIDE_CHIN_UP = {"Neck": 14, "Head": 26}  # degrees, about each bone's sideways axis
def straighten_glide(action):
    from mathutils import Quaternion
    import math
    by_bone = {}
    for c in action_curves(action):
        if c.data_path.endswith("rotation_quaternion"): by_bone.setdefault(c.data_path.split('"')[1], {})[c.array_index] = c
    for bone, comps in by_bone.items():
        part = bone.split(":")[-1]
        if len(comps) < 4 or (part not in GLIDE_UNTWIST and part not in GLIDE_CHIN_UP): continue
        keys = [comps[i].keyframe_points for i in range(4)]
        for k in range(len(keys[0])):
            q = Quaternion([keys[i][k].co[1] for i in range(4)])
            if part in GLIDE_UNTWIST:
                twist = Quaternion((q.w, 0, q.y, 0)); twist.normalize()  # bone Y runs along the spine
                q = q @ twist.inverted()
            if part in GLIDE_CHIN_UP:
                q = q @ Quaternion((1, 0, 0), math.radians(-GLIDE_CHIN_UP[part]))
            for i in range(4): keys[i][k].co[1] = q[i]
        for i in range(4): comps[i].update()
    print("SORCERESS_GLIDE straightened")

target_hips = hips_height(rig)
rig.animation_data_create()
# Rest values for GLIDE_BLEND: every rotation curve of the idle's first frame, keyed (path, index).
def glide_weight(bone):
    part = bone.split(":")[-1]
    for side in ("Left", "Right"):
        if part.startswith(side) and part[len(side):] in GLIDE_BLEND: return GLIDE_BLEND[part[len(side):]]
    return 0
objs = imported(GLIDE_POSE); pose_source = next(o for o in objs if o.type == "ARMATURE").animation_data.action
glide_pose = {(c.data_path, c.array_index): c.evaluate(pose_source.frame_range[0]) for c in action_curves(pose_source)
              if c.data_path.endswith("rotation_quaternion")}
for o in objs: bpy.data.objects.remove(o, do_unlink=True)
for take, pieces in TAKES.items():
    out = bpy.data.actions.new(take)
    if not hasattr(out, "fcurves"): rig.animation_data.action = out  # 5.x creates curves through the rig's slot
    curves, offset, copied = {}, 0.0, 0
    for file, start_s, end_s in pieces:
        objs = imported(file)
        source = next(o for o in objs if o.type == "ARMATURE")
        action = source.animation_data.action
        f0, f1 = action.frame_range
        lo = f0 + (start_s or 0) * scene.render.fps
        hi = f1 if end_s is None else f0 + end_s * scene.render.fps
        # Hip travel in the source rig's own bone units -> the sorceress's.
        src_bone = next(b for b in source.data.bones if b.name.endswith("Hips"))
        dst_bone = next(b for b in rig.data.bones if b.name.endswith("Hips"))
        ratio = dst_bone.head_local.length / max(1e-6, src_bone.head_local.length)
        for curve in action_curves(action):
            path = curve.data_path
            if not path.startswith('pose.bones["'): continue
            bone = path.split('"')[1]
            if bone not in rig.pose.bones: continue
            is_location = path.endswith(".location")
            if is_location and not bone.endswith("Hips"): continue  # would stretch the limbs
            if path.endswith(".scale"): continue
            key = (path, curve.array_index)
            if key not in curves: curves[key] = new_curve_for(out, path, curve.array_index, bone)
            # Sample every frame of the window (keys are per-frame from Mixamo; sampling also cuts cleanly mid-key).
            frames = [lo + i for i in range(int(round(hi - lo)) + 1)]
            points = [(offset + (f - lo), curve.evaluate(f)) for f in frames]
            w = glide_weight(bone) if take == "Mage_Glide" and path.endswith("rotation_quaternion") else 0
            if w and (path, curve.array_index) in glide_pose:
                # Keep the rest quaternion in the same hemisphere as the clip's own first frame before mixing.
                prefix = path
                first_src = [next((c for c in action_curves(action) if c.data_path == prefix and c.array_index == i), None) for i in range(4)]
                ref = [glide_pose.get((prefix, i), 0) for i in range(4)]
                if all(first_src) and sum(c.evaluate(lo) * r for c, r in zip(first_src, ref)) < 0: ref = [-r for r in ref]
                rest = ref[curve.array_index]
                points = [(x, y + (rest - y) * w) for x, y in points]
            if is_location:
                # Planar travel removed (x/z of the Mixamo hip bone), height kept; all scaled to this body.
                first = curve.evaluate(lo)
                keep_height = curve.array_index == 1 and take != "Mage_Glide"
                points = [(x, (y if keep_height else first) * ratio) for x, y in points]
            target = curves[key]; base = len(target.keyframe_points); target.keyframe_points.add(len(points))
            for k, (x, y) in zip(target.keyframe_points[base:], points):
                k.co = (x + 1, y); k.interpolation = "LINEAR"
        copied = len(curves)
        print(f"SORCERESS_CLIP {take} <- '{os.path.basename(file)}' {(start_s or 0):.2f}-{(hi - f0) / scene.render.fps:.2f}s "
              f"at {offset / scene.render.fps:.2f}s hipRatio={ratio:.4f}")
        offset += hi - lo + 1
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    if copied < 40: raise SystemExit(f"too few curves for {take}")
    if take == "Mage_Glide": straighten_glide(out)
    out.use_fake_user = True
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new(); track.name = take
    strip = track.strips.new(take, 1, out)
    if hasattr(strip, "action_slot") and out.slots: strip.action_slot = out.slots[0]
    print(f"SORCERESS_TAKE {take} {(offset - 1) / scene.render.fps:.2f}s")
for a in list(bpy.data.actions):
    if a.name not in TAKES: bpy.data.actions.remove(a)
for o in list(bpy.data.objects):
    if o not in (rig, body): bpy.data.objects.remove(o, do_unlink=True)

os.makedirs(OUT, exist_ok=True)
for f in os.listdir(OUT):  # the previous sorceress's maps and single material (with their .meta files)
    if f.startswith(("sorceress_", "Packed_", "Source_Mage Sorceress.mat")): os.remove(os.path.join(OUT, f))
def save_png(name, pixels, size):
    img = bpy.data.images.new(name, size, size, alpha=False); img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(pixels.ravel()); img.filepath_raw = os.path.join(OUT, name); img.file_format = "PNG"; img.save()
def gray(path):
    img = bpy.data.images.load(path); w, h = img.size; a = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[..., 0], w
def rgb_png(src, name):  # Tripo normals can carry an all-opaque alpha; the game gets plain RGB
    img = bpy.data.images.load(src); w, h = img.size; a = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(a)
    a = a.reshape(h, w, 4); a[..., 3] = 1; save_png(name, a, w)
shutil.copyfile(os.path.join(SRC, "sorceress_basecolor.jpg"), os.path.join(OUT, "sorceress_body_basecolor.jpg"))
shutil.copyfile(os.path.join(SRC, "head_basecolor.jpg"), os.path.join(OUT, "sorceress_head_basecolor.jpg"))
rgb_png(os.path.join(SRC, "sorceress_normal_tripo.png"), "sorceress_body_normal.png")
rgb_png(os.path.join(SRC, "head_normal.png"), "sorceress_head_normal.png")
# glTF-style metallicRoughness (G roughness, B metallic), which SourceMaterials packs for URP.
rough, size = gray(os.path.join(SRC, "sorceress_roughness.jpg")); metal, _ = gray(os.path.join(SRC, "sorceress_metallic.jpg"))
packed = np.zeros((size, size, 4), np.float32); packed[..., 1] = rough; packed[..., 2] = metal; packed[..., 3] = 1
save_png("sorceress_body_metallicRoughness.png", packed, size)
with open(os.path.join(OUT, "materials.json"), "w") as f:
    json.dump({"Mage Sorceress Body": {"color": [1, 1, 1, 1], "alpha": 1, "metallic": 1, "roughness": 1,
                                       "albedo": "sorceress_body_basecolor.jpg", "normal": "sorceress_body_normal.png",
                                       "metallicRoughness": "sorceress_body_metallicRoughness.png"},
               "Mage Sorceress Head": {"color": [1, 1, 1, 1], "alpha": 1, "metallic": 0, "roughness": .6, "doubleSided": 1,
                                       "albedo": "sorceress_head_basecolor.jpg", "normal": "sorceress_head_normal.png"}}, f, indent=2)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "mage_sorceress.fbx"), use_selection=False, object_types={"ARMATURE", "MESH"},
                         add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=True,
                         bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0, path_mode="STRIP", embed_textures=False,
                         apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True, armature_nodetype="NULL")
print("SORCERESS_BUILD_DONE", OUT)
