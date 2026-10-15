using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  void StartRecoil(Enemy enemy)
  {
   if(enemy.AreaRecovery>0)return;
   var delta=enemy.View.transform.position-Player.transform.position;delta.y=0;float distance=delta.magnitude;
   float amount=enemy.Id=="boss"?.025f:enemy.Id=="tank"?.055f:.12f;
   // Reserve combo reach at the outer edge; repeated hits cannot push an enemy
   // beyond the shortest equipped melee weapon's normal reach.
   foreach(var entry in Run.Weapons)
   {
    var row=GameData.Row("weapons",entry.Key);if(row.S("behavior")!="melee")continue;
    float multiplier=Run.ClassId=="revenant"?1.8f:Run.ClassId=="warrior"?1.7f:1;
    float reach=row.N("range")*.02f*Run.Stats.N("attackRange")*entry.Value.N("range")*multiplier+.45f;
    amount=Mathf.Min(amount,Mathf.Max(0,reach-distance-.08f));
   }
   enemy.RecoilDirection=distance>.001f?delta/distance:Player.transform.forward;
   enemy.RecoilRemaining=amount;enemy.RecoilTime=.12f;
   enemy.View.ImpactPose(Player.transform.position,enemy.Id=="boss"?1.5f:enemy.Id=="tank"?3:7);
  }
  void StartAreaRecoil(Enemy enemy,Vector3 origin)
  {
   if(enemy.Hp<=0)return;
   var away=enemy.View.transform.position-origin;away.y=0;
   if(away.sqrMagnitude<.0001f){away=enemy.View.transform.position-Player.transform.position;away.y=0;}
   enemy.RecoilDirection=away.sqrMagnitude>.0001f?away.normalized:enemy.View.transform.forward;
   bool boss=enemy.Id=="boss",tank=enemy.Id=="tank";
   enemy.RecoilRemaining=boss?.08f:tank?.2f:.48f;
   enemy.RecoilTime=boss?.18f:.28f;
   enemy.AreaRecovery=boss?.32f:tank?.44f:.56f;
   enemy.Stagger=Mathf.Max(enemy.Stagger,enemy.AreaRecovery);
   // Invalidate attacks already winding up, so the reaction cannot conceal a hit.
   enemy.ImpactVersion++;
   enemy.View.Play("Hit",enemy.AreaRecovery);
   enemy.View.ImpactPose(origin,boss?3:tank?7:13,enemy.AreaRecovery);
  }
  void TickRecoil(Enemy enemy,float dt)
  {
   float step=Mathf.Min(dt,enemy.RecoilTime);float fraction=1-Mathf.Pow(1-step/Mathf.Max(.0001f,enemy.RecoilTime),2);
   float distance=enemy.RecoilRemaining*fraction;enemy.RecoilRemaining-=distance;enemy.RecoilTime=Mathf.Max(0,enemy.RecoilTime-step);
   enemy.View.transform.position=Move(enemy.View.transform.position,enemy.RecoilDirection*distance,.45f);
  }
 }
}
