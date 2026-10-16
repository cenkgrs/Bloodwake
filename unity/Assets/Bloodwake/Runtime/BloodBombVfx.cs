using UnityEngine;
using UnityEngine.Rendering;
using System.Linq;
using System.Collections.Generic;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static Mesh bloodBombFan,bloodShard;
  static Mesh BloodShard()
  {
   if(bloodShard)return bloodShard;
   // A long, asymmetric double-pointed crystal. Separate face vertices keep
   // the sharp facets visible under the same wet specular material as Space.
   var points=new[]{new Vector3(.13f,0,-.12f),new Vector3(-.55f,0,.31f),new Vector3(-.06f,.20f,.46f),new Vector3(.43f,0,.56f),new Vector3(.10f,-.12f,.27f),new Vector3(-.12f,0,1)};
   var faces=new[]{0,2,1,0,3,2,0,4,3,0,1,4,5,1,2,5,2,3,5,3,4,5,4,1};
   var vertices=new Vector3[faces.Length];var indices=new int[faces.Length];
   for(int i=0;i<faces.Length;i++){vertices[i]=points[faces[i]];indices[i]=i%3==0?i:i%3==1?i+1:i-1;}
   bloodShard=new Mesh{name="Faceted blood glass shard"};bloodShard.vertices=vertices;bloodShard.triangles=indices;bloodShard.RecalculateNormals();bloodShard.RecalculateBounds();return bloodShard;
  }
  void BloodBombShards(Vector3 hands,Quaternion rotation,float radius)
  {
   var targets=Game.Enemies.Where(e=>!e.Emerging).ToArray();var impacted=new HashSet<Enemy>();
   const int count=25;
   for(int i=0;i<count;i++)
   {
    float angle=Mathf.Lerp(-42,42,(i+.5f)/count)+UnityEngine.Random.Range(-1.2f,1.2f);
    var direction=rotation*Quaternion.Euler(UnityEngine.Random.Range(-11f,12f),angle,0)*Vector3.forward;
    bool hero=i%4==0;float length=hero?UnityEngine.Random.Range(.65f,1.05f):UnityEngine.Random.Range(.25f,.65f),width=hero?UnityEngine.Random.Range(.32f,.46f):UnityEngine.Random.Range(.13f,.25f);
    float reach=radius*UnityEngine.Random.Range(.58f,.98f),speed=UnityEngine.Random.Range(13f,20f);
    var facing=Quaternion.LookRotation(direction)*Quaternion.Euler(0,0,UnityEngine.Random.Range(0,180));
    var go=new GameObject("Blood bomb glass shard");go.transform.SetParent(transform);go.transform.SetPositionAndRotation(hands+direction*.1f,facing);
    go.AddComponent<MeshFilter>().sharedMesh=BloodShard();var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=Material("blood_glass");renderer.shadowCastingMode=ShadowCastingMode.Off;
    var fx=Life(go,.56f);fx.Block.SetColor("_Tone",hero?new Color(.62f,.012f,.035f,1):new Color(.44f,.006f,.021f,.9f));fx.Apply();bool landed=false,shattered=false;Vector3 previousTip=hands;
    void Shape(float p)
    {
     if(shattered)return;
     float age=fx.Age,grow=Mathf.Lerp(.3f,1,Mathf.Clamp01(age/.035f));
     float travel=(reach-length)*(1-Mathf.Exp(-speed*age));
     float fall=Mathf.Max(0,age-.08f);var point=hands+direction*(.1f+travel)-Vector3.up*6*fall*fall;
     var tip=point+direction*length*grow;
     if(age>0)foreach(var target in targets)
     {
      if(!target.View||target.Emerging)continue;var centre=target.View.transform.position;
      var a=previousTip;var b=tip;var query=centre;query.y=a.y=b.y=0;
      var delta=b-a;float fraction=Mathf.Clamp01(Vector3.Dot(query-a,delta)/Mathf.Max(.00001f,delta.sqrMagnitude));
      if(Vector3.Distance(query,a+delta*fraction)>.46f||tip.y<centre.y+.1f||tip.y>centre.y+target.View.Height)continue;
      // Visual break only: gameplay damage already occurred at the clap marker.
      shattered=true;go.transform.localScale=Vector3.zero;
      if(impacted.Add(target)){Splatter(centre+Vector3.up*Mathf.Min(tip.y-centre.y,target.View.Height*.8f),rotation*Vector3.forward);Stain(centre,.9f,2.5f,.6f);}
      return;
     }
     previousTip=tip;
     if(point.y<=.08f)
     {
      if(!landed){landed=true;Stain(point,width*3,2.5f,.6f);}go.transform.localScale=Vector3.zero;return;
     }
     go.transform.position=point;go.transform.rotation=facing*Quaternion.Euler(0,0,age*38);
     float shrink=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.55f,1,p));
     go.transform.localScale=new Vector3(width,width*.48f,length)*grow*shrink;
    }
    Shape(0);fx.Tick=(p,dt)=>Shape(p);
   }
  }
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
