using UnityEngine;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  // The enemy mage's bomb: an orb of magenta energy arcs to the spot, settles on the stone and throbs
  // faster and brighter as the fuse runs out, spitting sparks. The caller destroys it at the blast.
  public GameObject MageBomb(Vector3 from,Vector3 at,float flight,float fuse,Color tone)
  {
   var orb=Orb(from,true,true);orb.transform.localScale*=1.25f;var lamp=orb.GetComponentInChildren<Light>();
   var rest=at+Vector3.up*.38f;var top=Vector3.Lerp(from,rest,.5f)+Vector3.up*1.8f;
   var fx=Life(orb.gameObject,fuse+.2f);float sparks=0;
   fx.Tick=(p,dt)=>
   {
    float age=fx.Age;
    if(age<flight)
    {
     float t=age/flight;var a=Vector3.Lerp(from,top,t);var b=Vector3.Lerp(top,rest,t);orb.transform.position=Vector3.Lerp(a,b,t);
     if(Random.value<.6f)Glow(orb.transform.position,tone,.22f,1.6f,.25f);return;
    }
    // On the ground: the throb quickens from about 3 to 14 beats a second toward the end of the fuse.
    float left=Mathf.Clamp01((age-flight)/Mathf.Max(.01f,fuse-flight)),rate=Mathf.Lerp(3,14,left*left);
    float beat=.5f+.5f*Mathf.Sin(age*rate*Mathf.PI*2);
    orb.transform.position=rest;orb.transform.localScale=Vector3.one*1.25f*Mathf.Lerp(.9f,1.35f,beat)*Mathf.Lerp(1,1.3f,left);
    if(lamp){lamp.intensity=Mathf.Lerp(.8f,4.5f,beat*(.4f+.6f*left));lamp.range=Mathf.Lerp(2,4.5f,left);}
    if((sparks-=dt)<=0){sparks=Mathf.Lerp(.14f,.04f,left);Sparks(rest,tone,3,.3f,1.2f,3.2f);}
   };
   return orb.gameObject;
  }
 }
}
