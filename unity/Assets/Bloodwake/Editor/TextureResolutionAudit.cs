using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 // Every texture of the game imports at its own resolution up to 4096: several 4096 sources (enemies, rooms)
 // were capped at 2048 by their import defaults. Run in batch: -executeMethod Bloodwake.Editor.TextureResolutionAudit.Run
 public static class TextureResolutionAudit
 {
  [MenuItem("Bloodwake/Raise texture caps to source (4096)")]
  public static void Run()
  {
   int raised=0;
   foreach(var guid in AssetDatabase.FindAssets("t:Texture2D",new[]{"Assets/Bloodwake"}))
   {
    var path=AssetDatabase.GUIDToAssetPath(guid);if(AssetImporter.GetAtPath(path) is not TextureImporter importer)continue;
    if(importer.textureType==TextureImporterType.Sprite||importer.textureType==TextureImporterType.GUI)continue;
    importer.GetSourceTextureWidthAndHeight(out int w,out int h);int want=Mathf.Min(4096,Mathf.NextPowerOfTwo(Mathf.Max(w,h)));
    var standalone=importer.GetPlatformTextureSettings("Standalone");
    if(importer.maxTextureSize>=want&&(!standalone.overridden||standalone.maxTextureSize>=want))continue;
    importer.maxTextureSize=Mathf.Max(importer.maxTextureSize,want);
    if(standalone.overridden){standalone.maxTextureSize=Mathf.Max(standalone.maxTextureSize,want);importer.SetPlatformTextureSettings(standalone);}
    if(importer.textureCompression==TextureImporterCompression.Compressed)importer.textureCompression=TextureImporterCompression.CompressedHQ;
    importer.SaveAndReimport();raised++;Debug.Log("BLOODWAKE_TEXCAP "+path+" "+w+"x"+h+" -> "+want);
   }
   Debug.Log("BLOODWAKE_TEXCAP_DONE raised="+raised);
  }
 }
}
