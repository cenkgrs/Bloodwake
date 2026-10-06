"""Re-import the delivered GLB in a clean Blender scene and validate clips."""
from pathlib import Path
import json
import bpy

HERE=Path(__file__).resolve().parent
OUT=HERE/"bloodhound_delivery"
expected=["BH_BombThrow","BH_Death","BH_FiveShot","BH_GetHit","BH_Idle","BH_Ultimate_BloodWake","BH_Walk_InPlace"]
def check(path, importer):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    importer(filepath=str(path))
    rigs=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    imported=sorted(a.name for a in bpy.data.actions)
    actions=sorted(n.split("|")[-1] for n in imported if n.split("|")[-1].startswith("BH_"))
    return {"file":str(path),"armatures":len(rigs),"actions":actions,"raw_action_names":imported,"bones":len(rigs[0].data.bones) if rigs else 0,"passed":len(rigs)==1 and actions==expected}
glb=check(OUT/"Bloodhound_GameReady_Godot.glb",bpy.ops.import_scene.gltf)
fbx=check(OUT/"Bloodhound_GameReady_Unity_Unreal.fbx",bpy.ops.import_scene.fbx)
result={"expected_actions":expected,"glb":glb,"fbx":fbx,"passed":glb["passed"] and fbx["passed"]}
(OUT/"reimport_validation.json").write_text(json.dumps(result,indent=2)+"\n")
assert result["passed"], result
print("BLOODHOUND_REIMPORT_PASS",json.dumps(result))
