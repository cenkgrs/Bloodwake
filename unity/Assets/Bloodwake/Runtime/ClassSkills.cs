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
   if(Player.Locked>.15f)return;var cls=GameData.Rules["classes"][Run.ClassId];string id=index==2?cls.S("ability"):(string)cls["skills"][index];
   if(Run.Cooldowns.TryGetValue(id,out float cd)&&cd>0)return;var data=GameData.Row("abilities",id);Run.Cooldowns[id]=data.N("cooldown");StartCoroutine(CastRoutine(data,index==2));
  }
  IEnumerator CastRoutine(JObject data,bool ultimate)
  {
   string behavior=data.S("behavior");float range=data.N("range")*.02f*Run.Stats.N("attackRange"),radius=data.N("blastRadius",data.N("range"))*.02f,damage=data.N("damage")*Run.Stats.N("damage");
   var start=Player.transform.position;var dir=aim;var target=GroundTarget(range);Player.transform.rotation=Quaternion.LookRotation(dir);
   if(behavior=="markOfRuin"){var e=Enemies.Where(x=>Vector3.Distance(x.View.transform.position,start)<range).OrderBy(x=>Vector3.Distance(start,x.View.transform.position)).FirstOrDefault();if(e!=null){foreach(var other in Enemies)other.Mark=0;markChain=0;e.Mark=float.PositiveInfinity;Effects.Ring(e.View.transform.position,.7f,Color.magenta,1);}yield break;}
   Player.Play(ultimate?"Ultimate":behavior=="bloodTeleport"?"Teleport":behavior=="powderCharge"?"BombThrow":behavior=="whirl"?"SpinAttack":behavior=="voidLeap"?"SunderLeap":"Attack",.8f);
   Sound(behavior=="meteor"?"skill_meteor_cast":"skill_leap_launch");
   if(behavior=="whirl"){float duration=Player.ClipLength("SpinAttack")/1.5f;Player.Play("SpinAttack",duration);for(int sweep=0;sweep<3;sweep++){yield return Delay(duration/4);Area(Player.transform.position,radius,damage/3);}yield break;}
   if(behavior=="ricochet"){yield return Delay(9f/60);StartCoroutine(Ricochet(start,dir,damage,range,(int)data.N("bounces",3),data.N("projectileSpeed",560)*.02f));yield break;}
   if(behavior=="fanShot"||behavior=="backstepVolley")
   {
    if(behavior=="fanShot"&&Run.ClassId=="gunslinger"){Player.Play("Ultimate");yield return Delay(29f/60);for(int shot=0;shot<9;shot++){var heading=Quaternion.Euler(0,360f*shot*6/52,0)*dir;StartCoroutine(Projectile(Player.transform.position,heading,damage*5/9,data.N("projectileSpeed",560)*.02f,range,false));Sound("gun_pistol");if(shot<8)yield return Delay(6f/60);}yield break;}
    if(behavior=="backstepVolley")Player.transform.position=Move(start,-dir*2.6f*Run.Stats.N("attackRange"));
    yield return Delay(.18f);int count=behavior=="fanShot"?5:behavior=="backstepVolley"?3:1;
    for(int i=0;i<count;i++)StartCoroutine(Projectile(Player.transform.position,Quaternion.Euler(0,(i-(count-1)*.5f)*12,0)*dir,damage,data.N("projectileSpeed",560)*.02f,range,false,behavior=="ricochet"?3:0));yield break;
   }
   if(behavior=="bloodTeleport")
   {
    target=BlinkDestination(start,target);Player.Play("Teleport");invulnerable=25f/60;
    yield return Delay(15f/60);foreach(var r in Player.GetComponentsInChildren<Renderer>())r.enabled=false;yield return Delay(4f/60);Player.transform.position=target;yield return Delay(2f/60);foreach(var r in Player.GetComponentsInChildren<Renderer>())r.enabled=true;yield return Delay(4f/60);Area(target,radius,damage);yield return Delay(9f/60);Player.Locked=0;yield break;
   }
   if(behavior=="bloodBurst"){Player.Play("Ultimate");Effects.Ring(start,radius,blood,59f/60);yield return Delay(59f/60);Area(start,radius,damage);yield return Delay(25f/60);Player.Locked=0;yield break;}
   if(behavior=="shadowStrike"){target=Move(start,dir*range*.5f);float age=0;while(age<.12f){if(Screen=="playing"&&hitStop<=0){age+=Time.deltaTime;Player.transform.position=Vector3.Lerp(start,target,Mathf.Clamp01(age/.12f));}yield return null;}Area(target,65*.02f*Run.Stats.N("attackRange"),damage);yield break;}
   if(behavior=="voidLeap")
   {
    float elapsed=0;invulnerable=.6f;while(elapsed<.6f){if(Screen=="playing"){elapsed+=Time.deltaTime;Player.transform.position=Vector3.Lerp(start,target,Mathf.Clamp01(elapsed/.6f))+Vector3.up*Mathf.Sin(Mathf.PI*Mathf.Clamp01(elapsed/.6f))*2;}yield return null;}Player.transform.position=target;Area(target,radius,damage);yield break;
   }
   bool targeted=behavior=="meteor"||behavior=="powderCharge";Vector3 origin=targeted?target:start;float delay=behavior=="meteor"?Mathf.Clamp(Vector3.Distance(start,target)/(data.N("projectileSpeed",500)*.02f),.26f,.55f):behavior=="powderCharge"?19f/60+.45f:.3f;
   Effects.Ring(origin,radius,Color.red,delay);yield return Delay(delay);Area(origin,radius,damage);
   if(behavior=="frostNova")foreach(var e in Enemies)if(Vector3.Distance(e.View.transform.position,origin)<radius)e.Slow=3;
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
   while(remaining>0){if(Screen!="playing"||hitStop>0){yield return null;continue;}float step=speed*Time.deltaTime;position+=dir*step;remaining-=step;var victim=Enemies.FirstOrDefault(e=>!seen.Contains(e)&&Vector3.Distance(position,e.View.transform.position)<.8f);if(victim!=null){seen.Add(victim);DamageEnemy(victim,damage);if(bounces--<=0)break;var next=Enemies.Where(e=>!seen.Contains(e)&&Vector3.Distance(position,e.View.transform.position)<range).OrderBy(e=>Vector3.Distance(position,e.View.transform.position)).FirstOrDefault();if(next==null)break;dir=(next.View.transform.position-position).normalized;remaining=range;}Effects.Ring(position,.09f,gold,.07f);yield return null;}
  }
  void Area(Vector3 origin,float radius,float damage){foreach(var e in Enemies.ToArray())if(Vector3.Distance(e.View.transform.position,origin)<radius+.4f)DamageEnemy(e,damage);Effects.Ring(origin,radius,new Color(.8f,.2f,.1f),.5f);Sound("skill_meteor_blast");}
 }
}
