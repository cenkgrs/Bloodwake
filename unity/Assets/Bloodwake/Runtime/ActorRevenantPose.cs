using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class ActorView
 {
  int revenantPose;Transform[] poseBones;Quaternion[] poseRest,poseEntry;Vector3[] poseEntryPosition;float poseDuration;
  public bool HasRevenantThrust=>NobleRevenant&&Animator.runtimeAnimatorController.animationClips.Any(c=>c.name=="REV_ClawThrust");
  public float RevenantPosePhase;
  public bool RevenantPoseActive=>revenantPose!=0;
  public void BeginRevenantDashPose(float duration)=>BeginRevenantPose(1,"Run",.16f,duration);
  // No synthetic arm IK: only enable the combo when a real authored clip is installed.
  public void BeginRevenantThrustPose(float duration){if(HasRevenantThrust)BeginRevenantPose(2,"REV_ClawThrust",0,duration);}
  void BeginRevenantPose(int mode,string clip,float sample,float duration)
  {
   EndRevenantPose();CancelAction();Play(clip,duration);
   poseBones=Animator.GetComponentsInChildren<Transform>();poseEntry=poseBones.Select(t=>t.localRotation).ToArray();poseEntryPosition=poseBones.Select(t=>t.localPosition).ToArray();poseDuration=duration;
   Animator.Play(Clip(clip),0,sample);Animator.Update(0);PlaybackRate=0;Animator.speed=0;
   poseBones=Animator.GetComponentsInChildren<Transform>();poseRest=poseBones.Select(t=>t.localRotation).ToArray();
   revenantPose=mode;RevenantPosePhase=0;Locked=duration+.03f;
  }
  public void EndRevenantPose()
  {
   if(revenantPose==0)return;
   if(revenantPose==1)RestorePose();revenantPose=0;PlaybackRate=1;if(Animator)Animator.speed=1;
   if(reactionPivot)reactionPivot.localRotation=Quaternion.identity;
   Play("Idle",0);
  }
  void RestorePose(){if(poseBones==null)return;for(int i=0;i<poseBones.Length;i++)if(poseBones[i])poseBones[i].localRotation=poseRest[i];}
  void LateUpdate(){ApplyRevenantPose();}
  public void ApplyRevenantPose()
  {
   if(revenantPose==0||IsDead)return;RestorePose();
   if(revenantPose==1)
   {
    // Hold the forward-leaning run silhouette instead of accelerating its foot cycle.
    if(reactionPivot)reactionPivot.localRotation=Quaternion.Euler(3*Mathf.Sin(RevenantPosePhase*Mathf.PI),0,0);
    return;
   }
   Animator.Play("REV_ClawThrust",0,Mathf.Min(.999f,RevenantPosePhase));Animator.Update(0);
   float blend=Mathf.SmoothStep(0,1,Mathf.Clamp01(RevenantPosePhase*poseDuration/.075f));
   if(blend<1)for(int i=0;i<poseBones.Length;i++)if(poseBones[i])
   {poseBones[i].localRotation=Quaternion.Slerp(poseEntry[i],poseBones[i].localRotation,blend);poseBones[i].localPosition=Vector3.Lerp(poseEntryPosition[i],poseBones[i].localPosition,blend);}
  }
 }
}
