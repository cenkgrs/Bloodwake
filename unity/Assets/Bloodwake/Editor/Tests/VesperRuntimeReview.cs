using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Bloodwake.Editor
{
 public static class VesperRuntimeReview
 {
  const string Scene="Assets/Bloodwake/Scenes/Bloodwake.unity";
  const string Output="/tmp/vesper-unity-review";
  const string Request="Library/VesperRuntimeReview.request";
  const string Running="Library/VesperRuntimeReview.running";
  static readonly (string key,float normalized,bool impact)[] Shots=
  {
   ("Idle",.18f,false),("Run",.42f,false),("Attack1",.42f,false),
   ("Attack2",.44f,false),("Attack3",.50f,false),("DashAttack",.48f,false),
   ("CastQ",.50f,true),("Ultimate",.55f,true),("Death",.72f,false)
  };
  static BloodwakeGame game;static Animator animator;static int stage=-1,index;static double next;
  static Vector3 focus;static RenderTexture target;static Texture2D image;
  static bool waitingForEditMode;

  [InitializeOnLoadMethod]
  static void Initialize()
  {
   EditorApplication.update+=PollRequest;
   if(File.Exists(Running))EditorApplication.update+=ResumeRunning;
  }

  static void ResumeRunning()
  {
   if(!EditorApplication.isPlaying||EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   EditorApplication.update-=ResumeRunning;stage=0;next=EditorApplication.timeSinceStartup+.25;
   EditorApplication.update+=Tick;
  }

  static void PollRequest()
  {
   if(!File.Exists(Request)||EditorApplication.isCompiling||EditorApplication.isUpdating||stage>=0)return;
   if(EditorApplication.isPlayingOrWillChangePlaymode)
   {
    if(waitingForEditMode)return;waitingForEditMode=true;EditorApplication.playModeStateChanged+=ResumeAfterStop;EditorApplication.isPlaying=false;return;
   }
   File.Delete(Request);Begin();
  }

  static void ResumeAfterStop(PlayModeStateChange state)
  {
   if(state!=PlayModeStateChange.EnteredEditMode)return;
   EditorApplication.playModeStateChanged-=ResumeAfterStop;waitingForEditMode=false;
   EditorApplication.delayCall+=PollRequest;
  }

  public static void Begin()
  {
   try
   {
    Directory.CreateDirectory(Output);
    foreach(var path in Directory.GetFiles(Output,"*.png"))File.Delete(path);
    File.Delete(Output+"/result.txt");File.Delete(Output+"/failure.txt");
    File.WriteAllText(Running,"run");
    var active=EditorSceneManager.GetActiveScene();
    if(active.path!=Scene)
    {
     if(active.isDirty)throw new Exception("Runtime review refused to replace a modified scene: "+active.path);
     EditorSceneManager.OpenScene(Scene,OpenSceneMode.Single);
    }
    EditorApplication.playModeStateChanged+=OnPlayMode;
    EditorApplication.update+=Tick;
    EditorApplication.isPlaying=true;
   }
   catch(Exception exception){Fail(exception);}
  }

  static void OnPlayMode(PlayModeStateChange state)
  {
   if(state==PlayModeStateChange.EnteredPlayMode){stage=0;next=EditorApplication.timeSinceStartup+.25;}
  }

  static void Tick()
  {
   if(stage<0||EditorApplication.timeSinceStartup<next)return;
   try
   {
    if(stage==0){Prepare();stage=1;next=EditorApplication.timeSinceStartup+.35;return;}
    if(stage==1){Validate();stage=2;index=0;next=EditorApplication.timeSinceStartup+.05;return;}
    if(stage==2)
    {
     if(index>=Shots.Length){Pass();return;}
     Pose(Shots[index].key,Shots[index].normalized,Shots[index].impact);
     stage=3;next=EditorApplication.timeSinceStartup+.08;return;
    }
    if(stage==3)
    {
     Capture(index+"-"+Shots[index].key.ToLowerInvariant());
     ClearTransientEffects();index++;stage=2;next=EditorApplication.timeSinceStartup+.04;
    }
   }
   catch(Exception exception){Fail(exception);}
  }

  static void Prepare()
  {
   game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();
   if(!game)throw new Exception("BloodwakeGame was not created by the production scene");
   game.StartRun("vesper");game.Screen="playing";game.enabled=false;
   if(!game.Player||game.Player.Kind!="vesper")throw new Exception("Production StartRun did not create Vesper");
   game.Player.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);
   animator=game.Player.Animator;animator.enabled=false;
   foreach(var renderer in UnityEngine.Object.FindObjectsByType<Renderer>(FindObjectsSortMode.None))
    if(!renderer.transform.IsChildOf(game.Player.transform))renderer.enabled=false;
   focus=game.Player.transform.position+Vector3.up*1.02f;
   game.Cam.transform.position=focus+new Vector3(4.6f,3.7f,5.8f);
   game.Cam.transform.LookAt(focus);game.Cam.orthographic=true;game.Cam.orthographicSize=2.45f;
   game.Cam.clearFlags=CameraClearFlags.SolidColor;game.Cam.backgroundColor=new Color(.018f,.012f,.014f);
   foreach(var canvas in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None))canvas.enabled=false;
   target=new RenderTexture(1400,1100,24,RenderTextureFormat.ARGB32);target.Create();
   image=new Texture2D(1400,1100,TextureFormat.RGB24,false);
   Pose("Idle",.18f,false);
  }

  static void Validate()
  {
   var clips=animator.runtimeAnimatorController.animationClips;
   foreach(var shot in Shots)if(!clips.Any(clip=>clip.name==shot.key))throw new Exception("Missing runtime animation clip: "+shot.key);
   var bones=animator.GetComponentsInChildren<Transform>(true);
   var hand=bones.FirstOrDefault(t=>t.name.EndsWith("RightHand"));
   var grip=bones.FirstOrDefault(t=>t.name=="VesperSwordGrip");
   var mid=bones.FirstOrDefault(t=>t.name=="VesperSwordMid");
   var tip=bones.FirstOrDefault(t=>t.name=="VesperSwordTip");
   if(!hand||!grip||!mid||!tip)throw new Exception("Sword grip/mid/tip sockets are absent from the imported runtime rig");
   if(grip.parent!=hand)throw new Exception("Sword grip is not parented directly to the right hand");
   if(Vector3.Distance(grip.position,tip.position)<1.1f)throw new Exception("Sword socket span is too short for the supplied greatsword");
   var renderers=animator.GetComponentsInChildren<Renderer>(true);
   foreach(var material in renderers.SelectMany(r=>r.sharedMaterials).Where(m=>m&&m.name.StartsWith("Source_Vesper")))
    if(!material.HasProperty("_BaseMap")||!material.GetTexture("_BaseMap"))throw new Exception("Runtime material has no albedo texture: "+material.name);
   if(renderers.SelectMany(r=>r.sharedMaterials).Count(m=>m&&m.name.StartsWith("Source_Vesper"))<2)throw new Exception("Armor and sword runtime materials were not both mapped");
   var blade=animator.GetComponent<VesperBladeVfx>();if(!blade)throw new Exception("Production prefab has no VesperBladeVfx");
   if(blade.GetComponentsInChildren<LineRenderer>(true).Length!=4)throw new Exception("Blade flame ribbons were not created");
   if(blade.GetComponentsInChildren<TrailRenderer>(true).Length!=2)throw new Exception("Blade motion trails were not created");
   if(blade.GetComponentsInChildren<ParticleSystem>(true).Length!=0)throw new Exception("Legacy square/smoke particle system is still attached to the blade");
   var shader=Resources.Load<Shader>("Vfx/vesper_blade_flame");if(!shader)throw new Exception("Blade flame shader could not be loaded");
   var shaderErrors=UnityEditor.ShaderUtil.GetShaderMessages(shader).Where(m=>m.severity==UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error).ToArray();
   if(shaderErrors.Length>0)throw new Exception("Blade flame shader error: "+shaderErrors[0].message);
   Debug.Log("VESPER_RUNTIME_VALIDATION_PASSED 9 clips, textured armor+sword, one-hand grip, ribbon flame VFX");
  }

  static void Pose(string key,float normalized,bool impact)
  {
   var clip=animator.runtimeAnimatorController.animationClips.First(c=>c.name==key);
   clip.SampleAnimation(animator.gameObject,Mathf.Clamp01(normalized)*clip.length);
   if(impact)
   {
    var property=typeof(BloodwakeGame).GetProperty("RevFx",BindingFlags.Instance|BindingFlags.NonPublic);
    var vfx=(RevenantVfx)property.GetValue(game);
    vfx.VesperGroundCast(game.Player.transform.position,key=="Ultimate"?3.5f:2.2f,key=="Ultimate");
   }
  }

  static void ClearTransientEffects()
  {
   foreach(var effect in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))
    if(effect)UnityEngine.Object.DestroyImmediate(effect.gameObject);
  }

  static void Capture(string name)
  {
   var previousTarget=game.Cam.targetTexture;var previousActive=RenderTexture.active;
   try
   {
    game.Cam.targetTexture=target;game.Cam.Render();RenderTexture.active=target;
    image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();
    File.WriteAllBytes(Output+"/"+name+".png",image.EncodeToPNG());
   }
   finally{game.Cam.targetTexture=previousTarget;RenderTexture.active=previousActive;}
  }

  static void Pass()
  {
   File.WriteAllText(Output+"/result.txt","PASS: production Unity scene; 9 supplied clips; textured armor and supplied sword; right-hand grip socket; no legacy particles; 4 flame ribbons + 2 motion trails; Q and Space impact VFX rendered.\n");
   Debug.Log("VESPER_RUNTIME_REVIEW_PASSED "+Output);Finish(0);
  }

  static void Fail(Exception exception)
  {
   try{Directory.CreateDirectory(Output);File.WriteAllText(Output+"/failure.txt",exception.ToString());}catch{}
   Debug.LogException(exception);Finish(1);
  }

  static void Finish(int code)
  {
   stage=-1;EditorApplication.update-=Tick;EditorApplication.playModeStateChanged-=OnPlayMode;
   File.Delete(Running);
   if(target){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image)UnityEngine.Object.DestroyImmediate(image);
   if(EditorApplication.isPlaying)EditorApplication.isPlaying=false;
   if(Application.isBatchMode)EditorApplication.delayCall+=()=>EditorApplication.Exit(code);
  }
 }
}
