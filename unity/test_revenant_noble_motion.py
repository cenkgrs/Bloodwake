"""Blender roundtrip regression: catches named clips that export as frozen poses.
Run: blender -b -t 2 --python unity/test_revenant_noble_motion.py
"""
import bpy
from pathlib import Path
root=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'Assets/Bloodwake/Resources/Models/revenant_noble/revenant_noble.fbx'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
for name in ['REV_NeutralIdle','REV_StandardRun','REV_SwaggerWalk']:
 action=next(a for a in bpy.data.actions if a.name.split('|')[-1]==name)
 rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 points=[];bone='mixamorig:Head' if 'Idle' in name else 'mixamorig:LeftFoot'
 lo,hi=action.frame_range
 for i in range(20):
  bpy.context.scene.frame_set(int(lo+(hi-lo)*i/20));bpy.context.view_layer.update()
  points.append(rig.matrix_world@rig.pose.bones[bone].head)
 travel=max((a-b).length for a in points for b in points)
 assert travel>(.001 if 'Idle' in name else .2),(name,travel)
 print('NOBLE_EXPORTED_MOTION_PASSED',name,'bone travel',round(travel,4),flush=True)
