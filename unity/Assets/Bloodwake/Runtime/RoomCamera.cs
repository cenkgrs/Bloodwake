using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // Blender's FBX importer conversion mirrors source X, not source Z.
  readonly Vector3 cameraOffset=new Vector3(-12,14,16);
  // Closer than the old 6.5-7.2 so armour, faces and fire read like the art-direction frames.
  const float DefaultZoom=4.5f;
  Vector3 CameraFocus(Vector3 target)
  {
   if(room==null)return target;Vector3 forward=-cameraOffset.normalized,right=Vector3.Cross(Vector3.up,forward).normalized,up=Vector3.Cross(forward,right);
   float minX=float.PositiveInfinity,maxX=float.NegativeInfinity,minZ=float.PositiveInfinity,maxZ=float.NegativeInfinity;
   foreach(int x in new[]{-1,1})foreach(int y in new[]{-1,1}){var p=cameraOffset+right*x*Cam.orthographicSize*Cam.aspect+up*y*Cam.orthographicSize;var g=p+forward*(-p.y/forward.y);minX=Mathf.Min(minX,g.x);maxX=Mathf.Max(maxX,g.x);minZ=Mathf.Min(minZ,g.z);maxZ=Mathf.Max(maxZ,g.z);}
   float left=-half.x-5-minX,rightEdge=half.x+5-maxX,bottom=-half.y-7-minZ,top=half.y+4-maxZ;
   return new Vector3(left<=rightEdge?Mathf.Clamp(target.x,left,rightEdge):(left+rightEdge)/2,0,bottom<=top?Mathf.Clamp(target.z,bottom,top):(bottom+top)/2);
  }
  Vector3 cameraRest;float shakeTrauma,shakeSeed;Vector3 shakeKick;
  // Trauma-based screen shake; it keeps running through hit stop so the freeze frame reads as an impact.
  void ShakeCamera(float trauma,Vector3 direction)
  {
   shakeTrauma=Mathf.Min(1,Mathf.Max(shakeTrauma,trauma));direction.y=0;
   shakeKick=direction.sqrMagnitude>.0001f?direction.normalized:Vector3.zero;shakeSeed=Random.value*100;
   Rumble(trauma*.55f,trauma*.85f,.07f+trauma*.12f);
  }
  void PositionCamera(bool snap)
  {
   if(!Player)return;var focus=CameraFocus(Player.transform.position);var desired=focus+cameraOffset;
   cameraRest=snap||cameraRest==Vector3.zero?desired:Vector3.Lerp(cameraRest,desired,1-Mathf.Exp(-10*Time.unscaledDeltaTime));
   var offset=Vector3.zero;
   if(shakeTrauma>0&&!snap)
   {
    float power=shakeTrauma*shakeTrauma*Cam.orthographicSize*.09f,t=Time.unscaledTime*38;
    var right=Cam.transform.right;var up=Vector3.ProjectOnPlane(Vector3.up,Cam.transform.forward).normalized;
    offset=(right*(Mathf.PerlinNoise(shakeSeed,t)-.5f)+up*(Mathf.PerlinNoise(shakeSeed+7,t)-.5f))*2*power+shakeKick*power*.8f;
    shakeTrauma=Mathf.Max(0,shakeTrauma-Time.unscaledDeltaTime*3.2f);
   }
   else if(snap)shakeTrauma=0;
   Cam.transform.position=cameraRest+offset;Cam.transform.rotation=Quaternion.LookRotation(-cameraOffset,Vector3.up);
  }
 }
}
