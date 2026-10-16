using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class SanctuaryImport
 {
  const string Folder="Assets/Bloodwake/Resources/Sanctuary/",Name="sanctuary_rooms",Request="Library/SanctuaryImport.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!File.Exists(Request))return;
   File.Delete(Request);File.Delete("Library/SanctuaryImport.result");
   try{Build();File.WriteAllText("Library/SanctuaryImport.result","PASS");}
   catch(Exception e){File.WriteAllText("Library/SanctuaryImport.result","FAIL "+e);Debug.LogException(e);}
  }
  [MenuItem("Bloodwake/Import Sanctuary Rooms")]
  public static void Build()
  {
   string model=Folder+Name+".fbx";AssetDatabase.ImportAsset(model,ImportAssetOptions.ForceSynchronousImport);
   var importer=(ModelImporter)AssetImporter.GetAtPath(model);importer.importAnimation=false;importer.importLights=false;importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;importer.SaveAndReimport();
   var source=AssetDatabase.LoadAssetAtPath<GameObject>(model);if(!source)throw new Exception("Sanctuary FBX missing");
   var instance=(GameObject)PrefabUtility.InstantiatePrefab(source);instance.name="Sanctuary rooms";SourceMaterials.Apply(instance,model);
   foreach(var renderer in instance.GetComponentsInChildren<MeshRenderer>())
   {
    renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.On;renderer.receiveShadows=true;
    foreach(var material in renderer.sharedMaterials.Where(m=>m))
    {
     if(!material.GetTexture("_BaseMap"))throw new Exception("Sanctuary albedo missing: "+renderer.name);
     // The GLB factor is already linear. The generic converter's gamma lift
     // makes these bright atlases clip under Bloodwake's cool key light.
     material.SetColor("_BaseColor",new Color(.56f,.53f,.49f,1));
     material.SetFloat("_Smoothness",Mathf.Min(material.GetFloat("_Smoothness"),.34f));
     EditorUtility.SetDirty(material);
    }
   }
   int triangles=instance.GetComponentsInChildren<MeshFilter>().Where(f=>f.sharedMesh).Sum(f=>f.sharedMesh.triangles.Length/3);
   if(instance.GetComponentsInChildren<MeshRenderer>().Length!=4||triangles<250000)throw new Exception($"Sanctuary geometry incomplete renderers={instance.GetComponentsInChildren<MeshRenderer>().Length} triangles={triangles}");
   PrefabUtility.SaveAsPrefabAsset(instance,Folder+"sanctuary_environment.prefab");UnityEngine.Object.DestroyImmediate(instance);AssetDatabase.SaveAssets();
   Debug.Log($"SANCTUARY_IMPORTED rooms=4 triangles={triangles}");
  }
 }
}
