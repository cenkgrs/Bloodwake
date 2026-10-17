using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // Actors without an authored stride measurement get one from their own run clip, so steps match the
 // ground they cover instead of sliding.
 public sealed partial class ActorView
 {
  static readonly Dictionary<string,float> measuredStride=new();
  // In place, a planted foot travels back through one step while the body passes over it; a run cycle
  // is two steps. Speed at playback rate 1 is therefore twice the foot's fore-aft span per cycle length.
  public void CalibrateRunFromFeet()
  {
   if(LocomotionSpeed>0)return;string key=Kind+":"+Height.ToString("F2");
   if(!measuredStride.TryGetValue(key,out float speed))
   {
    var clip=Animator.runtimeAnimatorController.animationClips.FirstOrDefault(c=>c.name==Clip("Run"));
    var foot=Animator.GetComponentsInChildren<Transform>().FirstOrDefault(t=>t.name.EndsWith("LeftFoot"));
    if(!clip||!foot)return;var root=Animator.transform;float min=float.PositiveInfinity,max=float.NegativeInfinity;
    for(int i=0;i<40;i++){clip.SampleAnimation(Animator.gameObject,clip.length*i/40);float along=Vector3.Dot(foot.position-root.position,root.forward);min=Mathf.Min(min,along);max=Mathf.Max(max,along);}
    speed=clip.length>0?2*(max-min)/clip.length:0;measuredStride[key]=speed;
    Debug.Log($"LOCOMOTION_CALIBRATED {Kind} span={max-min:F3}m cycle={clip.length:F3}s speed={speed:F3}m/s");
   }
   if(speed>.2f)LocomotionSpeed=speed;
  }
 }
}
