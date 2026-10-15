using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public static class CourtyardWell
 {
  static Mesh waterMesh;static Material waterMaterial;
  static Mesh WaterMesh()
  {
   if(waterMesh)return waterMesh;const int rings=5,segments=48;var vertices=new Vector3[1+rings*segments];var normals=new Vector3[vertices.Length];var uv=new Vector2[vertices.Length];var triangles=new int[segments*3+(rings-1)*segments*6];
   vertices[0]=Vector3.zero;normals[0]=Vector3.up;uv[0]=new Vector2(.5f,.5f);
   for(int ring=1;ring<=rings;ring++)for(int segment=0;segment<segments;segment++)
   {
    float angle=segment*Mathf.PI*2/segments,radius=ring/(float)rings,index=1+(ring-1)*segments+segment;float wave=Mathf.Sin(angle*3+ring*.9f)*.006f*radius;
    vertices[(int)index]=new Vector3(Mathf.Cos(angle)*radius,wave,Mathf.Sin(angle)*radius);normals[(int)index]=new Vector3(-Mathf.Cos(angle)*.035f,1,-Mathf.Sin(angle)*.035f).normalized;uv[(int)index]=new Vector2(.5f+Mathf.Cos(angle)*radius*.5f,.5f+Mathf.Sin(angle)*radius*.5f);
   }
   int t=0;for(int segment=0;segment<segments;segment++){triangles[t++]=0;triangles[t++]=1+(segment+1)%segments;triangles[t++]=1+segment;}
   for(int ring=1;ring<rings;ring++)for(int segment=0;segment<segments;segment++)
   {
    int next=(segment+1)%segments,a=1+(ring-1)*segments+segment,b=1+(ring-1)*segments+next,c=1+ring*segments+segment,d=1+ring*segments+next;
    triangles[t++]=a;triangles[t++]=b;triangles[t++]=c;triangles[t++]=b;triangles[t++]=d;triangles[t++]=c;
   }
   waterMesh=new Mesh{name="Well water surface"};waterMesh.vertices=vertices;waterMesh.normals=normals;waterMesh.uv=uv;waterMesh.triangles=triangles;waterMesh.RecalculateBounds();return waterMesh;
  }
  static Material WaterMaterial()
  {
   if(waterMaterial)return waterMaterial;waterMaterial=new Material(Shader.Find("Bloodwake/Presentation/WellWater")){name="Well water"};return waterMaterial;
  }
  public static void Apply(Transform room,Transform parent,Vector3 center,float radius)
  {
   var prefab=Resources.Load<GameObject>("Environment/Kit01/well/well");
   if(!prefab){Debug.LogWarning("BLOODWAKE_WELL_MODEL_MISSING");return;}
   var source=room.GetComponentsInChildren<Renderer>().Where(r=>
   {
    var b=r.bounds;var flat=new Vector2(b.center.x-center.x,b.center.z-center.z);
    // Preserve the courtyard paving, but remove every authored placeholder
    // component inside the well footprint before installing the finished prop.
    return r.enabled&&flat.magnitude<radius*1.8f&&b.size.y>.12f&&Mathf.Max(b.size.x,b.size.z)<radius*3.6f;
   }).ToArray();
   foreach(var renderer in source)renderer.enabled=false;
   var well=Object.Instantiate(prefab,parent);well.name="Courtyard well - user model";well.transform.rotation=Quaternion.Euler(0,180,0);
   var bounds=EnvironmentDressing.BoundsOf(well.GetComponentsInChildren<Renderer>());
   well.transform.position=center-new Vector3(bounds.center.x,bounds.min.y,bounds.center.z);
   var water=new GameObject("Courtyard well water");water.transform.SetParent(parent);water.transform.position=center+Vector3.up*1.025f;water.transform.localScale=new Vector3(radius*.69f,1,radius*.69f);
   water.AddComponent<MeshFilter>().sharedMesh=WaterMesh();var waterRenderer=water.AddComponent<MeshRenderer>();waterRenderer.sharedMaterial=WaterMaterial();waterRenderer.shadowCastingMode=ShadowCastingMode.Off;waterRenderer.receiveShadows=true;
   Debug.Log("BLOODWAKE_WELL_USER_MODEL source="+source.Length+" bounds="+bounds.size);
  }
 }
}
