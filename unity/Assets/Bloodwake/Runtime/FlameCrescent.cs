using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // A travelling crescent of fire: a swept-streak ribbon bent into a half moon, bulging toward where it flies,
 // shedding flame cards behind it. Vertical stands it on the ground like an upward cut; horizontal lays it
 // flat at waist height like a wide sweep. Gameplay moves it and decides what it hits.
 public sealed class FlameCrescent:MonoBehaviour
 {
  const int Segments=28;
  public float Radius,Width;public bool Vertical;public float Alpha=1;
  RevenantVfx fx;Mesh mesh;Material material;float shed;
  public static FlameCrescent Create(RevenantVfx fx,Vector3 position,Vector3 forward,float radius,float width,bool vertical)
  {
   forward.y=0;var go=new GameObject(vertical?"Rising flame crescent":"Sweeping flame crescent");
   go.transform.SetPositionAndRotation(position,Quaternion.LookRotation(forward.normalized));
   var c=go.AddComponent<FlameCrescent>();c.fx=fx;c.Radius=radius;c.Width=width;c.Vertical=vertical;c.Build();return c;
  }
  void Build()
  {
   mesh=new Mesh{name="Flame crescent"};mesh.MarkDynamic();gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;
   var r=gameObject.AddComponent<MeshRenderer>();material=new Material(Resources.Load<Shader>("Vfx/vesper_blade_streak")){name="Flame crescent"};material.SetFloat("_Intensity",2f);material.SetFloat("_Speed",5);
   r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;Rebuild();
  }
  // Local frame: z forward, the arc spans y (vertical) or x (horizontal).
  public Vector3 ArcPoint(float t,float inset=0)
  {
   float a=Mathf.Lerp(-90,90,t)*Mathf.Deg2Rad,bulge=Radius*.55f;var along=Mathf.Cos(a)*bulge-inset*Mathf.Cos(a);var span=Mathf.Sin(a)*Radius;
   return Vertical?new Vector3(0,span+Radius,along):new Vector3(span,0,along);
  }
  void Rebuild()
  {
   var verts=new Vector3[(Segments+1)*2];var uv=new Vector2[verts.Length];var col=new Color[verts.Length];var tris=new List<int>();
   for(int i=0;i<=Segments;i++)
   {
    float t=i/(float)Segments,taper=Mathf.Sin(t*Mathf.PI);
    verts[i*2]=ArcPoint(t);verts[i*2+1]=ArcPoint(t,Width*(.25f+.75f*taper));
    // The streak shader fades v toward both ends of the blade; map the arc so its middle burns hottest.
    float v=.12f+.8f*t;uv[i*2]=new Vector2(0,v);uv[i*2+1]=new Vector2(1,v);col[i*2]=col[i*2+1]=new Color(1,1,1,Alpha*(.35f+.65f*taper));
    if(i<Segments){int k=i*2;tris.AddRange(new[]{k,k+1,k+2,k+1,k+3,k+2});}
   }
   mesh.Clear();mesh.vertices=verts;mesh.uv=uv;mesh.colors=col;mesh.triangles=tris.ToArray();mesh.RecalculateBounds();
  }
  void Update()
  {
   Rebuild();shed-=Time.deltaTime;if(shed>0||fx==null||Alpha<.2f)return;shed=.045f;
   // Flames tear off the crescent and hang in the air behind it.
   for(int i=0;i<3;i++){var p=transform.TransformPoint(ArcPoint(Random.value,Width*.3f));fx.FlameCard(p,Random.Range(.4f,.7f)*Radius*.7f,Random.Range(.25f,.4f),-transform.forward*.6f+Vector3.up*.3f,0,2f*Alpha);}
  }
  void OnDestroy(){if(mesh)Destroy(mesh);if(material)Destroy(material);}
 }
}
