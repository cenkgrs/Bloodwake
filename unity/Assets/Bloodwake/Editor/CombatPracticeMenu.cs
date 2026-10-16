using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class CombatPracticeMenu
 {
  const string Scene="Assets/Bloodwake/Scenes/GateyardCombatPractice.unity";
  const string Request="Library/BloodwakeOpenPractice.request";
  [InitializeOnLoadMethod]
  static void ResumeRequest(){EditorApplication.update+=ProcessRequest;}
  static bool opening;
  static void ProcessRequest()
  {
   if(Application.isBatchMode||opening||!File.Exists(Request))return;
   if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   Open();
  }
  [MenuItem("Bloodwake/Play Gateyard Combat Practice")]
  public static void Open()
  {
   if(EditorApplication.isPlayingOrWillChangePlaymode)
   {
    opening=true;
    EditorApplication.playModeStateChanged+=AfterStop;
    EditorApplication.isPlaying=false;return;
   }
   OpenAndPlay();
  }
  static void AfterStop(PlayModeStateChange state)
  {
   if(state!=PlayModeStateChange.EnteredEditMode)return;
   EditorApplication.playModeStateChanged-=AfterStop;
   opening=false;
   EditorApplication.delayCall+=OpenAndPlay;
  }
  static void OpenAndPlay()
  {
   if(!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()){if(File.Exists(Request))File.Delete(Request);return;}
   if(File.Exists(Request))File.Delete(Request);
   EditorSceneManager.OpenScene(Scene,OpenSceneMode.Single);
   EditorApplication.isPlaying=true;
  }
 }
}
