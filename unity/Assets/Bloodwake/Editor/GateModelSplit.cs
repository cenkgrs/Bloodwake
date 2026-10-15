using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class GateModelSplit
 {
  struct Vertex
  {
   public Vector3 p,n;public Vector2 uv;
   public static Vertex Lerp(Vertex a,Vertex b,float t)=>new Vertex{p=Vector3.Lerp(a.p,b.p,t),n=Vector3.Lerp(a.n,b.n,t).normalized,uv=Vector2.Lerp(a.uv,b.uv,t)};
  }
  static List<Vertex> Clip(List<Vertex> poly,float x,bool greater)
  {
   var result=new List<Vertex>();if(poly.Count==0)return result;
   for(int i=0;i<poly.Count;i++)
   {
    var a=poly[i];var b=poly[(i+1)%poly.Count];bool insideA=greater?a.p.x>=x:a.p.x<=x,insideB=greater?b.p.x>=x:b.p.x<=x;
    if(insideA)result.Add(a);if(insideA!=insideB)result.Add(Vertex.Lerp(a,b,(x-a.p.x)/(b.p.x-a.p.x)));
   }return result;
  }
  [MenuItem("Bloodwake/Prepare articulated user gate")]
  public static void Build()
  {
   const string dir="Assets/Bloodwake/Resources/Environment/Kit01/gate/";
   var source=Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(dir+"gate.prefab"));
   var filter=source.GetComponentInChildren<MeshFilter>();var input=filter.sharedMesh;var v=input.vertices;var normals=input.normals;var uv=input.uv;var triangles=input.triangles;
   var bounds=source.GetComponentInChildren<Renderer>().bounds;float hinge=bounds.size.x*.33f;
   var root=new GameObject("gate_articulated");
   foreach(string part in new[]{"Frame","Left leaf","Right leaf"})
   {
    var vertices=new List<Vector3>();var ns=new List<Vector3>();var uvs=new List<Vector2>();var indices=new List<int>();
    float pivot=part=="Left leaf"?-hinge:part=="Right leaf"?hinge:0;
    for(int i=0;i<triangles.Length;i+=3)
    {
     var poly=new List<Vertex>();for(int j=0;j<3;j++){int k=triangles[i+j];poly.Add(new Vertex{p=filter.transform.TransformPoint(v[k]),n=filter.transform.TransformDirection(normals[k]),uv=uv[k]});}
     var regions=part=="Frame"?new[]{Clip(poly,-hinge,false),Clip(poly,hinge,true)}:new[]{Clip(Clip(poly,part=="Left leaf"?-hinge:0,true),part=="Left leaf"?0:hinge,false)};
     foreach(var region in regions)for(int j=1;j<region.Count-1;j++)foreach(var vertex in new[]{region[0],region[j],region[j+1]}){vertices.Add(vertex.p-Vector3.right*pivot);ns.Add(vertex.n);uvs.Add(vertex.uv);indices.Add(indices.Count);}
    }
    var mesh=new Mesh{name="User gate "+part,indexFormat=UnityEngine.Rendering.IndexFormat.UInt32};mesh.SetVertices(vertices);mesh.SetNormals(ns);mesh.SetUVs(0,uvs);mesh.SetTriangles(indices,0);mesh.RecalculateTangents();mesh.RecalculateBounds();
    string path=dir+part.Replace(' ','_')+".asset";var existing=AssetDatabase.LoadAssetAtPath<Mesh>(path);if(existing){EditorUtility.CopySerialized(mesh,existing);Object.DestroyImmediate(mesh);mesh=existing;}else AssetDatabase.CreateAsset(mesh,path);
    var obj=new GameObject(part);obj.transform.SetParent(root.transform,false);obj.transform.localPosition=Vector3.right*pivot;obj.AddComponent<MeshFilter>().sharedMesh=mesh;obj.AddComponent<MeshRenderer>().sharedMaterial=source.GetComponentInChildren<Renderer>().sharedMaterial;
   }
   PrefabUtility.SaveAsPrefabAsset(root,dir+"gate_articulated.prefab");Object.DestroyImmediate(source);Object.DestroyImmediate(root);AssetDatabase.SaveAssets();Debug.Log("BLOODWAKE_GATE_SPLIT_COMPLETE hinge="+hinge);
  }
 }
}
