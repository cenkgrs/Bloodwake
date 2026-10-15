using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 // Deterministic in-scene diagnostic: no saved profile, scene or gameplay tuning writes.
 public static class WarriorMotionCapture
 {
  const string Request="Library/WarriorMotionCapture.request";
  static BloodwakeGame game;static Enemy enemy;static int frame;static double next;
  static string output;static RenderTexture rt;static Texture2D image;
  static Vector3 playerStart,enemyStart;static Quaternion playerRotation,enemyRotation;
  static Vector3 cameraStart;static Quaternion cameraRotation;static float cameraSize;
  static float cooldown;static readonly List<string> rows=new();
  static object Call(string method,params object[] args)=>typeof(BloodwakeGame).GetMethod(method,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(game,args);
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Update;}
  static void Update()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   if(!game)
   {
    if(!File.Exists(Request)||!EditorApplication.isPlaying)return;
    game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();
    if(!game||game.Screen!="playing"||game.Enemies.Count!=1){game=null;return;}
    output=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(output);
    enemy=game.Enemies[0];playerStart=game.Player.transform.position;enemyStart=enemy.View.transform.position;playerRotation=game.Player.transform.rotation;enemyRotation=enemy.View.transform.rotation;cooldown=enemy.Cooldown;
    cameraStart=game.Cam.transform.position;cameraRotation=game.Cam.transform.rotation;cameraSize=game.Cam.orthographicSize;
    game.enabled=false;game.Player.Animator.enabled=false;enemy.View.Animator.enabled=false;
    if(enemy.View.LocomotionSpeed<=0)throw new Exception("Warrior walk calibration is missing");
    game.Player.transform.position=new Vector3(0,0,5);enemy.View.transform.position=Vector3.zero;
    enemy.Stagger=enemy.RecoilTime=enemy.AreaRecovery=enemy.View.Locked=0;enemy.Casting=false;
    foreach(int fps in new[]{30,60,144,240,360})
    {
     enemy.Turning=false;enemy.View.Play("Idle",0);enemy.View.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);game.Player.transform.position=Vector3.back*6;enemy.Cooldown=999;
     Call("UpdateNavigation",1f);Call("TickEnemies",1f/fps);
     for(int i=0;i<fps*2&&enemy.Turning;i++){Call("TickEnemies",1f/fps);enemy.View.Animator.Update(1f/fps);}
     var start=enemy.View.transform.position;Call("TickEnemies",1f/fps);var step=enemy.View.transform.position-start;
     if(step.sqrMagnitude<1e-8f||Vector3.Dot(step.normalized,enemy.View.transform.forward)<.999f)throw new Exception("Warrior behind-player facing failed at "+fps+" fps");
     Debug.Log("WARRIOR_FACING_PASSED "+fps+" fps");
    }
    foreach(float multiplier in new[]{1f,.3f,1.22f})
    {
     enemy.View.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);game.Player.transform.position=Vector3.forward*7;enemy.Cooldown=999;
     enemy.Slow=multiplier<1?5:0;enemy.SlowAmount=1-multiplier;enemy.Aura=multiplier>1?5:0;
     Call("UpdateNavigation",1f);var before=enemy.View.transform.position;Call("TickEnemies",1f/60);
     float actual=(enemy.View.transform.position-before).magnitude*60,expected=actual/enemy.View.LocomotionSpeed;
     if(Mathf.Abs(enemy.View.PlaybackRate-expected)>.001f)throw new Exception("Warrior gait does not match speed modifier "+multiplier);
     Debug.Log($"WARRIOR_STRIDE_RATE_PASSED modifier={multiplier} mps={actual:F4} rate={expected:F4}");
    }
    enemy.Slow=enemy.Aura=0;
    enemy.View.transform.position=Vector3.zero;game.Player.transform.position=new Vector3(0,0,5);
    enemy.View.Play("Run",0);game.Player.Play("Idle",0);
    rt=new RenderTexture(1280,720,24);image=new Texture2D(1280,720,TextureFormat.RGB24,false);
    frame=0;next=EditorApplication.timeSinceStartup;rows.Clear();rows.Add("frame,phase,speed,root_dot_target,chest_dot_target,anim_speed,state");
   }
   if(EditorApplication.timeSinceStartup<next)return;next=EditorApplication.timeSinceStartup+1.0/30;
   try
   {
    int phase=frame/90;
    Vector3[] targets={new Vector3(0,0,7),new Vector3(0,0,-7),new Vector3(7,0,0),new Vector3(-7,0,0)};
    game.Player.transform.position=targets[phase];enemy.Cooldown=999;
    var before=enemy.View.transform.position;
    // Exercise the high-FPS case, recording 30 Hz output without skipping sim ticks.
    for(int substep=0;substep<8;substep++){Call("UpdateNavigation",1f/240);Call("TickEnemies",1f/240);enemy.View.Animator.Update(1f/240);game.Player.Animator.Update(1f/240);}
    game.Cam.transform.position=enemy.View.transform.position+new Vector3(6,5,7);game.Cam.transform.LookAt(enemy.View.transform.position+Vector3.up);game.Cam.orthographicSize=3.2f;
    var moved=enemy.View.transform.position-before;var target=(game.Player.transform.position-enemy.View.transform.position).normalized;
    var bones=enemy.View.Animator.GetComponentsInChildren<Transform>();
    var left=bones.First(t=>t.name.EndsWith("LeftArm"));var right=bones.First(t=>t.name.EndsWith("RightArm"));var hips=bones.First(t=>t.name.EndsWith("Hips"));var head=bones.First(t=>t.name.EndsWith("Head"));
    var chest=Vector3.Cross(right.position-left.position,head.position-hips.position);chest.y=0;chest.Normalize();
    rows.Add($"{frame},{phase},{moved.magnitude*30:F4},{Vector3.Dot(enemy.View.transform.forward,target):F4},{Vector3.Dot(chest,target):F4},{enemy.View.PlaybackRate:F4},{enemy.View.Animator.GetCurrentAnimatorStateInfo(0).shortNameHash}");
    if(frame==15)
    {
     var clip=enemy.View.Animator.GetCurrentAnimatorClipInfo(0).First().clip;
     if(clip.name!="Warrior_ShieldWalk")throw new Exception("Warrior plays the wrong locomotion clip: "+clip.name);
     Debug.Log("WARRIOR_WALK_LIVE_CLIP_PASSED "+AssetDatabase.GetAssetPath(clip));
    }
    if(frame%2==0)
    {
     var camera=game.Cam;var oldTarget=camera.targetTexture;var oldActive=RenderTexture.active;
     camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
     File.WriteAllBytes(Path.Combine(output,$"frame-{frame/2:D4}.jpg"),image.EncodeToJPG(88));camera.targetTexture=oldTarget;RenderTexture.active=oldActive;
    }
    if(++frame>=360)Finish();
   }
   catch(Exception ex){Debug.LogException(ex);Finish();}
  }
  static void Finish()
  {
   File.WriteAllLines(Path.Combine(output,"motion.csv"),rows);
   if(game){enemy.Turning=false;enemy.View.Play("Idle",0);game.Player.transform.SetPositionAndRotation(playerStart,playerRotation);enemy.View.transform.SetPositionAndRotation(enemyStart,enemyRotation);enemy.Cooldown=cooldown;game.Cam.transform.SetPositionAndRotation(cameraStart,cameraRotation);game.Cam.orthographicSize=cameraSize;game.Player.Animator.enabled=true;enemy.View.Animator.enabled=true;game.enabled=true;}
   if(rt){rt.Release();UnityEngine.Object.DestroyImmediate(rt);}if(image)UnityEngine.Object.DestroyImmediate(image);
   Debug.Log("WARRIOR_MOTION_CAPTURE_DONE "+output+" frames="+frame);game=null;
  }
 }
}
