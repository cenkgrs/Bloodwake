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
  bool revenantDashing,revenantThrusting,thrustContactDone,thrustQueued,practiceDashImpact,thrustRecovering;float thrustRecoveryAge;
  const float ThrustRecoveryTime=.22f;
  Vector3 revenantDashDirection,thrustDirection;
  public bool RevenantActionActive=>revenantDashing||revenantThrusting;
  public bool RevenantDashActive=>revenantDashing;
  public bool DashImpactUnlocked=>Run?.ClassId=="revenant"&&(Run.Stats.N("revenantDashImpact")>0||(combatPractice&&practiceDashImpact));
  void ResetRevenantDash()
  {
   revenantDashing=revenantThrusting=thrustQueued=thrustContactDone=false;
   thrustWindow=revenantDashAge=revenantThrustAge=dashWakeDistance=dashTravelled=0;thrustRecovering=false;
   if(Player)Player.EndRevenantPose();
   if(revenantFx)revenantFx.CancelDashMist();
  }
  bool TryRevenantDash(Vector3 direction)
  {
   // Second Step: Vesper may dash again during, or just after, the first.
   CancelThrustRecovery();
   bool chain=(Run?.ClassId=="vesper"||Run?.ClassId=="revenant")&&Time.time<secondDashUntil&&!revenantThrusting;
   if((Run?.ClassId!="revenant"&&Run?.ClassId!="vesper")||Rooted||Screen!="playing"||Run.Stats.N("hp")<=0||vesperMoveActive||bladeThrown||Player.IsCasting||Player.ContactPending)return false;
   if(!chain&&(RevenantActionActive||dashCd>0))return false;
   if(chain){secondDashUntil=0;if(revenantDashing)Player.EndRevenantPose();}
   else if(Run.ClassId=="vesper"&&Owns("vesper_double_dash")||Run.ClassId=="revenant"&&Owns("revenant_mist_chain"))secondDashUntil=Time.time+RevenantDashDuration+.45f;
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
    // With R1 queued the dash is an attack: it pulls up in front of the first body on its line instead of
    // ending inside it. Without one it stays an escape and passes through.
    bool stopShort=false;if(thrustQueued&&travel>0){float allowed=LungeDistance(revenantDashDirection,travel);if(allowed<travel-.001f){travel=allowed;stopShort=true;}}
    var from=Player.transform.position;Player.transform.position=Move(from,revenantDashDirection*travel);
    float actual=Vector3.Distance(from,Player.transform.position);dashTravelled+=actual;dashWakeDistance+=actual;
    for(float d=.45f;dashWakeDistance>=d;dashWakeDistance-=d){var wake=Player.transform.position-revenantDashDirection*(dashWakeDistance-d);RevFx.DashWake(wake,revenantDashDirection,Run.ClassId=="vesper");if(Run.ClassId=="vesper")AddFireZone(wake,.45f,1.5f,RevenantBasicDamage()*.1f);}
    Player.RevenantPosePhase=b;
    bool blocked=travel>.001f&&Vector3.Dot(Player.transform.position-from,revenantDashDirection)<travel*.35f;
    if(revenantDashAge>=RevenantDashDuration||blocked||stopShort)
    {
     revenantDashing=false;Player.EndRevenantPose();thrustWindow=Player.HasRevenantThrust||Run.ClassId=="vesper"?RevenantThrustWindow:0;
     if(DashImpactUnlocked&&dashTravelled>.1f)DashLandingImpact();
     if(thrustQueued){thrustQueued=false;if(!BeginRevenantThrust()&&!BeginVesperRisingSlash())Attack();}
    }
   }
   else if(revenantThrusting)
   {
    // Keep the authored approach speed, but never play its post-contact recovery.
    revenantThrustAge=Mathf.Min(thrustContact+.07f,revenantThrustAge+dt);Player.RevenantPosePhase=Mathf.Min(revenantThrustAge,thrustContact)/thrustDuration;
    if(!thrustContactDone&&revenantThrustAge>=thrustContact)
    {
     Player.ApplyRevenantPose();thrustContactDone=true;RevenantThrustHit();if(Owns("revenant_mist_chain"))secondDashUntil=Time.time+.5f;
    }
    // Hold the extended contact silhouette briefly, then run the rest of the clip quickly back to stance;
    // attacking, dashing or moving cuts that recovery short.
    if(revenantThrustAge>=thrustContact+.07f-.00001f){revenantThrusting=false;attackCd=0;thrustRecovering=true;thrustRecoveryAge=0;}
   }
   else if(thrustRecovering)
   {
    thrustRecoveryAge+=dt;float from=(thrustContact+.07f)/thrustDuration;
    Player.RevenantPosePhase=Mathf.Lerp(from,1,Mathf.SmoothStep(0,1,thrustRecoveryAge/ThrustRecoveryTime));
    if(thrustRecoveryAge>=ThrustRecoveryTime||moveIntent.sqrMagnitude>.01f)CancelThrustRecovery();
   }
   else thrustWindow=Mathf.Max(0,thrustWindow-dt);
  }
  void CancelThrustRecovery(){if(!thrustRecovering)return;thrustRecovering=false;Player.EndRevenantPose();}
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
   var aimAt=!usingPad?aim:moveIntent.sqrMagnitude>.01f?moveIntent:revenantDashDirection.sqrMagnitude>.01f?revenantDashDirection:Player.transform.forward;aimAt.y=0;
   if(aimAt.sqrMagnitude>.001f)Player.transform.rotation=Quaternion.LookRotation(aimAt.normalized);PadFacing();
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
