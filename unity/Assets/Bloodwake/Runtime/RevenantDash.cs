using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  public const float RevenantDashDistance=3.2f,RevenantDashDuration=.24f,RevenantDashCooldown=.85f;
  public const float RevenantThrustWindow=.42f;
  float thrustDuration,thrustContact;
  float revenantDashAge,revenantThrustAge,thrustWindow,dashWakeDistance,dashTravelled;
  bool revenantDashing,revenantThrusting,thrustContactDone,thrustQueued,practiceDashImpact;
  Vector3 revenantDashDirection,thrustDirection;
  public bool RevenantActionActive=>revenantDashing||revenantThrusting;
  public bool RevenantDashActive=>revenantDashing;
  public bool DashImpactUnlocked=>Run?.ClassId=="revenant"&&(Run.Stats.N("revenantDashImpact")>0||(combatPractice&&practiceDashImpact));
  void ResetRevenantDash()
  {
   revenantDashing=revenantThrusting=thrustQueued=thrustContactDone=false;
   thrustWindow=revenantDashAge=revenantThrustAge=dashWakeDistance=dashTravelled=0;
   if(Player)Player.EndRevenantPose();
   if(revenantFx)revenantFx.CancelDashMist();
  }
  bool TryRevenantDash(Vector3 direction)
  {
   if((Run?.ClassId!="revenant"&&Run?.ClassId!="vesper")||Screen!="playing"||Run.Stats.N("hp")<=0||RevenantActionActive||dashCd>0||Player.IsCasting||Player.ContactPending)return false;
   direction.y=0;if(direction.sqrMagnitude<.001f)direction=Player.transform.forward;
   revenantDashDirection=direction.normalized;revenantDashAge=dashWakeDistance=dashTravelled=thrustWindow=0;thrustQueued=false;
   revenantDashing=true;dashCd=combatPractice?0:RevenantDashCooldown;attackCd=0;
   Player.transform.rotation=Quaternion.LookRotation(revenantDashDirection);Player.BeginRevenantDashPose(RevenantDashDuration);
   bool fire=Run.ClassId=="vesper";if(fire)Sound("vesper_dash");RevFx.DashCloud(Player,revenantDashDirection,fire);RevFx.DashWake(Player.transform.position,revenantDashDirection,fire);return true;
  }
  // Game-clock state machine: pause and hit-stop freeze movement, pose and combo window together.
  void TickRevenantDash(float dt)
  {
   // Vesper shares the dash; only Revenant has the thrust follow-up and landing talent.
   if(Run?.ClassId!="revenant"&&Run?.ClassId!="vesper")return;
   if(Run.Stats.N("hp")<=0){ResetRevenantDash();return;}
   if(Screen!="playing"||hitStop>0||dt<=0)return;
   if(revenantDashing)
   {
    float previous=revenantDashAge;revenantDashAge=Mathf.Min(RevenantDashDuration,revenantDashAge+dt);
    if(RevenantDashDuration-revenantDashAge<.00001f)revenantDashAge=RevenantDashDuration;
    float a=previous/RevenantDashDuration,b=revenantDashAge/RevenantDashDuration;
    float travel=RevenantDashDistance*((1-(1-b)*(1-b))-(1-(1-a)*(1-a)));
    var from=Player.transform.position;Player.transform.position=Move(from,revenantDashDirection*travel);
    float actual=Vector3.Distance(from,Player.transform.position);dashTravelled+=actual;dashWakeDistance+=actual;
    for(float d=.45f;dashWakeDistance>=d;dashWakeDistance-=d)RevFx.DashWake(Player.transform.position-revenantDashDirection*(dashWakeDistance-d),revenantDashDirection,Run.ClassId=="vesper");
    Player.RevenantPosePhase=b;
    bool blocked=travel>.001f&&Vector3.Dot(Player.transform.position-from,revenantDashDirection)<travel*.35f;
    if(revenantDashAge>=RevenantDashDuration||blocked)
    {
     revenantDashing=false;Player.EndRevenantPose();thrustWindow=Player.HasRevenantThrust?RevenantThrustWindow:0;
     if(DashImpactUnlocked&&dashTravelled>.1f)DashLandingImpact();
     if(thrustQueued){thrustQueued=false;if(!BeginRevenantThrust())Attack();}
    }
   }
   else if(revenantThrusting)
   {
    // Keep the authored approach speed, but never play its post-contact recovery.
    revenantThrustAge=Mathf.Min(thrustContact+.07f,revenantThrustAge+dt);Player.RevenantPosePhase=Mathf.Min(revenantThrustAge,thrustContact)/thrustDuration;
    if(!thrustContactDone&&revenantThrustAge>=thrustContact)
    {
     Player.ApplyRevenantPose();thrustContactDone=true;RevenantThrustHit();
    }
    // Briefly show the fully extended contact silhouette; no recovery frames.
    if(revenantThrustAge>=thrustContact+.07f-.00001f){revenantThrusting=false;attackCd=0;Player.EndRevenantPose();}
   }
   else thrustWindow=Mathf.Max(0,thrustWindow-dt);
  }
  float RevenantBasicDamage()
  {
   var weapon=Run.Weapons.FirstOrDefault(w=>GameData.Row("weapons",w.Key).S("behavior")=="melee");
   return weapon.Value==null?0:GameData.Row("weapons",weapon.Key).N("damage")*Run.Stats.N("damage")*weapon.Value.N("damage");
  }
  bool BeginRevenantThrust()
  {
   if(Run?.ClassId!="revenant"||!Player.HasRevenantThrust||thrustWindow<=0||revenantDashing||revenantThrusting||Run.Stats.N("hp")<=0)return false;
   thrustWindow=0;thrustQueued=false;revenantThrusting=true;revenantThrustAge=0;thrustContactDone=false;
   thrustDuration=Player.ClipLength("REV_ClawThrust");thrustContact=Player.MarkerTime("REV_ClawThrust","DAMAGE");
   thrustDirection=Player.transform.forward;attackCd=thrustContact+.07f;combo=0;
   Player.BeginRevenantThrustPose(thrustDuration);Sound("revenant_swing");return true;
  }
  void DashLandingImpact()
  {
   var origin=Player.transform.position;const float radius=1.25f;
   DamageCargo(origin,radius,revenantDashDirection);
   foreach(var e in Enemies.ToArray())if(!e.Emerging&&e.Hp>0&&Vector3.Distance(e.View.transform.position,origin)<=radius+.4f)DamageEnemy(e,RevenantBasicDamage()*.65f);
   RevFx.DashLanding(origin);
  }
  void RevenantThrustHit()
  {
   var start=Player.transform.position;float reach=1.7f*Run.Stats.N("attackRange");
   if(Run.Weapons.TryGetValue("sword",out var sword))reach*=sword.N("range",1);
   var end=start+thrustDirection*reach;DamageCargoSegment(start,end,.3f);
   foreach(var e in Enemies.ToArray())
   {
    if(e.Emerging||e.Hp<=0)continue;var offset=e.View.transform.position-start;offset.y=0;
    float along=Vector3.Dot(offset,thrustDirection);
    if(along<0||along>reach+.45f||SegmentDistance(e.View.transform.position,start,end)>.7f)continue;
    DamageEnemy(e,RevenantBasicDamage());
    if(e.Hp>0)
    {
     // Double the previous thrust push (now 4x basic); damage is unchanged.
     e.RecoilDirection=thrustDirection;e.RecoilRemaining=BasicRecoilDistance(e)*4;e.RecoilTime=.36f;
     e.View.ImpactPose(start,e.Id=="boss"?3:e.Id=="tank"?6:11,.36f);
     ShakeCamera(.55f,thrustDirection);
    }
    RevFx.Splatter(e.View.transform.position+Vector3.up*.9f,thrustDirection);
    RevFx.ThrustClawImpact(e.View);
   }
   RevFx.ThrustStrike(start+Vector3.up*(Player.Height*.62f),thrustDirection,reach);
  }
 }
}
