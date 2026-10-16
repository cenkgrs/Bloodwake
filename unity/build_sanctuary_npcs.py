import bpy
import json
import shutil
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Assets/Bloodwake/Resources/Models"
REVIEW = ROOT.parent / "art/sanctuary/integration-20261016/npcs"
REVIEW.mkdir(parents=True, exist_ok=True)

SOURCES = [
    {
        "id": "enemy_merchant",
        "rig": Path("/home/cenkargevim/Downloads/Unarmed Idle.fbx"),
        "art": Path("/home/cenkargevim/Downloads/medieval fantasy character 3d model.glb"),
    },
    {
        "id": "enemy_mentor",
        "rig": Path("/home/cenkargevim/Downloads/Idle(1).fbx"),
        "art": Path("/home/cenkargevim/Downloads/fantasy character 3d model(1).glb"),
    },
]


def glb_doc(path):
    raw = path.read_bytes()
    json_length = struct.unpack_from("<I", raw, 12)[0]
    return raw, json.loads(raw[20 : 20 + json_length]), json_length


def extract_materials(path, folder):
    raw, doc, json_length = glb_doc(path)
    binary = raw[28 + json_length :]
    images = []
    for index, image in enumerate(doc.get("images", [])):
        suffix = ".jpg" if image.get("mimeType") == "image/jpeg" else ".png"
        name = f"SourceImage_{index}{suffix}"
        view = doc["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        (folder / name).write_bytes(binary[start : start + view["byteLength"]])
        images.append(name)

    result = {}
    material_names = []
    for index, material in enumerate(doc.get("materials", [])):
        name = material.get("name", f"Material_{index}")
        material_names.append(name)
        pbr = material.get("pbrMetallicRoughness", {})
        color = pbr.get("baseColorFactor", [1, 1, 1, 1])
        row = {
            "color": color,
            "alpha": color[3],
            "metallic": pbr.get("metallicFactor", 1),
            "roughness": pbr.get("roughnessFactor", 1),
        }
        for key, texture in (
            ("albedo", pbr.get("baseColorTexture")),
            ("normal", material.get("normalTexture")),
            ("metallicRoughness", pbr.get("metallicRoughnessTexture")),
        ):
            if texture is not None:
                row[key] = images[doc["textures"][texture["index"]]["source"]]
        result[name] = row
    (folder / "materials.json").write_text(json.dumps(result, indent=2))
    return material_names


audit = []
for source in SOURCES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = OUT / source["id"]
    folder.mkdir(parents=True, exist_ok=True)

    bpy.ops.import_scene.gltf(filepath=str(source["art"]))
    art_mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    if not art_mesh.data.materials:
        raise RuntimeError(f"Source GLB has no material: {source['art']}")
    art_material = art_mesh.data.materials[0]
    material_names = extract_materials(source["art"], folder)
    art_material.name = material_names[0]
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    bpy.ops.import_scene.fbx(filepath=str(source["rig"]))
    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    mesh.data.materials.clear()
    mesh.data.materials.append(art_material)
    armature.name = "Rig"
    mesh.name = "Character"
    mesh.data.name = source["id"] + " Mesh"

    if not bpy.data.actions:
        raise RuntimeError(f"Rig has no animation: {source['rig']}")
    action = bpy.data.actions[0]
    action.name = "Idle"
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = armature
    output = folder / f"{source['id']}.fbx"
    bpy.ops.export_scene.fbx(
        filepath=str(output),
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_all_actions=True,
        bake_anim_simplify_factor=0.0,
        path_mode="STRIP",
        axis_forward="-Z",
        axis_up="Y",
    )
    shutil.copy2(source["rig"], REVIEW / source["rig"].name)
    shutil.copy2(source["art"], REVIEW / source["art"].name)
    audit.append(
        {
            "id": source["id"],
            "rig": str(source["rig"]),
            "art": str(source["art"]),
            "bones": len(armature.data.bones),
            "triangles": sum(max(0, len(poly.vertices) - 2) for poly in mesh.data.polygons),
            "frames": list(action.frame_range),
            "materials": material_names,
        }
    )

(REVIEW / "audit.json").write_text(json.dumps(audit, indent=2))
print("SANCTUARY_NPCS_BUILT", json.dumps(audit))
