using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // Vesper's moves beyond the three-swing chain: the rising cut out of a dash, and the flame crescents it throws.
 public sealed partial class BloodwakeGame
 {
  bool vesperMoveActive;
  public bool VesperMoveActive=>vesperMoveActive;
  float VesperBasicDamage()=>RevenantBasicDamage();

  // Dash, then R1 inside the window: slide on, drag the blade up off the stone, and send a standing
  // crescent of fire racing ahead.
  bool BeginVesperRisingSlash()
  {
   if(Run?.ClassId!="vesper"||thrustWindow<=0||revenantDashing||vesperMoveActive||Run.Stats.N("hp")<=0)return false;
   thrustWindow=0;thrustQueued=false;StartCoroutine(VesperRisingSlash(revenantDashDirection.sqrMagnitude>.01f?revenantDashDirection:Player.transform.forward));return true;
  }
  IEnumerator VesperRisingSlash(Vector3 dir)
  {
   vesperMoveActive=true;dir.y=0;dir.Normalize();Player.transform.rotation=Quaternion.LookRotation(dir);
   const float hold=.62f;float contact=.52f*hold;
   Player.Play("DashAttack",hold);invulnerable=Mathf.Max(invulnerable,.25f);SoundOnContact("vesper_attack_3",contact);
   StartCoroutine(VesperLunge(dir,LungeDistance(dir,1.7f),.24f));
   // Sparks scrape off the stone as the blade drags through the slide.
   for(float t=0;t<contact;t+=.06f)StartCoroutine(DelayedCall(t,()=>RevFx.VesperTrailBurn(Player.transform.position+dir*.9f,dir,1)));
   yield return Delay(contact);
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    ShakeCamera(.45f,dir);hitStop=Mathf.Max(hitStop,.05f);
    StartCoroutine(LaunchCrescent(Player.transform.position+dir*.6f,dir,true,1.3f,.5f,13,8,VesperBasicDamage()*1.8f,2.5f));
   }
   yield return Delay(hold-contact);vesperMoveActive=false;attackCd=Mathf.Min(attackCd,.15f);
  }
  IEnumerator DelayedCall(float delay,System.Action action){yield return Delay(delay);if(Screen=="playing")action();}

  // A crescent flies `distance` at `speed`, burning and throwing back everything it passes through once.
  IEnumerator LaunchCrescent(Vector3 from,Vector3 dir,bool vertical,float radius,float width,float speed,float distance,float damage,float burn)
  {
   dir.y=0;dir.Normalize();from.y=0;var crescent=FlameCrescent.Create(RevFx,from,dir,radius,width,vertical);if(roomRoot)crescent.transform.SetParent(roomRoot,true);
   var hit=new HashSet<Enemy>();float travelled=0,scorch=0;Vector3 side=Vector3.Cross(Vector3.up,dir);
   // A vertical cut is a narrow blade of fire; a horizontal sweep covers its whole span.
   float halfSpan=vertical?.75f:radius;
   while(travelled<distance&&crescent)
   {
    if(Screen=="playing"&&hitStop<=0)
    {
     float step=Mathf.Min(speed*Time.deltaTime,distance-travelled);var previous=crescent.transform.position;var next=previous+dir*step;
     // Walls stop it short.
     if(Vector3.Distance(Move(previous,dir*step),next)>.2f)break;
     crescent.transform.position=next;travelled+=step;crescent.Alpha=1-Mathf.SmoothStep(0,1,(travelled/distance-.7f)/.3f);
     DamageCargoSegment(previous,next,halfSpan);
     // It scorches a burning line along the stone behind it.
     for(scorch+=step;scorch>=.5f;scorch-=.5f){RevFx.VesperTrailBurn(next,dir,vertical?2:1);if(vertical)AddFireZone(next,.45f,1.2f,damage*.05f);}
     foreach(var e in Enemies.ToArray())
     {
      if(e.Emerging||hit.Contains(e))continue;var d=e.View.transform.position-next;d.y=0;
      float along=Vector3.Dot(d,dir),across=Mathf.Abs(Vector3.Dot(d,side));
      if(along>-width-.4f&&along<radius*.42f+.5f&&across<halfSpan+.35f)
      {
       hit.Add(e);DamageEnemy(e,damage);Ignite(e,burn,damage*.12f);MeleeKnockback(e,dir,true);
       RevFx.FlameCard(e.View.transform.position+Vector3.up*.9f,1.2f,.35f,Vector3.zero,0,2.6f,"burst");
      }
     }
    }
    yield return null;
   }
   if(crescent)
   {
    // Dies out in a last flare where it stops.
    RevFx.FlameCard(crescent.transform.position+Vector3.up*(vertical?radius:.4f),radius*1.1f,.4f,Vector3.zero,0,2.2f,"burst");
    float fade=0;while(fade<.18f&&crescent){fade+=Time.deltaTime;crescent.Alpha=Mathf.Lerp(crescent.Alpha,0,fade/.18f);yield return null;}
    if(crescent)Destroy(crescent.gameObject);
   }
  }
 }
}
