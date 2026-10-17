using System.Collections;
using System.Collections.Generic;
using System.Linq;
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
   Player.Play("DashAttack",hold);invulnerable=Mathf.Max(invulnerable,.25f);SoundOnContact(Voice("vesper_rising_crescent","vesper_attack_3"),contact);
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
  // ---- Tree moves (Blood Sage, Motion branch).
  float heavyBuffer,lastHeavyTime=-9,secondDashUntil;bool bladeThrown;
  // The thrown blade borrows the hand's flame sockets; anything that cuts the throw short puts them back.
  Transform thrownGrip,thrownGripParent,thrownPivot;SkinnedMeshRenderer thrownSword;Vector3 thrownGripPosition;Quaternion thrownGripRotation;Mesh thrownMesh;
  void RestoreThrownBlade()
  {
   if(thrownGrip&&thrownGripParent){thrownGrip.SetParent(thrownGripParent,false);thrownGrip.localPosition=thrownGripPosition;thrownGrip.localRotation=thrownGripRotation;}
   if(thrownSword)thrownSword.enabled=true;if(thrownPivot)Destroy(thrownPivot.gameObject);if(thrownMesh)Destroy(thrownMesh);
   thrownGrip=thrownGripParent=thrownPivot=null;thrownSword=null;thrownMesh=null;bladeThrown=false;vesperMoveActive=false;
  }
  float VesperReach()
  {
   foreach(var entry in Run.Weapons){var row=GameData.Row("weapons",entry.Key);if(row.S("behavior")=="melee")return row.N("range")*.02f*Run.Stats.N("attackRange")*entry.Value.N("range")*2.1f;}
   return 2.5f;
  }
  // R2 picks the move from what came before it: R1 R1 R2 is Falling Star, R2 R2 is Crescent Fan, otherwise Heavy Cleave.
  void VesperHeavy()
  {
   bool afterTwoSwings=combo==2&&Time.time<=comboExpires,afterCleave=Time.time-lastHeavyTime<1.4f;
   if(afterTwoSwings&&Owns("vesper_falling_star")){StartCoroutine(FallingStar());return;}
   StartCoroutine(VesperCleave(afterCleave&&Owns("vesper_crescent_fan")));
  }
  IEnumerator VesperCleave(bool fan)
  {
   vesperMoveActive=true;var dir=Player.transform.forward;dir.y=0;dir.Normalize();
   // A deliberate two-handed cut: the authored swing at three quarters speed.
   float hold=Player.ClipLength("Attack2")*1.45f,contact=.40f*hold;
   Player.Play("Attack2",hold);SoundOnContact(fan?Voice("vesper_crescent_fan",Voice("vesper_heavy_cleave","vesper_attack_2")):Voice("vesper_heavy_cleave","vesper_attack_2"),contact);StartCoroutine(VesperLunge(dir,LungeDistance(dir,.9f),contact*.8f));
   yield return Delay(contact);
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    float damage=VesperBasicDamage();hitStop=Mathf.Max(hitStop,FinisherHitStop);
    StartCoroutine(MeleeContact(dir,VesperReach()*1.2f,damage*2.2f,0,false,0,0,true));RevFx.VesperBladeArc(Player.transform.position,dir,VesperReach(),200);
    if(fan){RevFx.Flash(Player.transform.position+dir,RevenantVfx.Tone("ffb347"),1.2f,2.4f,.18f);StartCoroutine(LaunchCrescent(Player.transform.position+dir*.7f,dir,false,2.3f,.55f,11,7,damage*1.6f,2.5f));}
   }
   lastHeavyTime=fan?-9:Time.time;combo=0;
   yield return Delay(hold-contact);vesperMoveActive=false;attackCd=.08f;
  }
  // Leap, turn once in the air, and come down blade-first into the stone.
  IEnumerator FallingStar()
  {
   vesperMoveActive=true;combo=0;var dir=Player.transform.forward;dir.y=0;dir.Normalize();var start=Player.transform.position;
   const float air=.62f;float clip=Player.ClipLength("Ultimate"),hold=air*clip/.50f;
   // The Ultimate clip drives the blade into the ground at 0.50 s; time it to land with the body.
   Player.Play("Ultimate",hold);SoundOnContact(Voice("vesper_falling_star","vesper_bloodfire_rite"),air);invulnerable=Mathf.Max(invulnerable,air+.1f);
   var landing=start+dir*LungeDistance(dir,1.6f);float age=0;var facing=Quaternion.LookRotation(dir);
   while(age<air)
   {
    if(Screen=="playing"&&hitStop<=0)
    {
     age=Mathf.Min(air,age+Time.deltaTime);float t=age/air;
     var ground=Vector3.Lerp(start,landing,Mathf.SmoothStep(0,1,t));Player.transform.position=ground+Vector3.up*Mathf.Sin(t*Mathf.PI)*1.5f;
     // One full turn while rising, facing the target again before the blade comes down.
     Player.transform.rotation=facing*Quaternion.Euler(0,360*Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.75f)),0);
     if(Random.value<.5f)RevFx.FlameCard(Player.transform.position+Vector3.up*.9f,.7f,.3f,Vector3.up*-.4f,0,1.6f,"body");
    }
    yield return null;
   }
   Player.transform.position=landing;Player.transform.rotation=facing;
   if(Screen=="playing"&&Run.Stats.N("hp")>0)
   {
    float damage=VesperBasicDamage()*2.6f,radius=2.8f;
    Area(landing,radius,damage,false,true);IgniteAround(landing,radius,3,damage*.12f);AddFireZone(landing,radius*.8f,2,damage*.06f);
    RevFx.VesperGroundCast(landing,radius,true);ShakeCamera(.85f,dir);hitStop=Mathf.Max(hitStop,.14f);
   }
   yield return Delay(Mathf.Max(.15f,hold-air));vesperMoveActive=false;attackCd=.1f;
  }
  // Hurl the greatsword, flames and all, then wrench it back to the hand; it cuts on the way out and back.
  IEnumerator TetheredBlade()
  {
   vesperMoveActive=true;PadFacing();var dir=Player.transform.forward;dir.y=0;dir.Normalize();
   Player.Play("Attack1",.5f);SoundOnContact(Voice("vesper_blade_throw","vesper_attack_1"),.18f);
   yield return Delay(.18f);
   var bones=Player.GetComponentsInChildren<Transform>(true);var grip=System.Array.Find(bones,t=>t.name=="VesperSwordGrip");
   var sword=Player.GetComponentsInChildren<SkinnedMeshRenderer>(true).FirstOrDefault(r=>r.name.Contains("Sword"));
   if(!grip||!sword||Screen!="playing"){vesperMoveActive=false;yield break;}
   // Freeze the skinned blade into a free-flying copy; the flame sockets ride along with it.
   var baked=new Mesh{name="Thrown greatsword"};sword.BakeMesh(baked,true);
   var pivot=new GameObject("Thrown blade").transform;var mid=System.Array.Find(bones,t=>t.name=="VesperSwordMid");pivot.position=mid?mid.position:grip.position;
   var flier=new GameObject("Blade").transform;flier.SetPositionAndRotation(sword.transform.position,sword.transform.rotation);flier.SetParent(pivot,true);
   flier.gameObject.AddComponent<MeshFilter>().sharedMesh=baked;flier.gameObject.AddComponent<MeshRenderer>().sharedMaterials=sword.sharedMaterials;
   thrownGrip=grip;thrownGripParent=grip.parent;thrownGripPosition=grip.localPosition;thrownGripRotation=grip.localRotation;thrownSword=sword;thrownPivot=pivot;thrownMesh=baked;
   grip.SetParent(flier,true);sword.enabled=false;bladeThrown=true;
   vesperMoveActive=false;
   float damage=VesperBasicDamage()*1.3f,reach=6.5f;var height=pivot.position.y;
   var hitOut=new HashSet<Enemy>();var hitBack=new HashSet<Enemy>();
   // Out, a short hang, back to the hand.
   var from=pivot.position;var to=Move(new Vector3(from.x,0,from.z),dir*reach);to.y=height;
   float age=0,outTime=.32f,hang=.08f,backTime=.3f,flame=0;
   while(age<outTime+hang+backTime)
   {
    if(Screen=="playing"&&hitStop<=0)
    {
     age+=Time.deltaTime;var hand=Player.transform.position+Vector3.up*height;
     pivot.position=age<outTime?Vector3.Lerp(from,to,1-(1-age/outTime)*(1-age/outTime)):age<outTime+hang?to:Vector3.Lerp(to,hand,Mathf.Pow((age-outTime-hang)/backTime,2));
     pivot.Rotate(Vector3.up,1440*Time.deltaTime,Space.World);
     var set=age<outTime+hang?hitOut:hitBack;var flat=new Vector3(pivot.position.x,0,pivot.position.z);
     DamageCargo(flat,1,dir);
     foreach(var e in Enemies.ToArray()){if(e.Emerging||set.Contains(e))continue;var d=e.View.transform.position-flat;d.y=0;if(d.magnitude<1.1f){set.Add(e);DamageEnemy(e,damage);Ignite(e,2,damage*.1f);MeleeKnockback(e,set==hitOut?dir:-dir,false);}}
     flame-=Time.deltaTime;if(flame<=0){flame=.035f;RevFx.FlameCard(pivot.position,.6f,.3f,Vector3.zero,0,1.8f,"body");}
    }
    yield return null;
   }
   RestoreThrownBlade();Sound(Voice("vesper_blade_catch","vesper_hit_flesh"));attackCd=.05f;
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
