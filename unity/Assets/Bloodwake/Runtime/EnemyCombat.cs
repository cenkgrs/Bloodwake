using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  IEnumerator Projectile(Vector3 start,Vector3 direction,float damage,float speed,float range,bool hostile,int pierce=0,bool hostileMagic=false,string hand="R",bool finisher=false)
  {
   bool magic=hostile?hostileMagic:Run.ClassId=="mage";var origin=!hostile&&magic?Player.MagicPalmPosition():start+Vector3.up;
   var go=RevFx.ProjectileVisual(origin,direction,magic,hostile);float traveled=0,trail=0;var hit=new HashSet<Enemy>();
   if(!hostile)RevFx.Muzzle(origin,direction,magic,null);
   while(traveled<range&&go){if(Screen!="playing"||hitStop>0){yield return null;continue;}float step=Mathf.Min(range-traveled,Mathf.Max(1,speed)*Time.deltaTime);var previous=go.transform.position;go.transform.position+=direction*step;traveled+=step;trail-=Time.deltaTime;if(trail<=0&&(magic||hostile)){RevFx.ProjectileTrail(go.transform.position,magic,hostile);trail=magic?.035f:.02f;}
    if(!hostile)DamageCargoSegment(previous,go.transform.position,magic?.4f:.15f);
    if(hostile){if(SegmentDistance(Player.transform.position+Vector3.up,previous,go.transform.position)<.55f){RevFx.ProjectileImpact(go.transform.position,magic,true,direction);HurtPlayer(damage);break;}}
    else foreach(var e in Enemies.OrderBy(e=>Vector3.Distance(previous,e.View.transform.position+Vector3.up)).ToArray()){if(e.Emerging||hit.Contains(e)||ProjectileBodyDistance(e.View,previous,go.transform.position)>e.Data.N("radius",16)*.02f+(magic?.5f:.16f))continue;hit.Add(e);RevFx.ProjectileImpact(e.View.transform.position+Vector3.up,magic,false,direction);DamageEnemy(e,damage);if(finisher)hitStop=Mathf.Max(hitStop,FinisherHitStop);if(e.Hp>0&&Run.Weapons.TryGetValue("magic_orb",out var orb)&&Run.ClassId=="mage"&&orb.N("burn")>0){e.Burn=3;e.BurnDps=orb.N("burn");}if(hit.Count>pierce){traveled=range;break;}}
    yield return null;
   }if(go)Destroy(go);
  }
  static float SegmentDistance(Vector3 point,Vector3 start,Vector3 end){var delta=end-start;return Vector3.Distance(point,start+delta*Mathf.Clamp01(Vector3.Dot(point-start,delta)/Mathf.Max(.000001f,delta.sqrMagnitude)));}
  // Closest points between the swept projectile and the standing body's axis.
  // Hand/muzzle-origin shots must not pass above the old fixed-height sphere.
  static float ProjectileBodyDistance(ActorView actor,Vector3 from,Vector3 to)
  {
   var bottom=actor.transform.position+Vector3.up*.3f;var top=actor.transform.position+Vector3.up*Mathf.Max(.31f,actor.Height-.25f);
   var d1=to-from;var d2=top-bottom;var r=from-bottom;float a=Vector3.Dot(d1,d1),e=Vector3.Dot(d2,d2),f=Vector3.Dot(d2,r),s,t;
   if(a<.000001f)return SegmentDistance(from,bottom,top);
   float b=Vector3.Dot(d1,d2),c=Vector3.Dot(d1,r),denom=a*e-b*b;
   s=denom>.000001f?Mathf.Clamp01((b*f-c*e)/denom):0;t=(b*s+f)/e;
   if(t<0){t=0;s=Mathf.Clamp01(-c/a);}else if(t>1){t=1;s=Mathf.Clamp01((b-c)/a);}
   return Vector3.Distance(from+d1*s,bottom+d2*t);
  }
  void TickEnemies(float dt)
  {
   TickFireZones(dt);
   foreach(var e in Enemies.ToArray())
   {
    if(e.Emerging)
    {
     HoldEnemyAgent(e);e.View.TickEmergence(dt);
     if(!e.Emerging)e.Cooldown=.35f;
     continue;
    }
    if(e.Training)
    {
     HoldEnemyAgent(e);
     if(e.RecoilTime>0)TickRecoil(e,dt);
     else if(Vector3.Distance(e.View.transform.position,e.TrainingHome)>6)e.View.transform.position=e.TrainingHome;
     e.View.Tick(dt,false);continue;
    }
    if(e.Burn>0){DamageEnemy(e,e.BurnDps*Mathf.Min(dt,e.Burn),false);e.Burn-=dt;}if(e.Hp<=0)continue;
    if(e.Bleed>0){DamageEnemy(e,e.BleedDps*Mathf.Min(dt,e.Bleed),false);e.Bleed-=dt;}if(e.Hp<=0)continue;
    TickBurnVisual(e,dt);e.PanicCooldown-=dt;
    if(e.Panic>0&&e.RecoilTime<=0){TickPanic(e,dt);continue;}
    // Burning enemies come on slower and take longer to ready an attack.
    e.Cooldown-=dt*(e.Burn>0?.6f:1);e.AreaRecovery=Mathf.Max(0,e.AreaRecovery-dt);e.Stagger-=dt;e.Slow-=dt;e.Mark-=dt;e.Aura-=dt;e.RuneCooldown-=dt;var delta=Player.transform.position-e.View.transform.position;float distance=delta.magnitude;var dir=delta.normalized;
    if(e.Turning)
    {
     if(e.RecoilTime>0||e.Stagger>0||e.Casting)e.Turning=false;
     else{HoldEnemyAgent(e);TickWarriorTurn(e,dt);continue;}
    }
    if(e.RecoilTime>0){e.StepPending=false;e.StepTime=0;HoldEnemyAgent(e);TickRecoil(e,dt);e.View.Tick(dt,false);continue;}
    if(e.Casting){HoldEnemyAgent(e);e.View.Tick(dt,false);continue;}
    if(e.Stagger>0||e.View.Locked>0){if(e.Id=="grunt")e.Intent=e.View.ContactPending?WarriorIntent.Attack:WarriorIntent.Recover;HoldEnemyAgent(e);e.View.Tick(dt,false);continue;}
    if(e.Id=="assassin"&&distance<3.2f&&e.Cooldown<=0){StartCoroutine(AssassinStrike(e));continue;}
    float speed=e.Data.N("moveSpeed")*.02f*(e.Id=="boss"?2.5f:1)*(e.Slow>0?1-e.SlowAmount:1)*(e.Aura>0?1.22f:1)*(e.Burn>0?.6f:1);bool ranged=e.Id=="archer"||e.Id=="mage"||e.Id=="warlock"||e.Id=="healer";float reach=ranged?7:1.25f;
    if(e.Id=="boss"){var pattern=BossPattern;string next=pattern[e.Pattern%pattern.Length];reach=next=="attack"||next=="sweep"||next=="slam"?GameData.Rules["boss"][next].N("radius")-.3f:12;}
    var before=e.View.transform.position;Vector3 wish=Vector3.zero;
    if(distance>reach)wish=ChaseDirection(before);else if(ranged&&distance<4)wish=-dir;
    var goal=Player.transform.position;
    bool crowdWarrior=e.Id=="grunt"&&Enemies.Count>1,positioning=false;
    if(crowdWarrior)positioning=WarriorEngagement(e,distance,dt,out goal,out wish);
    else if(ranged&&distance<4)goal=before-dir*2;
    // Single-actor steering stays deterministic; crowd avoidance matters with neighbours.
    if(Enemies.Count>1)wish=EnemyWish(e,wish,goal,speed,dt);else HoldEnemyAgent(e);
    if(crowdWarrior&&positioning)wish=UnstickCrowdWish(e,wish,goal);
    float travelSpeed=speed*Mathf.Clamp01(wish.magnitude);
    bool warriorSteering=e.Id=="grunt"&&e.View.TurnData!=null;
    var steering=wish.sqrMagnitude>.0025f?wish:dir;
    // Avoidance corrections are not requests to play a 180-degree body turn.
    bool deliberateTurn=!crowdWarrior||(!positioning||e.Intent!=WarriorIntent.Reposition&&Vector3.Angle(steering,goal-before)<45);
    if(e.Id=="grunt"&&deliberateTurn&&BeginWarriorTurn(e,steering)){HoldEnemyAgent(e);continue;}
    if(warriorSteering)e.View.transform.position=SteerWarrior(e,steering,wish,travelSpeed,dt);
    else if(wish.sqrMagnitude>.0001f)e.View.transform.position=MoveEnemy(e,wish.normalized*travelSpeed*dt);
    var moved=e.View.transform.position-before;moved.y=0;bool moving=moved.sqrMagnitude>.000001f;
    if(crowdWarrior)e.StuckTime=positioning&&moved.magnitude<dt*.08f?e.StuckTime+dt:0;
    // A forward run must face its actual displacement, including collision sliding.
    // Use a direction, not a per-frame distance: at >180 fps a grunt moves
    // less than 1 cm and the old squared-distance gate prevented ALL turning.
    var facing=moving?moved.normalized:dir;if(!warriorSteering&&facing.sqrMagnitude>.000001f)e.View.transform.rotation=Quaternion.LookRotation(facing);
    // Match steps to actual displacement, including slow/aura modifiers and wall sliding.
    float gaitSpeed=e.View.LocomotionSpeed>0?e.View.LocomotionSpeed:speed;
    float gaitRate=moved.magnitude/Mathf.Max(.0001f,dt*gaitSpeed);
    e.View.Tick(dt,moving,moving?(e.View.LocomotionSpeed>0?gaitRate:Mathf.Clamp(gaitRate,.5f,1.5f)):1);
    delta=Player.transform.position-e.View.transform.position;distance=delta.magnitude;dir=delta.normalized;
    if(e.Cooldown>0||distance>reach+.5f||(crowdWarrior&&e.Intent==WarriorIntent.Reposition))continue;
    if(warriorSteering&&Vector3.Angle(e.View.transform.forward,dir)>WarriorAttackFacingTolerance)continue;
    e.Cooldown=e.Data.N("attackCooldown",1.5f);
    if(e.Id=="boss"){StartCoroutine(BossCast(e));continue;}
    if(!warriorSteering)e.View.transform.rotation=Quaternion.LookRotation(dir.sqrMagnitude>.001f?dir:Vector3.forward);
    if(e.Id=="grunt"&&e.View.HasWarriorSlashes){WarriorMelee(e,warriorSteering?e.View.transform.forward:dir);continue;}
    e.View.Play("Attack",.6f);Sound(e.Id+"_attack");
    if(e.Id=="healer"||e.Id=="commander")StartCoroutine(SupportCast(e));
    else if(e.Id=="mage"){
     e.Pattern++;if(e.Pattern%2==0&&e.RuneCooldown<=0){e.RuneCooldown=e.Data.N("runeCooldown",6.5f);StartCoroutine(EnemyArea(e,Player.transform.position,e.Data.N("runeRadius",150)*.02f,e.Data.N("runeFuse",1.4f)));}
     else StartCoroutine(EnemyShot(e,dir));
    }
    else if(e.Id=="warlock")WarlockCast(e,dir,distance);
    else if(e.Id=="archer")StartCoroutine(EnemyShot(e,dir));
    else StartCoroutine(EnemyMelee(e,dir));
   }
  }
  void WarriorMelee(Enemy e,Vector3 dir)
  {
   // Advance only when an attack starts, never on a hit/miss or animation event.
   string clip=(e.Pattern&1)==0?"Warrior_OutwardSlash":"Warrior_InwardSlash";
   e.Pattern=(e.Pattern+1)&1;
   e.AttackCount++;e.Intent=WarriorIntent.Attack;Sound("grunt_attack");e.StepPending=Enemies.Count>1&&e.AttackCount%2==0;
   int impact=e.ImpactVersion;
   // Default hold uses the source length at 1x, instead of squeezing to 0.6 s.
   e.View.Play(clip);
   e.View.OnMarker("DAMAGE",()=>
   {
    if(Screen=="playing"&&e.Hp>0&&impact==e.ImpactVersion)Sound("warrior_sword_clash_user");
    if(Screen=="playing"&&e.Hp>0&&impact==e.ImpactVersion&&
       (Player.transform.position-e.View.transform.position).magnitude<1.8f&&
       Vector3.Angle(dir,Player.transform.position-e.View.transform.position)<70)
    {e.ContactCount++;HurtPlayer(e.Damage*(e.Aura>0?1.25f:1));}
   });
  }
  IEnumerator EnemyShot(Enemy e,Vector3 dir){int impact=e.ImpactVersion;e.Casting=true;yield return Delay(.3f);if(e.Hp>0&&impact==e.ImpactVersion)StartCoroutine(Projectile(e.View.transform.position,dir,e.Damage,e.Data.N("projectileSpeed",340)*.02f,12,true,0,e.Id=="mage"));yield return Delay(.3f);e.Casting=false;}
  IEnumerator EnemyMelee(Enemy e,Vector3 dir){int impact=e.ImpactVersion;yield return Delay(.3f);if(e.Hp>0&&impact==e.ImpactVersion&&(Player.transform.position-e.View.transform.position).magnitude<1.8f&&Vector3.Angle(dir,Player.transform.position-e.View.transform.position)<70)HurtPlayer(e.Damage*(e.Aura>0?1.25f:1));}
  IEnumerator SupportCast(Enemy e)
  {
   if(e.Id=="healer"){yield return HealerCast(e);yield break;}
   int impact=e.ImpactVersion;e.Casting=true;float reach=e.Data.N("supportRadius",250)*.02f;
   var target=Enemies.Where(a=>a!=e&&Vector3.Distance(a.View.transform.position,e.View.transform.position)<reach).OrderByDescending(a=>a.MaxHp-a.Hp).FirstOrDefault();
   yield return Delay(.4f);if(e.Hp>0&&impact==e.ImpactVersion){if(e.Id=="healer"&&target!=null&&target.Hp>0)target.Hp=Mathf.Min(target.MaxHp,target.Hp+e.Data.N("healAmount",20));else if(e.Id=="commander")foreach(var a in Enemies)if(a!=e&&a.Id!="boss"&&Vector3.Distance(a.View.transform.position,e.View.transform.position)<reach)a.Aura=e.Data.N("auraDuration",5);Effects.Ring(e.View.transform.position,reach,Color.green);}e.Casting=false;
  }
  IEnumerator AssassinStrike(Enemy e)
  {
   int impact=e.ImpactVersion;e.Casting=true;e.Cooldown=2;foreach(var r in e.View.GetComponentsInChildren<Renderer>())r.enabled=false;yield return Delay(.35f);
   if(e.Hp<=0)yield break;if(impact!=e.ImpactVersion){foreach(var r in e.View.GetComponentsInChildren<Renderer>())r.enabled=true;e.Casting=false;yield break;}var offset=Quaternion.Euler(0,Random.Range(0,360),0)*Vector3.forward*3.2f;e.View.transform.position=Move(Player.transform.position,offset);
   foreach(var r in e.View.GetComponentsInChildren<Renderer>())r.enabled=true;
   float age=0;while(age<.6f&&e.Hp>0&&impact==e.ImpactVersion){if(Screen=="playing"&&hitStop<=0){age+=Time.deltaTime;var dir=(Player.transform.position-e.View.transform.position).normalized;e.View.transform.position=Move(e.View.transform.position,dir*e.Data.N("moveSpeed")*.02f*4.5f*Time.deltaTime);if(Vector3.Distance(e.View.transform.position,Player.transform.position)<1){HurtPlayer(e.Damage);break;}}yield return null;}e.Casting=false;
  }
  IEnumerator EnemyArea(Enemy e,Vector3 pos,float radius,float delay){var tone=RevenantVfx.Tone("e04dc0");var sigil=RevFx.BindingSigil(pos,radius,delay,tone);yield return Delay(delay);if(sigil)Destroy(sigil.gameObject);if(e.Hp>0){RevFx.HostileRuneImpact(pos,radius);RevFx.ArcaneBlast(pos,radius,false);ShakeCamera(.3f,Vector3.zero);RevFx.Flash(pos,tone,2.6f,radius*2.2f,.2f);RevFx.Sparks(pos+Vector3.up*.3f,tone,18,.45f,2,5);RevFx.Glow(pos+Vector3.up*.6f,tone,radius*1.2f,2.4f,.18f);if(Vector3.Distance(Player.transform.position,pos)<radius)HurtPlayer(e.Damage*1.7f);}}
  IEnumerator BossCast(Enemy e)
  {
   int impact=e.ImpactVersion;e.Casting=true;Sound("boss_roar");string[] pattern=BossPattern;string attack=pattern[e.Pattern++%pattern.Length];var spec=GameData.Rules["boss"][attack];var origin=e.View.transform.position;var dir=(Player.transform.position-origin).normalized;float radius=spec.N("radius"),windup=spec.N("windup")*BossTempo,recovery=spec.N("recovery")*BossTempo*.6f;string clip=char.ToUpper(attack[0])+attack.Substring(1);float contact=spec.N("contact",.5f);e.View.Play(clip,windup/contact);var warning=BossWarning(origin,dir,radius,spec.N("arc",360),attack,windup);float preparation=0;while(preparation<windup&&e.Hp>0&&impact==e.ImpactVersion){if(Screen=="playing"&&hitStop<=0)preparation+=Time.deltaTime;yield return null;}if(warning)Destroy(warning);if(e.Hp<=0||impact!=e.ImpactVersion){e.Casting=false;yield break;}
   e.View.PlaybackRate=e.View.ClipLength(clip)*(1-contact)/(recovery+(attack=="charge"?.6f:0));e.View.Locked=recovery+(attack=="charge"?.6f:0);
   RevFx.BossContact(attack,origin,dir,radius,spec.N("arc",360));
   if(attack=="summon"){var kinds=BossSummons;int count=(int)BossVariant.N("summonCount",4);for(int i=0;i<count&&Enemies.Count<RolledAliveCap;i++){var spawn=Move(origin,Quaternion.Euler(0,i*360f/count,0)*Vector3.forward*4);SpawnEnemy(kinds[i%kinds.Length],spawn);}}
   else if(attack=="cast"){int bolts=(int)BossVariant.N("castCount",3);for(int k=0;k<bolts;k++){float i=k-(bolts-1)*.5f;StartCoroutine(Projectile(origin,Quaternion.Euler(0,i*.22f*Mathf.Rad2Deg,0)*dir,e.Damage*.7f,6.5f,14,true,0,true));}}
   else if(attack=="charge"){float age=0,wake=0;bool struck=false;while(age<.6f&&e.Hp>0&&impact==e.ImpactVersion){if(Screen!="playing"||hitStop>0){yield return null;continue;}float dt=Mathf.Min(Time.deltaTime,.6f-age);age+=dt;var previous=e.View.transform.position;var intended=previous+dir*(8/.6f)*dt;var actual=Move(previous,intended-previous,.65f);if(Vector3.Distance(actual,intended)>.15f)break;e.View.transform.position=actual;wake-=dt;if(wake<=0){RevFx.ChargeWake(previous,dir);wake=.08f;}if(!struck&&SegmentDistance(Player.transform.position,previous,actual)<1.36f){HurtPlayer(e.Damage*1.35f);struck=true;}yield return null;}}
   else if(Vector3.Distance(Player.transform.position,origin)<=radius+.36f&&Vector3.Angle(dir,Player.transform.position-origin)<=spec.N("arc",360)*.5f)HurtPlayer(e.Damage*spec.N("damage",1));
   yield return Delay(recovery);e.Casting=false;e.Cooldown=.08f;
  }
  GameObject BossWarning(Vector3 origin,Vector3 direction,float radius,float arc,string attack,float lifetime)
  {
   // No ground markings: the warden's wind-up is the only warning, so it has to be read from the body.
   return null;
  }
 }
}
