#!/usr/bin/env python3
"""Export a player rig's body as a Mixamo-ready OBJ package.

Mixamo's auto-rigger wants one static mesh in its bind pose with nothing held in
the hands, so this reads the built .glb, drops the welded weapon, bakes the bind
pose into world space and normalises the result the same way the enemy packages
are normalised: 1.8 m tall, feet on the origin, centred on X/Z.

    python3 godot/tools/prepare_player_obj.py [class_id ...]

Writes art/<class>/mixamo_upload/<id>/ plus the zip to upload, and a front/side
preview so the pose can be checked before it goes anywhere.
"""
import json
import pathlib
import struct
import sys
import zipfile

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODELS = ROOT / "godot/assets/models"

# Which .glb holds each class's body, and which material is the body rather than
# the weapon that was rigidly bound into the hand.
RIGS = {
    "warrior": {"glb": "warrior_player.glb", "body": "Knight PBR", "folder": "warrior"},
    "mage": {"glb": "mage_player.glb", "body": None, "folder": "mage"},
    "assassin": {"glb": "assassin_player.glb", "body": None, "folder": "assassin"},
    "gunslinger": {"glb": "bloodbound.glb", "body": None, "folder": "gunslinger"},
}

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    raw = path.read_bytes()
    offset, meta, blob = 12, None, None
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        chunk = raw[offset + 8: offset + 8 + length]
        if kind == 0x4E4F534A:
            meta = json.loads(chunk.decode("utf8"))
        elif kind == 0x004E4942:
            blob = chunk
        offset += 8 + length
    return meta, blob


def accessor(meta, blob, index):
    acc = meta["accessors"][index]
    view = meta["bufferViews"][acc["bufferView"]]
    fmt = COMPONENT[acc["componentType"]]
    width = COUNT[acc["type"]]
    item = struct.calcsize(fmt) * width
    stride = view.get("byteStride") or item
    base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = np.empty((acc["count"], width), dtype=np.dtype(fmt))
    for i in range(acc["count"]):
        out[i] = struct.unpack_from("<" + fmt * width, blob, base + i * stride)
    return out


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    out = np.eye(4)
    if "scale" in node:
        out = np.diag(list(node["scale"]) + [1.0]) @ out
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        rot = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
            [0, 0, 0, 1]])
        out = rot @ out
    if "translation" in node:
        move = np.eye(4)
        move[:3, 3] = node["translation"]
        out = move @ out
    return out


def mesh_nodes(meta):
    """Every mesh-bearing node with the world transform it inherits."""
    found = []
    scene = meta["scenes"][meta.get("scene", 0)]

    def walk(index, parent):
        node = meta["nodes"][index]
        world = parent @ node_matrix(node)
        if "mesh" in node:
            # glTF ignores a skinned node's own transform: the joint matrices place
            # the mesh, and the accessor data is already the bind pose. Applying the
            # node matrix here laid the character on its back.
            found.append((node, np.eye(4) if "skin" in node else world))
        for child in node.get("children", []):
            walk(child, world)

    for root in scene["nodes"]:
        walk(root, np.eye(4))
    return found


def collect(meta, blob, body_material):
    """Bind-pose triangles for the body, skipping any welded weapon."""
    positions, normals, uvs, faces = [], [], [], []
    for node, world in mesh_nodes(meta):
        mesh = meta["meshes"][node["mesh"]]
        for prim in mesh["primitives"]:
            name = meta["materials"][prim["material"]].get("name", "") if "material" in prim else ""
            if body_material is not None and name != body_material:
                continue
            attrs = prim["attributes"]
            base = len(positions)
            raw = accessor(meta, blob, attrs["POSITION"]).astype(np.float64)
            homogeneous = np.hstack([raw, np.ones((len(raw), 1))])
            positions.extend((homogeneous @ world.T)[:, :3])
            if "NORMAL" in attrs:
                normals.extend(accessor(meta, blob, attrs["NORMAL"]).astype(np.float64) @ world[:3, :3].T)
            if "TEXCOORD_0" in attrs:
                uvs.extend(accessor(meta, blob, attrs["TEXCOORD_0"]).astype(np.float64))
            index = accessor(meta, blob, prim["indices"]).reshape(-1)
            faces.extend((index.reshape(-1, 3) + base).tolist())
    return np.array(positions), np.array(normals), np.array(uvs), np.array(faces, dtype=np.int64)


def normalise(points):
    low, high = points.min(axis=0), points.max(axis=0)
    height = high[1] - low[1]
    factor = 1.8 / height if height > 1e-6 else 1.0
    pivot = np.array([(low[0] + high[0]) / 2, low[1], (low[2] + high[2]) / 2])
    return (points - pivot) * factor, factor


