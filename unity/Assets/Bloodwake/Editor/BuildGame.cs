using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class BuildGame
 {
  [MenuItem("Bloodwake/Build Imported Game")]
  public static void Build()
  {
   const string root="Assets/Bloodwake/Resources/";Directory.CreateDirectory(root+"Actors");Directory.CreateDirectory(root+"Controllers");
   if(AssetDatabase.LoadAssetAtPath<Material>(root+"EffectUnlit.mat")==null)AssetDatabase.CreateAsset(new Material(Shader.Find("Universal Render Pipeline/Unlit")),root+"EffectUnlit.mat");
   foreach(string path in Directory.GetFiles(root+"Models","*.fbx",SearchOption.AllDirectories))
   {
    // Noble importer owns its action events; the generic pass would erase them.
    if(Path.GetFileNameWithoutExtension(path)=="revenant_noble"){RevenantNobleImport.Build();continue;}
    var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.animationType=ModelImporterAnimationType.Generic;importer.importAnimation=true;importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
    var clips=importer.defaultClipAnimations;foreach(var c in clips){c.name=c.name.Split('|').Last();c.loopTime=c.name.Contains("Idle")||c.name.Contains("Run")||c.name.Contains("Walk");c.lockRootPositionXZ=true;c.lockRootHeightY=true;c.lockRootRotation=true;}importer.clipAnimations=clips;importer.SaveAndReimport();
    string name=Path.GetFileNameWithoutExtension(path),controllerPath=root+"Controllers/"+name+".controller";
    var controller=AssetDatabase.LoadAssetAtPath<AnimatorController>(controllerPath);
    if(controller==null)controller=AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
    var machine=controller.layers[0].stateMachine;
    foreach(var clip in AssetDatabase.LoadAllAssetsAtPath(path).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__"))){var state=machine.states.FirstOrDefault(s=>s.state.name==clip.name).state;if(state==null)state=machine.AddState(clip.name);state.motion=clip;if(clip.name.Contains("Idle"))machine.defaultState=state;}
    var instance=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(path));
    var animator=instance.GetComponentInChildren<Animator>();if(animator==null)animator=instance.AddComponent<Animator>();animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;
    SourceMaterials.Apply(instance,path);
    PrefabUtility.SaveAsPrefabAsset(instance,root+"Actors/"+name+".prefab");UnityEngine.Object.DestroyImmediate(instance);
   }
   RevenantVfxImport.Build();
   if(File.Exists(root+"Animations/WarriorLocomotion/Warrior_ShieldWalk.fbx"))WarriorWalkImport.Build();
   if(File.Exists(root+"Animations/WarriorCombat/Warrior_OutwardSlash.fbx"))WarriorAttackImport.Build();
   BuildRooms();
   var scene=EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,Application.isBatchMode?NewSceneMode.Single:NewSceneMode.Additive);
   UnityEngine.SceneManagement.SceneManager.SetActiveScene(scene);new GameObject("Bloodwake").AddComponent<BloodwakeGame>();
   string scenePath="Assets/Bloodwake/Scenes/Bloodwake.unity";EditorSceneManager.SaveScene(scene,scenePath);EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(scenePath,true)};EditorSceneManager.playModeStartScene=AssetDatabase.LoadAssetAtPath<SceneAsset>(scenePath);PlayerSettings.productName="Bloodwake";PlayerSettings.companyName="Bloodwake";AssetDatabase.SaveAssets();Validate();Debug.Log("BLOODWAKE_GAME_SCENE_READY");
  }
  public static void Validate()
  {
   int checks=0;
   foreach(string id in new[]{"warrior","revenant","gunslinger","mage","assassin"})
   {
    var run=new RunState(id);if(run.Stats.N("hp")<=0||run.Weapons.Count!=1)throw new Exception("Invalid class "+id);checks++;
    run.AddXp(100000);if(run.Level!=2||run.PendingLevels!=1)throw new Exception("XP one-level gate broken");checks++;
    float before=run.Stats.N("damage");run.Upgrade("sharpened");if(run.Stats.N("damage")<=before)throw new Exception("Upgrade effect missing");checks++;
   }
   foreach(var guid in AssetDatabase.FindAssets("t:Prefab",new[]{"Assets/Bloodwake/Resources/Actors"}))
   {
    var p=AssetDatabase.LoadAssetAtPath<GameObject>(AssetDatabase.GUIDToAssetPath(guid));var a=p.GetComponentInChildren<Animator>();if(a==null||a.runtimeAnimatorController==null||a.runtimeAnimatorController.animationClips.Length==0)throw new Exception("Missing clips: "+p.name);checks++;
    if(p.GetComponentsInChildren<Renderer>().Any(r=>r.name=="Icosphere"||r.sharedMaterials.Any(m=>m==null||m.shader==null)))throw new Exception("Invalid geometry/material: "+p.name);checks++;
   }
   var meta=new Progression();if(!meta.Import("{\"essence\":25,\"levels\":{},\"ownedEquipment\":[],\"loadouts\":[{},{},{}],\"activeLoadout\":0}")||meta.Essence!=25)throw new Exception("Save compatibility failed");checks++;
   foreach(var room in GameData.Rooms["rooms"])
   {
    string id=room.S("id"),path="Assets/Bloodwake/Resources/Rooms/"+id+"/"+id+"_environment.prefab";
    var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(path);if(prefab==null)throw new Exception("Missing converted room "+id);checks++;
    if(!File.Exists(Path.GetDirectoryName(path)+"/collision.json"))throw new Exception("Missing room collisions "+id);checks++;
    foreach(var renderer in prefab.GetComponentsInChildren<Renderer>(true))foreach(var mat in renderer.sharedMaterials)if(mat==null||!AssetDatabase.GetAssetPath(mat).Contains("/Source_"))throw new Exception("Room uses unconverted material "+id+" / "+renderer.name);
    checks++;
   }
   Debug.Log("BLOODWAKE_DATA_ASSET_CHECKS "+checks+" passed");
  }
  static void BuildRooms()
  {
   string root="Assets/Bloodwake/Resources/Rooms";if(!Directory.Exists(root))return;
   foreach(var path in Directory.GetFiles(root,"*.fbx",SearchOption.AllDirectories))
   {
    var importer=(ModelImporter)AssetImporter.GetAtPath(path);if(!importer.importLights){importer.importLights=true;importer.SaveAndReimport();}
    var go=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(path));var converted=new System.Collections.Generic.Dictionary<Material,Material>();
    foreach(var lamp in go.GetComponentsInChildren<Light>()){lamp.type=LightType.Point;lamp.range=6.5f;lamp.intensity=2;lamp.color=new Color(1,.7f,.42f);lamp.shadows=LightShadows.None;}
    SourceMaterials.Apply(go,path);
    var room=GameData.Rooms["rooms"].First(r=>r.S("id")==Path.GetFileNameWithoutExtension(path));
    foreach(var renderer in go.GetComponentsInChildren<Renderer>())if(renderer.name=="Outside"){
     string matPath=Path.GetDirectoryName(path)+"/Source_Outside.mat";var mat=AssetDatabase.LoadAssetAtPath<Material>(matPath);if(mat==null){mat=new Material(Shader.Find("Bloodwake/Town Outside"));AssetDatabase.CreateAsset(mat,matPath);}mat.SetTexture("_BaseMap",AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/Bloodwake/Resources/textures/rooms/cobble_albedo.png"));mat.SetVector("_HalfSize",new Vector4((float)room["size"][0]/2+9,(float)room["size"][1]/2+9,0,0));renderer.sharedMaterial=mat;
    }
    PrefabUtility.SaveAsPrefabAsset(go,Path.GetDirectoryName(path)+"/"+Path.GetFileNameWithoutExtension(path)+"_environment.prefab");UnityEngine.Object.DestroyImmediate(go);
   }
  }
  public static void BuildLinux()
  {
   Validate();Directory.CreateDirectory("Builds/Linux");
   var report=BuildPipeline.BuildPlayer(new[]{"Assets/Bloodwake/Scenes/Bloodwake.unity"},"Builds/Linux/Bloodwake.x86_64",BuildTarget.StandaloneLinux64,BuildOptions.Development);
   if(report.summary.result!=UnityEditor.Build.Reporting.BuildResult.Succeeded)throw new Exception("Linux player build failed");
   Debug.Log("BLOODWAKE_LINUX_BUILD_READY");
  }
  public static void BuildAndLinux(){Build();BuildLinux();}
 }
}
