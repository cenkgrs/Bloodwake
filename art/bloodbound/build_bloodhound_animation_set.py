"""Build the game-ready Bloodhound animation package from the existing rig.

Run with:
  blender -b art/bloodbound/source/bloodbound_render.blend \
    --python art/bloodbound/build_bloodhound_animation_set.py

The source blend is never overwritten. The script is intentionally deterministic
and can be re-run to rebuild every authored action, marker, preview and export.
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
OUT = HERE / "bloodhound_delivery"
SOURCE_BLEND = HERE / "source" / "bloodbound_render.blend"
BLEND_OUT = OUT / "Bloodhound_GameReady.blend"
GLB_OUT = OUT / "Bloodhound_GameReady_Godot.glb"
FBX_OUT = OUT / "Bloodhound_GameReady_Unity_Unreal.fbx"
PREVIEW_DIR = OUT / "previews"
QA_DIR = OUT / "qa"

FPS = 60
ACTION_RANGES = {
    "BH_Idle": (1, 72),
    "BH_Walk_InPlace": (1, 32),
    "BH_GetHit": (1, 18),
    "BH_Death": (1, 60),
    "BH_FiveShot": (1, 42),
    "BH_BombThrow": (1, 50),
    "BH_Ultimate_BloodWake": (1, 108),
}
EVENTS = {
    "BH_FiveShot": {"FIRE_01": 10, "FIRE_02": 14, "FIRE_03": 18, "FIRE_04": 22, "FIRE_05": 26},
    "BH_BombThrow": {"THROW_RELEASE": 20},
    "BH_Ultimate_BloodWake": {
        "ULT_FIRE_01": 30, "ULT_FIRE_02": 36, "ULT_FIRE_03": 42,
        "ULT_FIRE_04": 48, "ULT_FIRE_05": 54, "ULT_FIRE_06": 60,
        "ULT_FIRE_07": 66, "ULT_FIRE_08": 72, "ULT_FIRE_09": 78,
        "ULT_FIRE_10": 82,
    },
}

B = {
    "hips": "mixamorig:Hips", "spine": "mixamorig:Spine", "spine1": "mixamorig:Spine1",
    "chest": "mixamorig:Spine2", "neck": "mixamorig:Neck", "head": "mixamorig:Head",
    "lua": "mixamorig:LeftArm", "lfa": "mixamorig:LeftForeArm", "lh": "mixamorig:LeftHand",
    "rua": "mixamorig:RightArm", "rfa": "mixamorig:RightForeArm", "rh": "mixamorig:RightHand",
    "lul": "mixamorig:LeftUpLeg", "ll": "mixamorig:LeftLeg", "lf": "mixamorig:LeftFoot",
    "rul": "mixamorig:RightUpLeg", "rl": "mixamorig:RightLeg", "rf": "mixamorig:RightFoot",
}


def clean_output() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for folder in (PREVIEW_DIR, QA_DIR):
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True, exist_ok=True)


def get_rig() -> bpy.types.Object:
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1, f"Expected one armature, found {len(rigs)}"
    return rigs[0]


def ensure_helpers(rig: bpy.types.Object) -> None:
    """Add non-deforming root/socket bones without changing existing weights."""
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    if "GameRoot" not in eb:
        root = eb.new("GameRoot")
        root.head, root.tail = (0, 0, 0), (0, 0, 0.25)
        root.use_deform = False
        eb[B["hips"]].parent = root
    sockets = [
        ("socket_weapon_R", B["rh"], (0.0, 0.0, 0.0), (0.0, 0.16, 0.0)),
        ("socket_weapon_L", B["lh"], (0.0, 0.0, 0.0), (0.0, 0.16, 0.0)),
        ("socket_bomb_L", B["lh"], (0.0, 0.0, 0.0), (0.0, 0.13, 0.0)),
    ]
    for name, parent_name, head_offset, tail_offset in sockets:
        if name in eb:
            continue
        parent = eb[parent_name]
        bone = eb.new(name)
        bone.head = parent.tail + Vector(head_offset)
        bone.tail = bone.head + Vector(tail_offset)
        bone.parent = parent
        bone.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")


def ensure_vfx(rig: bpy.types.Object) -> dict[str, bpy.types.Object]:
    old = bpy.data.collections.get("BH_VFX_PREVIEW")
    if old:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new("BH_VFX_PREVIEW")
    bpy.context.scene.collection.children.link(col)

    def move_to_collection(obj):
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        col.objects.link(obj)

    # Readable grenade prop; kept separate from the character mesh/rig.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.035)
    bomb = bpy.context.object
    bomb.name = "BH_Bomb_Preview"
    move_to_collection(bomb)
    bomb.parent = rig
    bomb.parent_type = "BONE"
    bomb.parent_bone = "socket_bomb_L"
    bomb.location = (0, 0, 0)
    bomb["gameplay_note"] = "Preview only; detach at THROW_RELEASE and spawn projectile/VFX in engine."

    mat_bomb = bpy.data.materials.get("BH_Bomb_Brass") or bpy.data.materials.new("BH_Bomb_Brass")
    mat_bomb.diffuse_color = (0.32, 0.12, 0.035, 1)
    bomb.data.materials.append(mat_bomb)

    # Radius ring and radial tracer guides are engine-independent previews.
    bpy.ops.mesh.primitive_torus_add(major_radius=1.25, minor_radius=0.018, major_segments=64, minor_segments=6)
    ring = bpy.context.object
    ring.name = "BH_Bomb_Area_Ring"
    move_to_collection(ring)
    mat_red = bpy.data.materials.get("BH_VFX_Red") or bpy.data.materials.new("BH_VFX_Red")
    mat_red.diffuse_color = (0.55, 0.015, 0.01, 1)
    ring.data.materials.append(mat_red)
    ring.hide_render = True
    ring["gameplay_note"] = "Preview radius; drive from bomb impact event in engine."

    tracers = bpy.data.collections.new("BH_Ultimate_Radial_Tracers")
    col.children.link(tracers)
    for i in range(12):
        angle = math.tau * i / 12
        bpy.ops.mesh.primitive_cube_add(location=(math.cos(angle) * 1.8, math.sin(angle) * 1.8, 1.15))
        t = bpy.context.object
        t.name = f"ULT_Tracer_{i+1:02d}"
        t.scale = (0.55, 0.018, 0.018)
        t.rotation_euler[2] = angle
        for c in list(t.users_collection): c.objects.unlink(t)
        tracers.objects.link(t)
        t.data.materials.append(mat_red)
        t.hide_render = True
    return {"bomb": bomb, "ring": ring}


def set_action(rig, action):
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if getattr(action, "slots", None):
        try: rig.animation_data.action_slot = action.slots[0]
        except Exception: pass


def sample_source(rig, scene, source, source_frame):
    # The supplied Mixamo clips drive quaternion channels. Restore that mode
    # before evaluation, regardless of what the authored action used last.
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    set_action(rig, source)
    scene.frame_set(int(source_frame), subframe=source_frame - int(source_frame))
    bpy.context.view_layer.update()
    return {p.name: p.matrix_basis.copy() for p in rig.pose.bones}


def key_pose(rig, scene, action, frame, matrices, rotations=None, locations=None):
    set_action(rig, action)
    scene.frame_set(frame)
    for pb in rig.pose.bones:
        # Authored clips use one rotation representation throughout. This avoids
        # dual quaternion/Euler curves and gives deterministic loop seams/export.
        pb.rotation_mode = "XYZ"
        pb.matrix_basis = matrices.get(pb.name, Matrix.Identity(4))
    bpy.context.view_layer.update()
    rotations = rotations or {}
    locations = locations or {}
    for name, xyz in rotations.items():
        pb = rig.pose.bones[name]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler.rotate_axis("X", math.radians(xyz[0]))
        pb.rotation_euler.rotate_axis("Y", math.radians(xyz[1]))
        pb.rotation_euler.rotate_axis("Z", math.radians(xyz[2]))
    for name, xyz in locations.items():
        rig.pose.bones[name].location += Vector(xyz)
    # GameRoot is deliberately fixed on the horizontal plane in every action.
    if "GameRoot" in rig.pose.bones:
        rig.pose.bones["GameRoot"].location = (0, 0, 0)
        rig.pose.bones["GameRoot"].rotation_mode = "XYZ"
        if "GameRoot" not in rotations:
            rig.pose.bones["GameRoot"].rotation_euler = (0, 0, 0)
    for pb in rig.pose.bones:
        if pb.name.startswith("socket_"):
            continue
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("rotation_quaternion" if pb.rotation_mode == "QUATERNION" else "rotation_euler", frame=frame, group=pb.name)
    rig.pose.bones["GameRoot"].keyframe_insert("location", frame=frame, group="GameRoot")
    rig.pose.bones["GameRoot"].keyframe_insert("rotation_euler", frame=frame, group="GameRoot")


def new_action(name, start, end):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action.frame_start, action.frame_end = start, end
    action["game_ready"] = True
    action["fps"] = FPS
    return action


def add_marker(action, name, frame):
    try:
        marker = action.pose_markers.new(name)
        marker.frame = frame
    except Exception:
        pass


def sync_timeline_markers(scene):
    scene.timeline_markers.clear()
    for markers in EVENTS.values():
        for name, frame in markers.items():
            scene.timeline_markers.new(name, frame=frame)


def build_actions(rig):
    scene = bpy.context.scene
    original = {name: bpy.data.actions[name] for name in ("idle", "run", "hit", "death", "attack")}
    actions = {name: new_action(name, *span) for name, span in ACTION_RANGES.items()}

    # Idle: restrained breathing and slow target scan; identical first/last sample.
    for f, src, extra in [
        (1, 0, {}), (18, 92, {B["head"]:(0,0,-4), B["chest"]:(1.5,0,-1)}),
        (36, 184, {B["chest"]:(-1.5,0,1)}),
        (54, 276, {B["head"]:(0,0,4), B["rh"]:(0,0,-4)}), (72, 0, {})]:
        key_pose(rig, scene, actions["BH_Idle"], f, sample_source(rig, scene, original["idle"], src), extra)

    # Walk: source locomotion retimed to the requested contact/passing cadence.
    for f, src in [(1,0), (9,7.5), (17,15), (25,22.5), (32,0)]:
        mods = {B["chest"]:(0,7,0), B["head"]:(0,-4,0)}
        key_pose(rig, scene, actions["BH_Walk_InPlace"], f, sample_source(rig, scene, original["run"], src), mods)

    for f, src in [(1,0), (3,3), (7,10), (15,21), (18,23)]:
        mods = {B["chest"]:(0, -12 if f in (3,7) else 0, 0), B["hips"]:(0, 5 if f==7 else 0, 0)}
        key_pose(rig, scene, actions["BH_GetHit"], f, sample_source(rig, scene, original["hit"], src), mods)

    for f, src in [(1,0), (5,6), (22,26), (30,36), (42,52), (60,72)]:
        mods = {B["head"]:(0,0,8 if f==30 else 0), B["chest"]:(0,-8 if f>=22 else 0,0)}
        key_pose(rig, scene, actions["BH_Death"], f, sample_source(rig, scene, original["death"], src), mods)

    # Combat base uses a stable idle stance; arms/chest provide readable recoil.
    base = sample_source(rig, scene, original["idle"], 0)
    combat_frames = [1, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 30, 36, 42]
    for f in combat_frames:
        fire = f in (10,14,18,22,26)
        right = f in (10,18,26)
        left = f in (14,22,26)
        strength = 1.25 if f == 26 else 1.0
        rot = {
            B["chest"]:(-5*strength if fire else 1, 0, (3 if right else -3 if left else 0)),
            B["rua"]:(-48 if f>=8 and f<=30 else -12, -14, -12),
            B["rfa"]:(-20, 2, -16), B["rh"]:(0, 0, -5),
            B["lua"]:(-48 if f>=8 and f<=30 else -12, 14, 12),
            B["lfa"]:(-20, -2, 16), B["lh"]:(0, 0, 5),
        }
        if right and fire: rot[B["rua"]] = (-48 + 12*strength, -14, -12)
        if left and fire: rot[B["lua"]] = (-48 + 12*strength, 14, 12)
        key_pose(rig, scene, actions["BH_FiveShot"], f, base, rot)

    # Bomb throw: left hand travels from belt to overhead release and guard recovery.
    bomb_poses = {
        1: {}, 8:{B["lua"]:(15,10,35),B["lfa"]:(-35,0,20),B["chest"]:(5,0,-8)},
        14:{B["lua"]:(-80,8,25),B["lfa"]:(-55,0,10),B["chest"]:(14,0,-18)},
        20:{B["lua"]:(-115,-4,-10),B["lfa"]:(-10,0,-5),B["chest"]:(-16,0,22)},
        27:{B["lua"]:(-45,15,35),B["lfa"]:(-70,0,25),B["rfa"]:(-55,0,-15),B["chest"]:(-8,0,10)},
        38:{B["lfa"]:(-45,0,20),B["rfa"]:(-35,0,-10)}, 50:{}
    }
    for f, rot in bomb_poses.items():
        key_pose(rig, scene, actions["BH_BombThrow"], f, base, rot)

    # Ultimate: charge, full 360-degree active phase around the planted root, hard stop.
    ultimate_frames = [1,12,24,30,36,42,48,54,60,66,72,78,82,92,100,108]
    for f in ultimate_frames:
        if f < 30:
            yaw = 0
            charge = f / 24
        elif f <= 82:
            yaw = 360 * (f-30)/(82-30)
            charge = 1
        else:
            yaw = 360
            charge = max(0, (108-f)/26)
        fire_side = 1 if ((f//6)%2)==0 else -1
        rot = {
            # Blender bones point along local Y; for this vertical root, local Y
            # rotation is the world-up spin used by the 360-degree ultimate.
            "GameRoot":(0,yaw,0), B["chest"]:(-8*charge,0,fire_side*7*charge),
            B["rua"]:(-55*charge,-18,-18), B["rfa"]:(-28,0,-18),
            B["lua"]:(-55*charge,18,18), B["lfa"]:(-28,0,18),
            B["head"]:(0,0,-fire_side*5*charge),
        }
        key_pose(rig, scene, actions["BH_Ultimate_BloodWake"], f, base, rot)

    for action_name, markers in EVENTS.items():
        for marker_name, frame in markers.items():
            add_marker(actions[action_name], marker_name, frame)
    # Source clips were construction material only. Keeping them would make the
    # engine export contain more than the seven requested character actions.
    set_action(rig, actions["BH_Idle"])
    for source_action in original.values():
        bpy.data.actions.remove(source_action)
    return actions


def animate_vfx(props, actions, rig):
    bomb = props["bomb"]
    action = bpy.data.actions.get("BH_Bomb_Projectile_Parabola") or bpy.data.actions.new("BH_Bomb_Projectile_Parabola")
    bomb.animation_data_create(); bomb.animation_data.action = action
    # Preview visibility/flight lives on a separate object/action, never the character action.
    for f, loc in [(1,(0,0,0)), (20,(0,0,0)), (28,(0,-1.4,1.1)), (38,(0,-2.8,0.7)), (50,(0,-4.0,0.05))]:
        bomb.location = loc
        bomb.keyframe_insert("location", frame=f)
    action.frame_start, action.frame_end = 1, 50
    action.use_fake_user = True


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 8
    scene.eevee.use_shadows = False
    scene.eevee.use_gtao = False
    scene.eevee.use_raytracing = False
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.018, 0.012, 0.016)
    scene.render.fps = FPS
    scene.render.fps_base = 1
    return scene


def character_bounds(rig):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    pts=[]
    for o in meshes:
        for c in o.bound_box: pts.append(o.matrix_world @ Vector(c))
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    return lo,hi


def make_camera(name, center, height, azimuth):
    data = bpy.data.cameras.new(name)
    cam = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(cam)
    a=math.radians(azimuth)
    cam.location = center + Vector((math.sin(a)*height*4.2, -math.cos(a)*height*4.2, height*0.45))
    cam.rotation_euler = (center-cam.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO"; data.ortho_scale=height*1.34
    return cam


def render_previews(rig, actions):
    scene=setup_render(); lo,hi=character_bounds(rig); height=hi.z-lo.z
    center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z+height*.48))
    cams={"front":make_camera("BH_Camera_Front",center,height,0),"side":make_camera("BH_Camera_Side",center,height,90),"three_quarter":make_camera("BH_Camera_ThreeQuarter",center,height,35)}
    for action_name, action in actions.items():
        start,end=ACTION_RANGES[action_name]
        set_action(rig,action)
        bomb=bpy.data.objects.get("BH_Bomb_Preview")
        if bomb:
            bomb.hide_render = action_name != "BH_BombThrow"
        # Three-angle QA sheet at the most informative frames.
        key_frames=sorted(set([start,round(start+(end-start)*.5),end]))
        rendered=[]
        for view,cam in cams.items():
            scene.camera=cam
            for f in key_frames:
                scene.frame_set(f); scene.render.filepath=str(QA_DIR/f"{action_name}_{view}_{f:03d}.png")
                bpy.ops.render.render(write_still=True); rendered.append(scene.render.filepath)
        # Lightweight 3/4 preview: 12 samples, preserving the requested time range.
        scene.camera=cams["three_quarter"]
        temp=PREVIEW_DIR/f"_{action_name}"
        if temp.exists(): shutil.rmtree(temp)
        temp.mkdir()
        samples=12
        for i in range(samples):
            f=start+(end-start)*(i/(samples if action_name in ("BH_Idle","BH_Walk_InPlace") else samples-1))
            scene.frame_set(int(f),subframe=f-int(f)); scene.render.filepath=str(temp/f"{i:03d}.png")
            bpy.ops.render.render(write_still=True)
        mp4=PREVIEW_DIR/f"{action_name}.mp4"
        subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","12","-i",str(temp/"%03d.png"),"-c:v","libx264","-pix_fmt","yuv420p",str(mp4)],check=True)
        shutil.rmtree(temp)


def export_assets(rig):
    scene=bpy.context.scene
    selected=[]
    for o in scene.objects:
        o.select_set(False)
        if o==rig or (o.type=="MESH" and any(m.type=="ARMATURE" and m.object==rig for m in o.modifiers)):
            o.select_set(True); selected.append(o)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(GLB_OUT),export_format="GLB",use_selection=True,export_animations=True,export_animation_mode="ACTIONS",export_anim_scene_split_object=True)
    # FBX's all-actions mode assigns every action datablock to the armature,
    # including object-only VFX actions. Temporarily remove the bomb trajectory
    # for a clean seven-clip character FBX; reload the already-saved blend after.
    bomb_action=bpy.data.actions.get("BH_Bomb_Projectile_Parabola")
    if bomb_action:
        bpy.data.actions.remove(bomb_action)
    bpy.ops.export_scene.fbx(filepath=str(FBX_OUT),use_selection=True,add_leaf_bones=False,bake_anim=True,bake_anim_use_all_actions=True,apply_scale_options="FBX_SCALE_ALL")
    bpy.ops.wm.open_mainfile(filepath=str(BLEND_OUT))


def validate(actions, rig):
    checks={}
    for name,(start,end) in ACTION_RANGES.items():
        a=actions[name]
        checks[name]={"range":[int(a.frame_start),int(a.frame_end)],"markers":EVENTS.get(name,{}),"fps":FPS}
    # Loop seam: compare evaluated pose matrices at first/last frame.
    loop_errors={}
    for name in ("BH_Idle","BH_Walk_InPlace"):
        set_action(rig,actions[name]); bpy.context.scene.frame_set(ACTION_RANGES[name][0]); bpy.context.view_layer.update()
        first={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
        bpy.context.scene.frame_set(ACTION_RANGES[name][1]); bpy.context.view_layer.update()
        loop_errors[name]=max(
            max(abs(first[p.name][r][c]-p.matrix_basis[r][c]) for r in range(4) for c in range(4))
            for p in rig.pose.bones
        )
    validation={
        "source":str(SOURCE_BLEND.relative_to(HERE)), "fps":FPS, "actions":checks,
        "loop_matrix_max_error":loop_errors,
        "root_horizontal_fixed":True, "scale_keys_on_deform_bones":False,
        "single_mesh_limitation":"Hat, coat and revolvers are baked into the supplied skinned mesh; socket bones were added without splitting UVs/weights.",
        "missing_references":[
            "outputs/bloodhound-character-model-sheet.png", "outputs/bloodhound-idle-walk-animation-sheet.png",
            "outputs/bloodhound-hit-death-animation-sheet.png", "outputs/bloodhound-five-shot-bomb-animation-sheet.png",
            "outputs/bloodhound-ultimate-animation-sheet.png", "outputs/bloodhound-animation-design.md"
        ],
    }
    (OUT/"Bloodhound_Animation_Report.json").write_text(json.dumps(validation,indent=2)+"\n")
    md=["# Bloodhound game-ready animation report","",f"- Source: `{SOURCE_BLEND.relative_to(HERE)}`",f"- Timeline: {FPS} FPS","- Engine target: Godot GLB; Unity/Unreal FBX also included.","- Root: `GameRoot`, fixed on the horizontal plane.","- Non-deforming sockets: `socket_weapon_R`, `socket_weapon_L`, `socket_bomb_L`.","","## Actions","","| Action | Frames | Loop | Events |","|---|---:|:---:|---|"]
    for name,(start,end) in ACTION_RANGES.items():
        events=", ".join(f"{k}@{v}" for k,v in EVENTS.get(name,{}).items()) or "—"
        md.append(f"| {name} | {start}–{end} | {'yes' if name in ('BH_Idle','BH_Walk_InPlace') else 'no'} | {events} |")
    md += ["","## QA","",f"- Loop matrix errors: `{loop_errors}` (0.0 means an exact seam).","- Three-angle stills are in `qa/`; each Action has a 3/4 MP4 in `previews/`.","- GLB and FBX are re-imported by `validate_bloodhound_export.py`; see `reimport_validation.json`.","","## Known limitations","","- The six requested `outputs/bloodhound-*` design references were not present in the workspace.","- The supplied character is a single skinned mesh. Hat, coat, scarf and revolvers cannot be made independent rigid props without destructive mesh/UV/weight surgery; socket bones were added for future engine props.","- Cloth/scarf follow-through is inherited through the supplied skin weights because the rig has no dedicated cloth or accessory bones."]
    (OUT/"Bloodhound_Animation_Report.md").write_text("\n".join(md)+"\n")
    return validation


def main():
    clean_output()
    scene=bpy.context.scene; scene.render.fps=FPS
    rig=get_rig(); rig.name="Bloodhound_Rig"
    ensure_helpers(rig)
    props=ensure_vfx(rig)
    actions=build_actions(rig)
    sync_timeline_markers(scene)
    animate_vfx(props,actions,rig)
    validate(actions,rig)
    # Make the first authored action active and keep the UI range useful.
    set_action(rig,actions["BH_Idle"]); scene.frame_start=1; scene.frame_end=72
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
    render_previews(rig,actions)
    export_assets(rig)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
    print("BLOODHOUND_BUILD_COMPLETE", BLEND_OUT)


if __name__ == "__main__":
    main()
