using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  [SerializeField] bool combatPractice;
  void Start()
  {
   if(!combatPractice)return;
   StartRun("revenant");Run.Awarded=true;
   EnterRoom("town_gateyard_01");waves=null;roomClear=false;
   Player.transform.position=new Vector3(0,0,2);
   Player.transform.rotation=Quaternion.LookRotation(Vector3.back);aim=Vector3.back;
   SpawnEnemy("grunt",new Vector3(0,0,.3f));
   Enemies[0].View.transform.rotation=Quaternion.LookRotation(Vector3.forward);
   PositionCamera(true);
   Debug.Log("BLOODWAKE_PRACTICE_READY Revenant / Gateyard / one Warrior / infinite HP / no cooldowns");
  }
 }
}
