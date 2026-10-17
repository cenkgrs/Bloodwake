using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class ActorView:MonoBehaviour
 {
  public Animator Animator; public float Locked,PlaybackRate=1; public string Kind;public float Height {get;private set;} string state="";
  readonly System.Collections.Generic.Dictionary<string,System.Action> markers=new();
  Transform reactionPivot;Vector3 reactionAxis;float reactionAge=1,reactionDegrees,reactionDuration=.28f;
  public const float SpawnDelay=.35f,SpawnRiseTime=.9f;
  public float SpawnRemaining {get;private set;}
  public bool Emerging=>SpawnRemaining>0;
  public float VisualSpawnOffset=>reactionPivot?reactionPivot.localPosition.y:0;
  public void BeginEmergence()
  {
   CancelAction();Play("Idle",0);SpawnRemaining=SpawnDelay+SpawnRiseTime;
   reactionPivot.localPosition=Vector3.down*(Height+.25f);SetVisible(false);Animator.speed=0;
  }
  public void TickEmergence(float dt)
  {
   if(!Emerging)return;
   SpawnRemaining=Mathf.Max(0,SpawnRemaining-Mathf.Max(0,dt));
   float rise=Mathf.Clamp01(1-SpawnRemaining/SpawnRiseTime);
   // Move only the visual pivot: NavMesh and spawn reservations remain on the street.
   reactionPivot.localPosition=Vector3.down*(Height+.25f)*Mathf.Pow(1-rise,3);
   SetVisible(SpawnRemaining<SpawnRiseTime);Animator.speed=SpawnRemaining<SpawnRiseTime?1:0;
   if(!Emerging){reactionPivot.localPosition=Vector3.zero;SetVisible(true);}
  }
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
  public bool IsCasting=>Locked>0&&(state==Clip("Teleport")||state==Clip("Ultimate")||state==Clip("CastQ")||state=="REV_BloodClap");
  public bool NobleRevenant=>Kind=="revenant"&&Animator.runtimeAnimatorController.name=="revenant_noble";
  public float LocomotionSpeed {get;private set;}
  public bool HasWarriorSlashes {get;private set;}
  public WarriorTurnData TurnData {get;private set;}
  public HitFlash HitFlash {get;private set;}
  public HitShake Shake {get;private set;}
  public void FlashHit(bool player)=>HitFlash.Pulse(player);
  [System.Serializable]class StrideCalibration {public float referenceSpeed,referenceHeight;}
  public float ActionStartTime(string key)=>NobleRevenant&&Clip(key)=="REV_BloodBurst"?ClipLength(key)*.15f:0;
  public float MarkerTime(string key,string marker)=>Mathf.Max(0,Animator.runtimeAnimatorController.animationClips.First(c=>c.name==Clip(key)).events.First(e=>e.stringParameter==marker).time-ActionStartTime(key));
  public bool IsDead=>state==Clip("Death");
  public void SetVisible(bool visible){Visible=visible;foreach(var r in Animator.GetComponentsInChildren<Renderer>())r.enabled=visible;}
  public void ReceiveMarker(AnimationEvent evt)
  {
   if(evt.animatorClipInfo.clip==null||evt.animatorClipInfo.clip.name!=state)return;
   if(markers.TryGetValue(evt.stringParameter,out var action)){markers.Remove(evt.stringParameter);action();}
  }
  public static ActorView Create(string id,bool enemy,float height,Transform parent)
  {
   string name=enemy?"enemy_"+(id=="grunt"?"warrior":id):id+"_player";
   if(!enemy&&id=="revenant")name="revenant_noble";
   var prefab=Resources.Load<GameObject>("Actors/"+name);
   if(prefab==null)throw new System.InvalidOperationException("Missing actor prefab: "+name);
   var go=new GameObject(id);go.transform.SetParent(parent,false);var pivot=new GameObject("Impact pose").transform;pivot.SetParent(go.transform,false);var model=Instantiate(prefab,pivot);var view=go.AddComponent<ActorView>();view.Kind=id;view.Height=height;view.reactionPivot=pivot;
   view.Animator=model.GetComponentInChildren<Animator>();view.Animator.gameObject.AddComponent<RevenantMarkerRelay>().Owner=view;view.Animator.applyRootMotion=false;view.Animator.Rebind();view.Animator.Update(0);
   // These production rigs are authored at 1.8 m. Bind-pose renderer bounds
   // include weapons and are not a valid standing-height or foot-origin measure.
   model.transform.localScale*=height/1.8f;model.transform.localPosition=Vector3.zero;
   foreach(var renderer in model.GetComponentsInChildren<Renderer>())renderer.renderingLayerMask|=2u;
   view.HitFlash=go.AddComponent<HitFlash>();view.HitFlash.Initialize(model.GetComponentsInChildren<Renderer>());
   view.Shake=go.AddComponent<HitShake>();view.Shake.Initialize(model.transform);
   if(!enemy&&id=="vesper")model.AddComponent<VesperBladeVfx>();
   if(enemy&&id=="grunt"&&view.Animator.runtimeAnimatorController.animationClips.Any(c=>c.name=="Warrior_ShieldWalk"))
   {
    var calibration=JsonUtility.FromJson<StrideCalibration>(Resources.Load<TextAsset>("Animations/WarriorLocomotion/stride").text);
    view.LocomotionSpeed=calibration.referenceSpeed*height/calibration.referenceHeight;
   }
   view.HasWarriorSlashes=enemy&&id=="grunt"&&new[]{"Warrior_OutwardSlash","Warrior_InwardSlash"}.All(n=>view.Animator.runtimeAnimatorController.animationClips.Any(c=>c.name==n));
   if(enemy&&id=="grunt"&&view.Animator.runtimeAnimatorController.animationClips.Any(c=>c.name=="Warrior_Turn180"))
    view.TurnData=JsonUtility.FromJson<WarriorTurnData>(Resources.Load<TextAsset>("Animations/WarriorCombat/turn").text);
   view.Play("Idle",0);return view;
  }
  Transform magicHand;
  Transform clapLeftHand,clapRightHand;
  public Vector3 ClapPosition()
  {
   if(!clapLeftHand||!clapRightHand)
   {
    var bones=Animator.GetComponentsInChildren<Transform>();
    clapLeftHand=bones.FirstOrDefault(t=>t.name.EndsWith("LeftHand"));
    clapRightHand=bones.FirstOrDefault(t=>t.name.EndsWith("RightHand"));
   }
   return clapLeftHand&&clapRightHand?(clapLeftHand.position+clapRightHand.position)*.5f:MagicPalmPosition();
  }
  public Vector3 MagicPalmPosition()
  {
   if(!magicHand)magicHand=Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("RightHand"));
   return magicHand?magicHand.position+magicHand.rotation*new Vector3(0,.1f,.035f):transform.position+Vector3.up*1.2f;
  }
  float hitRemaining,legsWeight;
  public void HitOverlay()
  {
   if(NobleRevenant&&!IsDead){ImpactPose(transform.position+transform.forward,5,.22f);return;}
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
   Animator.SetLayerWeight(legs,legsWeight);Animator.SetFloat("RevenantLegSpeed",rate/Mathf.Max(.01f,PlaybackRate));Animator.SetFloat("RevenantHitSpeed",1/Mathf.Max(.01f,PlaybackRate));
  }
  public string Clip(string key)
  {
   if(Kind=="grunt"&&LocomotionSpeed>0&&(key=="Run"||key=="Walk"))return "Warrior_ShieldWalk";
   if(Kind=="warrior"&&key=="Attack4")return "Ultimate";
   if(Kind=="revenant")return key switch{"Idle"=>"REV_NeutralIdle","Walk"=>"REV_SwaggerWalk","Run"=>"REV_StandardRun","Attack"=>"REV_ClawAttack_1","Attack1"=>"REV_ClawAttack_1","Attack2"=>"REV_ClawAttack_2","Attack3"=>"REV_ClawAttack_3","Hit"=>"REV_HitLight_Front","Death"=>"REV_Death","Teleport"=>"REV_TeleportAttack","Ultimate"=>"REV_BloodBurst",_=>key};
   return key;
  }
  public float Play(string key,float hold=-1)
  {
   if(key=="Death"){EndRevenantPose();reactionAge=1;if(reactionPivot)reactionPivot.localRotation=Quaternion.identity;hitRemaining=0;legsWeight=0;TickLayers(0,false,1);}
   string clip=Clip(key);var anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);
   if(anim==null){clip=Clip("Attack");anim=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==clip);}
   if(anim==null)return 0;
   float start=ActionStartTime(clip),duration=anim.length-start;
   if(state!=clip||hold!=0){CancelAction();PlaybackRate=hold>0?duration/hold:1;Animator.speed=PlaybackRate;Animator.CrossFadeInFixedTime(clip,BlendTime(key),0,start);state=clip;}
   Locked=hold==0?0:hold>0?hold:duration;return Locked;
  }
  // The Warrior's swings end and begin in very different poses (deep lunge, overhead, spin); a short
  // blend snaps between them, so his attacks and their settle back to stance blend longer.
  float BlendTime(string key)=>Kind=="vesper"?.16f:Kind=="warrior"?(key.StartsWith("Attack")||key=="Ultimate"?.2f:state.StartsWith("Attack")||state=="Ultimate"?.24f:.12f):.09f;
  public float ClipLength(string key)=>Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==Clip(key))?.length??.6f;
  public void Tick(float dt,bool moving,float rate=1,bool walking=false){if(RevenantPoseActive){Locked=Mathf.Max(.03f,Locked-dt);Animator.speed=0;TickImpact(dt);return;}Locked=Mathf.Max(0,Locked-dt);if(Locked<=0){Play(moving?(Kind=="revenant"&&walking?"Walk":"Run"):"Idle",0);PlaybackRate=moving?Mathf.Clamp(rate,LocomotionSpeed>0?.01f:.5f,LocomotionSpeed>0?3:2.5f):1;}Animator.speed=PlaybackRate;TickLayers(dt,moving,rate);TickImpact(dt);}
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
