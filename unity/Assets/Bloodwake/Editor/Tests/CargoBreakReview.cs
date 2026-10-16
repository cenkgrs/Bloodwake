using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class CargoBreakReview
 {
  const string Request="Library/CargoBreakReview.request";
  static BloodwakeGame game;static string output;static BreakableCargo target;
  static Material[] materials;static int frame,lastFrame;static float next,cleanupStart;
  static bool checkedBreak;static Vector3 focus;
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static T Field<T>(string name)=>(T)typeof(BloodwakeGame).GetField(name,Flags).GetValue(game);
  static void Set(string name,object value)=>typeof(BloodwakeGame).GetField(name,Flags).SetValue(game,value);
  static void Check(bool ok,string message){if(!ok)throw new Exception("CARGO_REVIEW: "+message);}
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Tick;}
  static void Tick()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying)return;
   try
   {
    if(!game)
    {
     if(!File.Exists(Request))return;
     var found=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!found||found.Screen!="playing")return;
     game=found;output=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(output);
     var pieces=Field<List<BreakableCargo>>("cargo");Check(pieces.Count>5,"Actual room cargo not registered");
     target=pieces.Where(p=>p.ReplacesFootprint).OrderBy(p=>p.Body.center.sqrMagnitude).First();focus=target.Body.center;
     var fixedBoxes=Field<List<Bounds>>("fixedCargoBlockers");
     foreach(var p in pieces.Where(p=>p.ReplacesFootprint))Check(!fixedBoxes.Any(b=>new Vector2(b.center.x-p.Footprint.center.x,b.center.z-p.Footprint.center.z).magnitude<.6f),"Original invisible stack collider remained");
     materials=target.GetComponentsInChildren<Renderer>().SelectMany(r=>r.sharedMaterials).ToArray();
     game.enabled=false;game.Player.Animator.enabled=false;game.Player.Play("Idle",0);game.Player.Animator.Update(.2f);
     var centre=new Vector3(focus.x,0,focus.z);var outward=centre.normalized;
     game.Player.transform.position=centre-outward*2.5f;Set("aim",outward);Set("hitStop",0f);
     Call("BloodCone",game.Player.transform.position,-outward,4f,1f);Check(target&&!target.Broken,"E hit a crate behind its cone");
     Call("Cast",1);frame=0;lastFrame=-1;next=0;checkedBreak=false;cleanupStart=0;
     Debug.Log("CARGO_REVIEW_STARTED actual E animation/contact on dressed Gateyard cargo");
    }
    if(Time.frameCount==lastFrame||EditorApplication.timeSinceStartup<next)return;
    lastFrame=Time.frameCount;next=(float)EditorApplication.timeSinceStartup+1f/30;
    if(frame<180)
    {
     Set("hitStop",0f);game.Player.Tick(1f/30,false);game.Player.Animator.Update(1f/30);
     if(!checkedBreak&&(!target||target.Broken))
     {
      checkedBreak=true;var debris=UnityEngine.Object.FindObjectsByType<CargoDebris>(FindObjectsSortMode.None);
      Check(debris.Length>0&&debris.Length<=256,"Debris absent or unbounded");
      Check(debris.Any(d=>materials.Contains(d.GetComponent<Renderer>().sharedMaterial)),"Debris lost source material/texture");
      Check(Field<Dictionary<string,float>>("soundTimes").ContainsKey("wood_break"),"Wood sound not played");
      Call("RebuildCargoNavigation");Check(game.Enemies.All(e=>e.Agent&&e.Agent.isOnNavMesh),"Navigation rebuild lost living agents");
      Debug.Log("CARGO_E_PASSED cone/contact/source-material/debris/audio/navigation");
     }
     Capture();frame++;return;
    }
    if(cleanupStart==0)
    {
     Check(checkedBreak,"E animation never broke its target");
     var remaining=Field<List<BreakableCargo>>("cargo");Check(remaining.Count>0,"Local E destroyed the entire room");
     var qTarget=remaining[0];var centre=qTarget.Body.center;centre.y=0;
     Call("BloodArea",centre,1f,1f,false,1f);Check(!qTarget||qTarget.Broken,"Q area did not break cargo");
     remaining=Field<List<BreakableCargo>>("cargo");var shotTarget=remaining[0];centre=shotTarget.Body.center;
     Call("DamageCargoSegment",centre-Vector3.right*2,centre+Vector3.right*2,.15f);Check(!shotTarget||shotTarget.Broken,"Swept projectile skipped cargo");
     Call("BloodArea",Vector3.zero,100f,1f,true,2.5f);Check(Field<List<BreakableCargo>>("cargo").Count==0,"Space area left live cargo");
     Call("RebuildCargoNavigation");
     Check(Field<List<Bounds>>("blockers").Count==Field<List<Bounds>>("fixedCargoBlockers").Count,"Destroyed cargo left collision behind");
     Set("hitStop",0f);cleanupStart=Time.time;Debug.Log("CARGO_AREA_PASSED Q/Space/projectile/static-obstacles-preserved");
    }
    if(Time.time-cleanupStart>6)
    {
     Check(UnityEngine.Object.FindObjectsByType<CargoDebris>(FindObjectsSortMode.None).Length==0,"Debris did not clean up");
     Debug.Log("CARGO_REVIEW_PASSED");Finish();
    }
   }
   catch(Exception ex){Debug.LogException(ex);if(game)Finish();}
  }
  static void Capture()
  {
   var camera=game.Cam;var position=camera.transform.position;var rotation=camera.transform.rotation;float size=camera.orthographicSize;
   var previous=camera.targetTexture;var active=RenderTexture.active;var rt=RenderTexture.GetTemporary(960,540,24);var image=new Texture2D(960,540,TextureFormat.RGB24,false);
   try
   {
    camera.transform.position=focus+new Vector3(7,8,9);camera.transform.LookAt(focus);camera.orthographicSize=4.5f;
    camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,960,540),0,0);image.Apply();
    File.WriteAllBytes(Path.Combine(output,$"frame-{frame:D4}.jpg"),image.EncodeToJPG(90));
   }
   finally{camera.targetTexture=previous;RenderTexture.active=active;camera.transform.SetPositionAndRotation(position,rotation);camera.orthographicSize=size;RenderTexture.ReleaseTemporary(rt);UnityEngine.Object.DestroyImmediate(image);}
  }
  static void Finish(){game.Player.Animator.enabled=true;game.enabled=true;Call("Start");game=null;}
 }
}
