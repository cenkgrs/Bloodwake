using System;
using System.IO;
using System.Reflection;
using System.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class NobleRevenantCapture
 {
  const string Request="Library/NobleRevenantCapture.request";
  static BloodwakeGame game;static int frame,impact;static double next;static string folder;static RenderTexture rt;static Texture2D image;
  static Vector3 cameraPos,playerPos;static Quaternion cameraRot;static float cameraSize;
  static object Call(string method,params object[] args)=>typeof(BloodwakeGame).GetMethod(method,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(game,args);
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   if(!game)
   {
    if(!EditorApplication.isPlaying||!File.Exists(Request))return;
    game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||!game.Player||!game.Player.NobleRevenant||game.Enemies.Count!=1){game=null;return;}
    folder=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(folder);
    game.enabled=false;game.Player.Animator.enabled=false;game.Enemies[0].View.Animator.enabled=false;
    cameraPos=game.Cam.transform.position;cameraRot=game.Cam.transform.rotation;cameraSize=game.Cam.orthographicSize;playerPos=game.Player.transform.position;
    game.Player.transform.position=Vector3.zero;game.Player.transform.rotation=Quaternion.identity;game.Enemies[0].View.transform.position=Vector3.forward*1.6f;
    typeof(BloodwakeGame).GetField("aim",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(game,Vector3.forward);
    game.Cam.transform.position=new Vector3(7,6,9);game.Cam.transform.LookAt(Vector3.up);game.Cam.orthographicSize=4;
    rt=new RenderTexture(1280,960,24);image=new Texture2D(1280,960,TextureFormat.RGB24,false);
    frame=0;impact=game.Enemies[0].ImpactVersion;next=EditorApplication.timeSinceStartup;
    foreach(float angle in new[]{0f,44f,-44f,46f,-46f,90f,180f})
    {
     var offset=Quaternion.Euler(0,angle,0)*Vector3.forward*3.9f;
     if(BloodwakeGame.InsideBloodCone(offset,Vector3.forward,4)!=(Mathf.Abs(angle)<45))throw new Exception("Blood cone angle mismatch "+angle);
    }
    if(BloodwakeGame.InsideBloodCone(Vector3.forward*4.01f,Vector3.forward,4))throw new Exception("Blood cone exceeds VFX reach");
    Debug.Log("NOBLE_BLOOD_CONE_PASSED front/edge/side/back/range");
   }
   if(EditorApplication.timeSinceStartup<next)return;next=EditorApplication.timeSinceStartup+1.0/30;
   try
   {
    if(frame==0)game.Player.Play("Idle",0);
    if(frame==30){game.Player.Locked=0;Call("Cast",1);}
    if(frame==75)
    {
     if(game.Enemies[0].ImpactVersion!=impact+2)throw new Exception("E must damage exactly once on clap (hit + area interruption)");
     Debug.Log("NOBLE_E_CONTACT_PASSED");impact=game.Enemies[0].ImpactVersion;game.Player.Locked=0;Call("Cast",2);
    }
    if(frame==125)
    {
     if(game.Enemies[0].ImpactVersion!=impact+2)throw new Exception("Space must damage exactly once on opening (hit + area interruption)");Debug.Log("NOBLE_SPACE_CONTACT_PASSED");game.Player.Play("Run",0);
    }
    if(frame==165)game.Player.Play("Walk",0);
    if(frame==140||frame==180||frame==10)
    {
     string key=frame==140?"Run":frame==180?"Walk":"Idle";
     var clip=game.Player.Animator.GetCurrentAnimatorClipInfo(0).First().clip;
     if(clip.name!=game.Player.Clip(key))throw new Exception("Wrong runtime locomotion: "+key+" plays "+clip.name);
     Debug.Log("NOBLE_LIVE_CLIP "+key+"="+clip.name+" "+AssetDatabase.GetAssetPath(clip));
    }
    if(frame==205)game.Player.Play("Attack1");
    if(frame==225)game.Player.Play("Attack2");
    if(frame==250)game.Player.Play("Attack3");
    if(frame==280)game.Player.Play("Death");
    // Deterministic effect clock too: disabled gameplay cannot decrement hitStop.
    foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))
    {
     fx.enabled=false;fx.Age+=1f/30;float p=Mathf.Clamp01(fx.Age/fx.Duration);
     fx.Block.SetFloat("_Progress",p);fx.Block.SetFloat("_Clock",fx.Age);fx.Tick?.Invoke(p,1f/30);fx.Apply();
     if(fx.Age>=fx.Duration){fx.Completed?.Invoke();UnityEngine.Object.Destroy(fx.gameObject);}
    }
    typeof(BloodwakeGame).GetField("hitStop",BindingFlags.Instance|BindingFlags.NonPublic).SetValue(game,0f);
    int previousImpact=game.Enemies[0].ImpactVersion;
    // No gameplay ticks: stationary review, real animation events + skill code.
    game.Player.Animator.Update(1f/30);
    foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))fx.enabled=false;
    if(frame>=30&&frame<75&&game.Enemies[0].ImpactVersion!=previousImpact)
    {
     var flash=GameObject.Find("Blood bomb flash");if(!flash)throw new Exception("Clap damage without same-frame hand flash");
     float error=Vector3.Distance(flash.transform.position,game.Player.ClapPosition());
     if(flash.transform.position.y<game.Player.Height*.45f||error>.3f)throw new Exception("Bomb is not at hands: error="+error);
     if((frame-30)/30f>.42f)throw new Exception("Clap damage is delayed");
     Debug.Log($"NOBLE_BOMB_SYNC_PASSED frame={frame} elapsed={(frame-30)/30f:F3} height={flash.transform.position.y:F3} handError={error:F3}");
     foreach(var stain in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Where(f=>f.name=="Blood stain"&&Mathf.Abs(f.Duration-3.1f)<.001f))
     {
      float savedAge=stain.Age;stain.Age=2.5f;stain.Tick(2.5f/3.1f,0);
      if(stain.Block.GetFloat("_Progress")>.001f)throw new Exception("Ability stain fades before 2.5 seconds");
      stain.Age=savedAge;stain.Tick(savedAge/3.1f,0);stain.Apply();
     }
     Debug.Log("NOBLE_ABILITY_STAIN_HOLD_PASSED 2.5 seconds plus 0.6 fade");
    }
    var camera=game.Cam;var target=camera.targetTexture;var active=RenderTexture.active;
    try{camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,960),0,0);image.Apply();File.WriteAllBytes(Path.Combine(folder,$"frame-{frame:D4}.jpg"),image.EncodeToJPG(92));}
    finally{camera.targetTexture=target;RenderTexture.active=active;}
    if(++frame>=390)Finish();
   }
   catch(Exception ex){Debug.LogException(ex);Finish();}
  }
  static void Finish()
  {
   if(game){game.Cam.transform.SetPositionAndRotation(cameraPos,cameraRot);game.Cam.orthographicSize=cameraSize;game.Player.transform.position=playerPos;game.Player.Play("Idle",0);game.Player.Animator.enabled=true;game.Enemies[0].View.Animator.enabled=true;game.enabled=true;}
   if(rt){rt.Release();UnityEngine.Object.DestroyImmediate(rt);}if(image)UnityEngine.Object.DestroyImmediate(image);
   Debug.Log("NOBLE_CAPTURE_COMPLETE frames="+frame+" "+folder);game=null;
  }
 }
}
