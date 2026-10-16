using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace Bloodwake.Editor
{
 public static class VesperImport
 {
  const string Root="Assets/Bloodwake/Resources/",Model=Root+"Models/vesper_player/vesper_player.fbx";
  const string Request="Library/VesperImport.request";
  static readonly string[] Required={"Idle","Run","Attack1","Attack2","Attack3","DashAttack","CastQ","Ultimate","Death"};
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   File.Delete(Request);try{Build();}catch(Exception ex){Debug.LogException(ex);}
  }
  [MenuItem("Bloodwake/Import Vesper")]
  public static void Build()
  {
   if(!File.Exists(Model))throw new FileNotFoundException("Build Vesper's FBX first",Model);
   AssetDatabase.ImportAsset(Model,ImportAssetOptions.ForceSynchronousImport|ImportAssetOptions.ForceUpdate);
   var importer=(ModelImporter)AssetImporter.GetAtPath(Model);if(importer==null)throw new Exception("Vesper ModelImporter missing");
   importer.animationType=ModelImporterAnimationType.Generic;importer.avatarSetup=ModelImporterAvatarSetup.NoAvatar;importer.importAnimation=true;importer.animationCompression=ModelImporterAnimationCompression.Off;importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
   var clips=importer.defaultClipAnimations;
   foreach(var clip in clips)
   {
    clip.name=clip.name.Split('|').Last();clip.loopTime=clip.name=="Idle"||clip.name=="Run";clip.loopPose=clip.loopTime;
    clip.lockRootPositionXZ=true;clip.lockRootHeightY=true;clip.lockRootRotation=true;
   }
   importer.clipAnimations=clips;importer.SaveAndReimport();
   var imported=AssetDatabase.LoadAllAssetsAtPath(Model).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__")).ToArray();
   foreach(var required in Required)if(!imported.Any(c=>c.name==required))throw new Exception("Vesper clip missing: "+required+". Found: "+string.Join(", ",imported.Select(c=>c.name)));
   string controllerPath=Root+"Controllers/vesper_player.controller";var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath)??AnimatorController.CreateAnimatorControllerAtPath(controllerPath);var machine=controller.layers[0].stateMachine;
   foreach(var clip in imported){var state=machine.states.FirstOrDefault(s=>s.state.name==clip.name).state??machine.AddState(clip.name);state.motion=clip;if(clip.name=="Idle")machine.defaultState=state;}
   Directory.CreateDirectory(Root+"Actors");var source=AssetDatabase.LoadAssetAtPath<GameObject>(Model);var instance=(GameObject)PrefabUtility.InstantiatePrefab(source);
   try
   {
    var animator=instance.GetComponentInChildren<Animator>()??instance.AddComponent<Animator>();animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;SourceMaterials.Apply(instance,Model);
    if(!instance.GetComponentsInChildren<Renderer>(true).Any(r=>r.name.Contains("FierySword")))throw new Exception("Vesper sword renderer is not bound to the character");
    if(!instance.GetComponentsInChildren<Transform>(true).Any(t=>t.name.EndsWith("RightHand")))throw new Exception("Vesper right-hand bone missing");
    foreach(var socket in new[]{"VesperSwordGrip","VesperSwordMid","VesperSwordTip"})if(!instance.GetComponentsInChildren<Transform>(true).Any(t=>t.name==socket))throw new Exception("Vesper sword socket missing: "+socket);
    PrefabUtility.SaveAsPrefabAsset(instance,Root+"Actors/vesper_player.prefab");
    foreach(var key in new[]{"Run","Attack1","Attack2","Attack3","DashAttack","CastQ","Ultimate"})
    {
     var clip=imported.First(c=>c.name==key);clip.SampleAnimation(instance,clip.length*.5f);
     if(clip.length<.2f)throw new Exception("Vesper clip too short: "+key);Debug.Log($"VESPER_CLIP {key} length={clip.length:F3}s");
    }
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   AssetDatabase.SaveAssets();Debug.Log("VESPER_IMPORT_COMPLETE nine clips, supplied sword, prefab and controller ready");
  }
 }
}
