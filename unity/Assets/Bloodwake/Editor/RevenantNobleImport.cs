using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class RevenantNobleImport
 {
  const string Root="Assets/Bloodwake/Resources/",Model=Root+"Models/revenant_noble/revenant_noble.fbx";
  const string Request="Library/RevenantNobleImport.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   File.Delete(Request);try{Build();}catch(Exception ex){Debug.LogException(ex);}
  }
  [MenuItem("Bloodwake/Import Noble Revenant")]
  public static void Build()
  {
   AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(Model);importer.animationType=ModelImporterAnimationType.Generic;
   importer.importAnimation=true;importer.animationCompression=ModelImporterAnimationCompression.Off;
   importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
   var actions=(JObject)JObject.Parse(File.ReadAllText(Root+"Data/revenant_events.json"))["actions"];
   var clips=importer.defaultClipAnimations;
   foreach(var clip in clips)
   {
    clip.name=clip.name.Split('|').Last();clip.loopTime=clip.name.Contains("Idle")||clip.name.Contains("Run")||clip.name.Contains("Walk");clip.loopPose=false;
    clip.lockRootPositionXZ=true;clip.lockRootRotation=true;
    JObject markers=actions[clip.name]?["events"] as JObject;
    // First visible palm/finger contact, not the later held-together pose.
    if(clip.name=="REV_BloodClap")markers=JObject.Parse("{\"CLAP_GATHER\":8,\"CLAP_DAMAGE\":24,\"RECOVER\":60}");
    if(clip.name=="REV_BloodBurst")markers=JObject.Parse("{\"ULT_TELEGRAPH_START\":12,\"ULT_DAMAGE\":51,\"ULT_DISSIPATE\":73}");
    if(clip.name=="REV_Death")markers=JObject.Parse("{\"DEATH_GROUND\":150}");
    float frames=clip.lastFrame-clip.firstFrame;
    clip.events=markers==null?Array.Empty<AnimationEvent>():markers.Properties().Where(p=>(float)p.Value-1<=frames).Select(p=>new AnimationEvent{functionName="OnRevenantMarker",stringParameter=p.Name,time=((float)p.Value-1)/frames,messageOptions=SendMessageOptions.DontRequireReceiver}).ToArray();
   }
   importer.clipAnimations=clips;importer.SaveAndReimport();
   var path=Root+"Controllers/revenant_noble.controller";var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(path)??AnimatorController.CreateAnimatorControllerAtPath(path);
   var machine=controller.layers[0].stateMachine;
   foreach(var clip in AssetDatabase.LoadAllAssetsAtPath(Model).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__")))
   {
    var state=machine.states.FirstOrDefault(s=>s.state.name==clip.name).state??machine.AddState(clip.name);state.motion=clip;if(clip.name=="REV_NeutralIdle")machine.defaultState=state;
    Debug.Log($"NOBLE_CLIP {clip.name} length={clip.length} events={string.Join(",",clip.events.Select(e=>e.stringParameter+"@"+e.time))}");
   }
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Model);var instance=(GameObject)PrefabUtility.InstantiatePrefab(model);
   try
   {
    var animator=instance.GetComponentInChildren<Animator>()??instance.AddComponent<Animator>();animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;
    SourceMaterials.Apply(instance,Model);
    var texture=instance.GetComponentInChildren<Renderer>().sharedMaterial.GetTexture("_BaseMap");if(!texture||texture.width!=8192)throw new Exception("Noble source texture is not 8K");
    PrefabUtility.SaveAsPrefabAsset(instance,Root+"Actors/revenant_noble.prefab");
    // Validate actual imported bone motion, not merely the existence of clip names.
    foreach(var key in new[]{"REV_NeutralIdle","REV_StandardRun","REV_SwaggerWalk"})
    {
     var clip=controller.animationClips.First(c=>c.name==key);
     var bone=instance.GetComponentsInChildren<Transform>().First(t=>t.name.EndsWith(key.Contains("Idle")?"Head":"LeftFoot"));
     var min=Vector3.positiveInfinity;var max=Vector3.negativeInfinity;
     for(int sample=0;sample<20;sample++){clip.SampleAnimation(instance,clip.length*sample/20);min=Vector3.Min(min,bone.position);max=Vector3.Max(max,bone.position);}
     float travel=(max-min).magnitude;
     if(travel<(key.Contains("Idle")?.001f:.2f))throw new Exception(key+" contains a frozen pose: travel="+travel);
     Debug.Log($"NOBLE_MOTION_VALIDATED {key} bone={bone.name} travel={travel:F4}m");
    }
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   AssetDatabase.SaveAssets();Debug.Log("REVENANT_NOBLE_IMPORT_COMPLETE original 8K color, unchanged geometry, six supplied clips + temporary previous combat");
  }
 }
}
