using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class InspectMigration
 {
  public static void Run()
  {
   var asset=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Bloodwake/Resources/Rooms/town_safehouse/town_safehouse_environment.prefab");var go=Object.Instantiate(asset);
   foreach(Transform t in go.transform)Debug.Log("ROOM_NODE "+t.name+" pos="+t.position+" scale="+t.lossyScale);
   foreach(var t in go.GetComponentsInChildren<Transform>())if(t.name.Contains("CamWall")||t.name.Contains("Gate"))Debug.Log("ROOM_ANCHOR "+t.name+" pos="+t.position);
   Object.DestroyImmediate(go);
  }
 }
}
