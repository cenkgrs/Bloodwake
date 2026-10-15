using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static Mesh bloodBombFan;
  static Mesh BloodBombFan()
  {
   if(bloodBombFan)return bloodBombFan;
   const int rings=40,slices=96;var vertices=new Vector3[(rings+1)*(slices+1)];var uv=new Vector2[vertices.Length];var triangles=new int[rings*slices*6];int index=0;
   for(int r=0;r<=rings;r++)for(int s=0;s<=slices;s++)
   {
    float radial=(float)r/rings,across=(float)s/slices,angle=Mathf.Lerp(-Mathf.PI/4,Mathf.PI/4,across);int v=r*(slices+1)+s;
    vertices[v]=new Vector3(Mathf.Sin(angle)*radial,0,Mathf.Cos(angle)*radial);uv[v]=new Vector2(radial,across);
    if(r<rings&&s<slices){triangles[index++]=v;triangles[index++]=v+1;triangles[index++]=v+slices+1;triangles[index++]=v+1;triangles[index++]=v+slices+2;triangles[index++]=v+slices+1;}
   }
   bloodBombFan=new Mesh{name="Blood bomb 90 degree liquid fan"};bloodBombFan.vertices=vertices;bloodBombFan.uv=uv;bloodBombFan.triangles=triangles;bloodBombFan.RecalculateNormals();
   bloodBombFan.bounds=new Bounds(new Vector3(0,0,.5f),new Vector3(2,5,2));return bloodBombFan;
  }
  void BloodBombSheet(Vector3 hands,Quaternion rotation,float radius,int layer)
  {
   var go=new GameObject("Blood bomb liquid sheet");go.transform.SetParent(transform);go.transform.SetPositionAndRotation(hands,rotation);go.transform.localScale=new Vector3(radius,1,radius);
   go.AddComponent<MeshFilter>().sharedMesh=BloodBombFan();var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=Material("blood_bomb");renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
   var fx=Life(go,.48f);fx.Block.SetFloat("_Layer",layer);fx.Block.SetFloat("_Seed",(layer+2)*9.17f);fx.Apply();
  }
 }
}
