import bpy, os, sys
src, out = sys.argv[-2], sys.argv[-1]
outdir = os.path.dirname(out)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

TARGET_TRIS = 2500
for o in [x for x in bpy.data.objects if x.type=='MESH']:
    tris = sum(len(p.vertices)-2 for p in o.data.polygons)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("dec", 'DECIMATE'); m.decimate_type='COLLAPSE'
    m.ratio = min(1.0, TARGET_TRIS/float(tris))
    bpy.ops.object.modifier_apply(modifier=m.name)
    print("DECIMATED", tris, "->", sum(len(p.vertices)-2 for p in o.data.polygons))

for img in list(bpy.data.images):
    if img.type != 'IMAGE' or not img.filepath_raw and not img.packed_file:
        continue
    try:
        img.reload()
        _ = img.pixels[0]          # force decode into memory
    except Exception as e:
        print("SKIP", img.name, e); continue
    if max(img.size) == 0: 
        print("SKIP-empty", img.name); continue
    is_normal = 'normal' in img.name.lower()
    size = 1024 if is_normal else 512
    if max(img.size) > size:
        img.scale(size, size)
    img.file_format = 'PNG' if is_normal else 'JPEG'
    ext = '.png' if is_normal else '.jpg'
    img.filepath_raw = os.path.join(outdir, img.name + ext)
    img.save()
    print("IMG", img.name, img.size[0], img.size[1], os.path.getsize(img.filepath_raw))

bpy.ops.export_scene.fbx(filepath=out, path_mode='COPY', embed_textures=True,
                         mesh_smooth_type='FACE', use_mesh_modifiers=True)
