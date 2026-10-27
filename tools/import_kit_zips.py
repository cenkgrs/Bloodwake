#!/usr/bin/env python3
"""Unpack Tripo zips from art/environment-incoming/<id>.zip into the Unity kit folder.

Each zip holds one FBX and its textures (Color/albedo, *metallic*, *roughness*, *normal*). They land in
unity/Assets/Bloodwake/Resources/Environment/Kit01/<id>/ as model.fbx, albedo.jpg, metallic.jpg,
roughness.jpg and normal.png, the names UserEnvironmentImport expects; textures keep their full resolution.
Prints the ids it unpacked, comma separated, for BW_ENV_IDS. Ids already in the kit are skipped unless named
on the command line.
"""
import io, sys, zipfile, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
INCOMING = ROOT / "art/environment-incoming"
KIT = ROOT / "unity/Assets/Bloodwake/Resources/Environment/Kit01"


def role(name):
    n = name.lower()
    if n.endswith(".fbx"):
        return "model"
    if not n.endswith((".jpg", ".jpeg", ".png")):
        return None
    if "normal" in n:
        return "normal"
    if "metal" in n:
        return "metallic"
    if "rough" in n:
        return "roughness"
    if "color" in n or "albedo" in n or "basecolor" in n or "diffuse" in n:
        return "albedo"
    return None


def unpack(zip_path, force):
    kit_id = zip_path.stem
    folder = KIT / kit_id
    if (folder / "model.fbx").exists() and not force:
        return None
    with zipfile.ZipFile(zip_path) as z:
        found = {}
        for name in z.namelist():
            r = role(name)
            if r and r not in found:
                found[r] = name
        missing = {"model", "albedo", "normal", "roughness"} - found.keys()
        if missing:
            print(f"SKIP {kit_id}: missing {sorted(missing)} in {zip_path.name}", file=sys.stderr)
            return None
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "model.fbx").write_bytes(z.read(found["model"]))
        for r, out in (("albedo", "albedo.jpg"), ("roughness", "roughness.jpg"), ("metallic", "metallic.jpg")):
            if r not in found:
                continue
            data = z.read(found[r])
            if found[r].lower().endswith(".png"):
                img = Image.open(io.BytesIO(data)).convert("RGB")
                img.save(folder / out, quality=95)
            else:
                (folder / out).write_bytes(data)
        if "metallic" not in found:
            # Stone and wood: a black metallic map, the same size as roughness.
            size = Image.open(folder / "roughness.jpg").size
            Image.new("RGB", size, 0).save(folder / "metallic.jpg", quality=95)
        Image.open(io.BytesIO(z.read(found["normal"]))).convert("RGB").save(folder / "normal.png")
    return kit_id


def main():
    named = set(sys.argv[1:])
    done = []
    for zip_path in sorted(INCOMING.glob("*.zip")):
        if named and zip_path.stem not in named:
            continue
        kit_id = unpack(zip_path, force=zip_path.stem in named)
        if kit_id:
            done.append(kit_id)
    print(",".join(done))


if __name__ == "__main__":
    main()
