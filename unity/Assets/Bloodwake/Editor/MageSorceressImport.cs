using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;
namespace Bloodwake.Editor
{
 // The player Mage is the sorceress (v3, 20 Oct 2026), built by art/mage/build_sorceress.py: Tripo body with a
 // swapped-in Tripo head, Mixamo rig, 4K PBR maps, and her Mixamo clips trimmed to their cast windows, all baked
 // onto the one skeleton in Blender. This points mage_player's prefab and controller at it.
 public static class MageSorceressImport
 {
  const string Root="Assets/Bloodwake/Resources/";
  public const string Model=Root+"Models/mage_sorceress/mage_sorceress.fbx";
  [MenuItem("Bloodwake/Import Mage Sorceress")]
  public static void Build()
  {
   AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(Model);if(importer==null)throw new Exception("Mage sorceress: run art/mage/build_sorceress.py first");
   importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;importer.animationCompression=ModelImporterAnimationCompression.Off;
   importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
   var clips=importer.defaultClipAnimations;
   foreach(var clip in clips){clip.name=clip.name.Split('|').Last();clip.loopTime=clip.name=="Idle"||clip.name=="Run"||clip.name=="Walk"||clip.name=="Mage_Fall";clip.loopPose=false;clip.lockRootPositionXZ=true;clip.lockRootRotation=true;}
   importer.clipAnimations=clips;importer.SaveAndReimport();
   var names=new[]{"Idle","Run","Walk","Attack","Hit","Hit2","Death","Ultimate","Mage_Backhand","Mage_GroundCast","Mage_Comet","Mage_Hurl","Mage_Fall","Mage_Land","Mage_Glide"};
   var imported=AssetDatabase.LoadAllAssetsAtPath(Model).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__")).ToDictionary(c=>c.name);
   foreach(var n in names)if(!imported.ContainsKey(n))throw new Exception("Mage sorceress: clip missing "+n);
   var path=Root+"Controllers/mage_player.controller";var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(path)??AnimatorController.CreateAnimatorControllerAtPath(path);
   var machine=controller.layers[0].stateMachine;
   foreach(var n in names){var state=machine.states.FirstOrDefault(s=>s.state.name==n).state??machine.AddState(n);state.motion=imported[n];if(n=="Idle")machine.defaultState=state;}
   EditorUtility.SetDirty(controller);
   var model=AssetDatabase.LoadAssetAtPath<GameObject>(Model);var instance=(GameObject)PrefabUtility.InstantiatePrefab(model);
   try
   {
    PrefabUtility.UnpackPrefabInstance(instance,PrefabUnpackMode.Completely,InteractionMode.AutomatedAction);instance.name="mage_player";
    var animator=instance.GetComponentInChildren<Animator>()??instance.AddComponent<Animator>();animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;
    SourceMaterials.Apply(instance,Model);
    var texture=instance.GetComponentInChildren<Renderer>().sharedMaterial.GetTexture("_BaseMap");if(!texture)throw new Exception("Mage sorceress: base colour did not bind");Debug.Log($"MAGE_SORCERESS_TEXTURE {texture.name} {texture.width}x{texture.height}");
    PrefabUtility.SaveAsPrefabAsset(instance,Root+"Actors/mage_player.prefab");
    // Real bone motion, not merely clip names.
    foreach(var n in new[]{"Idle","Run","Attack"})
    {
     var bone=instance.GetComponentsInChildren<Transform>().First(t=>t.name.EndsWith(n=="Idle"?"Head":n=="Run"?"LeftFoot":"RightHand"));
     var min=Vector3.positiveInfinity;var max=Vector3.negativeInfinity;
     for(int sample=0;sample<20;sample++){imported[n].SampleAnimation(instance,imported[n].length*sample/20);min=Vector3.Min(min,bone.position);max=Vector3.Max(max,bone.position);}
     float travel=(max-min).magnitude;if(travel<(n=="Idle"?.001f:.15f))throw new Exception($"Mage sorceress: {n} is frozen (travel {travel:F4} m)");
     Debug.Log($"MAGE_SORCERESS_MOTION {n} bone={bone.name} travel={travel:F3}m length={imported[n].length:F2}s");
    }
   }
   finally{UnityEngine.Object.DestroyImmediate(instance);}
   AssetDatabase.SaveAssets();
   Debug.Log("MAGE_SORCERESS_IMPORT_COMPLETE");
  }
  // Batch entry: import, then the usual Windows build.
  public static void ImportAndBuild(){Build();BuildGame.BuildWindows();}
 }
}
