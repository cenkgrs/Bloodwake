using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // How enemies answer what hits them: a struck enemy cannot strike straight back, and fire makes them burn.
 public sealed partial class BloodwakeGame
 {
  // After a hit the enemy's own attack waits out the stagger plus this, so the next swing of a combo lands first.
  const float HitAttackDelay=.6f,BossHitAttackDelay=.25f;
  void HoldAttack(Enemy e){e.Cooldown=Mathf.Max(e.Cooldown,e.Stagger+(e.Id=="boss"?BossHitAttackDelay:HitAttackDelay));}

  // Set alight: damage over time, and on first catching fire ordinary enemies thrash in place instead of fighting.
  void Ignite(Enemy e,float seconds,float dps)
  {
   if(e==null||e.Hp<=0||e.Emerging||!e.View)return;
   bool caught=e.Burn<=0;e.Burn=Mathf.Max(e.Burn,seconds);e.BurnDps=Mathf.Max(e.BurnDps,dps);
   if(!caught||e.Training)return;
   float panic=e.Id=="boss"?0:e.Id=="tank"?.8f:1.5f;
   if(panic>0&&e.PanicCooldown<=0)
   {
    e.Panic=panic;e.PanicCooldown=panic+2.5f;e.ImpactVersion++;e.Casting=false;
    var away=e.View.transform.position-Player.transform.position;away.y=0;
    e.PanicDirection=Quaternion.Euler(0,Random.Range(-50f,50f),0)*(away.sqrMagnitude>.01f?away.normalized:-e.View.transform.forward);
    e.View.Play("Hit",.45f);e.PanicFlinch=.45f;
   }
   e.BurnVisual=0;
  }
  // Burning thrash: stumble away from the hunter, flinching, unable to attack.
  void TickPanic(Enemy e,float dt)
  {
   e.Panic-=dt;e.PanicFlinch-=dt;e.Cooldown=Mathf.Max(e.Cooldown,.6f);HoldEnemyAgent(e);
   e.PanicDirection=Quaternion.Euler(0,Mathf.Sin(Time.time*7+e.CrowdId)*140*dt,0)*e.PanicDirection;
   e.View.transform.position=MoveEnemy(e,e.PanicDirection*e.Data.N("moveSpeed")*.02f*.4f*dt);
   e.View.transform.rotation=Quaternion.Slerp(e.View.transform.rotation,Quaternion.LookRotation(e.PanicDirection),dt*8);
   if(e.PanicFlinch<=0){e.View.Play("Hit",.45f);e.PanicFlinch=.45f;}
   e.View.Tick(dt,false);
  }
  // Flames ride a burning body; re-lit in short bursts while the burn lasts.
  void TickBurnVisual(Enemy e,float dt)
  {
   if(e.Burn<=0||!e.View)return;e.BurnVisual-=dt;if(e.BurnVisual>0)return;e.BurnVisual=.42f;
   var bones=e.View.GetComponentsInChildren<Transform>();int lit=0;
   foreach(var name in new[]{"Spine1","Spine2","LeftArm","RightArm","LeftUpLeg","RightUpLeg","Head"})
   {
    var bone=System.Array.Find(bones,b=>b.name.EndsWith(":"+name)||b.name==name);if(!bone)continue;
    RevFx.FlameCard(bone.position,Random.Range(.35f,.6f)*(name.Contains("Spine")?1.3f:1),Random.Range(.45f,.6f),Vector3.up*.3f,Random.Range(0,.2f),1.6f,"body",bone);lit++;
   }
   if(lit==0)for(int i=0;i<3;i++)RevFx.FlameCard(e.View.transform.position+Vector3.up*(.5f+i*.45f),.6f,.55f,Vector3.up*.3f,i*.08f,1.6f,"body",e.View.transform);
  }

  // Ground that keeps burning after Vesper's fire: anyone standing in it catches.
  readonly List<FireZone> fireZones=new();
  sealed class FireZone{public Vector3 At;public float Radius,Remaining,Dps;}
  void AddFireZone(Vector3 at,float radius,float seconds,float dps){at.y=0;fireZones.Add(new FireZone{At=at,Radius=radius,Remaining=seconds,Dps=dps});}
  void TickFireZones(float dt)
  {
   for(int i=fireZones.Count-1;i>=0;i--)
   {
    var zone=fireZones[i];zone.Remaining-=dt;if(zone.Remaining<=0){fireZones.RemoveAt(i);continue;}
    foreach(var e in Enemies){if(e.Emerging||e.Burn>1)continue;var d=e.View.transform.position-zone.At;d.y=0;if(d.magnitude<zone.Radius+.3f)Ignite(e,1.6f,zone.Dps);}
   }
  }
  void IgniteAround(Vector3 at,float radius,float seconds,float dps)
  {
   foreach(var e in Enemies.ToArray()){if(e.Emerging)continue;var d=e.View.transform.position-at;d.y=0;if(d.magnitude<radius+.4f)Ignite(e,seconds,dps);}
  }
 }
}
