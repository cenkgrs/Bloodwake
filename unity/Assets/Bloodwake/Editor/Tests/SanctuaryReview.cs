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
   try{Run(game);File.WriteAllText(Output+"/result.txt","PASS: four imported sanctuary rooms use URP materials; merchant and mentor use their skinned idle rigs; passive immortal training Warrior resets; eight breakables shatter; overview rendered.\n");}
   catch(Exception e){File.WriteAllText(Output+"/failure.txt",e.ToString());Debug.LogException(e);}
   File.Delete(Request);started=opening=false;
  }
  static void Check(bool ok,string message){if(!ok)throw new Exception("SANCTUARY_REVIEW_FAILED: "+message);}
  static void Run(BloodwakeGame game)
  {
   Directory.CreateDirectory(Output);File.Delete(Output+"/failure.txt");File.Delete(Output+"/result.txt");
   var root=(Transform)typeof(BloodwakeGame).GetField("roomRoot",Flags).GetValue(game);
   var sanctuary=root.GetComponentsInChildren<Transform>(true).FirstOrDefault(t=>t.name=="Imported town geometry");Check(sanctuary,"Imported sanctuary absent");
   var renderers=sanctuary.GetComponentsInChildren<MeshRenderer>();Check(renderers.Length==4,"Expected four room meshes");
   File.WriteAllLines(Output+"/layout.txt",renderers.Select(r=>$"{r.name}: center={r.bounds.center} size={r.bounds.size}")
    .Concat(root.GetComponentsInChildren<BreakableCargo>().Select(c=>$"cargo: center={c.Body.center}")));
   Check(renderers.All(r=>r.sharedMaterials.All(m=>m&&m.shader&&m.shader.name=="Universal Render Pipeline/Lit"&&m.GetTexture("_BaseMap"))),"Sanctuary albedo or URP material missing");
   Check(root.GetComponentsInChildren<BreakableCargo>().Length==8,"Training breakable count changed");
   Check(game.Enemies.Count==1&&game.Enemies[0].Training,"Passive training Warrior missing");
   var hosts=root.GetComponentsInChildren<ActorView>().Where(a=>a.name.StartsWith("Host ·")).ToArray();Check(hosts.Length==2,"Merchant/mentor hosts missing");
   Check(hosts.Select(h=>h.Kind).OrderBy(x=>x).SequenceEqual(new[]{"mentor","merchant"}),"Wrong sanctuary NPC models");
   foreach(var host in hosts)
   {
    Check(host.Animator&&host.Animator.runtimeAnimatorController&&host.Animator.runtimeAnimatorController.animationClips.Any(c=>c.name=="Idle"),host.Kind+" idle missing");
    var skins=host.Animator.GetComponentsInChildren<SkinnedMeshRenderer>();Check(skins.Length>0&&skins.Sum(r=>r.sharedMesh?r.sharedMesh.triangles.Length/3:0)>90000,host.Kind+" skinned mesh incomplete");
    Check(skins.All(r=>r.sharedMaterials.All(m=>m&&m.shader&&m.shader.name=="Universal Render Pipeline/Lit")),host.Kind+" material missing");
   }
   var oldSize=game.Cam.orthographicSize;var oldPos=game.Cam.transform.position;var oldRot=game.Cam.transform.rotation;
   var rt=new RenderTexture(1600,1000,24);var image=new Texture2D(1600,1000,TextureFormat.RGB24,false);var oldTarget=game.Cam.targetTexture;var active=RenderTexture.active;
   try
   {
    game.Cam.orthographicSize=18;game.Cam.transform.position=new Vector3(-12,14,16)+new Vector3(0,0,-4);game.Cam.transform.rotation=Quaternion.LookRotation(new Vector3(12,-14,-16),Vector3.up);game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1600,1000),0,0);image.Apply();File.WriteAllBytes(Output+"/overview.png",image.EncodeToPNG());
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
