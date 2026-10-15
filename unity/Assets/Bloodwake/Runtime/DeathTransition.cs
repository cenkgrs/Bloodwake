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
 }
}
