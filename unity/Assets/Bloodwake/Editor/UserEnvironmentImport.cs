using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public sealed class UserEnvironmentTextures:AssetPostprocessor
 {
  void OnPreprocessTexture()
  {
   if(!assetPath.Contains("/Environment/Kit01/"))return;var t=(TextureImporter)assetImporter;
   t.textureType=assetPath.EndsWith("normal.png")?TextureImporterType.NormalMap:TextureImporterType.Default;
   t.sRGBTexture=assetPath.EndsWith("albedo.jpg");t.mipmapEnabled=true;t.anisoLevel=8;t.maxTextureSize=2048;t.wrapMode=TextureWrapMode.Repeat;
   t.isReadable=assetPath.EndsWith("roughness.jpg")||assetPath.EndsWith("metallic.jpg");t.textureCompression=TextureImporterCompression.CompressedHQ;
  }
  void OnPreprocessModel()
  {
   if(!assetPath.Contains("/Environment/Kit01/"))return;var m=(ModelImporter)assetImporter;m.materialImportMode=ModelImporterMaterialImportMode.None;m.importAnimation=false;m.addCollider=false;
  }
 }
 public static class UserEnvironmentImport
 {
  [MenuItem("Bloodwake/Import user courtyard models")]
  public static void Build()
  {
   string root="Assets/Bloodwake/Resources/Environment/Kit01";
   var ids=System.Environment.GetEnvironmentVariable("BW_ENV_IDS")?.Split(',')??new[]{"gate","brazier","wall","crate","barrel","lantern","cloth","house_haunted","house","building","well"};
   foreach(string id in ids)
   {
    string folder=root+"/"+id;var source=AssetDatabase.LoadAssetAtPath<GameObject>(folder+"/model.fbx");if(!source)throw new System.Exception("Missing user model "+id);
    var rough=AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"/roughness.jpg");var metal=AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"/metallic.jpg");
    int size=Mathf.Min(2048,rough.width);var packed=new Texture2D(size,size,TextureFormat.RGBA32,false,true);var pixels=new Color32[size*size];
    var roughPixels=rough.GetPixels32();var metalPixels=metal.GetPixels32();int rw=rough.width,rh=rough.height,mw=metal.width,mh=metal.height;
    for(int y=0;y<size;y++)for(int x=0;x<size;x++)pixels[y*size+x]=new Color32(metalPixels[(y*mh/size)*mw+x*mw/size].r,0,0,(byte)(255-roughPixels[(y*rh/size)*rw+x*rw/size].r));
    packed.SetPixels32(pixels);packed.Apply();File.WriteAllBytes(folder+"/metal-smooth.png",packed.EncodeToPNG());Object.DestroyImmediate(packed);AssetDatabase.ImportAsset(folder+"/metal-smooth.png");
    string matPath=folder+"/surface.mat";var material=AssetDatabase.LoadAssetAtPath<Material>(matPath);if(!material){material=new Material(Shader.Find("Universal Render Pipeline/Lit"));AssetDatabase.CreateAsset(material,matPath);}
    material.SetTexture("_BaseMap",AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"/albedo.jpg"));material.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"/normal.png"));material.SetTexture("_MetallicGlossMap",AssetDatabase.LoadAssetAtPath<Texture2D>(folder+"/metal-smooth.png"));
    material.SetColor("_BaseColor",Color.white);material.SetFloat("_Metallic",1);material.SetFloat("_Smoothness",1);material.SetFloat("_BumpScale",1);material.EnableKeyword("_NORMALMAP");material.EnableKeyword("_METALLICSPECGLOSSMAP");EditorUtility.SetDirty(material);
    var prefab=new GameObject(id);var model=Object.Instantiate(source,prefab.transform);var renderers=model.GetComponentsInChildren<Renderer>();var bounds=renderers[0].bounds;foreach(var renderer in renderers){bounds.Encapsulate(renderer.bounds);renderer.sharedMaterials=Enumerable.Repeat(material,renderer.sharedMaterials.Length).ToArray();}
    float height=id switch{"house_haunted"=>8f,"house"=>7f,"building"=>7f,"gate"=>3.5f,"wall"=>2.4f,"brazier"=>1.3f,"barrel"=>.95f,"lantern"=>.55f,"cloth"=>.65f,"well"=>3.35f,_=>1};float scale=height/Mathf.Max(.001f,bounds.size.y);model.transform.localScale*=scale;model.transform.localPosition=-new Vector3(bounds.center.x,bounds.min.y,bounds.center.z)*scale;
    PrefabUtility.SaveAsPrefabAsset(prefab,folder+"/"+id+".prefab");Debug.Log("USER_ENV_IMPORTED "+id+" meshes "+renderers.Length+" raw bounds "+bounds.size+" scale "+scale);Object.DestroyImmediate(prefab);
   }
   AssetDatabase.SaveAssets();Debug.Log("BLOODWAKE_USER_ENVIRONMENT_IMPORTED "+ids.Length);
  }
 }
}
