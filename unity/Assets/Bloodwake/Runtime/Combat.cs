using System.Collections;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Bloodwake
{
 public enum WarriorIntent { Approach,FaceTarget,Attack,Recover,Reposition }
 public sealed class Enemy
 {
  public bool Emerging=>View&&View.Emerging;
  public UnityEngine.AI.NavMeshAgent Agent;public int CrowdId,ApproachSlot=-1;public float PathTimer;public Vector3 PathGoal;
  public WarriorIntent Intent;public int AttackCount,ContactCount;public bool StepPending;public float StepTime,StuckTime,ApproachTimer;public Vector3 StepGoal,ApproachAnchor;
  public bool Turning;public float TurnAge,TurnYawScale;public Quaternion TurnRotation;public Vector3 TurnOffset;
  public string Id;public JObject Data;public ActorView View;public float Hp,MaxHp,Damage,Cooldown,Stagger,Slow,SlowAmount,Mark,Aura,RuneCooldown,Burn,BurnDps,Bleed,BleedDps;public int Pattern,ImpactVersion;public bool Casting,Training;public Vector3 RecoilDirection,TrainingHome;public float RecoilTime,RecoilRemaining,AreaRecovery;
 }
 public sealed partial class BloodwakeGame
 {
  int combo;float comboExpires;
  const float CombatActorScale=1.173f;
  const float NormalHitStop=.05f,FinisherHitStop=.07f;
  public void SpawnEnemy(string id,Vector3 pos)
  {
   var data=GameData.Row("enemies",id);float n=Run.Wave-1,t=Run.Night-1;
   float power=id=="boss"?1+.65f*t+.2f*t*t:1+.25f*n+.035f*n*n;
   float height=id=="boss"?3.5f:id=="tank"?2.3f:id=="commander"?2.225f:id=="grunt"?2.15f:1.8f;
   var view=ActorView.Create(id,true,height*CombatActorScale,actorRoot);view.transform.position=FreeEnemySpawn(pos,id=="boss"?.8f:id=="tank"||id=="grunt"?.65f:.56f);RevFx.HandMagic(view,true);
   var enemy=new Enemy{Id=id,Data=data,View=view,Hp=data.N("maxHp")*power,MaxHp=data.N("maxHp")*power,Damage=data.N("damage")*(id=="boss"?1+.25f*t:1+.09f*n+.002f*n*n),Cooldown=.9f};Enemies.Add(enemy);AttachEnemyAgent(enemy);
   var facing=Player.transform.position-view.transform.position;facing.y=0;if(facing.sqrMagnitude>.01f)view.transform.rotation=Quaternion.LookRotation(facing);
   view.BeginEmergence();HoldEnemyAgent(enemy);RevFx.EnemyEmergence(view.transform.position,view.Height);
  }
  void Attack()
  {
   if(RevenantActionActive)return;
   if(BeginRevenantThrust())return;
   if(Player.IsCasting)return;
   if(Player.Locked>0&&attackCd>0)return;
   foreach(var entry in Run.Weapons){var row=GameData.Row("weapons",entry.Key);var slot=entry.Value;float rate=row.N("attacksPerSecond")*Run.Stats.N("attackSpeed")*slot.N("speed");attackCd=Mathf.Max(.15f,1/rate);
    System.Action contactEvent=null;bool melee=row.S("behavior")=="melee";Vector3 dir=melee&&(Run.ClassId=="warrior"||Run.ClassId=="revenant"||Run.ClassId=="vesper")?Player.transform.forward:aim;
    if(!melee)Player.transform.rotation=Quaternion.LookRotation(dir);
    if(Time.time>comboExpires)combo=0;combo=combo%(Run.ClassId=="warrior"?4:3)+1;
    string clip=Run.ClassId=="warrior"||Run.ClassId=="revenant"||Run.ClassId=="vesper"?"Attack"+combo:"Attack";
    // Vesper finishes the combo with the upward greatsword thrust.
    if(Run.ClassId=="vesper"&&combo==3)clip="DashAttack";
    float damage=row.N("damage")*Run.Stats.N("damage")*slot.N("damage"),range=row.N("range")*.02f*Run.Stats.N("attackRange")*slot.N("range");
    bool heavy=Run.ClassId=="warrior"&&(Keyboard.current?.leftShiftKey.isPressed==true||Mouse.current?.rightButton.isPressed==true||Gamepad.current?.leftShoulder.isPressed==true);
    float duration=melee?Player.ClipLength(clip)/(1.5f*Mathf.Clamp(Run.Stats.N("attackSpeed"),.8f,2.5f)):Mathf.Min(.45f,attackCd*.85f);
    // Vesper's Mixamo swings are already quick; play them slightly slower than authored so each
    // reads, and let only attack speed gained above the class base shorten them.
    if(Run.ClassId=="vesper")duration=Player.ClipLength(clip)*1.1f/Mathf.Clamp(Run.Stats.N("attackSpeed")/GameData.Stats("vesper").N("attackSpeed"),.8f,1.6f);
    if(Run.ClassId=="revenant")duration=Player.ClipLength(clip)/Mathf.Sqrt(Mathf.Max(.5f,Run.Stats.N("attackSpeed")/GameData.Stats("revenant").N("attackSpeed")*slot.N("speed")));
    if(Run.ClassId=="warrior"&&combo==4)duration=.9f;
    if(heavy){clip="SpinAttack";duration=Player.ClipLength(clip)/(1.5f*Mathf.Clamp(Run.Stats.N("attackSpeed"),.8f,1.5f));attackCd*=2.6f;combo=0;}
    if(melee){float impact=Run.ClassId=="vesper"?(combo==1?.43f:combo==2?.40f:.52f):heavy?.55f:combo==1?.46f:combo==2?.33f:combo==3?.22f:.5f;float contact=Run.ClassId=="revenant"?(combo==1?10:combo==2?11:18)/60f*duration/Player.ClipLength(clip):duration*impact;if(Run.ClassId=="vesper")SoundOnContact("vesper_attack_"+combo,contact);else if(Run.ClassId!="warrior")Sound(Run.ClassId=="revenant"?"revenant_swing":"sword_swing");if(Run.ClassId=="revenant") {int swing=combo;float reach=range;contactEvent=()=>StartCoroutine(MeleeContact(dir,reach*1.8f,damage,0,false,swing,reach));}
     else StartCoroutine(MeleeContact(dir,range*(heavy?1.9f:Run.ClassId=="warrior"?1.7f:Run.ClassId=="vesper"?1.65f:1),damage*(heavy?2.2f:1),contact,heavy,0,0,combo==(Run.ClassId=="warrior"?4:3)));}
    else StartCoroutine(ReleaseWeapon(row,slot,dir,damage,range,duration*.55f,"R",combo==3));
    Player.Play(clip,duration);if(contactEvent!=null)Player.OnMarker("DAMAGE",contactEvent);attackCd=Mathf.Max(attackCd,duration*(heavy?.85f:.62f));comboExpires=Time.time+duration+.5f;
   }
  }
  IEnumerator Delay(float time){while(time>0){if(Screen=="playing"&&hitStop<=0)time-=Time.deltaTime;yield return null;}}
  IEnumerator MeleeContact(Vector3 dir,float range,float damage,float delay,bool wide=false,int revenantSwing=0,float sourceRadius=0,bool finisher=false)
  {
   if(delay>0)yield return Delay(delay);if(Screen!="playing"||Run.Stats.N("hp")<=0)yield break;
   // User-selected recording: use the contact beat, not the start of the wind-up.
   if(Run.ClassId=="warrior")Sound("warrior_sword_clash_user");
   string weapon="sword";Run.Weapons.TryGetValue(weapon,out var slot);
   if(slot!=null){slot["swings"]=slot.N("swings")+1;if(slot.N("shockwave")>0&&(int)slot.N("swings")%3==0){wide=true;float extra=slot.N("shockwave")*.02f;range+=extra*(revenantSwing>0?1.8f:1);sourceRadius+=extra;}}
   float arc=Run.ClassId=="warrior"?150:Run.ClassId=="revenant"?180:Run.ClassId=="vesper"?155:105;
   var hit=new System.Collections.Generic.HashSet<Enemy>();Vector3 origin=Player.transform.position;
   DamageCargo(origin,range,dir,wide?360:arc);
   foreach(var e in Enemies.ToArray()){if(e.Emerging)continue;var d=e.View.transform.position-origin;d.y=0;float bodyRadius=Mathf.Max(.45f,e.Data.N("radius",16)*.02f*CombatActorScale);float tolerance=Mathf.Asin(Mathf.Clamp01(bodyRadius/Mathf.Max(bodyRadius,d.magnitude)))*Mathf.Rad2Deg;if(d.magnitude<=range+bodyRadius&&(wide||Vector3.Angle(dir,d)<=arc*.5f+tolerance)){hit.Add(e);DamageEnemy(e,damage);if(e.Hp>0&&slot.N("bleed")>0){e.Bleed=3;e.BleedDps=slot.N("bleed");}}}
   if(hit.Count>0&&(revenantSwing==3||finisher))hitStop=Mathf.Max(hitStop,FinisherHitStop);
   if(hit.Count>0&&slot.N("chain")>0)ChainStrike(hit.First().View.transform.position,damage*.5f,(int)slot.N("chain"),2.4f,hit);
   if(revenantSwing>0){RevFx.Claws(origin,dir,sourceRadius,revenantSwing==2,wide||revenantSwing==3);foreach(var e in hit)if(e.View)RevFx.Impact(e.View.transform.position+Vector3.up*.9f);}
   else if(Run.ClassId=="vesper")RevFx.VesperBladeArc(origin,dir,range,wide?360:arc);
   else RevFx.BladeArc(origin,dir,range,wide?360:arc);
  }
  void ChainStrike(Vector3 origin,float damage,int count,float radius,System.Collections.Generic.HashSet<Enemy> hit)
  {
   for(int i=0;i<count;i++){var e=Enemies.Where(x=>!x.Emerging&&!hit.Contains(x)&&Vector3.Distance(origin,x.View.transform.position)<radius).OrderBy(x=>Vector3.Distance(origin,x.View.transform.position)).FirstOrDefault();if(e==null)break;var end=e.View.transform.position;var beam=new GameObject("Chain lightning").AddComponent<LineRenderer>();beam.transform.SetParent(actorRoot);beam.positionCount=2;beam.SetPosition(0,origin+Vector3.up);beam.SetPosition(1,end+Vector3.up);beam.startWidth=beam.endWidth=.05f;beam.material=Effects.Mat(new Color(.65f,.81f,1));Destroy(beam.gameObject,.16f);hit.Add(e);DamageEnemy(e,damage);if(e.Hp>0){e.Burn=2;e.BurnDps=4;}origin=end;}
  }
  IEnumerator ReleaseWeapon(JToken row,JToken slot,Vector3 dir,float damage,float range,float delay,string hand="R",bool finisher=false){yield return Delay(delay);Sound(Run.ClassId=="mage"?"orb_cast":"gun_rifle");int count=(int)row.N("projectileCount",1);for(int i=0;i<count;i++)StartCoroutine(Projectile(Player.transform.position,Quaternion.Euler(0,(i-(count-1)*.5f)*8,0)*dir,damage,row.N("projectileSpeed",500)*.02f,range,false,(int)(row.N("pierceCount")+slot.N("pierce")),false,hand,finisher));}
  int markChain;
  void DamageEnemy(Enemy e,float damage,bool effects=true)
  {
   if(e.Training)
   {
    if(e.Emerging)return;e.Hp-=damage;
    if(effects){RevFx.DamageText(e.View.transform.position,damage,RevenantVfx.Tone("d9dce2"));e.Stagger=.5f+PostImpactRecovery;hitStop=Mathf.Max(hitStop,NormalHitStop);Sound(Run.ClassId=="vesper"?"vesper_hit_flesh":"sword_hit_flesh");Blood(e.View.transform.position);e.ImpactVersion++;StartRecoil(e);e.View.FlashHit(false);e.View.Play("Hit",.5f);}
    if(e.Hp<=0){e.Hp=e.MaxHp;e.RecoilRemaining=e.RecoilTime=0;e.View.transform.position=e.TrainingHome;e.View.transform.rotation=Quaternion.LookRotation(Vector3.forward);}
    return;
   }
   if(e.Hp<=0||e.Emerging)return;bool critical=effects&&Random.value<Run.Stats.N("criticalChance");damage*=critical?Run.Stats.N("criticalDamage"):1;damage*=e.Mark>0?1.35f+.1f*markChain:1;float actual=Mathf.Min(e.Hp,damage);if(!combatPractice)e.Hp-=damage;
   if(Run.Stats.N("hp")>0)Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+actual*Run.Stats.N("lifesteal"));
   if(effects){RevFx.DamageText(e.View.transform.position,damage,RevenantVfx.Tone(critical?"ffe4a8":"d9dce2"));e.Stagger=Mathf.Max(e.Stagger,.5f+PostImpactRecovery);hitStop=Mathf.Max(hitStop,NormalHitStop);Sound(Run.ClassId=="vesper"?"vesper_hit_flesh":"sword_hit_flesh");Blood(e.View.transform.position);if(e.Hp>0){e.ImpactVersion++;StartRecoil(e);}}
   if(effects&&actual>0)e.View.FlashHit(false);
   if(e.Hp>0){if(effects&&e.AreaRecovery<=0)e.View.Play("Hit",.5f);return;}if(e.Agent)e.Agent.enabled=false;Enemies.Remove(e);
   if(e.Mark>0){var heir=Enemies.Where(x=>!x.Emerging&&Vector3.Distance(e.View.transform.position,x.View.transform.position)<9).OrderBy(x=>Vector3.Distance(e.View.transform.position,x.View.transform.position)).FirstOrDefault();if(heir!=null){markChain++;heir.Mark=float.PositiveInfinity;ApplyRuinMark(heir);}else markChain=0;}
   if(e.View.transform.Find("RuinMark"))Destroy(e.View.transform.Find("RuinMark").gameObject);Run.Kills++;Run.Gold+=(int)e.Data.N("goldReward")+(int)Run.Stats.N("bonusGoldPerKill");Drop(e.View.transform.position,"xp",(int)e.Data.N("xpReward"));if(e.Id=="boss"||Random.value<.08f)Drop(e.View.transform.position,"health",e.Id=="boss"?70:18);float length=e.View.Play("Death");Destroy(e.View.gameObject,Mathf.Max(1,length)+1);Sound(e.Id=="boss"?"boss_death":"enemy_death");
  }
  void HurtPlayer(float damage)
  {
   if(invulnerable>0||damage<=0||Run.Stats.N("hp")<=0)return;
   float beforeHp=Run.Stats.N("hp");if(!combatPractice)Run.Hurt(damage,Random.value);
   bool struck=combatPractice||Run.Stats.N("hp")<beforeHp;
   if(struck)
   {
    Player.FlashHit(true);Sound("player_hit");
    if(!combatPractice)RevFx.DamageText(Player.transform.position,beforeHp-Run.Stats.N("hp"),RevenantVfx.Tone("ff8678"));
    if(Run.ClassId=="revenant"&&Run.Stats.N("hp")>0)Player.HitOverlay();
   }
   invulnerable=.25f;
   if(Run.Stats.N("hp")<=0){ResetRevenantDash();Player.Play("Death");if(Run.ClassId=="revenant"){Player.OnMarker("DEATH_GROUND",()=>RevFx.Death(Player.transform.position));RevFx.Dissolve(Player);}hitStop=0;Screen="dying";SetMusic("");Sound(Run.ClassId=="vesper"?"vesper_death":"player_death");StartCoroutine(DeathTransition());if(!Run.Awarded){Run.Awarded=true;Meta.Essence+=Mathf.Clamp(Run.Wave*2+Run.Kills/5,2,100000);Meta.Save();}}
  }
 }
}
