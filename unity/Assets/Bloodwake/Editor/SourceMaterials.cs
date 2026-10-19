using System.IO;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 internal static class SourceMaterials
 {
  public static void Apply(GameObject instance,string modelPath)
  {
   // Forward slashes: on Windows GetDirectoryName returns backslashes and the "/Models/" full-resolution check never matched.
   string folder=Path.GetDirectoryName(modelPath).Replace('\\','/'),manifest=folder+"/materials.json";
   if(!File.Exists(manifest))throw new System.Exception("Missing source material manifest: "+manifest);
   var rows=JObject.Parse(File.ReadAllText(manifest));var converted=new System.Collections.Generic.Dictionary<string,Material>();
   foreach(var renderer in instance.GetComponentsInChildren<Renderer>(true))
   {
    var materials=renderer.sharedMaterials;
    for(int i=0;i<materials.Length;i++)
    {
     string name=materials[i].name;if(converted.TryGetValue(name,out var cached)){materials[i]=cached;continue;}var row=rows[name];
     if(row==null)throw new System.Exception("Source material not mapped: "+modelPath+" / "+name);
     var material=new Material(Shader.Find("Universal Render Pipeline/Lit")){name=name};
     var rgba=(JArray)row["color"];var tint=new Color((float)rgba[0],(float)rgba[1],(float)rgba[2],row.N("alpha",1));material.SetColor("_BaseColor",tint.gamma);
     material.SetFloat("_Metallic",row.N("metallic"));material.SetFloat("_Smoothness",1-row.N("roughness",.8f));
     SetTexture(material,row,folder,"albedo","_BaseMap",false);
     SetTexture(material,row,folder,"normal","_BumpMap",true);
     if(row["metallicRoughness"]!=null)
     {
      string packedPath=folder+"/Packed_"+Path.GetFileNameWithoutExtension(row.S("metallicRoughness"))+".png";
      var source=new Texture2D(2,2,TextureFormat.RGBA32,false,true);source.LoadImage(File.ReadAllBytes(folder+"/"+row.S("metallicRoughness")));
      var pixels=source.GetPixels32();for(int p=0;p<pixels.Length;p++)pixels[p]=new Color32(pixels[p].b,0,0,(byte)(255-pixels[p].g));source.SetPixels32(pixels);source.Apply();File.WriteAllBytes(packedPath,source.EncodeToPNG());Object.DestroyImmediate(source);
      AssetDatabase.ImportAsset(packedPath);var ti=(TextureImporter)AssetImporter.GetAtPath(packedPath);ConfigureTexture(ti,false,false,folder.Contains("/Models/"));
      material.SetTexture("_MetallicGlossMap",AssetDatabase.LoadAssetAtPath<Texture2D>(packedPath));material.SetFloat("_Smoothness",1);material.EnableKeyword("_METALLICSPECGLOSSMAP");
     }
     if(row["tiling"] is JArray scale)material.SetTextureScale("_BaseMap",new Vector2((float)scale[0],(float)scale[1]));
     if(row["offset"] is JArray offset)material.SetTextureOffset("_BaseMap",new Vector2((float)offset[0],(float)offset[1]));
     string path=folder+"/Source_"+string.Join("_",name.Split(Path.GetInvalidFileNameChars()))+".mat";
     var saved=AssetDatabase.LoadAssetAtPath<Material>(path);
     if(saved==null){AssetDatabase.CreateAsset(material,path);saved=material;}
     else{EditorUtility.CopySerialized(material,saved);Object.DestroyImmediate(material);}
     materials[i]=saved;converted[name]=saved;
    }
    renderer.sharedMaterials=materials;
   }
  }
  static void SetTexture(Material material,JToken row,string folder,string key,string property,bool normal)
  {
   if(row[key]==null)return;string path=folder+"/"+row.S(key);
   if(File.Exists(path))AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
   var importer=AssetImporter.GetAtPath(path) as TextureImporter;
   if(importer==null)throw new System.Exception("Missing texture "+path);
   ConfigureTexture(importer,normal,!normal,folder.Contains("/Models/"));
   material.SetTexture(property,AssetDatabase.LoadAssetAtPath<Texture2D>(path));if(normal)material.EnableKeyword("_NORMALMAP");
  }
  internal static void ConfigureTexture(TextureImporter importer,bool normal,bool srgb,bool character)
  {
   var type=normal?TextureImporterType.NormalMap:TextureImporterType.Default;
   bool changed=importer.textureType!=type||importer.sRGBTexture!=srgb;
   importer.textureType=type;importer.sRGBTexture=srgb;
   if(character)
   {
    // Keep full-resolution lossless source files. High-quality GPU compression
    // is separate from JPEG encoding and avoids multi-GB uncompressed actors.
    changed|=importer.maxTextureSize!=8192||importer.textureCompression!=TextureImporterCompression.CompressedHQ||importer.compressionQuality!=100||importer.crunchedCompression||importer.anisoLevel!=4;
    importer.maxTextureSize=8192;importer.textureCompression=TextureImporterCompression.CompressedHQ;importer.compressionQuality=100;importer.crunchedCompression=false;importer.anisoLevel=4;
   }
   if(changed)importer.SaveAndReimport();
  }
 }
}
