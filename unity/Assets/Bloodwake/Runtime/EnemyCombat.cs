using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  IEnumerator Projectile(Vector3 start,Vector3 direction,float damage,float speed,float range,bool hostile,int pierce=0)
  {
   var go=GameObject.CreatePrimitive(PrimitiveType.Sphere);go.name=hostile?"Enemy projectile":"Player projectile";Destroy(go.GetComponent<Collider>());go.transform.SetParent(actorRoot);go.transform.localScale=Vector3.one*.15f;go.transform.position=start+Vector3.up;go.GetComponent<Renderer>().sharedMaterial=Effects.Mat(hostile?new Color(.8f,.15f,.1f):new Color(.65f,.75f,1));float traveled=0;var hit=new HashSet<Enemy>();
   while(traveled<range&&go){if(Screen!="playing"||hitStop>0){yield return null;continue;}float step=Mathf.Min(range-traveled,Mathf.Max(1,speed)*Time.deltaTime);var previous=go.transform.position;go.transform.position+=direction*step;traveled+=step;
    if(hostile){if(SegmentDistance(Player.transform.position+Vector3.up,previous,go.transform.position)<.55f){HurtPlayer(damage);break;}}
    else foreach(var e in Enemies.OrderBy(e=>Vector3.Distance(previous,e.View.transform.position+Vector3.up)).ToArray()){if(hit.Contains(e)||SegmentDistance(e.View.transform.position+Vector3.up,previous,go.transform.position)>.65f)continue;hit.Add(e);DamageEnemy(e,damage);if(e.Hp>0&&Run.Weapons.TryGetValue("magic_orb",out var orb)&&Run.ClassId=="mage"&&orb.N("burn")>0){e.Burn=3;e.BurnDps=orb.N("burn");}if(hit.Count>pierce){traveled=range;break;}}
    yield return null;
   }if(go)Destroy(go);
  }
  static float SegmentDistance(Vector3 point,Vector3 start,Vector3 end){var delta=end-start;return Vector3.Distance(point,start+delta*Mathf.Clamp01(Vector3.Dot(point-start,delta)/Mathf.Max(.000001f,delta.sqrMagnitude)));}
  void TickEnemies(float dt)
  {
   foreach(var e in Enemies.ToArray())
   {
    if(e.Burn>0){DamageEnemy(e,e.BurnDps*Mathf.Min(dt,e.Burn),false);e.Burn-=dt;}if(e.Hp<=0)continue;
    if(e.Bleed>0){DamageEnemy(e,e.BleedDps*Mathf.Min(dt,e.Bleed),false);e.Bleed-=dt;}if(e.Hp<=0)continue;
    e.Cooldown-=dt;e.Stagger-=dt;e.Slow-=dt;e.Mark-=dt;e.Aura-=dt;e.RuneCooldown-=dt;var delta=Player.transform.position-e.View.transform.position;float distance=delta.magnitude;var dir=delta.normalized;
    if(e.Casting){e.View.Tick(dt,false);continue;}
    if(e.Id=="assassin"&&distance<3.2f&&e.Cooldown<=0){StartCoroutine(AssassinStrike(e));continue;}
    if(e.Stagger>0||e.View.Locked>0){e.View.Tick(dt,false);continue;}
    float speed=e.Data.N("moveSpeed")*.02f*(e.Slow>0?.45f:1)*(e.Aura>0?1.22f:1);bool ranged=e.Id=="archer"||e.Id=="mage"||e.Id=="healer";float reach=ranged?7:1.25f;
    if(e.Id=="boss"){string next=new[]{"attack","sweep","cast","charge","slam","summon"}[e.Pattern%6];reach=next=="attack"||next=="sweep"||next=="slam"?GameData.Rules["boss"][next].N("radius")-.3f:12;}
    bool moving=distance>reach;
    e.View.transform.rotation=Quaternion.LookRotation(dir.sqrMagnitude>.01f?dir:Vector3.forward);
    if(moving)e.View.transform.position=Move(e.View.transform.position,ChaseDirection(e.View.transform.position)*speed*dt,.45f);else if(ranged&&distance<4)e.View.transform.position=Move(e.View.transform.position,-dir*speed*dt,.45f);
    e.View.Tick(dt,moving);
    if(e.Cooldown>0||distance>reach+.5f)continue;e.Cooldown=e.Data.N("attackCooldown",1.5f);
    if(e.Id=="boss"){StartCoroutine(BossCast(e));continue;}
    e.View.Play("Attack",.6f);
    if(e.Id=="healer"||e.Id=="commander")StartCoroutine(SupportCast(e));
    else if(e.Id=="mage"){
     e.Pattern++;if(e.Pattern%2==0&&e.RuneCooldown<=0){e.RuneCooldown=e.Data.N("runeCooldown",6.5f);StartCoroutine(EnemyArea(e,Player.transform.position,e.Data.N("runeRadius",150)*.02f,e.Data.N("runeFuse",1.4f)));}
     else StartCoroutine(EnemyShot(e,dir));
    }
    else if(e.Id=="archer")StartCoroutine(EnemyShot(e,dir));
    else StartCoroutine(EnemyMelee(e,dir));
   }
  }
  IEnumerator EnemyShot(Enemy e,Vector3 dir){e.Casting=true;yield return Delay(.3f);if(e.Hp>0)StartCoroutine(Projectile(e.View.transform.position,dir,e.Damage,e.Data.N("projectileSpeed",340)*.02f,12,true));yield return Delay(.3f);e.Casting=false;}
  IEnumerator EnemyMelee(Enemy e,Vector3 dir){yield return Delay(.3f);if(e.Hp>0&&(Player.transform.position-e.View.transform.position).magnitude<1.8f&&Vector3.Angle(dir,Player.transform.position-e.View.transform.position)<70)HurtPlayer(e.Damage*(e.Aura>0?1.25f:1));}
  IEnumerator SupportCast(Enemy e)
  {
   e.Casting=true;float reach=e.Data.N("supportRadius",250)*.02f;
   var target=Enemies.Where(a=>a!=e&&Vector3.Distance(a.View.transform.position,e.View.transform.position)<reach).OrderByDescending(a=>a.MaxHp-a.Hp).FirstOrDefault();
   yield return Delay(.4f);if(e.Hp>0){if(e.Id=="healer"&&target!=null&&target.Hp>0)target.Hp=Mathf.Min(target.MaxHp,target.Hp+e.Data.N("healAmount",20));else if(e.Id=="commander")foreach(var a in Enemies)if(a!=e&&a.Id!="boss"&&Vector3.Distance(a.View.transform.position,e.View.transform.position)<reach)a.Aura=e.Data.N("auraDuration",5);Effects.Ring(e.View.transform.position,reach,Color.green);}e.Casting=false;
  }
  IEnumerator AssassinStrike(Enemy e)
  {
   e.Casting=true;e.Cooldown=2;foreach(var r in e.View.GetComponentsInChildren<Renderer>())r.enabled=false;yield return Delay(.35f);
   if(e.Hp<=0)yield break;var offset=Quaternion.Euler(0,Random.Range(0,360),0)*Vector3.forward*3.2f;e.View.transform.position=Move(Player.transform.position,offset);
   foreach(var r in e.View.GetComponentsInChildren<Renderer>())r.enabled=true;
   float age=0;while(age<.6f&&e.Hp>0){if(Screen=="playing"){age+=Time.deltaTime;var dir=(Player.transform.position-e.View.transform.position).normalized;e.View.transform.position=Move(e.View.transform.position,dir*e.Data.N("moveSpeed")*.02f*4.5f*Time.deltaTime);if(Vector3.Distance(e.View.transform.position,Player.transform.position)<1){HurtPlayer(e.Damage);break;}}yield return null;}e.Casting=false;
  }
  IEnumerator EnemyArea(Enemy e,Vector3 pos,float radius,float delay){Effects.Ring(pos,radius,Color.red,delay+.1f);yield return Delay(delay);if(e.Hp>0&&Vector3.Distance(Player.transform.position,pos)<radius)HurtPlayer(e.Damage*1.7f);}
  IEnumerator BossCast(Enemy e)
  {
   e.Casting=true;string[] pattern={"attack","sweep","cast","charge","slam","summon"};string attack=pattern[e.Pattern++%pattern.Length];var spec=GameData.Rules["boss"][attack];var origin=e.View.transform.position;var dir=(Player.transform.position-origin).normalized;float radius=spec.N("radius"),windup=spec.N("windup"),recovery=spec.N("recovery");string clip=char.ToUpper(attack[0])+attack.Substring(1);float contact=spec.N("contact",.5f);e.View.Play(clip,windup/contact);var warning=BossWarning(origin,dir,radius,spec.N("arc",360),attack,windup);yield return Delay(windup);if(warning)Destroy(warning);if(e.Hp<=0){e.Casting=false;yield break;}
   e.View.PlaybackRate=e.View.ClipLength(clip)*(1-contact)/(recovery+(attack=="charge"?.6f:0));e.View.Locked=recovery+(attack=="charge"?.6f:0);
   if(attack=="summon"){for(int i=Enemies.Count;i<5;i++)SpawnEnemy("grunt",Move(origin,Quaternion.Euler(0,i*72,0)*Vector3.forward*4));}
   else if(attack=="cast"){for(int i=-1;i<=1;i++)StartCoroutine(Projectile(origin,Quaternion.Euler(0,i*.22f*Mathf.Rad2Deg,0)*dir,e.Damage*.7f,6.5f,14,true));}
   else if(attack=="charge"){float age=0;bool struck=false;while(age<.6f&&e.Hp>0){if(Screen!="playing"||hitStop>0){yield return null;continue;}float dt=Mathf.Min(Time.deltaTime,.6f-age);age+=dt;var previous=e.View.transform.position;var intended=previous+dir*(8/.6f)*dt;var actual=Move(previous,intended-previous,.65f);if(Vector3.Distance(actual,intended)>.15f)break;e.View.transform.position=actual;if(!struck&&SegmentDistance(Player.transform.position,previous,actual)<1.36f){HurtPlayer(e.Damage*1.35f);struck=true;}yield return null;}}
   else if(Vector3.Distance(Player.transform.position,origin)<=radius+.36f&&Vector3.Angle(dir,Player.transform.position-origin)<=spec.N("arc",360)*.5f)HurtPlayer(e.Damage*spec.N("damage",1));
   yield return Delay(recovery);e.Casting=false;e.Cooldown=.45f;
  }
  GameObject BossWarning(Vector3 origin,Vector3 direction,float radius,float arc,string attack,float lifetime)
  {
   var go=new GameObject("Boss "+attack+" warning");go.transform.SetParent(actorRoot);go.transform.position=origin+Vector3.up*.05f;var line=go.AddComponent<LineRenderer>();line.useWorldSpace=false;line.loop=true;line.startWidth=line.endWidth=.09f;line.material=Effects.Mat(new Color(1,.35f,.15f));
   if(attack=="charge"){var side=Vector3.Cross(direction,Vector3.up);line.positionCount=4;line.SetPositions(new[]{-side,side,direction*radius+side,direction*radius-side});}
   else{line.positionCount=51;line.SetPosition(0,Vector3.zero);for(int i=0;i<=48;i++)line.SetPosition(i+1,Quaternion.Euler(0,-arc*.5f+arc*i/48,0)*direction*radius);line.SetPosition(50,Vector3.zero);}
   Destroy(go,lifetime+.1f);return go;
  }
 }
}
