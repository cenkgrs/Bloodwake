using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed class ActorView:MonoBehaviour
 {
  public Animator Animator; public float Locked,PlaybackRate=1; public string Kind;public float Height {get;private set;} string state="";
  readonly System.Collections.Generic.Dictionary<string,System.Action> markers=new();
  Transform reactionPivot;Vector3 reactionAxis;float reactionAge=1,reactionDegrees,reactionDuration=.28f;
  public void ImpactPose(Vector3 source,float degrees,float duration=.28f)
  {
   var away=transform.InverseTransformDirection(transform.position-source);away.y=0;
   reactionAxis=Vector3.Cross(Vector3.up,away.sqrMagnitude>.001f?away.normalized:Vector3.back);
   reactionAge=0;reactionDegrees=degrees;reactionDuration=Mathf.Max(.05f,duration);
  }
  void TickImpact(float dt)
  {
   if(!reactionPivot)return;reactionAge+=dt;
   float rise=Mathf.Clamp01(reactionAge/.045f),recover=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.045f,reactionDuration,reactionAge));
   reactionPivot.localRotation=IsDead?Quaternion.identity:Quaternion.AngleAxis(reactionDegrees*rise*recover,reactionAxis);
  }
  public void OnMarker(string marker,System.Action action)=>markers[marker]=action;
  public void CancelAction(){markers.Clear();SetVisible(true);}
  public bool Visible {get;private set;}=true;
  public bool ContactPending=>markers.ContainsKey("DAMAGE");
  public bool IsCasting=>Locked>0&&(state==Clip("Teleport")||state==Clip("Ultimate"));
  public bool IsDead=>state==Clip("Death");
  public void SetVisible(bool visible){Visible=visible;foreach(var r in Animator.GetComponentsInChildren<Renderer>())r.enabled=visible;}
  public void ReceiveMarker(AnimationEvent evt)
  {
   if(evt.animatorClipInfo.clip==null||evt.animatorClipInfo.clip.name!=state)return;
   if(markers.TryGetValue(evt.stringParameter,out var action)){markers.Remove(evt.stringParameter);action();}
  }
  public static ActorView Create(string id,bool enemy,float height,Transform parent)
  {
   string name=enemy?"enemy_"+(id=="grunt"?"warrior":id):id=="gunslinger"?"bloodhound_player":id+"_player";
   var prefab=Resources.Load<GameObject>("Actors/"+name);
   if(prefab==null)throw new System.InvalidOperationException("Missing actor prefab: "+name);
   var go=new GameObject(id);go.transform.SetParent(parent,false);var pivot=new GameObject("Impact pose").transform;pivot.SetParent(go.transform,false);var model=Instantiate(prefab,pivot);var view=go.AddComponent<ActorView>();view.Kind=id;view.Height=height;view.reactionPivot=pivot;
   view.Animator=model.GetComponentInChildren<Animator>();view.Animator.gameObject.AddComponent<RevenantMarkerRelay>().Owner=view;view.Animator.applyRootMotion=false;view.Animator.Rebind();view.Animator.Update(0);
   // These production rigs are authored at 1.8 m. Bind-pose renderer bounds
   // include weapons and are not a valid standing-height or foot-origin measure.
   model.transform.localScale*=height/1.8f;model.transform.localPosition=Vector3.zero;
   foreach(var renderer in model.GetComponentsInChildren<Renderer>())renderer.renderingLayerMask|=2u;
   view.Play("Idle",0);return view;
  }
  Transform magicHand;
  public Vector3 MagicPalmPosition()
  {
   if(!magicHand)magicHand=Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("RightHand"));
   return magicHand?magicHand.position+magicHand.rotation*new Vector3(0,.1f,.035f):transform.position+Vector3.up*1.2f;
  }
  Transform rightSocket,leftSocket;
  public Transform MuzzleSocket(string side)
  {
   var bone=side=="L"?leftSocket:rightSocket;
   if(!bone){bone=Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name=="WeaponSocket."+side);if(side=="L")leftSocket=bone;else rightSocket=bone;}
   return bone;
  }
  public Vector3 MuzzlePosition(string side)
  {
   var bone=MuzzleSocket(side);
   // FBX bones use centimetres; source socket offsets are in metres.
   return bone?bone.TransformPoint(new Vector3(side=="L"?-.068f:.073f,.266f,.035f)*.01f):transform.position+Vector3.up;
  }
  float hitRemaining,legsWeight;
  public void HitOverlay()
  {
   int layer=Animator.GetLayerIndex("Upper body hit");if(Kind!="revenant"||layer<0||IsDead)return;
   string clip="REV_HitLight_"+new[]{"Front","Left","Right"}[Random.Range(0,3)]+"_Additive";
   hitRemaining=Animator.runtimeAnimatorController.animationClips.First(c=>c.name==clip).length;
   Animator.SetFloat("RevenantHitSpeed",1/Mathf.Max(.01f,PlaybackRate));Animator.SetLayerWeight(layer,1);Animator.Play(clip,layer,0);
  }
  void TickLayers(float dt,bool moving,float rate)
  {
   if(Kind!="revenant")return;int legs=Animator.GetLayerIndex("Moving attack legs"),hit=Animator.GetLayerIndex("Upper body hit");if(legs<0||hit<0)return;
   hitRemaining=Mathf.Max(0,hitRemaining-dt);Animator.SetLayerWeight(hit,hitRemaining>0&&!IsDead?1:0);
   bool layered=moving&&!IsDead&&state.StartsWith("REV_ClawAttack")&&Locked>0;legsWeight=Mathf.MoveTowards(legsWeight,layered?1:0,dt*10);
   Animator.SetLayerWeight(legs,legsWeight);Animator.SetFloat("RevenantLegSpeed",rate*.85f/Mathf.Max(.01f,PlaybackRate));Animator.SetFloat("RevenantHitSpeed",1/Mathf.Max(.01f,PlaybackRate));
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
   if(key=="Death"){reactionAge=1;if(reactionPivot)reactionPivot.localRotation=Quaternion.identity;hitRemaining=0;legsWeight=0;TickLayers(0,false,1);}
   string clip=Clip(key);var anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);
   if(anim==null){clip=Clip("Attack");anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);}
   if(anim==null)return 0;
   if(state!=clip||hold!=0){CancelAction();PlaybackRate=hold>0?anim.length/hold:1;Animator.speed=PlaybackRate;Animator.CrossFadeInFixedTime(clip,.09f,0,0);state=clip;}
   Locked=hold==0?0:hold>0?hold:anim.length;return Locked;
  }
  public float ClipLength(string key)=>Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==Clip(key))?.length??.6f;
  public void Tick(float dt,bool moving,float rate=1){Locked=Mathf.Max(0,Locked-dt);if(Locked<=0){Play(moving?"Run":"Idle",0);PlaybackRate=moving?Mathf.Clamp(rate*(Kind=="revenant"?.85f:1),.5f,2.5f):1;}Animator.speed=PlaybackRate;TickLayers(dt,moving,rate);TickImpact(dt);}
 }
 public sealed class RevenantMarkerRelay:MonoBehaviour
 {
  public ActorView Owner;
  public void OnRevenantMarker(AnimationEvent evt){if(Owner)Owner.ReceiveMarker(evt);}
 }
 public static class Effects
 {
  static Material material;
  static readonly System.Collections.Generic.Dictionary<Color,Material> palette=new();
  public static Material Mat(Color color){if(palette.TryGetValue(color,out var m)&&m)return m;m=new Material(Shader.Find("Universal Render Pipeline/Lit")){color=color};palette[color]=m;return m;}
  public static void Release(){foreach(var m in palette.Values)if(m)Object.Destroy(m);palette.Clear();material=null;}
  public static GameObject Ring(Vector3 position,float radius,Color color,float duration=.4f)
  {
   var go=new GameObject("Fractured impact");go.transform.position=position+Vector3.up*.055f;
   if(material==null)material=Resources.Load<Material>("EffectUnlit");var tint=new MaterialPropertyBlock();tint.SetColor("_BaseColor",color);
   int count=radius>.45f?11:3;
   for(int i=0;i<count;i++)
   {
    float angle=(i+.5f)*Mathf.PI*2/count+Mathf.Sin(i*17.31f)*.18f;var direction=new Vector3(Mathf.Sin(angle),0,Mathf.Cos(angle));var side=new Vector3(direction.z,0,-direction.x);
    var shard=new GameObject("Impact fissure");shard.transform.SetParent(go.transform,false);var line=shard.AddComponent<LineRenderer>();line.useWorldSpace=false;line.loop=false;line.positionCount=3;line.startWidth=.018f;line.endWidth=.045f;line.numCornerVertices=1;
    line.SetPosition(0,direction*radius*.12f);line.SetPosition(1,direction*radius*.53f+side*radius*(Mathf.Sin(i*4.7f)*.07f));line.SetPosition(2,direction*radius*(.78f+.19f*Mathf.Abs(Mathf.Sin(i*2.3f))));
    line.sharedMaterial=material;line.SetPropertyBlock(tint);line.startColor=line.endColor=Color.white;
   }
   Object.Destroy(go,duration);return go;
  }
 }
}
