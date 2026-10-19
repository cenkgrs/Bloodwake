using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The Revenant's Motion branch (Blood Sage): moves built on blood and bleeding.
 //  R2 Crimson Rend · R1 R1 R2 Hemorrhage · L1+R1 Blood Lance · L1+R2 Sanguine Siphon · Mist Chain (second dash).
 public sealed partial class BloodwakeGame
 {
  static readonly Color BloodRed=new(.78f,.05f,.12f);
  void RevenantHeavy()
  {
   bool afterTwo=combo==2&&Time.time<=comboExpires&&Owns("revenant_hemorrhage");combo=0;
   StartCoroutine(afterTwo?Hemorrhage():CrimsonRend());
  }
  void Bleed(Enemy e,float seconds,float dps){if(e==null||e.Hp<=0)return;e.Bleed=Mathf.Max(e.Bleed,seconds);e.BleedDps=Mathf.Max(e.BleedDps,dps);}

  // Both claws tear across the front in a wide X.
  IEnumerator CrimsonRend()
  {
   vesperMoveActive=true;var dir=Player.transform.forward;dir.y=0;dir.Normalize();float damage=RevenantBasicDamage();
   const float hold=.62f;Player.Play("Attack3",hold);Sound(Voice("revenant_rend","revenant_swing"));float contact=hold*.42f;
   yield return Delay(contact);
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    var origin=Player.transform.position;const float reach=2.9f;bool any=false;DamageCargo(origin,reach,dir,220);
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||!e.View)continue;var rel=e.View.transform.position-origin;rel.y=0;if(rel.magnitude>reach+.4f||Vector3.Angle(dir,rel)>110)continue;
     any=true;DamageEnemy(e,damage*2.1f);if(!e.View)continue;MeleeKnockback(e,dir,true);Bleed(e,4,damage*.18f);RevFx.Splatter(e.View.transform.position+Vector3.up*.9f,rel.normalized);RevFx.ThrustClawImpact(e.View);
    }
    RevFx.Claws(origin,dir,reach,true,true);RevFx.Claws(origin,Quaternion.Euler(0,24,0)*dir,reach*.9f,false,true);
    if(any){hitStop=Mathf.Max(hitStop,FinisherHitStop);ShakeCamera(.6f,dir);}
   }
   yield return Delay(hold-contact);vesperMoveActive=false;attackCd=.1f;
  }
  // A clap that bursts the blood of everything bleeding nearby; every burst feeds the hunter.
  IEnumerator Hemorrhage()
  {
   vesperMoveActive=true;float damage=RevenantBasicDamage();const float hold=.7f,radius=6f;
   Player.Play("REV_BloodClap",hold);Sound(Voice("revenant_hemorrhage","revenant_swing"));float contact=hold*.45f;
   yield return Delay(contact);
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    var origin=Player.transform.position;int bursts=0;
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||!e.View||e.Bleed<=0)continue;var rel=e.View.transform.position-origin;rel.y=0;if(rel.magnitude>radius)continue;
     // Everything the bleed would still have done, at once and then some.
     float burst=damage+e.BleedDps*e.Bleed*1.5f;var at=e.View.transform.position;e.Bleed=0;DamageEnemy(e,burst);bursts++;
     RevFx.Burst(at,1.3f,1.2f);RevFx.Splatter(at+Vector3.up*1.1f,Vector3.up);RevFx.Flash(at+Vector3.up,BloodRed,2.2f,3,.15f);
    }
    if(bursts>0)
    {
     float heal=Run.Stats.N("maxHp")*Mathf.Min(.2f,.04f*bursts);Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+heal);RevFx.DamageText(Player.transform.position,heal,RevenantVfx.Tone("7dff9a"));
     hitStop=Mathf.Max(hitStop,FinisherHitStop);ShakeCamera(.7f,Vector3.zero);
    }
    else
    {
     // Nothing to burst: the clap still opens a small wound in everything close.
     foreach(var e in Enemies.ToArray()){if(e.Emerging||e.Hp<=0||!e.View)continue;var rel=e.View.transform.position-origin;rel.y=0;if(rel.magnitude>2.6f)continue;DamageEnemy(e,damage);Bleed(e,3,damage*.15f);}
     RevFx.Burst(origin,2.6f,1f);ShakeCamera(.35f,Vector3.zero);
    }
   }
   yield return Delay(hold-contact);vesperMoveActive=false;attackCd=.1f;
  }
  // L1 + R1: a lance of blood that pierces the whole line and drags what it skewers in.
  void BloodLance()
  {
   if(vesperMoveActive||attackCd>0||RevenantActionActive||Player.Locked>.15f)return;PadFacing();StartCoroutine(BloodLanceRoutine());
  }
  IEnumerator BloodLanceRoutine()
  {
   vesperMoveActive=true;var dir=Player.transform.forward;dir.y=0;dir.Normalize();float damage=RevenantBasicDamage();
   const float hold=.44f;Player.Play("Attack2",hold);Sound(Voice("revenant_blood_lance","revenant_swing"));attackCd=.5f;yield return Delay(hold*.45f);
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    var start=Player.transform.position;start.y=0;float reach=8.5f;var end=Move(start,dir*reach,.15f);reach=Vector3.Distance(start,end);
    DamageCargoSegment(start,end,.5f);
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||!e.View)continue;var p=e.View.transform.position;p.y=0;float along=Vector3.Dot(p-start,dir);
     if(along<0||along>reach+.4f||SegmentDistance(p,start,end)>.75f)continue;
     DamageEnemy(e,damage*1.5f);if(!e.View||e.Hp<=0)continue;Bleed(e,3.5f,damage*.15f);RevFx.Splatter(e.View.transform.position+Vector3.up*.9f,-dir);
     if(e.Id!="boss"){e.RecoilDirection=-dir;e.RecoilRemaining=Mathf.Min(1.6f,Mathf.Max(0,along-1.4f));e.RecoilTime=.26f;e.Stagger=Mathf.Max(e.Stagger,.7f);HoldAttack(e);}
    }
    var hand=Player.transform.position+Vector3.up*(Player.Height*.62f);RevFx.ThrustStrike(hand,dir,reach);RevFx.BloodLanceStreak(hand,dir,reach);ShakeCamera(.4f,dir);
   }
   yield return Delay(hold*.55f);vesperMoveActive=false;
  }
  // L1 + R2: drains everything in front for up to a second; ends early on any other action, and once nothing is left
  // in the cone. With nobody in reach it does not start at all, so it never plays out into empty air.
  const float SiphonRange=4.8f,SiphonCone=40;
  bool SiphonCanReach(Enemy e,Vector3 origin,Vector3 dir,float slack)
  {
   if(e.Emerging||e.Hp<=0||!e.View)return false;var rel=e.View.transform.position-origin;rel.y=0;
   return rel.magnitude<=SiphonRange+slack&&Vector3.Angle(dir,rel)<=SiphonCone*.5f+10+slack*20;
  }
  void BeginSiphon()
  {
   if(Run?.ClassId!="revenant"||flameBreathing||vesperMoveActive||RevenantActionActive||Run.Stats.N("hp")<=0)return;
   var want=!usingPad?aim:moveIntent.sqrMagnitude>.01f?moveIntent:Player.transform.forward;want.y=0;if(want.sqrMagnitude<.001f)want=Player.transform.forward;
   if(!Enemies.Any(e=>SiphonCanReach(e,Player.transform.position,want.normalized,.5f)))return;
   StartCoroutine(SiphonRoutine());
  }
  IEnumerator SiphonRoutine()
  {
   flameBreathing=true;vesperMoveActive=true;PadFacing();Player.Play("REV_BloodClap",1.1f);Sound(Voice("revenant_siphon","revenant_swing"));
   var tethers=new Dictionary<Enemy,TetherFx>();float age=0,tick=0,empty=0,damage=RevenantBasicDamage()*.2f;const float max=1.1f;
   Vector3 Palms()=>Player.MagicPalmPosition();
   while(flameBreathing&&age<max&&Run.Stats.N("hp")>0)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float dt=Time.deltaTime;age+=dt;Player.Locked=Mathf.Max(Player.Locked,.1f);
    var want=!usingPad?aim:moveIntent.sqrMagnitude>.01f?moveIntent:Player.transform.forward;want.y=0;
    if(want.sqrMagnitude>.001f)Player.transform.rotation=Quaternion.RotateTowards(Player.transform.rotation,Quaternion.LookRotation(want.normalized),400*dt);
    var dir=Player.transform.forward;var origin=Player.transform.position;
    if((tick-=dt)<=0)
    {
     tick=.1f;float drained=0;
     foreach(var e in Enemies.ToArray())
     {
      if(e.Emerging||e.Hp<=0||!e.View)continue;var rel=e.View.transform.position-origin;rel.y=0;
      if(!SiphonCanReach(e,origin,dir,0)){if(tethers.TryGetValue(e,out var t)){if(t)t.Release();tethers.Remove(e);}continue;}
      DamageEnemy(e,damage,false);if(!e.View)continue;drained+=damage;RevFx.DamageText(e.View.transform.position,damage,RevenantVfx.Tone("ff6b78"));e.View.FlashHit(false);
      if(!tethers.ContainsKey(e)){var target=e;var t=RevFx.Tether(Palms,()=>target.View?target.View.transform.position+Vector3.up*target.View.Height*.6f:Palms());t.Tone=new Color(1.4f,.08f,.16f,1);tethers[e]=t;}
      if(Random.value<.5f)RevFx.Splatter(e.View.transform.position+Vector3.up*1.1f,-rel.normalized);
      if(Random.value<.4f)RevFx.BloodMistPuff(e.View.transform.position+Vector3.up*e.View.Height*.6f,Palms());
     }
     if(drained>0){float heal=drained*.4f;Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+heal);empty=0;}
     // Everything drained, dead or out of the cone: let go instead of miming at nothing.
     else if((empty+=.1f)>=.2f)break;
    }
    yield return null;
   }
   foreach(var t in tethers.Values)if(t)t.Release();
   if(flameBreathing){flameBreathing=false;vesperMoveActive=false;attackCd=Mathf.Max(attackCd,.12f);}
  }
 }
 public sealed partial class RevenantVfx
 {
  // A long crimson spear of light down the lance's line, thinning as it fades.
  public void BloodLanceStreak(Vector3 hand,Vector3 dir,float reach)
  {
   var axis=Vector3.ProjectOnPlane(dir,Game.Cam.transform.forward).normalized;if(axis.sqrMagnitude<.01f)axis=Game.Cam.transform.up;
   var lance=Sheet("Blood lance",hand+dir*reach*.5f,new Vector3(.6f,reach,1),"claw_cut",.36f,Tone("ff3a52"));
   lance.transform.rotation=Quaternion.LookRotation(Game.Cam.transform.forward,axis);
   lance.Tick=(p,dt)=>{lance.transform.localScale=new Vector3(.6f*(1-p*.85f),reach*(.6f+.4f*Mathf.Min(1,p*6)),1);};
   var core=Sheet("Blood lance core",hand+dir*reach*.5f,new Vector3(.22f,reach,1),"claw_cut",.2f,Tone("ffd0d6"));core.transform.rotation=Quaternion.LookRotation(Game.Cam.transform.forward,axis);
   for(float d=1;d<reach;d+=1.1f)Splatter(hand+dir*d-Vector3.up*.6f,dir);
   Flash(hand+dir*reach*.5f,Tone("ff2440"),2f,reach*.6f,.14f);
  }
 }
}
