using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  void ArcaneLine(Vector3[] points,float width,float life,Color tint)
  {
   var go=new GameObject("Arcane branching fissure");go.transform.SetParent(transform);var line=go.AddComponent<LineRenderer>();line.useWorldSpace=true;line.positionCount=points.Length;line.SetPositions(points);line.widthMultiplier=width;line.numCornerVertices=2;line.sharedMaterial=Material("arcane_energy");line.shadowCastingMode=ShadowCastingMode.Off;line.receiveShadows=false;
   var fx=Life(go,life);fx.Block.SetColor("_Tone",tint);fx.Tick=(p,dt)=>{fx.Block.SetFloat("_Opacity",(1-p)*(1-p));line.widthMultiplier=width*(1+.6f*p);};fx.Apply();
  }
  void ArcaneFractures(Vector3 pos,float radius,bool ice)
  {
   // Ice leaves the painted frost bloom once delivered; the arcane (non-ice) blast keeps its violet procedural fracture.
   if(ice&&SheetTexture("frost_ground"))Textured("Frozen fractured ground",pos+Vector3.up*.035f,Vector3.one*radius*2.1f,"frost_ground",1.65f,new Color(.8f,.88f,1,1),false,1,false,true).transform.Rotate(Vector3.forward,UnityEngine.Random.Range(0,360f),Space.Self);
   else Sheet("Frozen fractured ground",pos+Vector3.up*.035f,Vector3.one*radius*2,"frost_ground",1.65f,ice?new Color(.85f,.9f,1,1):new Color(.8f,.55f,1,.75f),true);
   // Sparse short branches retain a directional impact without a radial wire cage.
   for(int i=0;i<6;i++)
   {
    var dir=Quaternion.Euler(0,i*60+Random.Range(-20,20),0)*Vector3.forward;var side=Vector3.Cross(dir,Vector3.up);
    var pts=new Vector3[5];for(int j=0;j<5;j++){float t=j/4f;pts[j]=pos+dir*radius*(.2f+.65f*t)+side*Random.Range(-.13f,.13f)+Vector3.up*(.07f+Mathf.Sin(t*Mathf.PI)*.2f);}
    ArcaneLine(pts,.014f,.38f,new Color(.65f,.42f,1.5f,1));
   }
  }

  public void ArcaneWarning(Vector3 pos,float radius,Color tone,float life)
  {
   // A broken, directional footprint communicates the affected area without
   // drawing another perfect circle on the floor.
   for(int branch=0;branch<8;branch++)
   {
    float angle=branch*45+Mathf.Sin(branch*8.17f)*13;var dir=Quaternion.Euler(0,angle,0)*Vector3.forward;var side=Vector3.Cross(Vector3.up,dir);
    var points=new Vector3[4];
    for(int point=0;point<4;point++)
    {
     float t=point/3f;points[point]=pos+dir*radius*(.12f+.78f*t)+side*radius*Mathf.Sin(branch*3.1f+point*2.7f)*.045f+Vector3.up*.06f;
    }
    ArcaneLine(points,.012f,life,tone*1.4f);
   }
   var core=Glow(pos+Vector3.up*.18f,tone,.26f,.7f,life);
   core.Tick=(p,dt)=>{core.transform.rotation=Game.Cam.transform.rotation;core.transform.localScale=Vector3.one*Mathf.Lerp(.14f,.42f,p);};
  }

  void ArcaneDebris(Vector3 pos,float radius,bool ice)
  {
   for(int i=0;i<48;i++)
   {
    var dir=Quaternion.Euler(0,Random.Range(0,360),0)*Vector3.forward;float offset=Random.Range(.25f,.7f)*radius;var start=pos+dir*offset+Vector3.up*.12f;float scale=Random.Range(.07f,.24f);
    bool shard=i%3!=0;var fx=Particle(start,Vector3.one*scale,Tone(shard?"bcb8ec":"514d58"),Random.Range(.65f,1.1f),false,true);fx.GetComponent<MeshFilter>().sharedMesh=shard?Crystal():Rock();
    if(shard)fx.GetComponent<MeshRenderer>().sharedMaterial=Material("arcane_crystal");
    var velocity=dir*Random.Range(.8f,2f)+Vector3.up*Random.Range(2.5f,4.5f);var spin=Random.onUnitSphere*Random.Range(120,420);fx.transform.rotation=Random.rotation;
    fx.Tick=(p,dt)=>{float t=fx.Age;fx.transform.position=start+velocity*t-Vector3.up*4*t*t;fx.transform.Rotate(spin*dt,Space.World);fx.transform.localScale=Vector3.one*scale*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.7f,1,p)));};
   }
  }
 }
}
