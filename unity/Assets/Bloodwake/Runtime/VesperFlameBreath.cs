using System.Collections;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // Vesper's L1 + R2 (left Alt + right mouse): the free left hand comes up and pours a jet of fire where
 // the stick points, for up to a second or until another attack, dash or skill takes over.
 public sealed partial class BloodwakeGame
 {
  bool flameBreathing;
  const float FlameBreathMax=1f,FlameBreathRange=4.6f,FlameBreathCone=34f,FlameBreathTick=.1f;
  void BeginFlameBreath()
  {
   // The left hand is free while the greatsword is in flight, so the breath works then too.
   if(Run?.ClassId!="vesper"||flameBreathing||vesperMoveActive||RevenantActionActive||Run.Stats.N("hp")<=0)return;
   StartCoroutine(FlameBreath());
  }
  // Any other action ends the jet at once and goes ahead the same frame.
  void StopFlameBreath(){if(!flameBreathing)return;flameBreathing=false;vesperMoveActive=false;var arm=Player?Player.GetComponentInChildren<VesperFlameArm>():null;if(arm)arm.Raised=false;}
  IEnumerator FlameBreath()
  {
   flameBreathing=true;vesperMoveActive=true;PadFacing();
   var arm=Player.GetComponentInChildren<VesperFlameArm>();if(!arm)arm=Player.Animator.gameObject.AddComponent<VesperFlameArm>();arm.Raised=true;
   var hand=Player.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("LeftHand"));
   Sound(Voice("vesper_flame_breath","vesper_bloodfire_rite"));
   float age=0,tick=0,emit=0,glow=0;float damage=VesperBasicDamage()*.32f;string jetKind=RevenantVfx.JetKind;float jetCard=0;
   while(flameBreathing&&age<FlameBreathMax&&Run.Stats.N("hp")>0)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float dt=Time.deltaTime;age+=dt;
    // The stick steers the jet; she turns on the spot to follow it.
    var want=!usingPad?aim:moveIntent.sqrMagnitude>.01f?moveIntent:Player.transform.forward;want.y=0;
    if(want.sqrMagnitude>.001f)Player.transform.rotation=Quaternion.RotateTowards(Player.transform.rotation,Quaternion.LookRotation(want.normalized),540*dt);
    var dir=Player.transform.forward;Player.Locked=Mathf.Max(Player.Locked,.1f);
    var origin=hand?hand.position+dir*.12f:Player.transform.position+Vector3.up*1.3f+dir*.45f;
    // A dense stream of flame tongues rushing out and widening; the first ones in reach the full length.
    float ramp=Mathf.Clamp01(age/.12f);
    // With the painted jet sheet: big flipbook cards anchored at the palm carry the stream; fewer loose
    // tongues add volume around it.
    bool painted=jetKind=="jet";
    if(painted&&(jetCard-=dt)<=0){jetCard=.09f;RevFx.FlameJetCard(origin,Quaternion.Euler(0,Random.Range(-3f,3f),0)*dir,Random.Range(3.4f,4f)*Mathf.Max(.45f,ramp),.28f);}
    for(emit-=dt;emit<=0;emit+=painted?.07f:.011f)
    {
     // Big overlapping tongues so the stream reads as one jet, fanning a little as it travels.
     var side=Vector3.Cross(Vector3.up,dir);float spread=Random.Range(-1f,1f);
     var drift=dir*Random.Range(10f,13f)+side*spread*2.2f+Vector3.up*Random.Range(-.2f,.5f);
     RevFx.FlameCard(origin-Vector3.up*.45f,painted?Random.Range(.4f,.6f):Random.Range(.75f,1.15f),Random.Range(.26f,.34f)*Mathf.Max(.4f,ramp),drift,0,painted?1.8f:3.2f,"flame");
    }
    if(Random.value<dt*18)RevFx.FlameCard(origin-Vector3.up*.2f,Random.Range(.4f,.55f),.14f,dir*2,0,4f,"burst",hand);
    if((glow-=dt)<=0){glow=.08f;RevFx.Flash(origin+dir*1.6f,RevenantVfx.Tone("ff9a3c"),1.1f,3.2f,.1f);}
    if((tick-=dt)<=0)
    {
     tick=FlameBreathTick;var flat=new Vector3(origin.x,0,origin.z);
     DamageCargoSegment(flat,flat+dir*FlameBreathRange*.8f,.9f);
     foreach(var e in Enemies.ToArray())
     {
      if(e.Emerging||e.Hp<=0||!e.View)continue;var d=e.View.transform.position-flat;d.y=0;
      if(d.magnitude>FlameBreathRange+.4f||Vector3.Angle(dir,d)>FlameBreathCone*.5f+12)continue;
      // Ticks, not blows: no hit stop per tick, but each one shows and keeps the target burning.
      DamageEnemy(e,damage,false);if(!e.View)continue;RevFx.DamageText(e.View.transform.position,damage,RevenantVfx.Tone("ffb347"));
      e.View.FlashHit(false);Ignite(e,2.2f,damage*.6f);
      if(e.Id!="boss"){e.RecoilDirection=dir;e.RecoilRemaining=Mathf.Max(e.RecoilRemaining,.12f);e.RecoilTime=Mathf.Max(e.RecoilTime,.1f);}
     }
    }
    yield return null;
   }
   if(flameBreathing){flameBreathing=false;vesperMoveActive=false;arm.Raised=false;attackCd=Mathf.Max(attackCd,.12f);}
  }
 }
 // Lifts the left arm off the animation and points it along the jet while Vesper breathes fire.
 public sealed class VesperFlameArm:MonoBehaviour
 {
  public bool Raised;float weight;Transform upper,fore,hand,root;
  void Start()
  {
   var bones=GetComponentsInChildren<Transform>();upper=bones.FirstOrDefault(t=>t.name.EndsWith("LeftArm"));fore=bones.FirstOrDefault(t=>t.name.EndsWith("LeftForeArm"));
   hand=bones.FirstOrDefault(t=>t.name.EndsWith("LeftHand"));root=transform;
  }
  void LateUpdate()
  {
   weight=Mathf.MoveTowards(weight,Raised?1:0,Time.deltaTime/(Raised?.08f:.18f));if(weight<=0||!upper||!fore||!hand)return;
   // Straight out ahead at chest height, a touch down so the palm faces the ground ahead of her.
   var target=(root.forward+Vector3.down*.08f).normalized;
   Aim(upper,fore.position-upper.position,target);Aim(fore,hand.position-fore.position,target);
  }
  void Aim(Transform bone,Vector3 current,Vector3 target)
  {
   if(current.sqrMagnitude<.0001f)return;var turn=Quaternion.FromToRotation(current.normalized,target);
   bone.rotation=Quaternion.Slerp(Quaternion.identity,turn,weight)*bone.rotation;
  }
 }
}
