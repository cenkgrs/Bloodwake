using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  [SerializeField] bool combatPractice;
  void TogglePracticeCrowd()
  {
   if(!combatPractice)return;
   if(Enemies.Count>1)
   {
    for(int i=Enemies.Count-1;i>0;i--){var e=Enemies[i];if(e.Agent)e.Agent.enabled=false;Destroy(e.View.gameObject);Enemies.RemoveAt(i);}
    if(Enemies.Count>0)Enemies[0].ApproachSlot=-1;
   }
   else
   {
    while(Enemies.Count<3){if(!TrySurroundSpawn("grunt",out var origin))break;SpawnEnemy("grunt",origin);}
   }
   Debug.Log("BLOODWAKE_PRACTICE_CROWD count="+Enemies.Count+" (F8: one / three Warriors)");
  }
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
