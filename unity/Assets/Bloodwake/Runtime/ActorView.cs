using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed class ActorView:MonoBehaviour
 {
  public Animator Animator; public float Locked,PlaybackRate=1; public string Kind; string state="";
  public static ActorView Create(string id,bool enemy,float height,Transform parent)
  {
   string name=enemy?"enemy_"+(id=="grunt"?"warrior":id):id=="gunslinger"?"bloodhound_player":id+"_player";
   var prefab=Resources.Load<GameObject>("Actors/"+name);
   if(prefab==null)throw new System.InvalidOperationException("Missing actor prefab: "+name);
   var go=new GameObject(id);go.transform.SetParent(parent,false);var model=Instantiate(prefab,go.transform);var view=go.AddComponent<ActorView>();view.Kind=id;
   view.Animator=model.GetComponentInChildren<Animator>();view.Animator.applyRootMotion=false;view.Animator.Rebind();view.Animator.Update(0);
   // These production rigs are authored at 1.8 m. Bind-pose renderer bounds
   // include weapons and are not a valid standing-height or foot-origin measure.
   model.transform.localScale*=height/1.8f;model.transform.localPosition=Vector3.zero;
   view.Play("Idle",0);return view;
  }
  public string Clip(string key)
  {
   if(Kind=="warrior"&&key=="Attack4")return "Ultimate";
   if(Kind=="revenant")return key switch{"Idle"=>"REV_AssassinIdle","Run"=>"REV_AssassinRun","Attack"=>"REV_ClawAttack_1","Attack1"=>"REV_ClawAttack_1","Attack2"=>"REV_ClawAttack_2","Attack3"=>"REV_ClawAttack_3","Hit"=>"REV_HitLight_Front","Death"=>"REV_Death","Teleport"=>"REV_TeleportAttack","Ultimate"=>"REV_BloodBurst",_=>key};
   if(Kind=="gunslinger")return key switch{"Idle"=>"BH_Idle","Run"=>"BH_Walk_InPlace","Attack"=>"BH_FiveShot","Hit"=>"BH_GetHit","Death"=>"BH_Death","Ultimate"=>"BH_Ultimate_BloodWake","BombThrow"=>"BH_BombThrow",_=>key};
   return key;
  }
  public float Play(string key,float hold=-1)
  {
   string clip=Clip(key);var anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);
   if(anim==null){clip=Clip("Attack");anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);}
   if(anim==null)return 0;
   if(state!=clip||hold!=0){PlaybackRate=hold>0?anim.length/hold:1;Animator.speed=PlaybackRate;Animator.CrossFadeInFixedTime(clip,.09f,0,0);state=clip;}
   Locked=hold==0?0:hold>0?hold:anim.length;return Locked;
  }
  public float ClipLength(string key)=>Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==Clip(key))?.length??.6f;
  public void Tick(float dt,bool moving,float rate=1){Locked=Mathf.Max(0,Locked-dt);if(Locked<=0){Play(moving?"Run":"Idle",0);PlaybackRate=moving?Mathf.Clamp(rate,.5f,2.5f):1;}Animator.speed=PlaybackRate;}
 }
 public static class Effects
 {
  static Material material;
  public static Material Mat(Color color){var m=new Material(Shader.Find("Universal Render Pipeline/Lit"));m.color=color;return m;}
  public static GameObject Ring(Vector3 position,float radius,Color color,float duration=.4f)
  {
   var go=new GameObject("Impact / warning");go.transform.position=position+Vector3.up*.05f;var line=go.AddComponent<LineRenderer>();line.useWorldSpace=false;line.loop=true;line.positionCount=64;line.startWidth=line.endWidth=.055f;
   if(material==null)material=Resources.Load<Material>("EffectUnlit");line.material=new Material(material);line.material.color=color;line.startColor=line.endColor=color;
   for(int i=0;i<64;i++){float a=i*Mathf.PI/32;line.SetPosition(i,new Vector3(Mathf.Sin(a)*radius,0,Mathf.Cos(a)*radius));}Object.Destroy(go,duration);return go;
  }
 }
}
