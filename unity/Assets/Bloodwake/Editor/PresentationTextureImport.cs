using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public sealed class PresentationTextureImport:AssetPostprocessor
 {
  void OnPreprocessTexture()
  {
   if(assetPath.Contains("/Presentation/HUD/"))
   {
    var ui=(TextureImporter)assetImporter;ui.textureType=TextureImporterType.Default;ui.sRGBTexture=true;ui.alphaIsTransparency=true;ui.mipmapEnabled=false;ui.maxTextureSize=4096;ui.wrapMode=TextureWrapMode.Clamp;ui.textureCompression=TextureImporterCompression.Uncompressed;return;
   }
   if(!assetPath.Contains("/Presentation/Cobblestone/"))return;
   var importer=(TextureImporter)assetImporter;
   importer.textureType=assetPath.EndsWith("normal.jpg")?TextureImporterType.NormalMap:TextureImporterType.Default;
   importer.sRGBTexture=assetPath.EndsWith("albedo.jpg");importer.anisoLevel=8;
   importer.maxTextureSize=2048;importer.mipmapEnabled=true;importer.wrapMode=TextureWrapMode.Repeat;
   importer.textureCompression=TextureImporterCompression.CompressedHQ;
  }
 }
}
