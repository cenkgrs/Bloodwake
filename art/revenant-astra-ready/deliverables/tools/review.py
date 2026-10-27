"""Review cameras and still/clip rendering for the Revenant authoring scripts."""
import bpy, math, os, subprocess
from mathutils import Vector
from pathlib import Path

D = Path(__file__).resolve().parents[1]

CAMS = {
    # name: (location, look-at, ortho scale)
    'front': ((0, -6, 1.0), (0, 0, .95), 2.5),
    'side': ((6, 0, 1.0), (0, 0, .95), 2.5),
    'three': ((4.2, -4.6, 2.6), (0, 0, .85), 2.6),
    # Bloodwake gameplay camera: offset (12,14,16) in Godot (Y up, +Z toward camera).
    # Godot -> Blender: x->x, y->z, z->-y. Character faces Blender -Y = Godot +Z.
    'game': ((12, -16, 14), (0, 0, .8), 3.2),
}


def setup(scene=None, res=640):
    s = scene or bpy.context.scene
    s.render.engine = 'BLENDER_WORKBENCH'
    s.render.resolution_x = res
    s.render.resolution_y = res
    s.render.resolution_percentage = 100
    s.render.fps = 60
    sh = s.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.show_cavity = True
    sh.cavity_type = 'BOTH'
    sh.background_type = 'WORLD'
    if s.world is None:
        s.world = bpy.data.worlds.new('Review')
    s.world.color = (.05, .05, .055)
    s.display.shadow_shift = .1
    for name, (loc, at, scale) in CAMS.items():
        cam = bpy.data.objects.get('CAM_' + name)
        if not cam:
            data = bpy.data.cameras.new('CAM_' + name)
            cam = bpy.data.objects.new('CAM_' + name, data)
            s.collection.objects.link(cam)
        cam.location = loc
        cam.rotation_euler = (Vector(at) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = scale
    g = bpy.data.objects.get('Review_Ground')
    if not g:
        me = bpy.data.meshes.new('Review_Ground')
        import bmesh
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=40, y_segments=40, size=10)
        bm.to_mesh(me)
        bm.free()
        g = bpy.data.objects.new('Review_Ground', me)
        s.collection.objects.link(g)
    g.location.z = -.002
    g.color = (.11, .12, .14, 1)
    mat = bpy.data.materials.get('Review_Ground') or bpy.data.materials.new('Review_Ground')
    mat.diffuse_color = (.11, .12, .14, 1)
    g.data.materials.clear()
    g.data.materials.append(mat)
    return s


def silhouette(on, scene=None):
    s = scene or bpy.context.scene
    sh = s.display.shading
    if on:
        sh.light = 'FLAT'
        sh.color_type = 'SINGLE'
        sh.single_color = (0.02, 0.02, 0.02)
        sh.show_shadows = False
        sh.show_cavity = False
        s.world.color = (.85, .85, .85)
    else:
        sh.light = 'STUDIO'
        sh.color_type = 'TEXTURE'
        sh.show_shadows = True
        sh.show_cavity = True
        s.world.color = (.05, .05, .055)
    g = bpy.data.objects.get('Review_Ground')
    if g:
        g.hide_render = on


def render(path, cam='three', frame=None, scene=None):
    s = scene or bpy.context.scene
    s.camera = bpy.data.objects['CAM_' + cam]
    if frame is not None:
        s.frame_set(int(frame))
    s.render.filepath = str(path)
    for attempt in range(3):
        try:
            bpy.ops.render.render(write_still=True)
            if os.path.exists(path):
                return
        except Exception as e:  # GPU workbench occasionally fails on this driver
            print('RENDER_RETRY', e)


def follow_camera(cam, offset):
    """Shift a camera (for root-motion style previews)."""
    loc, at, scale = CAMS[cam]
    o = bpy.data.objects['CAM_' + cam]
    o.location = Vector(loc) + Vector(offset)


def encode(frames_glob_dir, out, fps=60, pattern='%04d.png'):
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', str(Path(frames_glob_dir) / pattern),
           '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-vf', 'pad=ceil(iw/2)*2:ceil(ih/2)*2', str(out)]
    subprocess.run(cmd, check=True)
