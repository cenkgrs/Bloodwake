using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class MotionChecks
 {
  static int passed;
  static object Call(BloodwakeGame g,string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(g,args);
  static void Field(BloodwakeGame g,string name,object value)=>typeof(BloodwakeGame).GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).SetValue(g,value);
  static void Check(bool ok,string name){if(!ok)throw new Exception("MOTION_CHECK_FAILED "+name);passed++;Debug.Log("MOTION_CHECK_PASSED "+name);}
  public static IEnumerator Run(BloodwakeGame g)
  {
   passed=0;g.StartRun("warrior");g.Run.Awarded=true;Call(g,"EnterRoom",g.Run.Plan[0]);Field(g,"spawnTimer",9999f);g.enabled=false;
   var blockers=(List<Bounds>)typeof(BloodwakeGame).GetField("blockers",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(g);
   blockers.Clear();blockers.Add(new Bounds(Vector3.up,new Vector3(2,2,6)));Call(g,"BuildNavigation");g.Player.transform.position=new Vector3(-4,0,0);Call(g,"UpdateNavigation",1f);
   g.SpawnEnemy("grunt",new Vector3(4,0,0));var enemy=g.Enemies.Last();enemy.Cooldown=999;var initial=enemy.View.transform.position;bool aligned=true,detour=false;
   for(int frame=0;frame<720;frame++)
   {
    var before=enemy.View.transform.position;Call(g,"TickEnemies",1f/60);var delta=enemy.View.transform.position-before;if(delta.sqrMagnitude>1e-7f)aligned&=Vector3.Dot(delta.normalized,enemy.View.transform.forward)>.995f;
    detour|=Mathf.Abs(enemy.View.transform.position.z)>3.4f;
   }
   Check(aligned,"forward run faces actual movement around obstacle");Check(detour,"takes clearance route around wall");Check(Vector3.Distance(enemy.View.transform.position,g.Player.transform.position)<1.4f,"wall detour reaches melee range");
   blockers.Clear();Call(g,"BuildNavigation");
   foreach(int fps in new[]{30,60,144,240,360})
   {
    enemy.View.transform.position=Vector3.zero;enemy.View.transform.rotation=Quaternion.identity;enemy.View.Locked=0;enemy.Cooldown=999;
    g.Player.transform.position=Vector3.back*6;Call(g,"UpdateNavigation",1f);var before=enemy.View.transform.position;Call(g,"TickEnemies",1f/fps);
    var step=enemy.View.transform.position-before;
    Check(step.sqrMagnitude>0&&Vector3.Dot(step.normalized,enemy.View.transform.forward)>.999f,"turns toward player behind at "+fps+" fps");
   }
   g.Player.transform.position=new Vector3(-4,0,0);
   blockers.Clear();blockers.Add(new Bounds(new Vector3(0,1,0),new Vector3(1,2,100)));enemy.View.transform.position=new Vector3(3,0,0);Call(g,"BuildNavigation");Call(g,"UpdateNavigation",1f);var stuck=enemy.View.transform.position;
   for(int i=0;i<20;i++)Call(g,"TickEnemies",1f/60);yield return new WaitForSeconds(.15f);
   Check(Vector3.Distance(stuck,enemy.View.transform.position)<.001f,"unreachable target does not push against blocked route");Check(enemy.View.Animator.GetCurrentAnimatorStateInfo(0).IsName(enemy.View.Clip("Idle")),"blocked enemy idles rather than running in place");
   blockers.Clear();g.Player.transform.position=Vector3.zero;enemy.View.transform.position=Vector3.forward;enemy.Hp=10000;g.Run.Stats["criticalChance"]=0;
   Call(g,"DamageEnemy",enemy,1f,true);var start=enemy.View.transform.position;for(int i=0;i<12;i++)Call(g,"TickRecoil",enemy,1f/60);
   float recoil=Vector3.Distance(start,enemy.View.transform.position);Check(recoil>.18f&&recoil<=.241f,"ordinary hit produces visible recoil within twenty four centimetres");
   var row=GameData.Row("weapons","sword");float reach=row.N("range")*.02f*g.Run.Stats.N("attackRange")*g.Run.Weapons["sword"].N("range")*1.7f+.45f;
   enemy.View.transform.position=Vector3.forward*(reach-.015f);for(int hit=0;hit<5;hit++){Call(g,"DamageEnemy",enemy,1f,true);for(int i=0;i<12;i++)Call(g,"TickRecoil",enemy,1f/60);}
   Check(Vector3.Distance(g.Player.transform.position,enemy.View.transform.position)<=reach,"combo edge remains within next melee hit range");
   enemy.View.transform.position=Vector3.forward;blockers.Add(new Bounds(new Vector3(0,1,1.55f),new Vector3(2,2,.1f)));Call(g,"DamageEnemy",enemy,1f,true);for(int i=0;i<12;i++)Call(g,"TickRecoil",enemy,1f/60);Check(enemy.View.transform.position.z<=1.051f,"recoil respects wall collision");
   var rootBefore=enemy.View.transform.position;enemy.View.ImpactPose(g.Player.transform.position,7);enemy.View.Tick(.045f,false);var pivot=enemy.View.transform.Find("Impact pose");var pose=pivot.localRotation;
   Check(Quaternion.Angle(pose,Quaternion.identity)>6&&enemy.View.transform.position==rootBefore,"impact pose is visible without extra knockback");
   enemy.View.Tick(0,false);Check(Quaternion.Angle(pose,pivot.localRotation)<.001f,"impact pose freezes with gameplay time");
   enemy.View.Tick(.3f,false);Check(Quaternion.Angle(pivot.localRotation,Quaternion.identity)<.001f,"impact pose recovers completely");
   blockers.Clear();enemy.View.transform.position=Vector3.forward;enemy.AreaRecovery=0;
   var blast=enemy.View.transform.position-Vector3.right;start=enemy.View.transform.position;
   Call(g,"Area",blast,2f,1f,false,true);
   Check(enemy.Stagger>=.55f&&enemy.View.Locked>=.55f,"large area hit holds a longer reaction");
   Check(Vector3.Dot(enemy.RecoilDirection,Vector3.right)>.999f,"area recoil radiates from explosion rather than player");
   var remaining=enemy.RecoilRemaining;Call(g,"DamageEnemy",enemy,1f,true);
   Check(enemy.RecoilRemaining==remaining&&enemy.Stagger>=.55f&&enemy.View.Locked>=.55f,"small followup cannot cancel area reaction");
   for(int i=0;i<20;i++)Call(g,"TickRecoil",enemy,1f/60);
   Check(Mathf.Abs(Vector3.Distance(start,enemy.View.transform.position)-.48f)<.002f,"area scatters ordinary enemies forty eight centimetres");
   enemy.View.Tick(.3f,false);Check(Quaternion.Angle(pivot.localRotation,Quaternion.identity)>3,"area impact remains visible after ordinary hit recovery");
   enemy.View.Tick(.3f,false);Check(Quaternion.Angle(pivot.localRotation,Quaternion.identity)<.001f,"area impact fully recovers");
   foreach(var id in new[]{"tank","boss"})
   {
    g.SpawnEnemy(id,new Vector3(3,0,0));var heavy=g.Enemies.Last();Call(g,"StartAreaRecoil",heavy,Vector3.zero);
    Check(heavy.RecoilRemaining<(id=="boss"?.081f:.201f)&&heavy.AreaRecovery<.56f,"area resistance for "+id);
    g.Enemies.Remove(heavy);UnityEngine.Object.Destroy(heavy.View.gameObject);
   }
   enemy.View.transform.position=Vector3.forward;blockers.Add(new Bounds(new Vector3(0,1,1.55f),new Vector3(2,2,.1f)));Call(g,"StartAreaRecoil",enemy,Vector3.zero);
   for(int i=0;i<20;i++)Call(g,"TickRecoil",enemy,1f/60);Check(enemy.View.transform.position.z<=1.051f,"large area recoil respects wall collision");
   blockers.Clear();enemy.View.transform.position=Vector3.forward;enemy.AreaRecovery=0;var health=g.Run.Stats.N("hp");Field(g,"invulnerable",0f);
   var attack=(IEnumerator)Call(g,"EnemyMelee",enemy,Vector3.back);attack.MoveNext();Call(g,"StartAreaRecoil",enemy,Vector3.zero);attack.MoveNext();
   Check(g.Run.Stats.N("hp")==health,"area hit interrupts pending enemy melee damage");
   for(int i=0;i<40;i++)Call(g,"TickEnemies",1f/60);
   Check(enemy.AreaRecovery<=0&&enemy.Stagger<=0,"area reaction releases enemy after recovery");
   int version=enemy.ImpactVersion;enemy.Hp=0;Call(g,"StartAreaRecoil",enemy,Vector3.zero);Check(enemy.ImpactVersion==version,"area does not replace dead enemy animation");
   Field(g,"hitStop",0f);g.enabled=true;Debug.Log("BLOODWAKE_MOTION_CHECKS "+passed+" passed");
  }
 }
}
