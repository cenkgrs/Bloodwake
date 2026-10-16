using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace Bloodwake.Editor
{
 public static class SanctuaryNpcImport
 {
  const string Root="Assets/Bloodwake/Resources/",Request="Library/SanctuaryNpcImport.request";
  static readonly string[] Ids={"enemy_merchant","enemy_mentor"};

  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   File.Delete(Request);File.Delete("Library/SanctuaryNpcImport.result");
   try{Build();File.WriteAllText("Library/SanctuaryNpcImport.result","PASS");}
   catch(Exception e){File.WriteAllText("Library/SanctuaryNpcImport.result","FAIL "+e);Debug.LogException(e);}
  }

  [MenuItem("Bloodwake/Import Sanctuary NPCs")]
  public static void Build()
  {
   Directory.CreateDirectory(Root+"Actors");Directory.CreateDirectory(Root+"Controllers");
   foreach(string id in Ids)Build(id);
   AssetDatabase.SaveAssets();
   Debug.Log("SANCTUARY_NPCS_IMPORTED merchant+mentor");
  }

  static void Build(string id)
  {
   string folder=Root+"Models/"+id+"/",model=folder+id+".fbx";
   AssetDatabase.ImportAsset(model,ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(model);
   importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;
   importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
   var clips=importer.defaultClipAnimations;
   if(clips.Length==0)throw new Exception(id+" has no idle clip");
   foreach(var clip in clips){clip.name="Idle";clip.loopTime=true;clip.loopPose=true;clip.lockRootPositionXZ=true;clip.lockRootHeightY=true;clip.lockRootRotation=true;}
   importer.clipAnimations=clips;importer.SaveAndReimport();

   var source=AssetDatabase.LoadAssetAtPath<GameObject>(model);if(!source)throw new Exception(id+" model missing");
   var idle=AssetDatabase.LoadAllAssetsAtPath(model).OfType<AnimationClip>().FirstOrDefault(c=>c.name=="Idle"&&!c.name.StartsWith("__preview__"));
   if(!idle)throw new Exception(id+" imported Idle missing");
   string controllerPath=Root+"Controllers/"+id+".controller";
   var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath)??AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
   var machine=controller.layers[0].stateMachine;
   foreach(var child in machine.states)machine.RemoveState(child.state);
   var state=machine.AddState("Idle");state.motion=idle;machine.defaultState=state;

   var instance=(GameObject)PrefabUtility.InstantiatePrefab(source);instance.name=id;
   var animator=instance.GetComponentInChildren<Animator>()??instance.AddComponent<Animator>();
   animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;animator.cullingMode=AnimatorCullingMode.CullUpdateTransforms;
   SourceMaterials.Apply(instance,model);
   int bones=animator.GetComponentsInChildren<Transform>().Length;
   int triangles=instance.GetComponentsInChildren<SkinnedMeshRenderer>().Where(r=>r.sharedMesh).Sum(r=>r.sharedMesh.triangles.Length/3);
   if(triangles<90000||bones<60)throw new Exception($"{id} incomplete bones={bones} triangles={triangles}");
   PrefabUtility.SaveAsPrefabAsset(instance,Root+"Actors/"+id+".prefab");
   UnityEngine.Object.DestroyImmediate(instance);
  }
 }
}
