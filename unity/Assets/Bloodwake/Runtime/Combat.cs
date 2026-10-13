using System.Collections;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Bloodwake
{
 public sealed class Enemy
 {
  public string Id;public JObject Data;public ActorView View;public float Hp,MaxHp,Damage,Cooldown,Stagger,Slow,Mark,Aura,RuneCooldown,Burn,BurnDps,Bleed,BleedDps;public int Pattern;public bool Casting;
 }
 public sealed partial class BloodwakeGame
 {
  int combo;float comboExpires;
  public void SpawnEnemy(string id,Vector3 pos)
  {
   var data=GameData.Row("enemies",id);float n=Run.Wave-1,t=Run.Night-1;
   float power=id=="boss"?1+.65f*t+.2f*t*t:1+.25f*n+.035f*n*n;
   float height=id=="boss"?3.5f:id=="tank"?2.3f:id=="commander"?2.225f:id=="grunt"?2.15f:1.8f;
   var view=ActorView.Create(id,true,height,actorRoot);view.transform.position=pos;
   Enemies.Add(new Enemy{Id=id,Data=data,View=view,Hp=data.N("maxHp")*power,MaxHp=data.N("maxHp")*power,Damage=data.N("damage")*(id=="boss"?1+.25f*t:1+.09f*n+.002f*n*n),Cooldown=.9f});
  }
  void Attack()
  {
   if(Player.Locked>0&&attackCd>0)return;
   foreach(var entry in Run.Weapons){var row=GameData.Row("weapons",entry.Key);var slot=entry.Value;float rate=row.N("attacksPerSecond")*Run.Stats.N("attackSpeed")*slot.N("speed");attackCd=Mathf.Max(.15f,1/rate);
    bool melee=row.S("behavior")=="melee";Vector3 dir=melee&&(Run.ClassId=="warrior"||Run.ClassId=="revenant")?Player.transform.forward:aim;
    if(!melee)Player.transform.rotation=Quaternion.LookRotation(dir);
    if(Time.time>comboExpires)combo=0;combo=combo%(Run.ClassId=="warrior"?4:3)+1;
    string clip=Run.ClassId=="warrior"||Run.ClassId=="revenant"?"Attack"+combo:"Attack";
    float damage=row.N("damage")*Run.Stats.N("damage")*slot.N("damage"),range=row.N("range")*.02f*Run.Stats.N("attackRange")*slot.N("range");
    bool heavy=Run.ClassId=="warrior"&&(Keyboard.current?.leftShiftKey.isPressed==true||Mouse.current?.rightButton.isPressed==true||Gamepad.current?.leftShoulder.isPressed==true);
    float duration=melee?Player.ClipLength(clip)/(1.5f*Mathf.Clamp(Run.Stats.N("attackSpeed"),.8f,2.5f)):Mathf.Min(.45f,attackCd*.85f);
    if(Run.ClassId=="revenant")duration=Player.ClipLength(clip)/Mathf.Sqrt(Mathf.Max(.5f,Run.Stats.N("attackSpeed")/GameData.Stats("revenant").N("attackSpeed")*slot.N("speed")));
    if(Run.ClassId=="assassin")duration=Mathf.Min(duration,attackCd*.9f);
    if(Run.ClassId=="warrior"&&combo==4)duration=.9f;
    if(heavy){clip="SpinAttack";duration=Player.ClipLength(clip)/(1.5f*Mathf.Clamp(Run.Stats.N("attackSpeed"),.8f,1.5f));attackCd*=2.6f;combo=0;}
    if(Run.ClassId=="gunslinger"){duration=Player.ClipLength("Attack");StartCoroutine(BloodhoundVolley(row,slot,dir,damage*duration/attackCd/6,range));attackCd=duration;}
    else if(melee){float impact=heavy?.55f:combo==1?.46f:combo==2?.33f:combo==3?.22f:.5f;float contact=Run.ClassId=="revenant"?(combo==1?10:combo==2?11:18)/60f*duration/Player.ClipLength(clip):duration*impact;Sound(Run.ClassId=="revenant"?"revenant_swing":Run.ClassId=="assassin"?"dagger_swing":"sword_swing");StartCoroutine(MeleeContact(dir,range*(heavy?1.9f:Run.ClassId=="warrior"?1.7f:Run.ClassId=="revenant"?1.8f:1),damage*(heavy?2.2f:1),contact,heavy));}
    else StartCoroutine(ReleaseWeapon(row,slot,dir,damage,range,duration*.55f));
    Player.Play(clip,duration);attackCd=Mathf.Max(attackCd,duration*(heavy?.85f:.62f));comboExpires=Time.time+duration+.5f;
   }
  }
  IEnumerator Delay(float time){while(time>0){if(Screen=="playing"&&hitStop<=0)time-=Time.deltaTime;yield return null;}}
  IEnumerator MeleeContact(Vector3 dir,float range,float damage,float delay,bool wide=false)
  {
   yield return Delay(delay);if(Run.Stats.N("hp")<=0)yield break;
   string weapon=Run.ClassId=="assassin"?"daggers":"sword";Run.Weapons.TryGetValue(weapon,out var slot);
   if(slot!=null){slot["swings"]=slot.N("swings")+1;if(slot.N("shockwave")>0&&(int)slot.N("swings")%3==0){wide=true;range+=slot.N("shockwave")*.02f;}}
   var hit=new System.Collections.Generic.HashSet<Enemy>();Vector3 origin=Player.transform.position;
   foreach(var e in Enemies.ToArray()){var d=e.View.transform.position-origin;if(d.magnitude<=range+.45f&&(wide||Vector3.Angle(dir,d)<75)){hit.Add(e);DamageEnemy(e,damage);if(e.Hp>0&&slot.N("bleed")>0){e.Bleed=3;e.BleedDps=slot.N("bleed");}}}
   if(hit.Count>0&&slot.N("chain")>0)ChainStrike(hit.First().View.transform.position,damage*.5f,(int)slot.N("chain"),2.4f,hit);
   Effects.Ring(origin,range,new Color(.6f,.05f,.08f));
  }
  void ChainStrike(Vector3 origin,float damage,int count,float radius,System.Collections.Generic.HashSet<Enemy> hit)
  {
   for(int i=0;i<count;i++){var e=Enemies.Where(x=>!hit.Contains(x)&&Vector3.Distance(origin,x.View.transform.position)<radius).OrderBy(x=>Vector3.Distance(origin,x.View.transform.position)).FirstOrDefault();if(e==null)break;var end=e.View.transform.position;var beam=new GameObject("Chain lightning").AddComponent<LineRenderer>();beam.transform.SetParent(actorRoot);beam.positionCount=2;beam.SetPosition(0,origin+Vector3.up);beam.SetPosition(1,end+Vector3.up);beam.startWidth=beam.endWidth=.05f;beam.material=Effects.Mat(new Color(.65f,.81f,1));Destroy(beam.gameObject,.16f);hit.Add(e);DamageEnemy(e,damage);if(e.Hp>0){e.Burn=2;e.BurnDps=4;}origin=end;}
  }
  IEnumerator ReleaseWeapon(JToken row,JToken slot,Vector3 dir,float damage,float range,float delay){yield return Delay(delay);Sound(Run.ClassId=="mage"?"orb_cast":"gun_rifle");int count=(int)row.N("projectileCount",1);for(int i=0;i<count;i++)StartCoroutine(Projectile(Player.transform.position,Quaternion.Euler(0,(i-(count-1)*.5f)*8,0)*dir,damage,row.N("projectileSpeed",500)*.02f,range,false,(int)(row.N("pierceCount")+slot.N("pierce"))));}
  IEnumerator BloodhoundVolley(JToken row,JToken slot,Vector3 dir,float damage,float range){yield return Delay(9f/60);for(int i=0;i<5;i++){yield return ReleaseWeapon(row,slot,dir,damage,range,0);if(i==4)yield return ReleaseWeapon(row,slot,dir,damage,range,0);else yield return Delay(4f/60);}}
  int markChain;
  void DamageEnemy(Enemy e,float damage,bool effects=true)
  {
   if(e.Hp<=0)return;bool critical=effects&&Random.value<Run.Stats.N("criticalChance");damage*=critical?Run.Stats.N("criticalDamage"):1;damage*=e.Mark>0?1.35f+.1f*markChain:1;float actual=Mathf.Min(e.Hp,damage);e.Hp-=damage;
   if(Run.Stats.N("hp")>0)Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+actual*Run.Stats.N("lifesteal"));
   if(effects){e.Stagger=.18f;hitStop=Mathf.Max(hitStop,critical?.075f:.05f);Sound("sword_hit_flesh");Blood(e.View.transform.position);}
   if(e.Hp>0){if(effects)e.View.Play("Hit",.22f);return;}Enemies.Remove(e);
   if(e.Mark>0){var heir=Enemies.Where(x=>Vector3.Distance(e.View.transform.position,x.View.transform.position)<9).OrderBy(x=>Vector3.Distance(e.View.transform.position,x.View.transform.position)).FirstOrDefault();if(heir!=null){markChain++;heir.Mark=float.PositiveInfinity;Effects.Ring(heir.View.transform.position,.7f,Color.magenta,1);}else markChain=0;}
   Run.Kills++;Run.Gold+=(int)e.Data.N("goldReward")+(int)Run.Stats.N("bonusGoldPerKill");Drop(e.View.transform.position,"xp",(int)e.Data.N("xpReward"));if(e.Id=="boss"||Random.value<.08f)Drop(e.View.transform.position,"health",e.Id=="boss"?70:18);float length=e.View.Play("Death");Destroy(e.View.gameObject,Mathf.Max(1,length)+1);Sound(e.Id=="boss"?"boss_death":"enemy_death");
  }
  void HurtPlayer(float damage){if(invulnerable>0)return;Run.Hurt(damage,Random.value);invulnerable=.25f;Sound("player_hit");if(Run.Stats.N("hp")<=0){Player.Play("Death");Screen="dead";if(!Run.Awarded){Run.Awarded=true;Meta.Essence+=Mathf.Clamp(Run.Wave*2+Run.Kills/5,2,100000);Meta.Save();}}}
 }
}
