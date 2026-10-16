using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class RevenantThrustImport
 {
  const string Root="Assets/Bloodwake/Resources/",Folder=Root+"Animations/RevenantCombat/",Name="REV_ClawThrust",Request="Library/RevenantThrustImport.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   // Explicit one-shot refresh request for local asset iteration while the
   // editor is unfocused. No timers that reimport or rebuild assets unsolicited.
   const string refresh="Library/BloodwakeAssetRefresh.request";
   if(File.Exists(refresh)){File.Delete(refresh);AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);return;}
   if(!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   string command=File.ReadAllText(Request).Trim();File.Delete(Request);File.Delete("Library/RevenantThrustImport.result");
   try
   {
    Build();
    if(command=="review"){File.WriteAllText("Library/BloodwakeOpenPractice.request","play");File.WriteAllText("Library/RevenantDashReview.request","review");}
   }
   catch(Exception e){File.WriteAllText("Library/RevenantThrustImport.result","FAIL "+e);Debug.LogException(e);}
  }
  [MenuItem("Bloodwake/Import Revenant Claw Thrust")]
  public static void Build()
  {
   string path=Folder+Name+".fbx";AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.animationType=ModelImporterAnimationType.Generic;
   importer.importAnimation=true;importer.animationCompression=ModelImporterAnimationCompression.Off;
   var clips=importer.defaultClipAnimations;if(clips.Length!=1)throw new Exception("Expected one authored thrust clip");
   clips[0].name=Name;clips[0].loopTime=false;clips[0].loopPose=false;clips[0].lockRootPositionXZ=true;clips[0].lockRootRotation=true;
   importer.clipAnimations=clips;importer.SaveAndReimport();
   var imported=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Single(c=>c.name==Name);
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Root+"Models/revenant_noble/revenant_noble.fbx");
   var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(Folder+Name+".anim");
   if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,Folder+Name+".anim");}
   EditorUtility.CopySerialized(imported,clip);clip.name=Name;clip.ClearCurves();
   foreach(var binding in AnimationUtility.GetCurveBindings(imported))
   {
    // Combat poses must never resize the model or any skeletal segment.
    if(binding.path==""||binding.propertyName.StartsWith("m_LocalScale"))continue;var mapped=binding;
    if(!model.transform.Find(mapped.path))
    {
     var bone=model.GetComponentsInChildren<Transform>(true).SingleOrDefault(t=>t.name==binding.path.Split('/').Last());
     if(!bone)throw new Exception("Unmatched thrust bone "+binding.path);
     mapped.path=AnimationUtility.CalculateTransformPath(bone,model.transform);
    }
    AnimationUtility.SetEditorCurve(clip,mapped,AnimationUtility.GetEditorCurve(imported,binding));
   }
   var data=JObject.Parse(File.ReadAllText(Folder+"thrust.json"));float contact=(float)data["contact"],duration=(float)data["duration"];
   if(Mathf.Abs(clip.length-duration)>.002f||contact<=0||contact>=duration)throw new Exception("Authored thrust timing changed on import");
   AnimationUtility.SetAnimationEvents(clip,new[]{new AnimationEvent{time=contact,functionName="OnRevenantMarker",stringParameter="DAMAGE"}});clip.EnsureQuaternionContinuity();
   var instance=UnityEngine.Object.Instantiate(model);
   try
   {
    var bones=instance.GetComponentsInChildren<Transform>();var hand=bones.First(t=>t.name.EndsWith("RightHand"));var hips=bones.First(t=>t.name.EndsWith("Hips"));
    var scales=bones.ToDictionary(b=>b,b=>b.localScale);
    var min=Vector3.positiveInfinity;var max=Vector3.negativeInfinity;Vector3 hip=Vector3.zero;
    for(int i=0;i<=70;i++)
    {
     clip.SampleAnimation(instance,clip.length*i/70);min=Vector3.Min(min,hand.position);max=Vector3.Max(max,hand.position);
     if(i==0)hip=hips.position;var drift=hips.position-hip;drift.y=0;if(drift.magnitude>.005f)throw new Exception("Thrust retained uncontrolled root travel");
     foreach(var b in bones)if(Vector3.Distance(b.localScale,scales[b])>.0001f)throw new Exception("Thrust changes bone scale: "+b.name);
    }
    if((max-min).magnitude<.5f)throw new Exception("Thrust is frozen or incorrectly scaled");
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/revenant_noble.controller");var machine=controller.layers[0].stateMachine;
   var state=machine.states.FirstOrDefault(s=>s.state.name==Name).state??machine.AddState(Name);state.motion=clip;state.speed=1;state.speedParameterActive=false;
   EditorUtility.SetDirty(clip);EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();
   Debug.Log($"REVENANT_THRUST_IMPORTED duration={duration:F4} contact={contact:F4} windup trimmed; bind scale retained; open right claw; production mesh unchanged");
   File.WriteAllText("Library/RevenantThrustImport.result","PASS "+duration+" "+contact);
  }
 }
}
