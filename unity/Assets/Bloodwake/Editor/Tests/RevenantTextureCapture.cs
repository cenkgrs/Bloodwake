using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class RevenantTextureCapture
 {
  const string Request="Library/RevenantTextureCapture.request";
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying||!File.Exists(Request))return;
   var game=Object.FindFirstObjectByType<BloodwakeGame>();if(!game||!game.Player||game.Player.Kind!="revenant")return;
   string folder=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(folder);
   var camera=game.Cam;var pos=camera.transform.position;var rot=camera.transform.rotation;var size=camera.orthographicSize;var target=camera.targetTexture;var active=RenderTexture.active;
   var renderers=game.Player.GetComponentsInChildren<Renderer>();var materials=renderers.Select(r=>r.sharedMaterials).ToArray();
   var rt=new RenderTexture(960,960,24);var image=new Texture2D(960,960,TextureFormat.RGB24,false);
   var oldMaterials=new System.Collections.Generic.List<Material>();
   try
   {
    var focus=game.Player.transform.position+Vector3.up*game.Player.Height*.5f;
    camera.transform.position=focus+game.Player.transform.TransformDirection(new Vector3(3,1.5f,5));camera.transform.LookAt(focus);camera.orthographicSize=game.Player.Height*.65f;camera.targetTexture=rt;
    for(int version=0;version<2;version++)
    {
     if(version==1)
     for(int i=0;i<renderers.Length;i++)
     {
      renderers[i].sharedMaterials=materials[i].Select(original=>{
       var copy=new Material(original);oldMaterials.Add(copy);const string root="Assets/Bloodwake/Resources/Models/revenant_player/";
       copy.SetTexture("_BaseMap",AssetDatabase.LoadAssetAtPath<Texture2D>(root+"SourceImage_1.jpg"));
       copy.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>(root+"SourceImage_0.jpg"));
       copy.SetTexture("_MetallicGlossMap",AssetDatabase.LoadAssetAtPath<Texture2D>(root+"Packed_SourceImage_2.png"));return copy;}).ToArray();
     }
     camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,960,960),0,0);image.Apply();File.WriteAllBytes(Path.Combine(folder,version==0?"restored.png":"previous.png"),image.EncodeToPNG());
    }
    Debug.Log("REVENANT_TEXTURE_CAPTURE_COMPLETE "+folder);
   }
   finally
   {
    for(int i=0;i<renderers.Length;i++)renderers[i].sharedMaterials=materials[i];
    foreach(var mat in oldMaterials)Object.DestroyImmediate(mat);
    camera.targetTexture=target;camera.transform.SetPositionAndRotation(pos,rot);camera.orthographicSize=size;RenderTexture.active=active;rt.Release();Object.DestroyImmediate(rt);Object.DestroyImmediate(image);
   }
  }
 }
}
