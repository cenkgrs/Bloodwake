"""Verify the exported FBX, not just the Blender action, matches the measured gait."""
import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
report=json.loads((root/'art/enemies/mixamo/warrior/walk-20261015/walk-report.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'unity/Assets/Bloodwake/Resources/Animations/WarriorLocomotion/Warrior_ShieldWalk.fbx'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');action=next(iter(bpy.data.actions));rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
error=0
for index,sample in enumerate(report['footSamples']):
 bpy.context.scene.frame_set(index+1);bpy.context.view_layer.update()
 for name,expected in zip(['LeftFoot','RightFoot','LeftToeBase','RightToeBase'],sample):
  error=max(error,((rig.matrix_world@rig.pose.bones['mixamorig:'+name].head)-Vector(expected)).length)
assert error<.003,('FBX roundtrip changed the foot motion',error)
assert max(report['plantedFootMedianErrorMps'])<.15
print('WARRIOR_WALK_ROUNDTRIP_PASSED max_position_error_m=',error,'contact_errors_mps=',report['plantedFootMedianErrorMps'],flush=True)
