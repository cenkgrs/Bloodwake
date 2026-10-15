using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  Material wetBlood;
  void BloodVolume(Vector3 position,float radius,float height,float lifetime)
  {
   if(!wetBlood)
   {
    wetBlood=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Wet blood"};
    wetBlood.SetFloat("_Smoothness",.88f);wetBlood.SetFloat("_Metallic",0);
    wetBlood.SetColor("_BaseColor",new Color(.38f,.003f,.009f));
    materials["wet blood volume"]=wetBlood;
   }
   const int branches=19,segments=20,sides=8;
   var vertices=new Vector3[branches*(segments+1)*sides];var triangles=new List<int>();
   for(int branch=0;branch<branches;branch++)for(int step=0;step<segments;step++)for(int ring=0;ring<sides;ring++)
   {
    int q=(branch*(segments+1)+step)*sides+ring,n=(branch*(segments+1)+step)*sides+(ring+1)%sides;
    // Pinched jets separate into short airborne fragments near their ends.
    if(!(branch%4==1&&(step==13||step==17)))triangles.AddRange(new[]{q,q+sides,n,n,q+sides,n+sides});
   }
   var mesh=new Mesh{name="Liquid blood crown"};mesh.MarkDynamic();mesh.vertices=vertices;mesh.SetTriangles(triangles,0);
   var go=new GameObject("Lit blood volume");go.transform.SetParent(transform,false);go.transform.position=position;
   go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<OwnedVfxMesh>().Mesh=mesh;
   var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=wetBlood;renderer.shadowCastingMode=ShadowCastingMode.Off;
   // Thin sheets open between unequal jets. Grow along each curve, then carry
   // the released liquid outwards under gravity instead of scaling rigid rods.
   void Shape(float p)
   {
    float released=Mathf.Max(0,p-.16f)*lifetime,fade=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.65f,1,p));
    for(int branch=0;branch<branches;branch++)
    {
     float seed=Mathf.Sin(branch*7.13f),variation=.55f+.45f*seed*seed;
     float angle=branch*2.399963f;var direction=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));var side=Vector3.Cross(direction,Vector3.up);
     float growth=Mathf.SmoothStep(0,1,Mathf.Clamp01((p-(branch%4)*.015f)/.24f));
     bool sheet=branch%3==0;float breadth=sheet?.38f:.085f;
     float lift=sheet?.64f:branch%3==1?.82f:1;
     for(int step=0;step<=segments;step++)
     {
      float t=(float)step/segments,u=t*growth;
      float spread=Mathf.Pow(u,1.12f),rise=Mathf.Sin(u*Mathf.PI*.82f);
      float radial=radius*(.12f+spread*(.62f+.25f*variation))+released*1.7f*spread;
      float y=height*variation*lift*rise-9.8f*released*released*u;
      y+=Mathf.Sin(u*24+branch)*.09f*u;
      var centre=direction*radial+Vector3.up*Mathf.Max(.025f,y);
      centre+=side*(Mathf.Sin(u*18+branch)*.15f*u+seed*.15f*u*u);
      float width=(.018f+breadth*Mathf.Sin(Mathf.PI*t)*(.65f+.35f*Mathf.Sin(t*21+branch)))*(1-t*.9f)*growth*fade;
      width*=1-.82f*Mathf.Exp(-Mathf.Pow((t-(.42f+.09f*seed))/.055f,2));
      float thickness=sheet?.022f:.035f;
      // Orient the cross-section across the curved flow, not a fixed horizontal plane.
      float dr=radius*(.62f+.25f*variation)*1.12f*Mathf.Pow(Mathf.Max(.001f,u),.12f)+released*1.7f;
      float dy=height*variation*lift*Mathf.PI*.82f*Mathf.Cos(u*Mathf.PI*.82f)-9.8f*released*released;
      var tangent=(direction*dr+Vector3.up*dy).normalized;
      var depth=Vector3.Cross(side,tangent).normalized;
      // Closed elliptical sections give sheets a wet lit edge from either side.
      for(int ring=0;ring<sides;ring++)
      {
       float turn=ring*Mathf.PI*2/sides;
       vertices[(branch*(segments+1)+step)*sides+ring]=centre+side*Mathf.Cos(turn)*width+depth*Mathf.Sin(turn)*thickness*(1-t)*growth*fade;
      }
     }
    }
    mesh.vertices=vertices;mesh.RecalculateNormals();mesh.RecalculateBounds();
   }
   Shape(0);Life(go,lifetime).Tick=(p,dt)=>Shape(p);
  }
 }
}
