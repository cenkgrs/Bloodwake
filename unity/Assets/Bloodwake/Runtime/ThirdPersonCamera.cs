using UnityEngine;
using UnityEngine.InputSystem;
namespace Bloodwake
{
 // Third-person camera prototype (F6 / R3 toggles): an over-the-shoulder perspective camera at a fixed pitch; the
 // mouse or right stick only turns it left and right. Movement already follows the camera; in this mode the mouse aims where the camera looks.
 // Everything else (rooms, combat, HUD) is the isometric game unchanged, so this is for feel only.
 public sealed partial class BloodwakeGame
 {
  bool thirdPerson;float tpsYaw,tpsDistance=5.4f,tpsReach;Vector3 tpsPivot;float isoSize;
  // Fixed pitch (looking down on her like the 20 Oct test frame); only yaw turns.
  const float TpsPitch=24,TpsShoulder=.35f,TpsFov=55,TpsMouseDegreesPerPixel=.11f,TpsStickDegreesPerSecond=170;
  void ToggleThirdPerson()
  {
   thirdPerson=!thirdPerson;
   if(thirdPerson)
   {
    isoSize=Cam.orthographicSize;Cam.orthographic=false;Cam.fieldOfView=TpsFov;Cam.nearClipPlane=.1f;
    // Start behind the player, looking the way the isometric camera did.
    var flat=Vector3.ProjectOnPlane(-cameraOffset,Vector3.up);tpsYaw=Mathf.Atan2(flat.x,flat.z)*Mathf.Rad2Deg;
   }
   else{Cam.orthographic=true;Cam.orthographicSize=isoSize;Cursor.lockState=CursorLockMode.None;Cursor.visible=true;}
   PositionCamera(true);
  }
  public Vector3 ThirdPersonAim=>Vector3.ProjectOnPlane(Cam.transform.forward,Vector3.up).normalized;
  void PositionThirdPerson(bool snap)
  {
   bool playing=Screen=="playing"&&Application.isFocused;
   Cursor.lockState=playing?CursorLockMode.Locked:CursorLockMode.None;Cursor.visible=!playing;
   if(playing)
   {
    var look=Vector2.zero;
    if(Mouse.current!=null&&!usingPad)look+=Mouse.current.delta.ReadValue()*TpsMouseDegreesPerPixel;
    if(Gamepad.current is {} pad)look+=pad.rightStick.ReadValue()*new Vector2(1,-1)*TpsStickDegreesPerSecond*Time.unscaledDeltaTime;
    if(Mouse.current!=null)tpsDistance=Mathf.Clamp(tpsDistance-Mouse.current.scroll.ReadValue().y*.004f,3f,8f);
    tpsYaw+=look.x;
   }
   // The orbit is exact every frame (yaw applied to position and rotation together, so turning never swims);
   // only the followed point and the wall pull-in are eased.
   float h=Player.Height;var rotation=Quaternion.Euler(TpsPitch,tpsYaw,0);
   var target=Player.transform.position+Vector3.up*h*.78f;
   tpsPivot=snap||tpsPivot==Vector3.zero?target:Vector3.Lerp(tpsPivot,target,1-Mathf.Exp(-14*Time.unscaledDeltaTime));
   var shoulder=tpsPivot+rotation*Vector3.right*TpsShoulder;var back=-(rotation*Vector3.forward);
   // Pull in in front of walls and props (never the actors): at once when something comes between, back out gently.
   float reach=tpsDistance;
   foreach(var hit in Physics.SphereCastAll(shoulder,.25f,back,tpsDistance,~0,QueryTriggerInteraction.Ignore))
    if(!hit.collider.GetComponentInParent<ActorView>()&&hit.distance<reach)reach=hit.distance;
   reach=Mathf.Max(.8f,reach);
   tpsReach=snap||reach<tpsReach?reach:Mathf.Lerp(tpsReach,reach,1-Mathf.Exp(-4*Time.unscaledDeltaTime));
   cameraRest=shoulder+back*tpsReach;
   var offset=Vector3.zero;
   if(shakeTrauma>0&&!snap)
   {
    float power=shakeTrauma*shakeTrauma*.12f,t=Time.unscaledTime*38;
    offset=(Cam.transform.right*(Mathf.PerlinNoise(shakeSeed,t)-.5f)+Cam.transform.up*(Mathf.PerlinNoise(shakeSeed+7,t)-.5f))*2*power;
    shakeTrauma=Mathf.Max(0,shakeTrauma-Time.unscaledDeltaTime*3.2f);
   }
   else if(snap)shakeTrauma=0;
   Cam.transform.SetPositionAndRotation(cameraRest+offset,rotation);
  }
  // A small centre dot to aim by while the cursor is locked.
  void OnGUI()
  {
   if(!thirdPerson||Screen!="playing")return;
   var c=new Vector2(UnityEngine.Screen.width/2f,UnityEngine.Screen.height/2f);
   GUI.color=new Color(1,.92f,.85f,.75f);GUI.DrawTexture(new Rect(c.x-2,c.y-2,4,4),Texture2D.whiteTexture);GUI.color=Color.white;
  }
 }
}
