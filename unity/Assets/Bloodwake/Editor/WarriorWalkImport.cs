using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class WarriorWalkImport
 {
  const string Root="Assets/Bloodwake/Resources/",Folder=Root+"Animations/WarriorLocomotion/",Name="Warrior_ShieldWalk",Request="Library/WarriorWalkImport.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   File.Delete(Request);try{Build();}catch(Exception e){Debug.LogException(e);}
  }
  [MenuItem("Bloodwake/Import Warrior Shield Walk")]
  public static void Build()
  {
   var path=Folder+Name+".fbx";AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;importer.animationCompression=ModelImporterAnimationCompression.Off;
   var clips=importer.defaultClipAnimations;if(clips.Length!=1)throw new Exception("Expected one Warrior walk clip");
   clips[0].name=Name;clips[0].loopTime=true;clips[0].loopPose=false;clips[0].lockRootPositionXZ=true;clips[0].lockRootRotation=true;importer.clipAnimations=clips;importer.SaveAndReimport();
   var imported=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Single(c=>c.name==Name);
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Root+"Models/enemy_warrior/enemy_warrior.fbx");
   var output=Folder+Name+".anim";var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(output);
   if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,output);}EditorUtility.CopySerialized(imported,clip);clip.name=Name;clip.ClearCurves();
   foreach(var binding in AnimationUtility.GetCurveBindings(imported))
   {
    if(binding.path=="")continue;var mapped=binding;
    if(!model.transform.Find(mapped.path))
    {
     var bone=model.GetComponentsInChildren<Transform>(true).SingleOrDefault(t=>t.name==binding.path.Split('/').Last());
     if(!bone)throw new Exception("Unmatched Warrior walk bone "+binding.path);
     mapped.path=AnimationUtility.CalculateTransformPath(bone,model.transform);
    }
    AnimationUtility.SetEditorCurve(clip,mapped,AnimationUtility.GetEditorCurve(imported,binding));
   }
   var instance=UnityEngine.Object.Instantiate(model);
   try
   {
    var foot=instance.GetComponentsInChildren<Transform>().First(t=>t.name.EndsWith("LeftFoot"));var min=Vector3.positiveInfinity;var max=Vector3.negativeInfinity;
    for(int i=0;i<24;i++){clip.SampleAnimation(instance,clip.length*i/24);min=Vector3.Min(min,foot.position);max=Vector3.Max(max,foot.position);}
    if((max-min).magnitude<.4f)throw new Exception("Warrior walk is frozen or scale is incorrect");
    Debug.Log($"WARRIOR_WALK_BONE_VALIDATED duration={clip.length:F4} footTravel={(max-min).magnitude:F4}m");
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/enemy_warrior.controller");
   var machine=controller.layers[0].stateMachine;
   var state=machine.states.FirstOrDefault(s=>s.state.name==Name).state??machine.AddState(Name);state.motion=clip;
   EditorUtility.SetDirty(clip);EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();
   Debug.Log("WARRIOR_WALK_IMPORT_COMPLETE enemy only; existing mesh, equipment, idle and combat preserved");
  }
 }
}
