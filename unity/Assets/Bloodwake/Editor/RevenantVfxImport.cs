using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Bloodwake.Editor
{
 public static class RevenantVfxImport
 {
  const string Root="Assets/Bloodwake/Resources/Vfx/";
  const string Model="Assets/Bloodwake/Resources/Models/revenant_player/revenant_player.fbx";
  [MenuItem("Bloodwake/Import Revenant VFX and Events")]
  public static void Build()
  {
   foreach(var id in new[]{"revenant_claws","revenant_burst"})
   {
    var data=JObject.Parse(File.ReadAllText(Root+id+".json"));
    var root=new GameObject(id);
    try
    {
     foreach(var source in data["meshes"])
     {
      string name=(string)source["name"],path=Root+name+".asset";
      var mesh=AssetDatabase.LoadAssetAtPath<Mesh>(path);
      if(!mesh){mesh=new Mesh{name=name};AssetDatabase.CreateAsset(mesh,path);}else mesh.Clear();
      mesh.vertices=source["positions"].Select(v=>new Vector3((float)v[0],(float)v[1],(float)v[2])).ToArray();
      mesh.normals=source["normals"].Select(v=>new Vector3((float)v[0],(float)v[1],(float)v[2])).ToArray();
      mesh.uv=source["uv"].Select(v=>new Vector2((float)v[0],1-(float)v[1])).ToArray();
      // GLTF stores top-left UVs; Unity and Godot expose bottom-left UVs to shaders.
      mesh.triangles=source["indices"].Values<int>().ToArray();mesh.RecalculateBounds();EditorUtility.SetDirty(mesh);
      var child=new GameObject(name);child.transform.SetParent(root.transform,false);child.AddComponent<MeshFilter>().sharedMesh=mesh;
      var renderer=child.AddComponent<MeshRenderer>();renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
      string materialPath=Root+name+".mat";var material=AssetDatabase.LoadAssetAtPath<Material>(materialPath);
      var shader=AssetDatabase.LoadAssetAtPath<Shader>(Root+id+".shader");
      if(!material){material=new Material(shader);AssetDatabase.CreateAsset(material,materialPath);}else material.shader=shader;
      material.SetFloat("_Wisps",name.Contains("Wisps")||name.Contains("Veil")?1:0);EditorUtility.SetDirty(material);renderer.sharedMaterial=material;
     }
     PrefabUtility.SaveAsPrefabAsset(root,Root+id+".prefab");
    }
    finally {UnityEngine.Object.DestroyImmediate(root);}
   }
   AssetDatabase.ImportAsset(Model,ImportAssetOptions.ForceUpdate);
   ValidateEvents();RevenantLayersImport.Build();AssetDatabase.SaveAssets();Debug.Log("BLOODWAKE_REVENANT_VFX_IMPORTED");
  }
  public static void ValidateEvents()
  {
   var actions=JObject.Parse(File.ReadAllText("Assets/Bloodwake/Resources/Data/revenant_events.json"))["actions"];
   int count=0;
   foreach(var clip in AssetDatabase.LoadAllAssetsAtPath(Model).OfType<AnimationClip>().Where(c=>!c.name.StartsWith("__preview__")))
   {
    var expected=actions[clip.name]?["events"] as JObject;if(expected==null)continue;
    foreach(var marker in expected.Properties())
    {
     float seconds=((float)marker.Value-1)/60f;
     var events=clip.events.Where(e=>e.functionName=="OnRevenantMarker"&&e.stringParameter==marker.Name).ToArray();
     if(events.Length!=1||Mathf.Abs(events[0].time-seconds)>.0001f)throw new Exception("Wrong marker time: "+clip.name+"/"+marker.Name+" expected="+seconds+" actual="+string.Join(",",events.Select(e=>e.time))+" length="+clip.length);
     count++;
    }
   }
   if(count!=actions.Children<JProperty>().Sum(p=>(p.Value["events"] as JObject)?.Count??0))throw new Exception("Revenant clip events missing");
   Debug.Log("BLOODWAKE_REVENANT_EVENT_TIMES "+count+" passed");
  }

 }
 public sealed class RevenantAnimationImport:AssetPostprocessor
 {
  public override uint GetVersion()=>4;
  void OnPreprocessAnimation()
  {
   if(!assetPath.EndsWith("/revenant_player.fbx",StringComparison.Ordinal))return;
   const string path="Assets/Bloodwake/Resources/Data/revenant_events.json";
   var actions=JObject.Parse(File.ReadAllText(path))["actions"];
   var importer=(ModelImporter)assetImporter;var clips=importer.clipAnimations;
   if(clips.Length==0)clips=importer.defaultClipAnimations;
   foreach(var clip in clips)
   {
    var markers=actions[clip.name.Split('|').Last()]?["events"] as JObject;if(markers==null)continue;
    if(clip.name.EndsWith("_Additive",StringComparison.Ordinal)){clip.hasAdditiveReferencePose=true;clip.additiveReferencePoseFrame=clip.firstFrame;}
    float frames=clip.lastFrame-clip.firstFrame;
    if(frames<=0)throw new Exception("Invalid Revenant clip range: "+clip.name);
    // Production FBX is exported at 60fps. Importer events use normalized
    // positions; normalize authored frames by the ACTUAL imported frame range.
    clip.events=clip.events.Where(e=>e.functionName!="OnRevenantMarker").Concat(markers.Properties().Select(p=>new AnimationEvent{
     time=((float)p.Value-1)/frames,functionName="OnRevenantMarker",stringParameter=p.Name,
     messageOptions=SendMessageOptions.DontRequireReceiver
    })).OrderBy(e=>e.time).ToArray();
   }
   importer.clipAnimations=clips;
  }
 }
}
