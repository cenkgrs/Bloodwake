using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
namespace Bloodwake.Editor
{
 // Runs the look-development captures inside the editor (no player build): leaves a marker the game picks up on
 // play, enters play mode, and the game writes /tmp/bloodwake-lookdev-*.png and leaves play mode when done.
 public static class LookDevMenu
 {
  [MenuItem("Bloodwake/Glide Capture")]
  public static void Glide()
  {
   if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())return;
   EditorSceneManager.OpenScene("Assets/Bloodwake/Scenes/Bloodwake.unity");
   File.WriteAllText(BloodwakeGame.GlideCaptureMarker,"");EditorApplication.isPlaying=true;
  }
  [MenuItem("Bloodwake/LookDev Capture")]
  public static void Capture()
  {
   if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())return;
   EditorSceneManager.OpenScene("Assets/Bloodwake/Scenes/Bloodwake.unity");
   File.WriteAllText(BloodwakeGame.LookDevMarker,"");EditorApplication.isPlaying=true;
  }
 }
}
