using System;
using System.Collections;
using System.Reflection;
using Bloodwake;
using UnityEngine;

namespace Bloodwake.Editor
{
 // Run in an isolated editor Play Mode scene/profile, never against a user's run.
 public static class RevenantChecks
 {
  static int passed;
  static void Check(bool result,string message)
  {
   if(!result)throw new Exception("REVENANT_CHECK_FAILED "+message);
   passed++;Debug.Log("REVENANT_CHECK_PASSED "+message);
  }
  static object Call(BloodwakeGame g,string method,params object[] args)=>typeof(BloodwakeGame).GetMethod(method,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(g,args);
  static void Field(BloodwakeGame g,string name,object value)=>typeof(BloodwakeGame).GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).SetValue(g,value);
  public static IEnumerator Run(BloodwakeGame g)
  {
   passed=0;RevenantVfxImport.ValidateEvents();g.StartRun("revenant");g.Run.Awarded=true;
   Call(g,"EnterRoom",g.Run.Plan[0]);Field(g,"spawnTimer",9999f);g.enabled=false;
   var actor=g.Player;actor.Animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;
   foreach(float speed in new[]{1f,2f})foreach(var pair in new[]{("Attack1",10f/60),("Attack2",11f/60),("Attack3",18f/60),("Teleport",25f/60),("Ultimate",59f/60)})
   {
    actor.Play("Idle",0);actor.Animator.Update(.2f);
    int count=0;float elapsed=0,contact=-1;
    actor.Play(pair.Item1,actor.ClipLength(pair.Item1)/speed);
    actor.OnMarker(pair.Item1=="Ultimate"?"ULT_DAMAGE":"DAMAGE",()=>{count++;contact=elapsed;});
    for(int frame=0;frame<360;frame++){elapsed+=1f/120;actor.Animator.Update(1f/120);}
    Check(count==1,pair.Item1+" fires once at "+speed+"x");
    Check(Mathf.Abs(contact-pair.Item2/speed)<.025f,pair.Item1+" real Animator contact "+contact+" at "+speed+"x");
   }
   actor.Play("Attack1");actor.Animator.Update(.03f);int layeredContacts=0;actor.OnMarker("DAMAGE",()=>layeredContacts++);actor.HitOverlay();
   int hitLayer=actor.Animator.GetLayerIndex("Upper body hit"),legsLayer=actor.Animator.GetLayerIndex("Moving attack legs");
   Check(hitLayer>=0&&actor.Animator.GetLayerWeight(hitLayer)==1,"upper body hit layer is active");
   for(int i=0;i<26;i++){actor.Tick(1f/120,true);actor.Animator.Update(1f/120);}
   Check(layeredContacts==1,"hit overlay keeps pending claw contact");Check(legsLayer>=0&&actor.Animator.GetLayerWeight(legsLayer)>.9f,"moving claws blend running legs");
   actor.Play("Teleport");actor.Animator.Update(.02f);bool hit=false;actor.OnMarker("DAMAGE",()=>hit=true);actor.Animator.speed=0;
   actor.Animator.Update(1);Check(!hit,"paused Animator cannot deal teleport damage");
   actor.SetVisible(false);actor.CancelAction();actor.Animator.speed=1;actor.Animator.Update(1);
   Check(actor.Visible&&!hit,"cancel restores visibility and clears pending damage");
   var fx=new GameObject("Lifetime test").AddComponent<VfxLifetime>();fx.Game=g;fx.Duration=1;g.Screen="pause";yield return null;float age=fx.Age;yield return null;Check(fx.Age==age,"effect lifetime pauses with menus");
   g.Screen="playing";Field(g,"hitStop",1f);yield return null;Check(fx.Age==age,"effect lifetime pauses with hit-stop");Field(g,"hitStop",0f);yield return null;Check(fx.Age>age,"effect lifetime resumes");UnityEngine.Object.Destroy(fx.gameObject);
   var owner=(RevenantVfx)typeof(BloodwakeGame).GetProperty("RevFx",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(g);
   owner.Fountain(actor.transform.position,2,2,.5f);yield return null;
   var liquid=GameObject.Find("Lit blood volume");var liquidMesh=liquid.GetComponent<MeshFilter>().sharedMesh;
   g.Screen="pause";var vertex=liquidMesh.vertices[1000];yield return null;yield return null;
   Check(liquidMesh.vertices[1000]==vertex,"liquid geometry freezes with pause");
   g.Screen="playing";yield return new WaitForSeconds(.1f);
   Check(Vector3.Distance(liquidMesh.vertices[1000],vertex)>.01f,"liquid shape advances after resume");
   yield return new WaitForSeconds(.6f);yield return null;
   Check(!liquid&&!liquidMesh,"liquid lifetime releases dynamic mesh");
   actor.Play("Idle",0);actor.Locked=0;actor.Animator.Update(.2f);g.Run.Stats["criticalChance"]=0;g.Run.Stats["hp"]=1000;g.Run.Stats["maxHp"]=1000;
   g.SpawnEnemy("grunt",actor.transform.position+Vector3.forward);g.SpawnEnemy("grunt",actor.transform.position+Vector3.forward*2);
   var first=g.Enemies[0];var heir=g.Enemies[1];first.Mark=float.PositiveInfinity;Call(g,"ApplyRuinMark",first);Call(g,"DamageEnemy",first,100000f,true);yield return null;
   Check(heir.Mark>0&&heir.View.transform.Find("RuinMark"),"mark visual follows inherited target");
   actor.SetVisible(false);actor.OnMarker("DAMAGE",()=>hit=true);Call(g,"EnterRoom",g.Run.Plan[0]);yield return null;Check(actor.Visible,"room transition restores hidden player");
   Check(UnityEngine.Object.FindObjectsByType<RevenantVfx>(FindObjectsSortMode.None).Length==1,"room transition releases old effect owner");
   g.Run.Stats["dodgeChance"]=0;g.Run.Stats["armor"]=0;Field(g,"invulnerable",0f);Call(g,"HurtPlayer",1000000f);
   Check(g.Screen=="dying","death first leaves body visible");yield return new WaitForSeconds(2.1f);Check(g.Screen=="death_transition","death title follows body hold");yield return new WaitForSeconds(2.8f);Check(g.Screen=="dead","results follow death title");
   g.enabled=true;Debug.Log("BLOODWAKE_REVENANT_RUNTIME_CHECKS "+passed+" passed");
  }
 }
}
