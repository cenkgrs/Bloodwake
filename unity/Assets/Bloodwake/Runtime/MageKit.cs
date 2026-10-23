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
    StartCoroutine(DelayedCall(hold*.45f,()=>StartCoroutine(MageBolt(Player.MagicPalmPosition(),Player.transform.forward,damage,22,10,1.2f,3,false))));
    attackCd=.3f/rate;comboExpires=Time.time+hold+.3f;
   }
   else if(combo==2)
   {
    // The back of the left hand flings a heavier orb.
    float hold=.46f/rate;Player.Play("Mage_Backhand",hold);Sound("orb_cast");
    StartCoroutine(DelayedCall(hold*.53f,()=>StartCoroutine(MageBolt(MageLeftPalm(),Player.transform.forward,damage*1.2f,26,10,1.55f,3,false))));
    attackCd=.34f/rate;comboExpires=Time.time+hold+.3f;
   }
   else
   {
    float hold=.6f/rate;Player.Play("Mage_GroundCast",hold);
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
   RevFx.Muzzle(origin,dir,true,null);RevFx.Glow(origin,RevenantVfx.Tone("cfc0ff"),.9f*size,2.4f,.12f);GlideDiamonds(origin,3,.3f,1.4f);
   var hit=new HashSet<Enemy>();float travelled=0,trail=0;
   var streak=BoltStreak(size);
   while(orb&&travelled<range)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float step=Mathf.Min(range-travelled,speed*Time.deltaTime);var previous=orb.transform.position;var next=previous+dir*step;
    // Walls stop it.
    var flat=new Vector3(next.x,0,next.z);if(Vector3.Distance(Move(new Vector3(previous.x,0,previous.z),dir*step,.1f),flat)>.15f){RevFx.ProjectileImpact(next,true,false,dir);break;}
    orb.transform.position=next;travelled+=step;DamageCargoSegment(previous,next,.4f);
    if(streak){float reach=Mathf.Min(travelled,1.7f*size);for(int i=0;i<streak.positionCount;i++)streak.SetPosition(i,next-dir*reach*i/(streak.positionCount-1f));}
    if((trail-=Time.deltaTime)<=0){trail=.03f;RevFx.ProjectileTrail(next,true,false);}
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e)||ProjectileBodyDistance(e.View,previous,next)>e.Data.N("radius",16)*.02f+.45f*size)continue;
     hit.Add(e);var struck=e.View.transform.position+Vector3.up;RevFx.ProjectileImpact(struck,true,false,dir);DamageEnemy(e,damage);MeleeKnockback(e,dir,size>1.2f);
     ArcaneHit(struck,dir,size,hit.Count==1);
     if(hit.Count>pierce){travelled=range;break;}
    }
    yield return null;
   }
   if(orb)Destroy(orb.gameObject);
   if(streak)Destroy(streak.gameObject);
  }
  // The bolt's tail: the glide's arcane strip, bright at the orb, so the Mage's magic shares one look.
  LineRenderer BoltStreak(float size)
  {
   var material=RevFx.TexturedMaterial("arcane_streak");if(!material)return null;
   var l=new GameObject("Bolt streak").AddComponent<LineRenderer>();if(roomRoot)l.transform.SetParent(roomRoot,true);
   l.sharedMaterial=material;l.textureMode=LineTextureMode.Stretch;l.textureScale=new Vector2(.6f,1);l.alignment=LineAlignment.View;l.positionCount=8;
   l.widthMultiplier=.75f*size;l.widthCurve=new AnimationCurve(new Keyframe(0,.7f),new Keyframe(.15f,1),new Keyframe(1,.2f));
   l.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;l.receiveShadows=false;
   var block=new MaterialPropertyBlock();block.SetFloat("_Progress",.5f);block.SetFloat("_Opacity",1.8f);block.SetColor("_Tone",Color.white);l.SetPropertyBlock(block);
   return l;
  }

  // Where a spell meets a body: a bright arcane flare, a ring of light and diamond motes thrown on through the
  // body, and for the first body a camera kick scaled by the spell's size (the hit stop comes from DamageEnemy).
  void ArcaneHit(Vector3 at,Vector3 dir,float size,bool first)
  {
   RevFx.Flash(at,RevenantVfx.Arcane,2.2f*size,.9f*size,.12f);RevFx.Glow(at,RevenantVfx.Tone("cfc0ff"),1.1f*size,3,.14f);
   RevFx.BurstRing(at,.55f*size,RevenantVfx.Tone("cfc0ff"),10,2.6f,.22f);GlideDiamonds(at-dir*.1f,Mathf.RoundToInt(5*size),.45f,2.4f);
   if(RevenantVfx.SheetTexture("arcane_burst"))
   {
    var pop=RevFx.Textured("Arcane hit burst",at,Vector3.one*1.3f*size,"arcane_burst",.42f,Color.white,false,4,true);
    pop.Tick=(p,dt)=>{pop.transform.rotation=Cam.transform.rotation;pop.Block.SetFloat("_Progress",Mathf.Lerp(.12f,1,p));pop.Block.SetFloat("_Opacity",1.4f);};
   }
   if(first){ShakeCamera(.14f+.12f*size,dir);Rumble(.25f*size,.4f*size,.08f);}
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
    if(RevenantVfx.SheetTexture("frost_ground"))
    {
     var frost=RevFx.Textured("Shard frost",origin+dir*d+Vector3.up*.03f,Vector3.one*(half*2+.8f),"frost_ground",1f,new Color(.45f,.7f,1.3f,1),false,1,false,true);
     frost.Tick=(p,dt)=>{frost.Block.SetFloat("_Opacity",.5f*Mathf.Clamp01(frost.Age/.08f)*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.55f,1,p))));frost.Block.SetFloat("_Progress",.5f);};
    }
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e))continue;var rel=e.View.transform.position-origin;rel.y=0;float along=Vector3.Dot(rel,dir);
     if(along<d-rowStep-.3f||along>d+.4f||Vector3.Angle(dir,rel)>halfAngle+10)continue;
     hit.Add(e);DamageEnemy(e,damage);e.Slow=Mathf.Max(e.Slow,1.6f);e.SlowAmount=Mathf.Max(e.SlowAmount,.45f);if(e.Id!="boss")e.View.ImpactPose(origin,16,.35f);
     if(hit.Count==1){hitStop=Mathf.Max(hitStop,MeleeHitStop);ShakeCamera(.42f,dir);Rumble(.4f,.6f,.12f);}
     RevFx.Sparks(e.View.transform.position+Vector3.up*.8f,RevenantVfx.Tone("bfe4ff"),14,.35f,1.5f,4f);
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
   GlideRipples(origin,4.2f,.5f,1.5f);GlideDiamonds(origin+dir*1.2f+Vector3.up*.4f,12,.55f,4.5f);
   while(age<time)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    age+=Time.deltaTime;float radius=Mathf.Lerp(.6f,reach,1-(1-age/time)*(1-age/time));
    foreach(var e in Enemies.ToArray())
    {
     if(e.Emerging||e.Hp<=0||hit.Contains(e))continue;var rel=e.View.transform.position-origin;rel.y=0;
     if(rel.magnitude>radius+.5f||Vector3.Angle(dir,rel)>halfAngle+8)continue;
     hit.Add(e);DamageEnemy(e,damage);StartAreaRecoil(e,origin,2.2f);e.Slow=Mathf.Max(e.Slow,1.2f);e.SlowAmount=Mathf.Max(e.SlowAmount,.3f);
     ArcaneHit(e.View.transform.position+Vector3.up,rel.normalized,1.5f,hit.Count==1);if(hit.Count==1){hitStop=Mathf.Max(hitStop,MeleeHitStop);ShakeCamera(.55f,dir);Rumble(.5f,.7f,.14f);}
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
   float hold=.75f/MageSpeed;Player.Play("Mage_Comet",hold);attackCd=.8f/MageSpeed;vesperMoveActive=true;
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
   // Nothing in reach: no reach for empty air, just a short refusal (a little gap so holding the buttons doesn't buzz).
   if(foe==null){Sound("ui_error");attackCd=.25f;return;}
   Player.PlayWindow("Mage_Backhand",0,.55f,.28f);attackCd=.45f;
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
   Player.transform.rotation=Quaternion.LookRotation(aimAt);Player.Play("Mage_Hurl",.34f);Sound("orb_cast");
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
   if(Run?.ClassId!="mage"||Rooted||Screen!="playing"||dashCd>0||vesperMoveActive||Player.Locked>.15f||Run.Stats.N("hp")<=0)return false;
   direction.y=0;if(direction.sqrMagnitude<.001f)direction=Player.transform.forward;StartCoroutine(MageGlide(direction.normalized));return true;
  }
  IEnumerator MageGlide(Vector3 dir)
  {
   vesperMoveActive=true;dashCd=combatPractice?0:RevenantDashCooldown;invulnerable=Mathf.Max(invulnerable,.5f);
   // An unhurried glide, not a blink.
   const float time=.62f,distance=4.6f;var start=Player.transform.position;
   // The leap (0.5 s) spans the flight until the landing takes over.
   Player.transform.rotation=Quaternion.LookRotation(dir);Player.PlayWindow("Mage_Glide",0,.5f,time*.7f,.2f);GlideLiftoff(start,time);Sound(Voice("mage_glide","orb_cast"));
   // Three beats so the body answers the motion instead of sliding as one held pose: a quick push off (fast,
   // tipping forward), a floating middle that bleeds speed with a slow sway, and the legs reaching down for the
   // landing (the start of her landing clip) while she settles back against the momentum.
   float age=0,done=0;bool landing=false;float sway=Random.value<.5f?-1:1;
   while(age<time)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    age=Mathf.Min(time,age+Time.deltaTime);float t=age/time;
    // An even glide that eases in and out a little: half linear, half ease-out.
    float want=distance*Mathf.Lerp(t,1-Mathf.Pow(1-t,2f),.5f);
    var ground=Move(new Vector3(Player.transform.position.x,0,Player.transform.position.z),dir*(want-done));done=want;
    if(!landing&&t>=.7f){landing=true;Player.PlayWindow("Mage_Land",0,.32f,time-age,.18f);}
    float lift=Mathf.Pow(Mathf.Sin(t*Mathf.PI),.6f)*.5f+Mathf.Sin(t*Mathf.PI*3)*.03f;  // rises fast, hovers with a small bob
    float pitch=Mathf.Lerp(12,-5,Mathf.SmoothStep(0,1,Mathf.InverseLerp(.15f,.9f,t)))*Mathf.Sin(t*Mathf.PI);  // leans in, then back to brake
    float roll=sway*5*Mathf.Sin(t*Mathf.PI*1.5f)*Mathf.Sin(t*Mathf.PI);
    Player.transform.position=new Vector3(ground.x,lift,ground.z);Player.transform.rotation=Quaternion.LookRotation(dir)*Quaternion.Euler(pitch,0,roll);
    yield return null;
   }
   var p=Player.transform.position;p.y=0;Player.transform.position=p;Player.transform.rotation=Quaternion.LookRotation(dir);RevFx.Glow(p+Vector3.up*.6f,RevenantVfx.Arcane,.7f,1.6f,.16f);GlideTouchdown(p);vesperMoveActive=false;
  }
  // The glide must read as magic lifting her, not a jump (art/vfx-incoming storyboard, 20 Oct): blue-violet magic
  // erupts from under her feet with light ripples spreading on the stone and diamond motes; in flight long arcane
  // streaks stream behind her and two ribbons coil round her legs; she touches down on ripples and a last puff.
  void GlideLiftoff(Vector3 at,float time)
  {
   GlideRipples(at,3.4f,.75f,1.6f);StartCoroutine(DelayedCall(.12f,()=>GlideRipples(at,2.4f,.6f,1.1f)));
   GlideBurst(at,3.2f,.85f,0);GlideDiamonds(at,10,1f,3f);
   RevFx.Glow(at+Vector3.up*.55f,RevenantVfx.Arcane,1f,2,.25f);
   StartCoroutine(GlideTrails(time));
  }
  void GlideTouchdown(Vector3 at){GlideRipples(at,2.6f,.6f,1.2f);GlideBurst(at,1.5f,.55f,.35f);GlideDiamonds(at,8,.6f,1.6f);}
  // Thin bright rings on the ground, racing outward and fading.
  void GlideRipples(Vector3 at,float size,float life,float energy)
  {
   if(!RevenantVfx.SheetTexture("arcane_ripples"))return;at.y=.04f;
   var ring=RevFx.Textured("Glide ripples",at,Vector3.one*size*.3f,"arcane_ripples",life,new Color(.78f,.72f,1.25f,1),false,1,false,true);
   ring.Tick=(p,dt)=>{float e=1-Mathf.Pow(1-p,2.5f);ring.transform.localScale=Vector3.one*Mathf.Lerp(size*.3f,size,e);ring.Block.SetFloat("_Opacity",energy*(1-p));ring.Block.SetFloat("_Progress",.5f);};
  }
  // The eruption flipbook (4x4, side on), standing on the ground and turned to the camera. skip starts it later
  // in the sheet (0 = the first flash, .35 = already billowing smoke) for the softer landing puff.
  void GlideBurst(Vector3 at,float size,float life,float skip)
  {
   if(!RevenantVfx.SheetTexture("arcane_burst"))return;
   var burst=RevFx.Textured("Glide burst",at,new Vector3(size,size,1),"arcane_burst",life,Color.white,false,4,true);
   burst.Tick=(p,dt)=>
   {
    var cam=Cam.transform;var flat=Vector3.ProjectOnPlane(cam.forward,Vector3.up).normalized;
    burst.transform.rotation=Quaternion.LookRotation(flat.sqrMagnitude>.01f?flat:Vector3.forward,Vector3.up);
    burst.transform.position=at+Vector3.up*size*.42f;  // the flames rise from the bottom of each cell
    float q=Mathf.Lerp(skip,1,p);burst.Block.SetFloat("_Progress",q);burst.Block.SetFloat("_Opacity",1.5f*(p<.08f?p/.08f:1));
   };
  }
  // Small blue rhombus sparkles thrown up and out, drifting on upward and fading in the air (never settling).
  void GlideDiamonds(Vector3 at,int count,float life,float speed)
  {
   if(!RevenantVfx.SheetTexture("arcane_diamond"))return;
   for(int i=0;i<count;i++)
   {
    var dir=(Quaternion.Euler(0,Random.value*360,0)*Vector3.forward*Random.Range(.4f,1f)+Vector3.up*Random.Range(.8f,1.6f)).normalized*speed*Random.Range(.5f,1f);
    float s=Random.Range(.12f,.24f),spin=Random.Range(-120f,120f),l=life*Random.Range(.5f,.9f);var pos=at+Vector3.up*.15f;
    var d=RevFx.Textured("Glide diamond",pos,new Vector3(s*.75f,s,1),"arcane_diamond",l,new Color(.35f,.5f,1.7f,1),false);
    d.Tick=(p,dt)=>{pos+=dir*dt;dir+=Vector3.up*.5f*dt;dir*=1-2.2f*dt;d.transform.position=pos;d.transform.rotation=Cam.transform.rotation*Quaternion.Euler(0,0,d.Age*spin);d.Block.SetFloat("_Opacity",2.2f);};
   }
  }
  // In flight, everything hangs on her, never on the path behind: streaks stream back from her body (their
  // length follows her speed, so they shorten and fade as she slows instead of piling into her), two ribbons coil
  // round her legs, and under her feet a held column of the eruption, a glow, ground ripples and rising motes
  // keep her visibly borne up by the magic for the whole glide.
  IEnumerator GlideTrails(float time)
  {
   var material=RevFx.TexturedMaterial("arcane_streak");var player=Player;if(!material||!player)yield break;
   var root=new GameObject("Glide trails");if(roomRoot)root.transform.SetParent(roomRoot,true);  // a room change ends the coroutine; the room takes the trails with it
   var block=new MaterialPropertyBlock();const int N=14;
   // Lines use only the dense, bright front of the strip (textureScale); its thin tail reads as wire.
   LineRenderer Line(float width){var l=new GameObject("Glide trail").AddComponent<LineRenderer>();l.transform.SetParent(root.transform,false);l.sharedMaterial=material;l.textureMode=LineTextureMode.Stretch;l.alignment=LineAlignment.View;l.widthMultiplier=width;l.widthCurve=new AnimationCurve(new Keyframe(0,.55f),new Keyframe(.2f,1),new Keyframe(1,.15f));l.textureScale=new Vector2(.55f,1);l.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;l.receiveShadows=false;l.positionCount=N;return l;}
   var streaks=new[]{(Line(1.05f),1.1f,0f,0f),(Line(.8f),.7f,.18f,1.7f),(Line(.7f),1.5f,-.16f,3.4f)};var coils=new[]{Line(.26f),Line(.26f)};
   // The held column: the eruption's fullest frames (cells 3-8) looped under her feet, turned to the camera.
   VfxLifetime column=null;
   if(RevenantVfx.SheetTexture("arcane_burst"))
   {
    column=RevFx.Textured("Glide column",player.transform.position,new Vector3(1.5f,1.5f,1),"arcane_burst",time+.2f,Color.white,false,4,false);
   }
   var under=RevFx.Glow(player.transform.position,RevenantVfx.Arcane,1.05f,2.2f,time+.15f);
   float age=0,length=0,shed=0,ring=.1f,fade=0;
   // The card's own update sets _Progress every frame; take the frame, level and placement over in its Tick.
   if(column)column.Tick=(p,dt)=>
   {
    var cam=Cam.transform;var flat=Vector3.ProjectOnPlane(cam.forward,Vector3.up).normalized;
    column.transform.rotation=Quaternion.LookRotation(flat.sqrMagnitude>.01f?flat:Vector3.forward,Vector3.up);
    if(player)column.transform.position=player.transform.position+Vector3.up*.53f;  // flames rise from the cell's bottom edge to her soles
    column.Block.SetFloat("_Frames",0);column.Block.SetFloat("_Cell",3+Mathf.Floor(column.Age*18)%6);column.Block.SetFloat("_Progress",.5f);column.Block.SetFloat("_Opacity",1.3f*fade);
   };
   while(age<time+.15f&&player)
   {
    float dt=Mathf.Max(Time.deltaTime,.0001f);age+=dt;var at=player.transform.position;
    var fwd=player.transform.forward;fwd.y=0;fwd.Normalize();var right=Vector3.Cross(Vector3.up,fwd);
    float landing=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.62f,.95f,age/time));
    fade=Mathf.Clamp01(age/.07f)*(1-landing);
    // Streak length follows the flight, not the frame speed: grows out over the first fifth, shrinks into the landing.
    length=1.6f*Mathf.SmoothStep(0,1,Mathf.InverseLerp(0,.2f,age/time))*(1-landing*.8f);
    block.SetFloat("_Progress",.5f);block.SetColor("_Tone",Color.white);block.SetFloat("_Opacity",1.6f*fade);
    foreach(var(line,height,side,phase)in streaks)
    {
     for(int i=0;i<N;i++){float u=i/(N-1f);float wave=Mathf.Sin(age*9+phase+u*5)*.12f*u;line.SetPosition(i,at+Vector3.up*(height+wave)+right*side*(1+u*.6f)-fwd*length*u);}
     line.SetPropertyBlock(block);
    }
    for(int c=0;c<coils.Length;c++)
    {
     var line=coils[c];
     for(int i=0;i<N;i++){float u=i/(N-1f);float a=age*14+c*Mathf.PI-u*5.5f;float r=.26f*(1-u*.35f);line.SetPosition(i,at+Vector3.up*(.2f+.6f*u+Mathf.Sin(a)*r*.5f)+right*Mathf.Cos(a)*r-fwd*length*.2f*u);}  // wound round the legs, barely trailing
     line.SetPropertyBlock(block);
    }
    var feet=at+Vector3.up*.05f;
    if(under){under.transform.position=feet+Vector3.up*.45f;under.transform.rotation=Cam.transform.rotation;}
    shed+=dt;if(fade>.2f&&shed>.045f){shed=0;GlideDiamonds(feet,1,.55f,1.1f);}
    ring-=dt;if(fade>.3f&&ring<=0){ring=.16f;GlideRipples(new Vector3(at.x,0,at.z),1.6f,.45f,.9f*fade);}
    yield return null;
   }
   Destroy(root);if(column)Destroy(column.gameObject);
  }
 }
}
