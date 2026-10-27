using UnityEditor;
namespace Bloodwake.Editor
{
 // The keep's stone, floor and wood sets (Resources/textures/keep, from textures.com): kept at 4096, normal maps
 // as normal maps, the metallic/smoothness masks linear.
 public sealed class KeepTextureImport:AssetPostprocessor
 {
  void OnPreprocessTexture()
  {
   if(!assetPath.Contains("/textures/keep/"))return;var t=(TextureImporter)assetImporter;
   t.textureType=assetPath.EndsWith("_normal.png")?TextureImporterType.NormalMap:TextureImporterType.Default;
   t.sRGBTexture=assetPath.EndsWith("_albedo.png");t.mipmapEnabled=true;t.anisoLevel=8;t.maxTextureSize=4096;
   t.wrapMode=UnityEngine.TextureWrapMode.Repeat;t.textureCompression=TextureImporterCompression.CompressedHQ;
  }
 }
}
