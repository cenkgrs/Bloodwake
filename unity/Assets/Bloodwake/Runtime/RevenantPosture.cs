using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The Revenant's walk and run are authored deep in a sneaking crouch. While he moves, this straightens
 // him on top of the clips: the spine leans back, the head comes forward to keep his eyes level, and the
 // hips rise a little with the legs re-solved so the feet stay where the clip planted them.
 public sealed class RevenantPosture:MonoBehaviour
 {
  public ActorView Owner;
  // Degrees taken out of the forward lean, per spine bone (lower to upper), and given back at the neck.
  static readonly float[] SpineBack={9,8,5};const float NeckForward=8,HipLift=.07f;
  Transform hips,neck;Transform[] spine;Transform[] upLeg=new Transform[2],leg=new Transform[2],foot=new Transform[2];float weight;
  void Start()
  {
   var bones=GetComponentsInChildren<Transform>();Transform Find(string n)=>bones.FirstOrDefault(b=>b.name.EndsWith(":"+n)||b.name==n);
   hips=Find("Hips");neck=Find("Neck");spine=new[]{Find("Spine"),Find("Spine1"),Find("Spine2")};
   upLeg[0]=Find("LeftUpLeg");leg[0]=Find("LeftLeg");foot[0]=Find("LeftFoot");upLeg[1]=Find("RightUpLeg");leg[1]=Find("RightLeg");foot[1]=Find("RightFoot");
  }
  void LateUpdate()
  {
   bool moving=Owner&&(Owner.CurrentClip=="REV_SwaggerWalk"||Owner.CurrentClip=="REV_StandardRun"||Owner.CurrentClip=="REV_SneakWalk");
   weight=Mathf.MoveTowards(weight,moving?1:0,Time.deltaTime/.18f);if(weight<=0||!hips)return;
   var right=Owner.transform.right;float scale=Owner.transform.lossyScale.y*Owner.Height/1.8f;
   // Remember where the clip put the feet before anything moves.
   var footPos=new Vector3[2];var footRot=new Quaternion[2];for(int i=0;i<2;i++)if(foot[i]){footPos[i]=foot[i].position;footRot[i]=foot[i].rotation;}
   hips.position+=Vector3.up*HipLift*scale*weight;
   for(int i=0;i<spine.Length;i++)if(spine[i])spine[i].rotation=Quaternion.AngleAxis(-SpineBack[i]*weight,right)*spine[i].rotation;
   if(neck)neck.rotation=Quaternion.AngleAxis(NeckForward*weight,right)*neck.rotation;
   for(int i=0;i<2;i++)if(upLeg[i]&&leg[i]&&foot[i])SolveLeg(upLeg[i],leg[i],foot[i],footPos[i],footRot[i]);
  }
  // Two-bone IK in the leg's own bend plane: thigh, shin, foot back onto the clip's foot position.
  static void SolveLeg(Transform upper,Transform lower,Transform end,Vector3 target,Quaternion endRotation)
  {
   Vector3 a=upper.position,b=lower.position,c=end.position;float l1=(b-a).magnitude,l2=(c-b).magnitude;if(l1<.001f||l2<.001f)return;
   var toTarget=target-a;float d=Mathf.Clamp(toTarget.magnitude,.01f,l1+l2-.001f);var dir=toTarget.normalized;
   // Keep the knee bending the way the clip bent it.
   var pole=Vector3.ProjectOnPlane(b-a,dir);if(pole.sqrMagnitude<.000001f)pole=Vector3.ProjectOnPlane(upper.forward,dir);pole.Normalize();
   float cosA=Mathf.Clamp((l1*l1+d*d-l2*l2)/(2*l1*d),-1,1),sinA=Mathf.Sqrt(1-cosA*cosA);
   var knee=a+dir*cosA*l1+pole*sinA*l1;
   upper.rotation=Quaternion.FromToRotation(b-a,knee-a)*upper.rotation;
   var bNow=lower.position;lower.rotation=Quaternion.FromToRotation(end.position-bNow,target-bNow)*lower.rotation;
   end.rotation=endRotation;
  }
 }
}
