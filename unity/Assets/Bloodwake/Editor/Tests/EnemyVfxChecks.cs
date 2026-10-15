using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class EnemyVfxChecks
 {
  static int passed;
  static object Call(BloodwakeGame g,string method,params object[] args)=>typeof(BloodwakeGame).GetMethod(method,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(g,args);
  static void Field(BloodwakeGame g,string name,object value)=>typeof(BloodwakeGame).GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).SetValue(g,value);
  static void Check(bool result,string message){if(!result)throw new Exception("ENEMY_VFX_FAILED "+message);passed++;Debug.Log("ENEMY_VFX_PASSED "+message);}
  public static IEnumerator Run(BloodwakeGame g)
  {
   passed=0;g.StartRun("warrior");g.Run.Awarded=true;Call(g,"EnterRoom",g.Run.Plan[0]);Field(g,"spawnTimer",9999f);g.enabled=false;g.Screen="playing";
   var owner=(RevenantVfx)typeof(BloodwakeGame).GetProperty("RevFx",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(g);
   var heading=Vector3.right;var lane=owner.BossTelegraph(Vector3.zero,heading,8,360,"charge",1);var renderer=lane.GetComponent<Renderer>();
   Check(Vector3.Distance(lane.transform.position,new Vector3(4,.06f,0))<.001f&&lane.transform.localScale.x==2&&lane.transform.localScale.y==8,"charge warning matches eight metre path and two metre body width");
   Check(Vector3.Dot(lane.transform.up,heading)>.999f,"ground warning points along actual charge");
   var fx=lane.GetComponent<VfxLifetime>();g.Screen="pause";yield return null;float age=fx.Age;yield return new WaitForSeconds(.1f);Check(fx.Age==age&&lane,"danger warning survives pause");
   g.Screen="playing";Field(g,"hitStop",0f);yield return null;Check(fx.Age>age,"danger countdown resumes with gameplay");UnityEngine.Object.Destroy(lane);
   var volley=owner.BossTelegraph(Vector3.zero,Vector3.forward,14,360,"cast",1);var paths=volley.GetComponentsInChildren<VfxLifetime>();
   Check(paths.Length==3,"volley advertises three projectile lanes");
   for(int i=0;i<3;i++)Check(Vector3.Dot(paths[i].transform.up,Quaternion.Euler(0,(i-1)*.22f*Mathf.Rad2Deg,0)*Vector3.forward)>.999f,"volley lane follows projectile heading "+i);
   UnityEngine.Object.Destroy(volley);
   g.Player.transform.position=Vector3.forward*2;g.Run.Stats["maxHp"]=10000;g.Run.Stats["hp"]=10000;g.Run.Stats["armor"]=0;g.Run.Stats["dodgeChance"]=0;Field(g,"invulnerable",0f);
   g.SpawnEnemy("boss",Vector3.zero);var boss=g.Enemies.Last();boss.Pattern=0;float hp=g.Run.Stats.N("hp");g.StartCoroutine((IEnumerator)Call(g,"BossCast",boss));
   yield return new WaitForSeconds(.2f);Check(g.Run.Stats.N("hp")==hp,"boss warning does not deal early damage");yield return new WaitForSeconds(.25f);Check(g.Run.Stats.N("hp")<hp,"boss contact still deals damage at windup end");
   yield return new WaitForSeconds(.5f);Check(!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(v=>v.name=="Enemy danger area"),"finished boss contact clears warning");
   Field(g,"invulnerable",0f);boss.Pattern=4;hp=g.Run.Stats.N("hp");g.StartCoroutine((IEnumerator)Call(g,"BossCast",boss));yield return new WaitForSeconds(.1f);
   Call(g,"StartAreaRecoil",boss,g.Player.transform.position);yield return null;yield return null;
   Check(!boss.Casting&&!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(v=>v.name=="Enemy danger area"),"interrupted boss windup immediately removes danger warning");
   yield return new WaitForSeconds(1.3f);Check(g.Run.Stats.N("hp")==hp,"interrupted slam cannot deliver delayed damage");
   g.enabled=true;Debug.Log("BLOODWAKE_ENEMY_VFX_CHECKS "+passed+" passed");
  }
 }
}
