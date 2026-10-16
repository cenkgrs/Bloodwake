using UnityEngine;
namespace Bloodwake
{
 [System.Serializable]
 public sealed class WarriorTurnData
 {
  public float duration;public float[] yaw,x,z;
  public float Sample(float[] values,float progress)
  {
   float f=Mathf.Clamp01(progress)*(values.Length-1);int i=Mathf.Min((int)f,values.Length-2);
   return Mathf.Lerp(values[i],values[i+1],f-i);
  }
 }
 public sealed partial class BloodwakeGame
 {
  const float WarriorSteeringDegreesPerSecond=320;
  const float WarriorTurnPlayback=1.2f;
  const float WarriorAttackFacingTolerance=12;
  Vector3 SteerWarrior(Enemy e,Vector3 direction,Vector3 wish,float speed,float dt)
  {
   direction.y=0;
   if(direction.sqrMagnitude<.00001f)return e.View.transform.position;
   direction.Normalize();
   e.View.transform.rotation=Quaternion.RotateTowards(e.View.transform.rotation,
    Quaternion.LookRotation(direction),WarriorSteeringDegreesPerSecond*dt);
   var before=e.View.transform.position;
   if(wish.sqrMagnitude<.0001f)return before;
   // Advance along the body's forward axis, not sideways toward the target.
   // A target behind the shoulder first needs alignment; no backwards skating.
   float alignment=Mathf.Max(0,Vector3.Dot(e.View.transform.forward,direction));
   var next=MoveEnemy(e,e.View.transform.forward*(speed*dt*alignment));
   var moved=next-before;moved.y=0;
   // Collision sliding must not introduce an instantaneous second facing change.
   return moved.sqrMagnitude>.000001f&&Vector3.Angle(moved,e.View.transform.forward)>25?before:next;
  }
  bool BeginWarriorTurn(Enemy e,Vector3 direction)
  {
   var data=e.View.TurnData;
   if(data==null||direction.sqrMagnitude<.00001f||Vector3.Angle(e.View.transform.forward,direction)<150)return false;
   float endYaw=Vector3.SignedAngle(e.View.transform.forward,direction,Vector3.up);
   float authoredYaw=data.yaw[data.yaw.Length-1];
   // Keep the source's turn side: don't mirror the sword and shield or reverse time.
   if(Mathf.Sign(endYaw)!=Mathf.Sign(authoredYaw))endYaw+=Mathf.Sign(authoredYaw)*360;
   e.Turning=true;e.TurnAge=0;e.TurnYawScale=endYaw/authoredYaw;
   e.TurnRotation=e.View.transform.rotation;e.TurnOffset=Vector3.zero;
   e.View.Play("Warrior_Turn180",data.duration/WarriorTurnPlayback);return true;
  }
  void TickWarriorTurn(Enemy e,float dt)
  {
   var data=e.View.TurnData;e.TurnAge=Mathf.Min(data.duration,e.TurnAge+dt*WarriorTurnPlayback);
   float progress=e.TurnAge/data.duration;
   // Yaw exists ONLY here; the imported pose has its global yaw removed.
   e.View.transform.rotation=e.TurnRotation*Quaternion.Euler(0,data.Sample(data.yaw,progress)*e.TurnYawScale,0);
   var offset=e.TurnRotation*new Vector3(data.Sample(data.x,progress),0,data.Sample(data.z,progress))*(e.View.Height/1.8f);
   e.View.transform.position=MoveEnemy(e,offset-e.TurnOffset);e.TurnOffset=offset;
   e.View.Tick(dt,false);
   if(e.TurnAge>=data.duration){e.Turning=false;e.View.Locked=0;}
  }
 }
}
