using UnityEngine;
namespace Bloodwake
{
 // Weight on contact: the struck body trembles through the hit stop and squashes along the blow, then
 // springs back. Runs on unscaled time so it keeps moving while the game is frozen on the impact.
 public sealed class HitShake:MonoBehaviour
 {
  Transform target;Vector3 basePosition,baseScale,kick;float remaining,duration,amplitude,squash;
  public void Initialize(Transform model){target=model;basePosition=model.localPosition;baseScale=model.localScale;}
  public void Hit(Vector3 worldDirection,float strength)
  {
   if(!target)return;strength=Mathf.Clamp(strength,.2f,2);
   duration=.16f+.1f*strength;remaining=duration;amplitude=.03f+.045f*strength;squash=.07f+.07f*strength;
   worldDirection.y=0;kick=worldDirection.sqrMagnitude>.0001f?target.parent.InverseTransformDirection(worldDirection.normalized):Vector3.zero;
  }
  void LateUpdate()
  {
   if(!target||remaining<=0)return;
   remaining=Mathf.Max(0,remaining-Time.unscaledDeltaTime);float k=remaining/duration,t=1-k;
   if(remaining<=0){target.localPosition=basePosition;target.localScale=baseScale;return;}
   // Hard jitter that dies out, plus a shove along the blow that settles back.
   var jitter=new Vector3(Random.Range(-1f,1f),Random.Range(-.3f,.3f),Random.Range(-1f,1f))*amplitude*k*k;
   target.localPosition=basePosition+jitter+kick*amplitude*2.2f*Mathf.Sin(Mathf.Min(1,t*2.2f)*Mathf.PI)*k;
   // Damped spring: flattened on the impact, a little stretched on the rebound.
   float s=squash*Mathf.Exp(-5*t)*Mathf.Cos(t*16);
   target.localScale=new Vector3(baseScale.x*(1+s*.55f),baseScale.y*(1-s),baseScale.z*(1+s*.55f));
  }
  void OnDisable(){if(target){target.localPosition=basePosition;target.localScale=baseScale;}remaining=0;}
 }
}
