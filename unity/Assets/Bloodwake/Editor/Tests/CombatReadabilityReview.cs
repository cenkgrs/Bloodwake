using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class CombatReadabilityReview
 {
  const string Output="/tmp/bloodwake-combat-readability";
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static BloodwakeGame game;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static void Set(string name,object value)=>typeof(BloodwakeGame).GetField(name,Flags).SetValue(game,value);
  static void Check(bool condition,string message){if(!condition)throw new Exception("COMBAT_READABILITY_FAILED: "+message);}
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying||!File.Exists("Library/CombatReadabilityReview.request"))return;
   game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||game.Screen!="playing"||game.Enemies.Count==0)return;
   File.Delete("Library/CombatReadabilityReview.request");Run();
  }
  [MenuItem("Bloodwake/Tests/Combat readability review")]
  public static void Run()
  {
   game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||!EditorApplication.isPlaying)return;
   Directory.CreateDirectory(Output);game.enabled=false;
   try
   {
    Set("waves",null);Set("hitStop",0f);Set("combatPractice",true);
    var enemy=game.Enemies[0];enemy.View.TickEmergence(2);if(enemy.Agent)enemy.Agent.enabled=false;
    enemy.View.Animator.enabled=false;game.Player.Animator.enabled=false;
    ClearEffects();Capture("flash-before");
    float hp=enemy.Hp;Call("DamageEnemy",enemy,10f,true);
    Check(enemy.Hp==hp&&enemy.View.HitFlash.Active,"Practice infinite HP must still flash");
    var flash=enemy.View.HitFlash;var block=ReadEmission(enemy.View);
    Check(Mathf.Abs(block.GetColor("_EmissionColor").r-.322f)<.001f,"Enemy peak differs from restrained setting +15%");
    Check(block.GetTexture("_EmissionMap")==Texture2D.whiteTexture,"Armor mask still attenuates flash");
    ClearEffects();Capture("flash-contact");AdvanceFlash(flash,.02f);
    Check(Mathf.Abs(ReadEmission(enemy.View).GetColor("_EmissionColor").r-.322f)<.001f,"Contact hold too short");
    AdvanceFlash(flash,.09f);float fading=ReadEmission(enemy.View).GetColor("_EmissionColor").r;
    Check(fading>0&&fading<.322f,"Enemy fade missing");Capture("flash-fading");AdvanceFlash(flash,.2f);
    Check(!flash.Active,"Enemy flash never restores");Capture("flash-restored");
    game.Player.FlashHit(true);Check(Mathf.Abs(ReadEmission(game.Player).GetColor("_EmissionColor").r-.12f)<.001f,"Player flash changed");AdvanceFlash(game.Player.HitFlash,.2f);
    CheckPathDamage();
    for(int i=1;i<game.Enemies.Count;i++)game.Enemies[i].View.gameObject.SetActive(false);
    enemy.View.transform.position=new Vector3(0,0,.3f);enemy.View.Play("Idle",0);enemy.View.Animator.Update(.2f);
    Set("combatPractice",true);Set("hitStop",0f);
    game.Player.Animator.enabled=false;ClearEffects();
    Vector3 hands=game.Player.ClapPosition(),direction=Vector3.back;((RevenantVfx)typeof(BloodwakeGame).GetProperty("RevFx",Flags).GetValue(game)).BloodBomb(hands,direction,4);
    Check(!Effects().Any(f=>f.name=="Blood bomb glass shard"||f.name=="Blood bomb liquid sheet"),"Rejected stone/perfume VFX still active");
    var volume=Effects().Single(f=>f.name=="Blood bomb liquid pressure wave");
    Check(volume.GetComponent<MeshRenderer>().sharedMaterial.name=="Wet blood","E missing Space liquid material");
    Check(Effects().Count(f=>f.name=="Blood bomb droplet")==64,"Missing dense liquid spray");
    for(int frame=1;frame<=100;frame++)
    {
     foreach(var fx in Effects())
     {
      fx.enabled=false;fx.Age+=.01f;float p=Mathf.Clamp01(fx.Age/fx.Duration);fx.Block.SetFloat("_Progress",p);fx.Block.SetFloat("_Clock",fx.Age);fx.Tick?.Invoke(p,.01f);fx.Apply();
      if(fx.name=="Blood bomb liquid pressure wave")foreach(var point in fx.GetComponent<MeshFilter>().sharedMesh.vertices)
       Check(point.z>=-.08f&&Mathf.Abs(point.x)<=point.z+.25f&&new Vector2(point.x,point.z).magnitude<4.15f,"Liquid wave escaped forward cone");
      if(fx.Age>=fx.Duration)UnityEngine.Object.DestroyImmediate(fx.gameObject);
     }
     if(frame==8||frame==16||frame==30)Capture("e-liquid-"+frame);
    }
    Check(!Effects().Any(f=>f.name=="Blood bomb liquid pressure wave"||f.name=="Blood bomb droplet"),"Liquid VFX leaked past lifetime");
    File.WriteAllText(Output+"/result.txt","PASS: practice flash / white emission / contact hold / fade / player unchanged / Q full corridor + landing union / EMPTY LANDING with three path targets / single hit / outside exclusion / emerging immunity / zero distance / E liquid pressure wave + 64 drops / shared Space material / forward cone / cleanup\n");
    Debug.Log("COMBAT_READABILITY_PASSED "+Output);
   }
   catch(Exception e){File.WriteAllText(Output+"/failure.txt",e.ToString());Debug.LogException(e);}
   finally{Set("combatPractice",true);Call("Start");game.enabled=true;game=null;}
  }
  static void CheckPathDamage()
  {
   Set("combatPractice",false);game.Run.Stats["criticalChance"]=0f;
   var start=new Vector3(0,0,2);var end=start+Vector3.back*6;
   var positions=new[]{start+Vector3.back,start+Vector3.back*3,end+Vector3.forward*.5f,end+Vector3.right*1.8f,start+Vector3.back*2+Vector3.right*1.6f,start+Vector3.back*2};
   while(game.Enemies.Count<positions.Length)game.SpawnEnemy("grunt",start+Vector3.right*(game.Enemies.Count+2));
   for(int i=0;i<positions.Length;i++)
   {
    var e=game.Enemies[i];if(e.Agent)e.Agent.enabled=false;e.View.TickEmergence(2);e.View.Animator.enabled=false;e.View.transform.position=positions[i];e.Hp=e.MaxHp=1000;e.Mark=0;
    if(i==5)e.View.BeginEmergence();
   }
   Call("BloodStepArea",start,end,2.2f,10f);
   for(int i=0;i<positions.Length;i++)Check(game.Enemies[i].Hp==(i<4?990:1000),"Q wrong hit count for target "+i+" hp="+game.Enemies[i].Hp);
   // User's exact case: empty arrival, several enemies only in the traversed path.
   for(int i=0;i<positions.Length;i++){var e=game.Enemies[i];e.View.TickEmergence(2);e.Hp=1000;e.View.transform.position=i<3?start+Vector3.back*(.5f+i):end+Vector3.right*(8+i);}
   Call("BloodStepArea",start,end,2.2f,10f);
   for(int i=0;i<positions.Length;i++)Check(game.Enemies[i].Hp==(i<3?990:1000),"Q empty-landing corridor target "+i+" did not react");
   Check(BloodwakeGame.InsideBloodStep(end,end,end,2.2f)&&!BloodwakeGame.InsideBloodStep(end+Vector3.right*3,end,end,2.2f),"Zero-distance Q invalid");
   Check(BloodwakeGame.InsideBloodStep(start+Vector3.back*3+Vector3.up*2,start,end,2.2f),"Q must measure ground-plane corridor");
  }
  static VfxLifetime[] Effects()=>UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None);
  static void ClearEffects(){foreach(var fx in Effects())UnityEngine.Object.DestroyImmediate(fx.gameObject);}
  static void AdvanceFlash(HitFlash flash,float dt)=>typeof(HitFlash).GetMethod("Advance",Flags).Invoke(flash,new object[]{dt});
  static MaterialPropertyBlock ReadEmission(ActorView view)
  {
   foreach(var r in view.GetComponentsInChildren<Renderer>())for(int i=0;i<r.sharedMaterials.Length;i++)if(r.sharedMaterials[i].HasProperty("_EmissionColor")){var block=new MaterialPropertyBlock();r.GetPropertyBlock(block,i);return block;}
   throw new Exception("No flash-capable material");
  }
  static void Capture(string name)
  {
   var old=game.Cam.targetTexture;var active=RenderTexture.active;var rt=new RenderTexture(1280,960,24);var image=new Texture2D(1280,960,TextureFormat.RGB24,false);
   try{game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,960),0,0);image.Apply();File.WriteAllBytes(Output+"/"+name+".png",image.EncodeToPNG());}
   finally{game.Cam.targetTexture=old;RenderTexture.active=active;UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(image);}
  }
 }
}
