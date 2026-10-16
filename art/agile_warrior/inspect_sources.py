"""Print structural metadata for the supplied warrior model and animation files."""

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def inspect(path: Path):
    reset()
    if path.suffix.lower() in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        bpy.ops.import_scene.fbx(filepath=str(path), use_anim=True)
    arms = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    actions = list(bpy.data.actions)
    print(f"SOURCE|{path.name}|armatures={len(arms)}|meshes={len(meshes)}|actions={len(actions)}")
    for arm in arms:
        roots = [bone.name for bone in arm.data.bones if bone.parent is None]
        names = [bone.name for bone in arm.data.bones]
        print(f"ARMATURE|{arm.name}|bones={len(names)}|roots={roots}|sample={names[:16]}")
    for action in actions:
        slots = [getattr(slot, "identifier", str(slot)) for slot in action.slots] if hasattr(action, "slots") else []
        print(f"ACTION|{action.name}|range={tuple(round(v, 3) for v in action.frame_range)}|slots={slots}")
    for mesh in meshes:
        corners = [mesh.matrix_world @ Vector(corner) for corner in mesh.bound_box]
        low = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
        high = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
        print(f"MESH|{mesh.name}|verts={len(mesh.data.vertices)}|polys={len(mesh.data.polygons)}|materials={len(mesh.data.materials)}|groups={len(mesh.vertex_groups)}|low={tuple(round(v, 4) for v in low)}|high={tuple(round(v, 4) for v in high)}")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :]
    for value in args:
        inspect(Path(value))
