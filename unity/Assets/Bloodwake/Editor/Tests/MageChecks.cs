using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class MageChecks
 {
  static int passed;
  static object Call(BloodwakeGame g,string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(g,args);
  static void Field(BloodwakeGame g,string name,object value)=>typeof(BloodwakeGame).GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).SetValue(g,value);
  static ArcaneOrbRig[] Orbs()=>UnityEngine.Object.FindObjectsByType<ArcaneOrbRig>(FindObjectsSortMode.None);
  static void Check(bool ok,string name){if(!ok)throw new Exception("MAGE_CHECK_FAILED "+name);passed++;Debug.Log("MAGE_CHECK_PASSED "+name);}
  public static IEnumerator Run(BloodwakeGame g)
  {
   passed=0;g.StartRun("mage");g.Run.Awarded=true;Call(g,"EnterRoom",g.Run.Plan[0]);g.Player.transform.position=Vector3.zero;Field(g,"spawnTimer",9999f);g.enabled=false;
   yield return null;yield return null;var orb=Orbs().Single(x=>x.Owner==g.Player);
   Check(orb.GetComponentsInChildren<Renderer>().Count(r=>r.enabled)>=8,"held orb visible with core, shell and halo");
   var hand=g.Player.Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("RightHand"));Check(hand&&Vector3.Distance(orb.transform.position,hand.position)<.3f,"held orb stays at casting hand");
   Vector3 before=orb.transform.position;g.Player.transform.position+=Vector3.right*2;yield return null;yield return null;Check(Vector3.Distance(orb.transform.position,before+Vector3.right*2)<.1f,"orb follows player movement");
   g.Player.Play("Attack");yield return new WaitForSeconds(.18f);Check(Vector3.Distance(orb.transform.position,hand.position)<.3f,"orb follows animated hand");
   g.Screen="pause";yield return null;float age=orb.Age;yield return new WaitForSeconds(.1f);Check(orb.Age==age,"orb energy and shell pause in menu");
   g.Screen="playing";Field(g,"hitStop",1f);yield return null;age=orb.Age;yield return null;Check(orb.Age==age,"orb freezes during hit-stop");Field(g,"hitStop",0f);
   g.Player.SetVisible(false);yield return null;yield return null;Check(orb.GetComponentsInChildren<Renderer>().All(r=>!r.enabled),"orb hides with actor");g.Player.SetVisible(true);
   g.Player.transform.position=Vector3.zero;g.Player.transform.rotation=Quaternion.identity;g.Player.Locked=0;Field(g,"aim",Vector3.forward);Field(g,"attackCd",0f);g.Run.Stats["criticalChance"]=0;
   g.SpawnEnemy("grunt",Vector3.forward*4);var victim=g.Enemies.Last();float hp=victim.Hp;Call(g,"Attack");yield return new WaitForSeconds(.3f);
   Check(Orbs().Any(x=>x!=orb&&x.name=="Arcane projectile"),"basic attack releases dressed orb projectile");
   var projectile=Orbs().First(x=>x.name=="Arcane projectile");Check(projectile.GetComponentsInChildren<Renderer>().Any(r=>r.sharedMaterial.shader.name.EndsWith("arcane_trail")),"projectile has plasma tail");
   yield return new WaitForSeconds(.8f);Check(victim.Hp<hp,"hand-origin projectile hits enemy body");Field(g,"hitStop",0f);
   Call(g,"EnterRoom",g.Run.Plan[0]);yield return null;yield return null;Check(Orbs().Count(x=>x.Owner==g.Player)==1&&!orb,"room transition replaces held orb without duplicate");
   g.SpawnEnemy("mage",Vector3.zero);yield return null;Check(Orbs().Any(x=>x.Owner==g.Enemies.Last().View),"enemy mage has its own held orb");
   var current=Orbs().Single(x=>x.Owner==g.Player);g.Player.Play("Death");yield return null;yield return null;Check(!current,"player death removes hand orb");
   g.StartRun("warrior");g.Run.Awarded=true;yield return null;yield return null;Check(Orbs().Length==0,"class switch removes mage effects");
   g.enabled=true;Debug.Log("BLOODWAKE_MAGE_RUNTIME_CHECKS "+passed+" passed");
  }
 }
}