def texture(meta, blob, body_material):
    for material in meta.get("materials", []):
        if body_material is not None and material.get("name") != body_material:
            continue
        pbr = material.get("pbrMetallicRoughness", {})
        if "baseColorTexture" not in pbr:
            continue
        image = meta["images"][meta["textures"][pbr["baseColorTexture"]["index"]]["source"]]
        view = meta["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        suffix = ".png" if image.get("mimeType") == "image/png" else ".jpg"
        return blob[start: start + view["byteLength"]], suffix
    return None, None


def preview(points, faces, path):
    """Two flat-shaded orthographic views, only to confirm pose and facing."""
    from PIL import Image
    size, sheet = 520, []
    for axis, label in [((0, 1), "front"), ((2, 1), "side")]:
        flat = points[:, list(axis)].copy()
        flat[:, 0] *= -1 if label == "side" else 1
        span = max(flat[:, 1].max() - flat[:, 1].min(), 1e-6) * 1.12
        screen = np.empty_like(flat)
        screen[:, 0] = (flat[:, 0] / span + 0.5) * size
        screen[:, 1] = (1.0 - (flat[:, 1] - flat[:, 1].min()) / span - 0.04) * size
        depth = points[:, 2 if label == "front" else 0]
        buffer = np.full((size, size), np.inf)
        shade = np.zeros((size, size), dtype=np.float32)
        for tri in faces:
            pts, zs = screen[tri], depth[tri]
            lo = np.floor(pts.min(axis=0)).astype(int)
            hi = np.ceil(pts.max(axis=0)).astype(int)
            if hi[0] <= 0 or hi[1] <= 0 or lo[0] >= size or lo[1] >= size:
                continue
            lo = np.maximum(lo, 0); hi = np.minimum(hi, size)
            if hi[0] <= lo[0] or hi[1] <= lo[1]:
                continue
            xs, ys = np.meshgrid(np.arange(lo[0], hi[0]) + .5, np.arange(lo[1], hi[1]) + .5)
            (x0, y0), (x1, y1), (x2, y2) = pts
            area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            if abs(area) < 1e-9:
                continue
            w1 = ((xs - x0) * (y2 - y0) - (x2 - x0) * (ys - y0)) / area
            w2 = ((x1 - x0) * (ys - y0) - (xs - x0) * (y1 - y0)) / area
            inside = (w1 >= 0) & (w2 >= 0) & (w1 + w2 <= 1)
            if not inside.any():
                continue
            z = zs[0] + w1 * (zs[1] - zs[0]) + w2 * (zs[2] - zs[0])
            region = buffer[lo[1]:hi[1], lo[0]:hi[0]]
            nearer = inside & (z < region)
            region[nearer] = z[nearer]
            shade[lo[1]:hi[1], lo[0]:hi[0]][nearer] = 1.0
        valid = np.isfinite(buffer)
        if valid.any():
            near, far = buffer[valid].min(), buffer[valid].max()
            depth_shade = np.zeros_like(shade)
            depth_shade[valid] = 1.0 - (buffer[valid] - near) / max(far - near, 1e-6)
            shade = np.clip(0.22 + depth_shade * 0.78, 0, 1) * (shade > 0)
        sheet.append(Image.fromarray((shade * 255).astype(np.uint8), "L"))
    out = Image.new("L", (size * 2, size), 18)
    for i, view in enumerate(sheet):
        out.paste(view, (size * i, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def build(class_id):
    spec = RIGS[class_id]
    meta, blob = read_glb(MODELS / spec["glb"])
    points, normals, uvs, faces = collect(meta, blob, spec["body"])
    assert len(faces), "no body geometry found for " + class_id
    points, factor = normalise(points)

    dest = ROOT / "art" / spec["folder"] / "mixamo_upload" / class_id
    dest.mkdir(parents=True, exist_ok=True)
    blob_texture, suffix = texture(meta, blob, spec["body"])
    colour = class_id + "_color" + (suffix or ".jpg")
    if blob_texture:
        (dest / colour).write_bytes(blob_texture)
    (dest / (class_id + ".mtl")).write_text(
        "newmtl %s\nKd 1.000 1.000 1.000\nKs 0.100 0.100 0.100\nNs 20.0\nd 1.0\nillum 2\n%s\n"
        % (class_id, ("map_Kd " + colour) if blob_texture else ""))

    with open(dest / (class_id + ".obj"), "w") as obj:
        obj.write("# %s body, bind pose, %.1f m, for Mixamo auto-rig\n" % (class_id, 1.8))
        obj.write("mtllib %s.mtl\n" % class_id)
        for p in points:
            obj.write("v %.6f %.6f %.6f\n" % tuple(p))
        for t in uvs:
            obj.write("vt %.6f %.6f\n" % (t[0], 1.0 - t[1]))
        for n in normals:
            obj.write("vn %.6f %.6f %.6f\n" % tuple(n))
        obj.write("usemtl %s\ns 1\n" % class_id)
        has_uv, has_n = len(uvs) > 0, len(normals) > 0
        for f in faces + 1:
            if has_uv and has_n:
                obj.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % tuple(np.repeat(f, 3)))
            elif has_n:
                obj.write("f %d//%d %d//%d %d//%d\n" % tuple(np.repeat(f, 2)))
            else:
                obj.write("f %d %d %d\n" % tuple(f))

    package = dest.parent / (class_id + "_mixamo.zip")
    with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(dest.iterdir()):
            z.write(f, f.name)
    preview(points, faces, ROOT / "art" / spec["folder"] / "preview" / (class_id + "_mixamo_obj.png"))
    print("%-11s %6d verts  %6d tris  scale x%.3f  -> %s (%.1f MB)"
          % (class_id, len(points), len(faces), factor,
             package.relative_to(ROOT), package.stat().st_size / 1e6))


if __name__ == "__main__":
    for name in (sys.argv[1:] or ["warrior"]):
        build(name)
