using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The Mage's moveset.
 //  R1 chain: right-hand orb, backhand orb from the left, then ice shards ripping along a 30-degree wedge.
 //  R2: a 90-degree ring of force. R1 R1 R2: an ice comet called down on the nearest foe ahead.
 //  L1 + R1: seize a foe, drag it in and hurl it where the stick points; it hurts whatever it hits.
 //  Square: glide a short way through the air.
 public sealed partial class BloodwakeGame
 {
  float MageBasicDamage()
  {
   foreach(var entry in Run.Weapons){var row=GameData.Row("weapons",entry.Key);if(row.S("behavior")!="melee")return row.N("damage")*Run.Stats.N("damage")*entry.Value.N("damage");}
   return 20*Run.Stats.N("damage");
  }
  float MageSpeed=>Mathf.Clamp(Run.Stats.N("attackSpeed"),.8f,1.8f);
  Transform mageLeftHand;
  Vector3 MageLeftPalm(){if(!mageLeftHand)mageLeftHand=Player.Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("LeftHand"));return mageLeftHand?mageLeftHand.position:Player.transform.position+Vector3.up*1.2f;}

  void MageLight()
  {
   if(Time.time>comboExpires)combo=0;combo=combo%3+1;var dir=Player.transform.forward;dir.y=0;dir.Normalize();float damage=MageBasicDamage(),rate=MageSpeed;
   if(combo==1)
   {
    float hold=.42f/rate;Player.Play("Attack",hold);Sound("orb_cast");
    StartCoroutine(DelayedCall(hold*.45f,()=>StartCoroutine(MageBolt(Player.MagicPalmPosition(),Player.transform.forward,damage,22,10,1,3,false))));
    attackCd=.3f/rate;comboExpires=Time.time+hold+.6f;
   }
   else if(combo==2)
   {
    // The back of the left hand flings a heavier orb.
    float hold=.46f/rate;Player.PlayWindow("Mage_Backhand",.45f,1.15f,hold);Sound("orb_cast");
    StartCoroutine(DelayedCall(hold*.53f,()=>StartCoroutine(MageBolt(MageLeftPalm(),Player.transform.forward,damage*1.2f,26,10,1.35f,3,false))));
    attackCd=.34f/rate;comboExpires=Time.time+hold+.6f;
   }
   else
   {
    float hold=.6f/rate;Player.PlayWindow("Mage_GroundCast",.65f,1.6f,hold);
    StartCoroutine(DelayedCall(hold*.62f,()=>StartCoroutine(IceShards(Player.transform.position,Player.transform.forward,damage*1.5f))));
    attackCd=.55f/rate;comboExpires=Time.time+hold+.3f;
   }
  }
  void MageHeavy()
  {
   bool afterTwo=combo==2&&Time.time<=comboExpires;combo=0;float damage=MageBasicDamage();
   if(afterTwo){StartCoroutine(IceComet(damage*3.2f));return;}
   float hold=.55f/MageSpeed;Player.Play("Ultimate",hold);Sound(Voice("mage_force_ring","skill_meteor_blast"));
   StartCoroutine(DelayedCall(hold*.45f,()=>StartCoroutine(ForceArc(Player.transform.position,Player.transform.forward,damage*1.6f))));
   attackCd=.6f/MageSpeed;
  }

  // A bolt of the Mage's own: speed, size and pierce per move; damages each body it passes once.
  IEnumerator MageBolt(Vector3 origin,Vector3 dir,float damage,float speed,float range,float size,int pierce,bool finisher)
  {
   dir.y=0;dir.Normalize();var orb=RevFx.Orb(origin,false,true);orb.transform.localScale*=size;orb.transform.rotation=Quaternion.LookRotation(dir);
   RevFx.Muzzle(origin,dir,true,null);var hit=new HashSet<Enemy>();float travelled=0,trail=0;
   while(orb&&travelled<range)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float step=Mathf.Min(range-travelled,speed*Time.deltaTime);var previous=orb.transform.position;var next=previous+dir*step;
    // Walls stop it.
    var flat=new Vector3(next.x,0,next.z);if(Vector3.Distance(Move(new Vector3(previous.x,0,previous.z),dir*step,.1f),flat)>.15f){RevFx.ProjectileImpact(next,true,false,dir);break;}
    orb.transform.position=next;travelled+=step;DamageCargoSegment(previous,next,.4f);
    if((trail-=Time.deltaTime)<=0){trail=.03f;RevFx.ProjectileTrail(next,true,false);}
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e)||ProjectileBodyDistance(e.View,previous,next)>e.Data.N("radius",16)*.02f+.45f*size)continue;
     hit.Add(e);RevFx.ProjectileImpact(e.View.transform.position+Vector3.up,true,false,dir);DamageEnemy(e,damage);MeleeKnockback(e,dir,size>1.2f);
     if(hit.Count>pierce){travelled=range;break;}
    }
    yield return null;
   }
   if(orb)Destroy(orb.gameObject);
  }

  // Shards of ice tear up out of the ground in rows racing along a 30-degree wedge.
  IEnumerator IceShards(Vector3 origin,Vector3 dir,float damage)
  {
   dir.y=0;dir.Normalize();origin.y=0;const float length=6.6f,halfAngle=15,rowStep=.5f;var hit=new HashSet<Enemy>();var side=Vector3.Cross(Vector3.up,dir);
   Sound(Voice("mage_ice_shards","skill_meteor_blast"));ShakeCamera(.25f,dir);
   for(float d=.8f;d<=length;d+=rowStep)
   {
    while(Screen!="playing"||hitStop>0)yield return null;
    float half=Mathf.Tan(halfAngle*Mathf.Deg2Rad)*d;int count=1+Mathf.FloorToInt(half/.45f);
    for(int i=0;i<count;i++)
    {
     float across=count==1?0:Mathf.Lerp(-half,half,i/(count-1f))+Random.Range(-.12f,.12f);var at=origin+dir*(d+Random.Range(-.15f,.15f))+side*across;
     if(Vector3.Distance(Move(origin,at-origin,.1f),at)>.3f)continue;
     RevFx.IceSpike(at,dir,Random.Range(.8f,1.5f)*Mathf.Lerp(.85f,1.25f,d/length));
    }
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e))continue;var rel=e.View.transform.position-origin;rel.y=0;float along=Vector3.Dot(rel,dir);
     if(along<d-rowStep-.3f||along>d+.4f||Vector3.Angle(dir,rel)>halfAngle+10)continue;
     hit.Add(e);DamageEnemy(e,damage);e.Slow=Mathf.Max(e.Slow,1.6f);e.SlowAmount=Mathf.Max(e.SlowAmount,.45f);if(e.Id!="boss")e.View.ImpactPose(origin,16,.35f);
    }
    DamageCargoSegment(origin+dir*(d-rowStep),origin+dir*d,half);
    yield return Delay(.03f);
   }
  }

  // A 90-degree band of force rolls outward and throws back everything it meets.
  IEnumerator ForceArc(Vector3 origin,Vector3 dir,float damage)
  {
   dir.y=0;dir.Normalize();origin.y=0;const float reach=5.6f,time=.34f,halfAngle=45;var hit=new HashSet<Enemy>();
   var wave=RevFx.ForceArc(origin,dir,halfAngle,time,reach);ShakeCamera(.35f,dir);float age=0;
   while(age<time)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    age+=Time.deltaTime;float radius=Mathf.Lerp(.6f,reach,1-(1-age/time)*(1-age/time));
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e))continue;var rel=e.View.transform.position-origin;rel.y=0;
     if(rel.magnitude>radius+.5f||Vector3.Angle(dir,rel)>halfAngle+8)continue;
     hit.Add(e);DamageEnemy(e,damage);StartAreaRecoil(e,origin,2.2f);e.Slow=Mathf.Max(e.Slow,1.2f);e.SlowAmount=Mathf.Max(e.SlowAmount,.3f);
    }
    yield return null;
   }
  }

  // R1 R1 R2: a boulder of ice drops out of the night onto the nearest foe ahead.
  IEnumerator IceComet(float damage)
  {
   var dir=Player.transform.forward;dir.y=0;dir.Normalize();var origin=Player.transform.position;
   var foe=Enemies.Where(e=>!e.Emerging&&e.Hp>0&&e.View).Select(e=>(e,rel:Vector3.ProjectOnPlane(e.View.transform.position-origin,Vector3.up))).Where(x=>x.rel.magnitude<9.5f&&Vector3.Angle(dir,x.rel)<40).OrderBy(x=>x.rel.magnitude).Select(x=>x.e).FirstOrDefault();
   var target=foe!=null?foe.View.transform.position:Move(origin,dir*5);target.y=0;
   float hold=.75f/MageSpeed;Player.Play("Ultimate",hold);attackCd=.8f/MageSpeed;vesperMoveActive=true;
   const float fall=.5f;RevFx.IceComet(target,fall+.18f);Sound(Voice("mage_ice_comet","skill_meteor_blast"));
   yield return Delay(.18f+fall);vesperMoveActive=false;
   if(Screen!="playing")yield break;
   const float radius=2.7f;
   foreach(var e in Enemies.ToArray())
   {
    if(e.Emerging||e.Hp<=0)continue;var rel=e.View.transform.position-target;rel.y=0;if(rel.magnitude>radius+.4f)continue;
    DamageEnemy(e,damage);StartAreaRecoil(e,target,1.6f);e.Slow=Mathf.Max(e.Slow,2.2f);e.SlowAmount=Mathf.Max(e.SlowAmount,.75f);
   }
   DamageCargo(target,radius,dir);RevFx.ArcaneBlast(target,radius,true);ShakeCamera(.8f,dir);hitStop=Mathf.Max(hitStop,.12f);Rumble(.8f,1,.25f);Sound("skill_meteor_blast");
  }

  // ---- L1 + R1: seize, drag in, hurl.
  void MageGrip()
  {
   if(vesperMoveActive||attackCd>0||Player.Locked>.15f)return;PadFacing();var dir=Player.transform.forward;dir.y=0;dir.Normalize();var origin=Player.transform.position;
   var foe=Enemies.Where(e=>!e.Emerging&&e.Hp>0&&e.View&&e.Id!="boss").Select(e=>(e,rel:Vector3.ProjectOnPlane(e.View.transform.position-origin,Vector3.up))).Where(x=>x.rel.magnitude<9&&Vector3.Angle(dir,x.rel)<38).OrderBy(x=>x.rel.magnitude*(1+Vector3.Angle(dir,x.rel)/40)).Select(x=>x.e).FirstOrDefault();
   Player.PlayWindow("Mage_Backhand",.45f,.9f,.28f);attackCd=.45f;
   if(foe==null){RevFx.Glow(MageLeftPalm(),RevenantVfx.Arcane,.4f,1.6f,.18f);Sound("ui_error");return;}
   StartCoroutine(GripAndThrow(foe));
  }
  IEnumerator GripAndThrow(Enemy foe)
  {
   vesperMoveActive=true;float damage=MageBasicDamage();Sound(Voice("mage_grip","orb_cast"));
   var tether=RevFx.Tether(()=>MageLeftPalm(),()=>foe.View?foe.View.transform.position+Vector3.up*foe.View.Height*.55f:MageLeftPalm());
   // Drag: in to just in front of her, lifted off its feet.
   var from=foe.View.transform.position;float age=0;const float pull=.32f;
   while(age<pull)
   {
    if(!foe.View||foe.Hp<=0)break;if(Screen!="playing"||hitStop>0){yield return null;continue;}
    age+=Time.deltaTime;float t=Mathf.SmoothStep(0,1,age/pull);var hold=Player.transform.position+Player.transform.forward*1.5f;
    var ground=Vector3.Lerp(from,hold,t);ground=MoveEnemy(foe,ground-foe.View.transform.position);foe.View.transform.position=new Vector3(ground.x,Mathf.Sin(t*Mathf.PI*.5f)*.55f,ground.z);
    foe.Stagger=Mathf.Max(foe.Stagger,1);foe.Cooldown=Mathf.Max(foe.Cooldown,1);HoldEnemyAgent(foe);yield return null;
   }
   if(foe.View&&foe.Hp>0){DamageEnemy(foe,damage*1.1f);foe.View.Shake?.Hit(Player.transform.forward,1.2f);}
   // A beat to aim, then the throw goes where the stick (or mouse) points now.
   yield return Delay(.08f);
   var aimAt=!usingPad?aim:moveIntent.sqrMagnitude>.01f?moveIntent:Player.transform.forward;aimAt.y=0;if(aimAt.sqrMagnitude<.001f)aimAt=Player.transform.forward;aimAt.Normalize();
   Player.transform.rotation=Quaternion.LookRotation(aimAt);Player.Play("Attack",.34f);Sound("orb_cast");
   if(tether)tether.Release();
   var struck=new HashSet<Enemy>{foe};age=0;const float flight=.42f,distance=7.5f;bool smashed=false;
   while(age<flight&&foe.View&&foe.Hp>0)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float dt=Time.deltaTime;age+=dt;var before=foe.View.transform.position;before.y=0;var wanted=before+aimAt*(distance/flight)*dt;var moved=MoveEnemy(foe,wanted-before);moved.y=0;
    foe.View.transform.position=new Vector3(moved.x,.55f*(1-age/flight)+Mathf.Sin(age/flight*Mathf.PI)*.4f,moved.z);foe.Stagger=Mathf.Max(foe.Stagger,.6f);HoldEnemyAgent(foe);
    if(Random.value<.6f)RevFx.ProjectileTrail(foe.View.transform.position+Vector3.up,true,false);
    // Bowling through the crowd.
    foreach(var e in Enemies.ToArray())
    {
     if(struck.Contains(e)||e.Emerging||e.Hp<=0||!e.View)continue;var rel=e.View.transform.position-moved;rel.y=0;if(rel.magnitude>1.15f)continue;
     struck.Add(e);DamageEnemy(e,damage*1.4f);MeleeKnockback(e,aimAt,true);RevFx.ArcaneBlast(e.View.transform.position,.8f,false);ShakeCamera(.4f,aimAt);
    }
    // A wall ends the flight hard.
    if(Vector3.Distance(moved,wanted)>.2f){smashed=true;break;}
    yield return null;
   }
   if(foe.View){var p=foe.View.transform.position;p.y=0;foe.View.transform.position=p;if(foe.Hp>0){DamageEnemy(foe,damage*(smashed?1.8f:1.2f));RevFx.ArcaneBlast(p,smashed?1.4f:1f,false);ShakeCamera(smashed?.6f:.35f,aimAt);}}
   vesperMoveActive=false;
  }

  // ---- Square: a short glide through the air.
  bool TryMageGlide(Vector3 direction)
  {
   if(Run?.ClassId!="mage"||Screen!="playing"||dashCd>0||vesperMoveActive||Player.Locked>.15f||Run.Stats.N("hp")<=0)return false;
   direction.y=0;if(direction.sqrMagnitude<.001f)direction=Player.transform.forward;StartCoroutine(MageGlide(direction.normalized));return true;
  }
  IEnumerator MageGlide(Vector3 dir)
  {
   vesperMoveActive=true;dashCd=combatPractice?0:RevenantDashCooldown;invulnerable=Mathf.Max(invulnerable,.38f);
   const float time=.36f,distance=4.6f;var start=Player.transform.position;var end=Move(start,dir*distance);
   Player.transform.rotation=Quaternion.LookRotation(dir);Player.Play("Idle",0);RevFx.ArcaneFlight(start,end,time,false);RevFx.Glow(start+Vector3.up*.8f,RevenantVfx.Arcane,.9f,2,.2f);Sound(Voice("mage_glide","orb_cast"));
   float age=0,done=0;
   while(age<time)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    age=Mathf.Min(time,age+Time.deltaTime);float t=age/time,want=distance*Mathf.SmoothStep(0,1,t);
    var ground=Move(new Vector3(Player.transform.position.x,0,Player.transform.position.z),dir*(want-done));done=want;
    // Lifted off the ground, leaning into the glide.
    Player.transform.position=new Vector3(ground.x,Mathf.Sin(t*Mathf.PI)*.5f,ground.z);Player.transform.rotation=Quaternion.LookRotation(dir)*Quaternion.Euler(14*Mathf.Sin(t*Mathf.PI),0,0);
    yield return null;
   }
   var p=Player.transform.position;p.y=0;Player.transform.position=p;Player.transform.rotation=Quaternion.LookRotation(dir);RevFx.Glow(p+Vector3.up*.6f,RevenantVfx.Arcane,.7f,1.6f,.16f);vesperMoveActive=false;
  }
 }
}
