using System.Collections;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // Godot main.gd: show the body for two seconds, then the 2.7s death title.
  IEnumerator DeathTransition()
  {
   yield return new WaitForSeconds(2);
   if(Screen!="dying")yield break;
   Screen="death_transition";
   yield return new WaitForSeconds(2.7f);
   if(Screen=="death_transition")Screen="dead";
  }
  int RunEssence=>Mathf.Clamp(Run.Wave*2+Run.Kills/5,2,100000);
  // The last district's boss falls: let the room settle, then end the run with double essence.
  IEnumerator VictoryTransition()
  {
   yield return new WaitForSeconds(2.5f);
   if(Screen!="playing")yield break;
   Screen="victory";SetMusic("music_menu");
   if(!Run.Awarded){Run.Awarded=true;Meta.Essence+=RunEssence*2;Meta.Save();}
  }
 }
}
