using System.Collections;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The healer no longer heals only the ground around her own feet: she finds where her side is bunched
 // up and hurting, throws a mending orb there, and heals everyone it lands among.
 public sealed partial class BloodwakeGame
 {
  const float HealReach=13,HealRadius=3.2f;
  static readonly Color HealTone=new(.45f,1f,.55f);
  IEnumerator HealerCast(Enemy e)
  {
   int impact=e.ImpactVersion;e.Casting=true;var from=e.View.transform.position;
   // Score each ally as a landing spot: the missing health within the heal radius around it.
   Vector3 best=Vector3.zero;float bestScore=0;
   foreach(var a in Enemies)
   {
    if(a.Emerging||a.Hp<=0||!a.View)continue;var at=a.View.transform.position;if(Vector3.Distance(at,from)>HealReach)continue;
    float score=Enemies.Where(b=>b.Hp>0&&b.View&&!b.Emerging&&Vector3.Distance(b.View.transform.position,at)<=HealRadius).Sum(b=>b.MaxHp-b.Hp);
    if(score>bestScore){bestScore=score;best=at;}
   }
   if(bestScore<=0){e.Casting=false;e.Cooldown=.6f;yield break;}
   best.y=0;var palm=e.View.MagicPalmPosition();
   yield return Delay(.35f);
   if(e.Hp<=0||impact!=e.ImpactVersion){e.Casting=false;yield break;}
   // The mending orb arcs over to the spot.
   const float flight=.4f;Sound("healer_cast");RevFx.HealOrb(palm,best,flight,HealTone);
   yield return Delay(flight);e.Casting=false;
   if(Screen!="playing")yield break;
   float amount=e.Data.N("healAmount",20)*1.5f;
   foreach(var a in Enemies)if(a.Hp>0&&a.View&&!a.Emerging&&Vector3.Distance(a.View.transform.position,best)<=HealRadius){a.Hp=Mathf.Min(a.MaxHp,a.Hp+amount);RevFx.DamageText(a.View.transform.position,amount,HealTone);RevFx.Glow(a.View.transform.position+Vector3.up,HealTone,.9f,2,.3f);}
   Sound("healer_bloom");RevFx.HealBloom(best,HealRadius,HealTone);
  }
 }
 public sealed partial class RevenantVfx
 {
  public void HealOrb(Vector3 from,Vector3 to,float flight,Color tone)
  {
   var orb=Glow(from,tone,.45f,2.6f,flight);var top=Vector3.Lerp(from,to,.5f)+Vector3.up*2.2f;
   orb.Tick=(p,dt)=>{var a=Vector3.Lerp(from,top,p);var b=Vector3.Lerp(top,to+Vector3.up*.4f,p);orb.transform.position=Vector3.Lerp(a,b,p);orb.transform.rotation=Game.Cam.transform.rotation;if(Random.value<.5f)Glow(orb.transform.position,tone,.2f,1.4f,.25f);};
  }
  public void HealBloom(Vector3 at,float radius,Color tone)
  {
   var ring=Surface(at,radius,tone,.7f,2,2.2f);ring.Tick=(p,dt)=>{ring.transform.localScale=Vector3.one*radius*2*Mathf.Lerp(.6f,1.05f,Mathf.Sqrt(p));};
   BurstRing(at,radius,tone,20,2.5f,.6f);Flash(at,tone,2.4f,radius*2,.3f);
   for(int i=0;i<10;i++){var p0=at+Random.insideUnitSphere*radius*.8f;p0.y=.1f;var mote=Glow(p0,tone,.18f,2,.8f);var rise=Vector3.up*Random.Range(1.2f,2.2f);mote.Tick=(p,dt)=>{mote.transform.position=p0+rise*p;mote.transform.rotation=Game.Cam.transform.rotation;};}
  }
 }
}
