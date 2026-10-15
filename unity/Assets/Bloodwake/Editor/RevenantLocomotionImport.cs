using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class RevenantLocomotionImport
 {
  const string Root="Assets/Bloodwake/Resources/";
  [MenuItem("Bloodwake/Import Revenant Locomotion")]
  public static void Build()
  {
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(Root+"Controllers/revenant_player.controller");
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Root+"Models/revenant_player/revenant_player.fbx");
   foreach(var name in new[]{"REV_NeutralIdle","REV_SwaggerWalk","REV_StandardRun"})
   {
    var path=Root+"Animations/RevenantLocomotion/"+name+".fbx";
    var importer=AssetImporter.GetAtPath(path) as ModelImporter;
    if(!importer)throw new InvalidOperationException("Missing locomotion FBX: "+path);
    if(importer.clipAnimations.Length!=1||importer.clipAnimations[0].name!=name||!importer.clipAnimations[0].loopTime)
    {
     importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;
     importer.animationCompression=ModelImporterAnimationCompression.Off;
     var clips=importer.defaultClipAnimations;
     if(clips.Length!=1)throw new InvalidOperationException("Expected one clip: "+path);
     clips[0].name=name;clips[0].loopTime=true;clips[0].loopPose=false;
     clips[0].lockRootPositionXZ=true;clips[0].lockRootRotation=true;
     importer.clipAnimations=clips;importer.SaveAndReimport();
    }
    var imported=AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Single(c=>c.name==name);
    var output=Root+"Animations/RevenantLocomotion/"+name+".anim";
    var clip=AssetDatabase.LoadAssetAtPath<AnimationClip>(output);
    if(!clip){clip=new AnimationClip();AssetDatabase.CreateAsset(clip,output);}
    EditorUtility.CopySerialized(imported,clip);clip.name=name;
    // Unity collapses the only top-level object in an animation-only FBX.
    // Restore the production model's armature prefix, retaining its object transform.
    var rootBone=model.GetComponentsInChildren<Transform>(true).Single(t=>t.name=="root");
    var rootPath=AnimationUtility.CalculateTransformPath(rootBone,model.transform);
    var prefix=rootPath.Substring(0,rootPath.Length-"root".Length);
    var sourceBindings=AnimationUtility.GetCurveBindings(imported);
    clip.ClearCurves();
    foreach(var binding in sourceBindings)
    {
     if(binding.path=="")continue;
     var mapped=binding;
     if(!model.transform.Find(mapped.path))mapped.path=prefix+mapped.path;
     AnimationUtility.SetEditorCurve(clip,mapped,AnimationUtility.GetEditorCurve(imported,binding));
    }
    EditorUtility.SetDirty(clip);
    var bindings=AnimationUtility.GetCurveBindings(clip);
    var missing=bindings.Where(b=>b.path!=""&&!model.transform.Find(b.path)).Select(b=>b.path).Distinct().ToArray();
    if(missing.Length>0)throw new InvalidOperationException("Locomotion binding mismatch: "+string.Join(", ",missing));
    var machine=controller.layers[0].stateMachine;
    var state=machine.states.FirstOrDefault(s=>s.state.name==name).state;
    if(!state)state=machine.AddState(name);
    state.motion=clip;
    if(name=="REV_NeutralIdle")machine.defaultState=state;
    if(name=="REV_StandardRun")
    {
     var legs=controller.layers.First(l=>l.name=="Moving attack legs");
     foreach(var s in legs.stateMachine.states)s.state.motion=clip;
    }
    Debug.Log("REVENANT_LOCOMOTION_IMPORT "+name+" duration="+clip.length+" bindings="+bindings.Length+" all paths valid");
   }
   EditorUtility.SetDirty(controller);AssetDatabase.SaveAssets();
  }
 }
}
