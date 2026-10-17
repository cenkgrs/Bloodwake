using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // Extra stillness after impact; do not slow the hit clip or the recoil itself.
  const float PostImpactRecovery=.2f;
  static float BasicRecoilDistance(Enemy enemy)=>enemy.Id=="boss"?.06f:enemy.Id=="tank"?.12f:.24f;
  void StartRecoil(Enemy enemy)
  {
   if(enemy.Emerging||enemy.AreaRecovery>0)return;
   var delta=enemy.View.transform.position-Player.transform.position;delta.y=0;float distance=delta.magnitude;
   // Reserve combo reach at the outer edge; repeated hits cannot push an enemy
   // beyond the shortest equipped melee weapon's normal reach.
   float amount=Mathf.Min(BasicRecoilDistance(enemy),Mathf.Max(0,MeleeReach()-distance-.08f));
   enemy.RecoilDirection=distance>.001f?delta/distance:Player.transform.forward;
   enemy.RecoilRemaining=amount;enemy.RecoilTime=.36f;
   enemy.View.ImpactPose(Player.transform.position,enemy.Id=="boss"?1.5f:enemy.Id=="tank"?3:7);
  }
  float MeleeReach()
  {
   float reach=float.PositiveInfinity;
   foreach(var entry in Run.Weapons)
   {
    var row=GameData.Row("weapons",entry.Key);if(row.S("behavior")!="melee")continue;
    float multiplier=Run.ClassId=="revenant"?1.8f:Run.ClassId=="warrior"?1.7f:1;
    reach=Mathf.Min(reach,row.N("range")*.02f*Run.Stats.N("attackRange")*entry.Value.N("range")*multiplier+.45f);
   }
   return reach;
  }
  // A blade connecting: the body is thrown along the swing, harder on the combo finisher.
  // Ordinary swings may push just past reach; the finisher ends the chain, so it is not limited.
  void MeleeKnockback(Enemy enemy,Vector3 swing,bool heavy)
  {
   if(enemy.Hp<=0||enemy.Emerging||enemy.AreaRecovery>0||!enemy.View)return;
   var away=enemy.View.transform.position-Player.transform.position;away.y=0;float distance=away.magnitude;swing.y=0;
   var direction=(distance>.001f?away/distance:swing.normalized)*.6f+swing.normalized*.4f;
   float push=BasicRecoilDistance(enemy)*(heavy?3.4f:2);
   if(!heavy)push=Mathf.Min(push,Mathf.Max(BasicRecoilDistance(enemy),MeleeReach()-distance+.2f));
   enemy.RecoilDirection=direction.sqrMagnitude>.0001f?direction.normalized:Player.transform.forward;
   enemy.RecoilRemaining=push;enemy.RecoilTime=heavy?.34f:.24f;
   enemy.Stagger=Mathf.Max(enemy.Stagger,(heavy?.75f:.5f)+PostImpactRecovery);
   bool boss=enemy.Id=="boss",tank=enemy.Id=="tank";
   enemy.View.ImpactPose(Player.transform.position,boss?(heavy?5:3):tank?(heavy?11:7):(heavy?24:15),heavy?.42f:.32f);
  }
  void StartAreaRecoil(Enemy enemy,Vector3 origin,float distanceMultiplier=1)
  {
   if(enemy.Hp<=0||enemy.Emerging)return;
   var away=enemy.View.transform.position-origin;away.y=0;
   if(away.sqrMagnitude<.0001f){away=enemy.View.transform.position-Player.transform.position;away.y=0;}
   enemy.RecoilDirection=away.sqrMagnitude>.0001f?away.normalized:enemy.View.transform.forward;
   bool boss=enemy.Id=="boss",tank=enemy.Id=="tank";
   enemy.RecoilRemaining=(boss?.08f:tank?.2f:.48f)*distanceMultiplier;
   enemy.RecoilTime=boss?.18f:.28f;
   enemy.AreaRecovery=boss?.32f:tank?.44f:.56f;
   enemy.Stagger=Mathf.Max(enemy.Stagger,enemy.AreaRecovery+PostImpactRecovery);
   // Invalidate attacks already winding up, so the reaction cannot conceal a hit.
   enemy.ImpactVersion++;
   enemy.View.Play("Hit",enemy.AreaRecovery);
   enemy.View.ImpactPose(origin,boss?3:tank?7:13,enemy.AreaRecovery);
   ShakeCamera(boss?.35f:.5f,enemy.RecoilDirection);
  }
  void TickRecoil(Enemy enemy,float dt)
  {
   float step=Mathf.Min(dt,enemy.RecoilTime);float fraction=1-Mathf.Pow(1-step/Mathf.Max(.0001f,enemy.RecoilTime),2);
   float distance=enemy.RecoilRemaining*fraction;enemy.RecoilRemaining-=distance;enemy.RecoilTime=Mathf.Max(0,enemy.RecoilTime-step);
   enemy.View.transform.position=MoveEnemy(enemy,enemy.RecoilDirection*distance);
  }
 }
}
