import bpy
from pathlib import Path
D=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(D/'Revenant_Animated.blend'))
col=bpy.data.collections['REV_VFX_PROXY'];keep=[o for o in col.objects if not o.name.startswith('CLAW')]
for o in list(bpy.data.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
for o in keep:
 o.animation_data_clear();o.hide_render=False;o.hide_viewport=False;o.hide_set(False);o.scale=(1,1,1);o.select_set(True)
 if o.name.startswith('ULT_Thread'):o.location=(0,0,0)
bpy.context.view_layer.objects.active=keep[0];bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(D/'Revenant_VFX.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('VFX_EXPORT_DONE')
