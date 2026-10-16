using System.Collections;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  void Cast(int index)
  {
   if(RevenantActionActive)return;
   if(Player.Locked>.15f)return;var cls=GameData.Rules["classes"][Run.ClassId];string id=index==2?cls.S("ability"):(string)cls["skills"][index];
   if(!combatPractice&&Run.Cooldowns.TryGetValue(id,out float cd)&&cd>0)return;var data=GameData.Row("abilities",id);Run.Cooldowns[id]=combatPractice?0:data.N("cooldown");StartCoroutine(CastRoutine(data,index==2));
  }
  IEnumerator CastRoutine(JObject data,bool ultimate)
  {
   string behavior=data.S("behavior");float range=data.N("range")*.02f*Run.Stats.N("attackRange"),radius=data.N("blastRadius",data.N("range"))*.02f*Run.Stats.N("attackRange"),damage=data.N("damage")*Run.Stats.N("damage");
   thrustWindow=0;var start=Player.transform.position;var dir=aim;var target=GroundTarget(range);Player.transform.rotation=Quaternion.LookRotation(dir);
   if(behavior=="bloodClap")
   {
    // Approved full cast mix: palm impact is baked at CLAP_DAMAGE (23/60 s).
    Player.Play("REV_BloodClap");Sound("revenant_e_blood_bomb");
    Player.OnMarker("CLAP_GATHER",()=>RevFx.Charge(Player.transform.position,radius,Player.MarkerTime("REV_BloodClap","CLAP_DAMAGE")-Player.MarkerTime("REV_BloodClap","CLAP_GATHER")));
    Player.OnMarker("CLAP_DAMAGE",()=>
    {
     var hands=Player.ClapPosition();
     // VFX starts at the hands; ground-plane AoE keeps its full radius in every
     // direction rather than losing reach to the hands' height above enemy feet.
     var center=new Vector3(hands.x,Player.transform.position.y,hands.z);
     RevFx.BloodBomb(hands,dir,radius);BloodCone(center,dir,radius,damage);
    });
    Player.OnMarker("RECOVER",()=>Player.Locked=0);yield break;
   }
   if(behavior=="vesperWard"||behavior=="vesperRite")
   {
    bool major=behavior=="vesperRite";float hold=major?1.32f:1.15f,contact=major?.72f:.48f;
    Player.Play(major?"Ultimate":"CastQ",hold);Sound(major?"revenant_space_blood_burst":"revenant_e_blood_bomb");
    RevFx.VesperCastWarning(start,radius,contact,major);
    yield return Delay(contact);Area(start,radius,damage,false,true);RevFx.VesperGroundCast(start,radius,major);yield break;
   }
   if(behavior=="dash"&&Run.ClassId=="vesper")
   {
    var heading=dir.sqrMagnitude>.001f?dir.normalized:Player.transform.forward;target=Move(start,heading*range*.8f);
    Player.Play("Run",.16f);invulnerable=.34f;RevFx.VesperDash(start,target);
    float age=0;while(age<.16f){if(Screen=="playing"&&hitStop<=0){age+=Time.deltaTime;Player.transform.position=Vector3.Lerp(start,target,Mathf.SmoothStep(0,1,age/.16f));}yield return null;}
    Player.transform.position=target;Player.transform.rotation=Quaternion.LookRotation(heading);Player.Play("DashAttack",.6f);Sound("sword_swing");
    yield return Delay(.25f);yield return MeleeContact(heading,radius*1.25f,damage,0,false,0,0,true);yield break;
   }
   if(behavior=="markOfRuin"){var e=Enemies.Where(x=>!x.Emerging&&Vector3.Distance(x.View.transform.position,start)<range).OrderBy(x=>Vector3.Distance(start,x.View.transform.position)).FirstOrDefault();if(e!=null){foreach(var other in Enemies)other.Mark=0;markChain=0;e.Mark=float.PositiveInfinity;ApplyRuinMark(e);Player.Play("Attack",.24f);Sound("skill_leap_launch");}yield break;}
   if(behavior!="bloodTeleport"&&behavior!="bloodBurst")Player.Play(ultimate?"Ultimate":behavior=="bloodTeleport"?"Teleport":behavior=="powderCharge"?"BombThrow":behavior=="whirl"?"SpinAttack":behavior=="voidLeap"?"SunderLeap":"Attack",.8f);
   if(behavior!="bloodBurst"&&behavior!="bloodTeleport")Sound(behavior=="meteor"?"skill_meteor_cast":"skill_leap_launch");
   if(behavior=="whirl"){float duration=Player.ClipLength("SpinAttack")/1.5f;Player.Play("SpinAttack",duration);for(int sweep=0;sweep<3;sweep++){yield return Delay(duration/4);var pos=Player.transform.position;Area(pos,radius,damage/3,false);for(int turn=0;turn<3;turn++)RevFx.Slash(pos,Quaternion.Euler(0,turn*120,0)*dir,radius,RevenantVfx.Tone(data.S("accent","ff9a4d")));}yield break;}
   if(behavior=="ricochet"){yield return Delay(9f/60);StartCoroutine(Ricochet(start,dir,damage,range,(int)data.N("bounces",3),data.N("projectileSpeed",560)*.02f));yield break;}
   if(behavior=="fanShot"||behavior=="backstepVolley")
   {
    if(behavior=="fanShot"&&Run.ClassId=="gunslinger")
    {
     Player.Play("Ultimate");int previous=0;int[] contactFrames={17,28,39,50,61,72,83,94,103};
     for(int shot=0;shot<contactFrames.Length;shot++)
     {
      yield return Delay((contactFrames[shot]-previous)/60f);previous=contactFrames[shot];var heading=Quaternion.Euler(0,shot*40f,0)*dir;
      StartCoroutine(Projectile(Player.transform.position,heading,damage*5/9,data.N("projectileSpeed",560)*.02f,range,false,0,false,shot%2==0?"R":"L"));Sound("gun_pistol");
     }
     yield break;
    }
    if(behavior=="backstepVolley")Player.transform.position=Move(start,-dir*2.6f*Run.Stats.N("attackRange"));
    yield return Delay(.18f);int count=behavior=="fanShot"?5:behavior=="backstepVolley"?3:1;
    for(int i=0;i<count;i++)StartCoroutine(Projectile(Player.transform.position,Quaternion.Euler(0,(i-(count-1)*.5f)*12,0)*dir,damage,data.N("projectileSpeed",560)*.02f,range,false,behavior=="ricochet"?3:0));yield break;
   }
   if(behavior=="bloodTeleport")
   {
    target=BlinkDestination(start,target);var direction=(target-start).normalized;if(direction.sqrMagnitude<.001f)direction=Player.transform.forward;
    Player.Play("Teleport");Sound("revenant_q_mist_claw");invulnerable=RevenantEventTime("REV_TeleportAttack","DAMAGE");RevFx.Gate(start,1);
    Player.OnMarker("TELEPORT_HIDE",()=>{Player.SetVisible(false);RevFx.Travel(start,target);});
    Player.OnMarker("TELEPORT_MOVE",()=>Player.transform.position=target);
    Player.OnMarker("TELEPORT_SHOW",()=>{Player.SetVisible(true);RevFx.Gate(target,1.1f);});
    // The approved cast sound includes the claw, peaking at DAMAGE (25/60 s).
    // Do not layer the old generic landing sound over it.
    Player.OnMarker("DAMAGE",()=>{BloodStepArea(start,target,radius,damage);RevFx.Burst(target,radius,1.5f);RevFx.Claws(target,direction,radius*.65f,false,false);});
    Player.OnMarker("RECOVER",()=>Player.Locked=0);yield break;
   }
   if(behavior=="bloodBurst")
   {
    // Skip the first 15% of the noble clip and the same interval in its approved
    // audio. The native damage event remains attached to the hands-opening pose.
    radius=range;Player.Play("Ultimate");SoundFrom("revenant_space_blood_burst",Player.ActionStartTime("Ultimate"));
    float telegraph=Player.MarkerTime("Ultimate","ULT_TELEGRAPH_START"),contact=Player.MarkerTime("Ultimate","ULT_DAMAGE");
    // Gathering starts inside the removed lead-in, so start it immediately.
    if(telegraph<=0)RevFx.Charge(start,radius,contact);
    else Player.OnMarker("ULT_TELEGRAPH_START",()=>RevFx.Charge(start,radius,contact-telegraph));
    Player.OnMarker("ULT_DAMAGE",()=>{BloodArea(start,radius,damage,true,2.5f);RevFx.Burst(start,radius);});
    Player.OnMarker("ULT_DISSIPATE",()=>Player.Locked=0);yield break;
   }
   if(behavior=="shadowStrike"){target=Move(start,dir*range*.5f);float age=0;while(age<.12f){if(Screen=="playing"&&hitStop<=0){age+=Time.deltaTime;Player.transform.position=Vector3.Lerp(start,target,Mathf.Clamp01(age/.12f));}yield return null;}Area(target,65*.02f*Run.Stats.N("attackRange"),damage);yield break;}
   if(behavior=="voidLeap")
   {
    float flight=Mathf.Clamp(Vector3.Distance(start,target)/16,.26f,.6f);Player.Play("Ultimate",.7f);float elapsed=0;invulnerable=flight;if(Run.ClassId=="mage")RevFx.ArcaneFlight(start,target,flight,false);
    var tone=RevenantVfx.Tone(data.S("tone","7f6bff"));RevFx.ArcaneWarning(start,2,tone,.35f);RevFx.ArcaneWarning(target,radius,tone,flight);
    while(elapsed<flight){if(Screen=="playing"&&hitStop<=0){elapsed+=Time.deltaTime;float p=Mathf.Clamp01(elapsed/flight);float lift=p<.45f?Mathf.Sin(p/.45f*Mathf.PI*.5f):1-Mathf.Pow((p-.45f)/.55f,2);Player.transform.position=Vector3.Lerp(start,target,(1-Mathf.Cos(p*Mathf.PI))*.5f)+Vector3.up*lift*2.6f;if(Run.ClassId=="mage")RevFx.ProjectileTrail(Player.transform.position+Vector3.up*.5f,true,false);}yield return null;}
    Player.transform.position=target;Area(target,radius,damage,false,true);foreach(var e in Enemies)if(!e.Emerging&&Vector3.Distance(e.View.transform.position,target)<radius+.4f){e.Slow=2;e.SlowAmount=.3f;e.Stagger=Mathf.Max(e.Stagger,.27f);}
    if(Run.ClassId=="warrior")RevFx.GroundImpact(target,radius);else RevFx.ArcaneLeap(target,radius);Sound("skill_leap_land");yield break;
   }
   if(behavior=="warCry"){Player.Play("Ultimate",.9f);yield return Delay(.45f);Area(start,radius,damage,false,true);RevFx.GroundImpact(start,radius);RevFx.Flash(start,RevenantVfx.Tone("bf956b"),.8f,radius,.16f);Sound("ulti_war_cry");yield break;}
   bool targeted=behavior=="meteor"||behavior=="powderCharge";Vector3 origin=targeted?target:start;float delay=behavior=="meteor"?Mathf.Clamp(Vector3.Distance(start,target)/(data.N("projectileSpeed",500)*.02f),.26f,.55f):behavior=="powderCharge"?19f/60+.45f:behavior=="frostNova"?.45f:.3f;
   bool arcane=behavior=="meteor"||behavior=="frostNova";
   if(arcane){RevFx.ArcaneWarning(origin,radius,RevenantVfx.Arcane,delay);if(behavior=="meteor")RevFx.Meteor(Player.MagicPalmPosition(),origin,delay);}else Effects.Ring(origin,radius,Color.red,delay);
   yield return Delay(delay);Area(origin,radius,damage,!arcane,arcane||behavior=="powderCharge");if(arcane){RevFx.ArcaneBlast(origin,radius,behavior=="frostNova");Sound("skill_meteor_blast");}
   if(behavior=="frostNova")foreach(var e in Enemies)if(!e.Emerging&&Vector3.Distance(e.View.transform.position,origin)<radius){e.Slow=3;e.SlowAmount=.45f;}
  }
  static JObject revenantEvents;
  static float RevenantEventTime(string clip,string marker)
  {
   revenantEvents??=JObject.Parse(Resources.Load<TextAsset>("Data/revenant_events").text);
   return ((float)revenantEvents["actions"][clip]["events"][marker]-1)/60f;
  }
  const float BloodStepHalfWidth=.75f;
  public static bool InsideBloodStep(Vector3 point,Vector3 start,Vector3 end,float landingRadius)
  {
   point.y=start.y=end.y=0;
   // Swept mist corridor + existing arrival blast, including enemy body radius.
   return SegmentDistance(point,start,end)<=BloodStepHalfWidth+.4f||Vector3.Distance(point,end)<=landingRadius+.4f;
  }
  void BloodStepArea(Vector3 start,Vector3 end,float radius,float damage)
  {
   if(Run.Stats.N("hp")<=0)return;
   DamageCargoSegment(start,end,BloodStepHalfWidth);DamageCargo(end,radius,Vector3.forward);
   // One union query, not two area attacks: an enemy on both regions is hit once.
   bakedImpactSound=true;
   try{foreach(var enemy in Enemies.ToArray())if(!enemy.Emerging&&enemy.Hp>0&&InsideBloodStep(enemy.View.transform.position,start,end,radius))
   {DamageEnemy(enemy,damage);RevFx.Impact(enemy.View.transform.position+Vector3.up*.9f,2.5f);}}
   finally{bakedImpactSound=false;}
  }
  void BloodArea(Vector3 origin,float radius,float damage,bool heavyImpact=false,float recoilMultiplier=1)
  {
   if(Run.Stats.N("hp")<=0)return;
   DamageCargo(origin,radius,Vector3.forward);
   bakedImpactSound=true;
   try{foreach(var enemy in Enemies.ToArray())if(!enemy.Emerging&&Vector3.Distance(enemy.View.transform.position,origin)<radius+.4f){DamageEnemy(enemy,damage);if(heavyImpact)StartAreaRecoil(enemy,origin,recoilMultiplier);RevFx.Impact(enemy.View.transform.position+Vector3.up*.9f,2.5f);}}
   finally{bakedImpactSound=false;}
  }
  public static bool InsideBloodCone(Vector3 offset,Vector3 direction,float radius)
  {
   offset.y=0;direction.y=0;
   return offset.sqrMagnitude<=radius*radius&&(offset.sqrMagnitude<.0001f||Vector3.Dot(offset.normalized,direction.normalized)>=.7071067f);
  }
  void BloodCone(Vector3 origin,Vector3 direction,float radius,float damage)
  {
   if(Run.Stats.N("hp")<=0)return;
   DamageCargo(origin,radius,direction,90);
   foreach(var enemy in Enemies.ToArray())if(!enemy.Emerging&&InsideBloodCone(enemy.View.transform.position-origin,direction,radius))
   {DamageEnemy(enemy,damage);StartAreaRecoil(enemy,origin,1.5f);RevFx.Impact(enemy.View.transform.position+Vector3.up*.9f,2.5f);}
  }
  void ApplyRuinMark(Enemy enemy)
  {
   foreach(var other in Enemies){if(other!=enemy)other.Mark=0;var old=other.View.transform.Find("RuinMark");if(old)Destroy(old.gameObject);}
   RevFx.Mark(enemy.View.transform,RevenantVfx.Tone("63bd9f"));
  }
  Vector3 GroundTarget(float range)
  {
   var start=Player.transform.position;var mouse=UnityEngine.InputSystem.Mouse.current;if(mouse==null||Application.isBatchMode||UnityEngine.InputSystem.Gamepad.current?.rightStick.ReadValue().sqrMagnitude>.1f)return BlinkDestination(start,start+aim*range);
   var ray=Cam.ScreenPointToRay(mouse.position.ReadValue());if(!new Plane(Vector3.up,0).Raycast(ray,out float distance))return start;
   return BlinkDestination(start,start+Vector3.ClampMagnitude(ray.GetPoint(distance)-start,range));
  }
  Vector3 BlinkDestination(Vector3 start,Vector3 end)
  {
   end.x=Mathf.Clamp(end.x,-half.x+.45f,half.x-.45f);end.z=Mathf.Clamp(end.z,-half.y+.45f,half.y-.45f);int steps=Mathf.Max(1,Mathf.CeilToInt(Vector3.Distance(start,end)/.1f));
   for(int i=0;i<=steps;i++){var p=Vector3.Lerp(end,start,(float)i/steps);bool blocked=false;foreach(var b in blockers){var area=b;area.Expand(new Vector3(.86f,0,.86f));if(area.Contains(new Vector3(p.x,b.center.y,p.z))){blocked=true;break;}}if(!blocked)return p;}return start;
  }
  IEnumerator Ricochet(Vector3 start,Vector3 dir,float damage,float range,int bounces,float speed)
  {
   var seen=new System.Collections.Generic.HashSet<Enemy>();var position=start;float remaining=range;
   while(remaining>0){if(Screen!="playing"||hitStop>0){yield return null;continue;}float step=speed*Time.deltaTime;var previous=position;position+=dir*step;remaining-=step;DamageCargoSegment(previous,position,.15f);var victim=Enemies.FirstOrDefault(e=>!e.Emerging&&!seen.Contains(e)&&Vector3.Distance(position,e.View.transform.position)<.8f);if(victim!=null){seen.Add(victim);DamageEnemy(victim,damage);if(bounces--<=0)break;var next=Enemies.Where(e=>!e.Emerging&&!seen.Contains(e)&&Vector3.Distance(position,e.View.transform.position)<range).OrderBy(e=>Vector3.Distance(position,e.View.transform.position)).FirstOrDefault();if(next==null)break;dir=(next.View.transform.position-position).normalized;remaining=range;}Effects.Ring(position,.09f,gold,.07f);yield return null;}
  }
  void Area(Vector3 origin,float radius,float damage,bool effects=true,bool heavyImpact=false){DamageCargo(origin,radius,Vector3.forward);foreach(var e in Enemies.ToArray())if(!e.Emerging&&Vector3.Distance(e.View.transform.position,origin)<radius+.4f){DamageEnemy(e,damage);if(heavyImpact)StartAreaRecoil(e,origin);}if(effects){Effects.Ring(origin,radius,new Color(.8f,.2f,.1f),.5f);Sound("skill_meteor_blast");}}
 }
}
