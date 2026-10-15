using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class CharacterTextureRestore
 {
  const string Request="Library/RestoreCharacterTextures.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   if(EditorApplication.isPlayingOrWillChangePlaymode){EditorApplication.isPlaying=false;return;}
   File.Delete(Request);
   try{Build();}catch(Exception ex){Debug.LogException(ex);}
  }
  [MenuItem("Bloodwake/Restore Original Character Textures")]
  public static void Build()
  {
   AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
   const string root="Assets/Bloodwake/Resources/";
   foreach(var manifest in Directory.GetFiles(root+"Models","materials.json",SearchOption.AllDirectories))
   {
    var folder=Path.GetDirectoryName(manifest).Replace('\\','/');var id=Path.GetFileName(folder);
    var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(root+"Actors/"+id+".prefab");
    if(!prefab)throw new Exception("Actor missing: "+id);
    var instance=UnityEngine.Object.Instantiate(prefab);
    try
    {
     SourceMaterials.Apply(instance,folder+"/"+id+".fbx");
     foreach(var mat in instance.GetComponentsInChildren<Renderer>(true).SelectMany(r=>r.sharedMaterials).Distinct())
     foreach(var prop in new[]{"_BaseMap","_BumpMap","_MetallicGlossMap"})
     {
      var tex=mat.GetTexture(prop);if(!tex)continue;
      var path=AssetDatabase.GetAssetPath(tex);
      bool originalNoble=id=="revenant_noble"&&prop=="_BaseMap"&&tex.width==8192&&Path.GetFileName(path)=="Noble_BaseColor_8K.jpg";
      if(!originalNoble&&(!path.EndsWith(".png",StringComparison.OrdinalIgnoreCase)||!Path.GetFileName(path).Contains("HQ_")))throw new Exception("Non-restored texture: "+path);
      Debug.Log($"CHARACTER_TEXTURE_VERIFIED {id} {mat.name} {prop} {tex.width}x{tex.height} {path}");
     }
    }
    finally{UnityEngine.Object.DestroyImmediate(instance);}
   }
   AssetDatabase.SaveAssets();Debug.Log("CHARACTER_TEXTURE_RESTORE_COMPLETE");
  }
 }
}
