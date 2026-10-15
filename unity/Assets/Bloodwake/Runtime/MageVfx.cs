using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static Mesh orbSphere,orbBlade;
  static Mesh OrbSphere()
  {
   if(orbSphere)return orbSphere;
   const int segments=20,rings=10;var vertices=new List<Vector3>();var normals=new List<Vector3>();var uv=new List<Vector2>();var triangles=new List<int>();
   for(int y=0;y<=rings;y++)for(int x=0;x<=segments;x++)
   {
    float a=Mathf.PI*y/rings,b=Mathf.PI*2*x/segments;var n=new Vector3(Mathf.Sin(a)*Mathf.Cos(b),Mathf.Cos(a),Mathf.Sin(a)*Mathf.Sin(b));
    vertices.Add(n*.21f);normals.Add(n);uv.Add(new Vector2((float)x/segments,(float)y/rings));
    if(y<rings&&x<segments){int q=y*(segments+1)+x;triangles.AddRange(new[]{q,q+1,q+segments+1,q+1,q+segments+2,q+segments+1});}
   }
   orbSphere=new Mesh{name="Arcane source core"};orbSphere.SetVertices(vertices);orbSphere.SetNormals(normals);orbSphere.SetUVs(0,uv);orbSphere.SetTriangles(triangles,0);orbSphere.RecalculateBounds();return orbSphere;
  }
  static Mesh OrbBlade()
  {
   if(orbBlade)return orbBlade;var vertices=new List<Vector3>();var triangles=new List<int>();
   for(int i=0;i<10;i++)
   {
    float t0=i/10f,t1=(i+1)/10f,a=t0*1.7f,b=t1*1.7f;
    var outer0=new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*(.29f+Mathf.Sin(t0*Mathf.PI)*.1f);
    var outer1=new Vector3(Mathf.Cos(b),0,Mathf.Sin(b))*(.29f+Mathf.Sin(t1*Mathf.PI)*.1f);
    var inner0=new Vector3(Mathf.Cos(a)*.28f,.035f,Mathf.Sin(a)*.28f);var inner1=new Vector3(Mathf.Cos(b)*.28f,.035f,Mathf.Sin(b)*.28f);
    foreach(var p in new[]{outer0,inner0,outer1,outer1,inner0,inner1}){vertices.Add(p);triangles.Add(triangles.Count);}
   }
   orbBlade=new Mesh{name="Arcane source curved shell"};orbBlade.SetVertices(vertices);orbBlade.SetTriangles(triangles,0);orbBlade.RecalculateNormals();orbBlade.RecalculateBounds();return orbBlade;
  }
  MeshRenderer OrbPart(Transform parent,string name,Mesh mesh,Material material,Vector3 scale)
  {
   var go=new GameObject(name);go.transform.SetParent(parent,false);go.transform.localScale=scale;go.AddComponent<MeshFilter>().sharedMesh=mesh;
   var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;return r;
  }
  public ArcaneOrbRig Orb(Vector3 position,bool hostile=false,bool tail=false)
  {
   var go=new GameObject(tail?"Arcane projectile":"Held arcane orb");go.transform.SetParent(transform,false);go.transform.position=position;
   var rig=go.AddComponent<ArcaneOrbRig>();rig.Game=Game;rig.Tone=hostile?Tone("ec45b5"):Arcane;rig.Accent=hostile?Tone("e02c50"):Tone("4036ab");
   OrbPart(go.transform,"Energy core",OrbSphere(),Material("arcane_core"),Vector3.one);
   var halo=OrbPart(go.transform,"Soft halo",Quad(),Material("glow"),Vector3.one*.95f);rig.Billboards.Add(halo.transform);
   rig.Motes=new GameObject("Orbiting shell").transform;rig.Motes.SetParent(go.transform,false);
   if(!materials.TryGetValue("arcane shell",out var shell))
   {
    shell=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Arcane dark shell"};shell.SetFloat("_Metallic",.55f);shell.SetFloat("_Smoothness",.5f);shell.SetFloat("_Cull",0);shell.EnableKeyword("_EMISSION");materials["arcane shell"]=shell;
   }
   for(int i=0;i<3;i++)
   {
    var blade=OrbPart(rig.Motes,"Curved shell",OrbBlade(),shell,Vector3.one);blade.transform.localRotation=Quaternion.Euler(.5f*Mathf.Rad2Deg,i*120,.45f*Mathf.Rad2Deg);
    var mote=OrbPart(rig.Motes,"Orbit mote",Quad(),Material("glow"),Vector3.one*.1f);mote.transform.localPosition=Quaternion.Euler(0,i*120,0)*Vector3.right*.31f;rig.Billboards.Add(mote.transform);
   }
   if(tail)
   {
    for(int i=0;i<2;i++)
    {
     var sheet=OrbPart(go.transform,"Plasma tail",Quad(),Material("arcane_trail"),new Vector3(.85f,2.1f,1));
     sheet.transform.localPosition=Vector3.back*1.008f;sheet.transform.localRotation=Quaternion.AngleAxis(i*90,Vector3.forward)*Quaternion.Euler(-90,0,0);
    }
   }
   var lamp=new GameObject("Orb light").AddComponent<Light>();lamp.transform.SetParent(go.transform,false);lamp.color=rig.Tone;lamp.intensity=tail?1.8f:.7f;lamp.range=tail?2.6f:1.2f;
   rig.Initialize();return rig;
  }
  public void HandMagic(ActorView actor,bool hostile=false)
  {
   if(actor.Kind!="mage")return;
   var rig=Orb(actor.MagicPalmPosition(),hostile);rig.Owner=actor;
  }
  public void FlameCrown(Vector3 pos,float radius)
  {
   for(int i=0;i<18;i++)
   {
    float angle=Mathf.PI*2*i/18+Random.Range(-.05f,.05f),tall=Random.Range(.55f,1.1f);var offset=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*radius*.91f+Vector3.up*tall*.6f;
    var fx=Sheet("Arcane flame crown",pos+offset,new Vector3(.7f,1.25f*tall,1),"arcane_flame",.7f,Arcane);fx.Block.SetColor("_Accent",Tone("4036ab"));fx.Apply();
    fx.transform.rotation=Quaternion.Euler(0,-angle*Mathf.Rad2Deg+90,0);
    fx.Tick=(p,dt)=>{float grow=Mathf.Lerp(.2f,1,1-Mathf.Pow(1-Mathf.Clamp01(fx.Age/.24f),3));fx.transform.position=pos+offset*grow;fx.transform.localScale=new Vector3(.7f,1.25f*tall,1)*grow;};
   }
  }
  public void ArcaneLeap(Vector3 pos,float radius)
  {
   ArcaneFractures(pos,radius*.8f,false);ArcaneDebris(pos,radius*.6f,false);
   BurstRing(pos,radius,Tone("cfc0ff"),34,4.8f,.62f);Flash(pos,Arcane,3.2f,radius*1.8f,.34f);ArcaneCrystals(pos,radius*.85f,false);
   for(int i=0;i<9;i++)
   {
    var dir=Quaternion.Euler(0,i*40,0)*Vector3.forward;var fx=Sheet("Arcane radial streak",pos+dir*radius*.5f+Vector3.up*.07f,new Vector3(.18f,radius,1),"glow",.32f,Tone("cfc0ff"),true);
    fx.transform.rotation=Quaternion.LookRotation(Vector3.up,dir);fx.Tick=(p,dt)=>fx.transform.position=pos+dir*radius*(.3f+.65f*p)+Vector3.up*.07f;
   }
  }
 }
 public sealed class ArcaneOrbRig:MonoBehaviour
 {
  public BloodwakeGame Game;public ActorView Owner;public Transform Motes;public Color Tone,Accent;public float Age;
  public readonly List<Transform> Billboards=new();Renderer[] renderers;MaterialPropertyBlock block;bool held;Light lamp;
  public void Initialize(){block=new MaterialPropertyBlock();renderers=GetComponentsInChildren<Renderer>();lamp=GetComponentInChildren<Light>();Apply();}
  void Apply()
  {
   block.SetColor("_Tone",Tone);block.SetColor("_Accent",Accent);block.SetColor("_BaseColor",Accent*.25f);block.SetColor("_EmissionColor",Tone*.06f);block.SetFloat("_Clock",Age);block.SetFloat("_Energy",.65f);
   foreach(var r in renderers)if(r){block.SetFloat("_Energy",r.name=="Orbit mote"?1.2f:.65f);r.SetPropertyBlock(block);}
  }
  void LateUpdate()
  {
   if(!Game){Destroy(gameObject);return;}
   if(Owner)
   {
    held=true;if(Owner.IsDead){Destroy(gameObject);return;}
    transform.position=Owner.MagicPalmPosition();float pulse=.75f*(1+Mathf.Sin(Age*5)*.06f)*(Owner.IsCasting?1.8f:1);transform.localScale=Vector3.one*pulse;
    foreach(var r in renderers)if(r)r.enabled=Owner.Visible;if(lamp)lamp.enabled=Owner.Visible;
   }
   else if(held){Destroy(gameObject);return;}
   Age+=Game.VfxDelta;Motes.localRotation=Quaternion.Euler(0,Age*360/.9f,0);foreach(var billboard in Billboards)if(billboard)billboard.rotation=Game.Cam.transform.rotation;Apply();
  }
 }
}
