using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class SanctuaryReview
 {
  const string Scene="Assets/Bloodwake/Scenes/Bloodwake.unity",Request="Library/BloodwakeOpenSanctuary.request",Output="/tmp/bloodwake-sanctuary-review";
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static readonly MethodInfo Move=typeof(BloodwakeGame).GetMethods(Flags).First(m=>m.Name=="Move");
  static bool opening,started;
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(!File.Exists(Request)||EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   if(!EditorApplication.isPlayingOrWillChangePlaymode)
   {
    if(opening)return;opening=true;EditorSceneManager.OpenScene(Scene,OpenSceneMode.Single);EditorApplication.isPlaying=true;return;
   }
   if(!EditorApplication.isPlaying)return;
   var game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game)return;
   if(!started){game.StartRun("revenant");started=true;return;}
   try{Run(game);File.WriteAllText(Output+"/result.txt","PASS: kit-built sanctuary with tall back and low front walls; merchant and mentor stand full height in view, solid and reachable; walls hold; passive immortal training Warrior resets; eight breakables shatter; overview rendered.\n");}
   catch(Exception e){File.WriteAllText(Output+"/failure.txt",e.ToString());Debug.LogException(e);}
   File.Delete(Request);started=opening=false;
  }
  static void Check(bool ok,string message){if(!ok)throw new Exception("SANCTUARY_REVIEW_FAILED: "+message);}
  static void Run(BloodwakeGame game)
  {
   Directory.CreateDirectory(Output);File.Delete(Output+"/failure.txt");File.Delete(Output+"/result.txt");
   var root=(Transform)typeof(BloodwakeGame).GetField("roomRoot",Flags).GetValue(game);
   var sanctuary=root.Find("Sanctuary");Check(sanctuary,"Kit-built sanctuary absent");
   var walls=sanctuary.Cast<Transform>().Where(c=>c.name=="Sanctuary wall").Select(c=>EnvironmentDressing.BoundsOf(c.GetComponentsInChildren<Renderer>())).ToArray();
   Check(walls.Length>20,"Sanctuary walls missing");Check(walls.Any(w=>w.size.y>3)&&walls.Any(w=>w.size.y<1.2f),"Expected tall back walls and low front walls");
   File.WriteAllLines(Output+"/layout.txt",sanctuary.Cast<Transform>().Select(c=>$"{c.name}: {c.position}").Concat(root.GetComponentsInChildren<BreakableCargo>().Select(c=>$"cargo: center={c.Body.center}")));
   Check(root.GetComponentsInChildren<BreakableCargo>().Length==8,"Training breakable count changed");
   Check(game.Enemies.Count==1&&game.Enemies[0].Training,"Passive training Warrior missing");
   var hosts=root.GetComponentsInChildren<ActorView>().Where(a=>a.name.StartsWith("Host ·")).ToArray();Check(hosts.Length==2,"Merchant/mentor hosts missing");
   Check(hosts.Select(h=>h.Kind).OrderBy(x=>x).SequenceEqual(new[]{"mentor","merchant"}),"Wrong sanctuary NPC models");
   foreach(var host in hosts)
   {
    Check(host.Animator&&host.Animator.runtimeAnimatorController&&host.Animator.runtimeAnimatorController.animationClips.Any(c=>c.name=="Idle"),host.Kind+" idle missing");
    var skins=host.Animator.GetComponentsInChildren<SkinnedMeshRenderer>();Check(skins.Length>0&&skins.Sum(r=>r.sharedMesh?r.sharedMesh.triangles.Length/3:0)>90000,host.Kind+" skinned mesh incomplete");
    Check(skins.All(r=>r.sharedMaterials.All(m=>m&&m.shader&&m.shader.name=="Universal Render Pipeline/Lit")),host.Kind+" material missing");
    // Measure the posed body, not import metadata: the first hosts passed while standing 1.08 m tall.
    var posed=new Mesh();skins[0].BakeMesh(posed,true);float top=float.MinValue,bottom=float.MaxValue;foreach(var v in posed.vertices){float y=skins[0].transform.TransformPoint(v).y;top=Mathf.Max(top,y);bottom=Mathf.Min(bottom,y);}UnityEngine.Object.DestroyImmediate(posed);
    Check(top-bottom>1.9f&&top-bottom<2.8f,$"{host.Kind} stands {top-bottom:0.00} m tall");Check(Mathf.Abs(bottom-host.transform.position.y)<.15f,$"{host.Kind} feet at {bottom:0.00}");
    Check(Vector3.Dot(host.transform.forward,-game.Cam.transform.forward)>0,host.Kind+" faces away from the camera");
    // Nothing solid may stand between the isometric camera and the host's head.
    var head=new Vector3(host.transform.position.x,top-.15f,host.transform.position.z);var view=new Ray(head,-game.Cam.transform.forward);
    var blocker=sanctuary.GetComponentsInChildren<Renderer>().FirstOrDefault(r=>r.enabled&&!r.name.Contains("rug")&&r.bounds.IntersectRay(view,out float d)&&d>.05f&&d<40);Check(!blocker,$"{host.Kind} hidden behind {blocker?.name}");
    // Walking into the host stops short of it, but still within talking range.
    var approach=host.transform.position+host.transform.forward*3;var stop=(Vector3)Move.Invoke(game,new object[]{approach,host.transform.position-approach,.4f});
    Check(Vector3.Distance(stop,host.transform.position)>.75f,host.Kind+" has no solid body");game.Player.transform.position=stop;
    Check(((Newtonsoft.Json.Linq.JToken)typeof(BloodwakeGame).GetMethod("NearbyHost",Flags).Invoke(game,null))?["model"]?.ToString()==host.Kind,host.Kind+" unreachable from the counter");
   }
   // Every outer wall stops the player at its face.
   foreach(var dir in new[]{Vector3.forward,Vector3.back,Vector3.left,Vector3.right}){var stop=(Vector3)Move.Invoke(game,new object[]{new Vector3(0,0,1.5f),dir*40,.4f});Check(Mathf.Abs(stop.x)<11.5f&&Mathf.Abs(stop.z)<11.5f,"Walked out through the "+dir+" wall");}
   var oldSize=game.Cam.orthographicSize;var oldPos=game.Cam.transform.position;var oldRot=game.Cam.transform.rotation;
   var rt=new RenderTexture(1600,1000,24);var image=new Texture2D(1600,1000,TextureFormat.RGB24,false);var oldTarget=game.Cam.targetTexture;var active=RenderTexture.active;
   try
   {
    game.Cam.orthographicSize=13;game.Cam.transform.position=new Vector3(-12,14,16)+new Vector3(0,0,-.5f);game.Cam.transform.rotation=Quaternion.LookRotation(new Vector3(12,-14,-16),Vector3.up);game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1600,1000),0,0);image.Apply();File.WriteAllBytes(Output+"/overview.png",image.EncodeToPNG());
   }
   finally{game.Cam.orthographicSize=oldSize;game.Cam.transform.position=oldPos;game.Cam.transform.rotation=oldRot;game.Cam.targetTexture=oldTarget;RenderTexture.active=active;UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(image);}
   var dummy=game.Enemies.Single();var home=dummy.TrainingHome;dummy.View.transform.position=home+Vector3.right*7;
   typeof(BloodwakeGame).GetMethod("TickEnemies",Flags).Invoke(game,new object[]{.016f});Check(Vector3.Distance(dummy.View.transform.position,home)<.01f,"Training Warrior did not return home");
   typeof(BloodwakeGame).GetMethod("DamageEnemy",Flags).Invoke(game,new object[]{dummy,dummy.MaxHp*2,false});Check(game.Enemies.Contains(dummy)&&Mathf.Approximately(dummy.Hp,dummy.MaxHp),"Training Warrior did not respawn in place");
   var cargo=root.GetComponentsInChildren<BreakableCargo>().First();var centre=cargo.Body.center;
   typeof(BloodwakeGame).GetMethod("DamageCargo",Flags).Invoke(game,new object[]{centre,1f,Vector3.forward,360f});Check(root.GetComponentsInChildren<BreakableCargo>().Length<8,"Training cargo did not shatter");
   game.StartRun("revenant");
   Debug.Log("SANCTUARY_REVIEW_PASSED "+Output);
  }
 }
}
