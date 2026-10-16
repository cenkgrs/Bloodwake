using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // Blender's FBX importer conversion mirrors source X, not source Z.
  readonly Vector3 cameraOffset=new Vector3(-12,14,16);
  // Closer than the old 6.5-7.2 so armour, faces and fire read like the art-direction frames.
  const float DefaultZoom=5.6f;
  Vector3 CameraFocus(Vector3 target)
  {
   if(room==null)return target;Vector3 forward=-cameraOffset.normalized,right=Vector3.Cross(Vector3.up,forward).normalized,up=Vector3.Cross(forward,right);
   float minX=float.PositiveInfinity,maxX=float.NegativeInfinity,minZ=float.PositiveInfinity,maxZ=float.NegativeInfinity;
   foreach(int x in new[]{-1,1})foreach(int y in new[]{-1,1}){var p=cameraOffset+right*x*Cam.orthographicSize*Cam.aspect+up*y*Cam.orthographicSize;var g=p+forward*(-p.y/forward.y);minX=Mathf.Min(minX,g.x);maxX=Mathf.Max(maxX,g.x);minZ=Mathf.Min(minZ,g.z);maxZ=Mathf.Max(maxZ,g.z);}
   float left=-half.x-5-minX,rightEdge=half.x+5-maxX,bottom=-half.y-7-minZ,top=half.y+4-maxZ;
   return new Vector3(left<=rightEdge?Mathf.Clamp(target.x,left,rightEdge):(left+rightEdge)/2,0,bottom<=top?Mathf.Clamp(target.z,bottom,top):(bottom+top)/2);
  }
  void PositionCamera(bool snap)
  {
   if(!Player)return;var focus=CameraFocus(Player.transform.position);var desired=focus+cameraOffset;
   Cam.transform.position=snap?desired:Vector3.Lerp(Cam.transform.position,desired,1-Mathf.Exp(-10*Time.unscaledDeltaTime));Cam.transform.rotation=Quaternion.LookRotation(-cameraOffset,Vector3.up);
  }
 }
}
