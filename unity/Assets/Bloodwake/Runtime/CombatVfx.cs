using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  public void Slash(Vector3 pos,Vector3 dir,float radius,Color tone)
  {
   var fx=Surface(pos+Vector3.up*.55f,radius,tone,.22f,1,1.6f);float heading=Mathf.Atan2(dir.x,dir.z)*Mathf.Rad2Deg;
   fx.Tick=(p,dt)=>fx.transform.rotation=Quaternion.Euler(90,heading+(Mathf.Pow(1-p,3)*.9f-.45f)*Mathf.Rad2Deg,0);
  }
  public void BladeArc(Vector3 pos,Vector3 dir,float radius,float degrees,Color? tone=null,float opacity=1)
  {
   var go=new GameObject("Blade contact sector");go.transform.SetParent(transform);go.transform.position=pos+Vector3.up*.09f;
   var vertices=new List<Vector3>();var uv=new List<Vector2>();var indices=new List<int>();int steps=degrees>180?72:32;
   for(int i=0;i<steps;i++){vertices.Add(Vector3.zero);vertices.Add(Quaternion.Euler(0,-degrees/2+degrees*i/steps,0)*dir*radius);vertices.Add(Quaternion.Euler(0,-degrees/2+degrees*(i+1)/steps,0)*dir*radius);uv.Add(new Vector2((float)i/steps,0));uv.Add(new Vector2((float)i/steps,1));uv.Add(new Vector2((float)(i+1)/steps,1));indices.AddRange(new[]{i*3,i*3+1,i*3+2});}
   var mesh=new Mesh{name="Blade sector"};mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetTriangles(indices,0);mesh.RecalculateBounds();go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<OwnedVfxMesh>().Mesh=mesh;
   var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=Material("blade_arc");renderer.shadowCastingMode=ShadowCastingMode.Off;var fx=Life(go,.24f);fx.Block.SetColor("_Tone",tone??Color.white);fx.Block.SetFloat("_Opacity",opacity);fx.Apply();
  }
  static Mesh rock;
  static Mesh Rock()
  {
   if(rock)return rock;var source=ParticleMesh(false);var points=source.vertices;var vertices=new List<Vector3>();var indices=new List<int>();var uvs=new List<Vector2>();
   foreach(int index in source.triangles){var p=Vector3.Scale(points[index],new Vector3(.32f,.3f,.32f));float rough=1+Mathf.Sin(Vector3.Dot(p,new Vector3(73,39,91)))*.2f;vertices.Add(Vector3.Scale(p*rough,new Vector3(1,.7f,.85f)));indices.Add(indices.Count);uvs.Add(new Vector2(p.x+p.y*.3f,p.z+p.y)*5);}
   rock=new Mesh{name="Ground impact fragments"};rock.SetVertices(vertices);rock.SetTriangles(indices,0);rock.SetUVs(0,uvs);rock.RecalculateNormals();rock.RecalculateBounds();return rock;
  }
  public void GroundImpact(Vector3 pos,float radius)
  {
   Flash(pos,Tone("ffc285"),5,radius*1.6f,.2f);
   for(int crack=0;crack<8;crack++)
   {
    var dir=Quaternion.Euler(0,crack*30+Random.Range(-12,12),0)*Vector3.forward;var side=Vector3.Cross(dir,Vector3.up);var points=new Vector3[6];
    for(int j=0;j<6;j++){float t=j/5f;points[j]=pos+dir*radius*t*.85f+side*Random.Range(-.16f,.16f)*t+Vector3.up*.055f;}
    ArcaneLine(points,.022f,.52f,new Color(1.7f,.45f,.045f,1));
   }
   Sparks(pos+Vector3.up*.1f,Tone("ffb45b"),18,.32f,.7f,2.5f);
   var scar=Sheet("Ground fracture",pos+Vector3.up*.035f,Vector3.one*radius*2,"ground_scar",1.9f,Color.white,true);scar.Tick=(p,dt)=>scar.Block.SetFloat("_Age",scar.Age);
   for(int i=0;i<24;i++)
   {
    float angle=2*Mathf.PI*i/24+Random.Range(-.2f,.2f);var dir=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));var start=pos+dir*radius*Random.Range(.12f,.4f);var end=pos+dir*radius*Random.Range(.55f,.95f)+Vector3.up*.08f;var apex=(start+end)*.5f+Vector3.up*Random.Range(.5f,1.55f);float scale=Random.Range(.5f,1.5f);
    var fx=Particle(start,Vector3.one*scale,Tone("625343"),1.42f,false,true);fx.GetComponent<MeshFilter>().sharedMesh=Rock();fx.GetComponent<MeshRenderer>().sharedMaterial=Resources.Load<Material>("Environment/Kit01/wall/surface");fx.Block.SetFloat("_Smoothness",0);fx.transform.rotation=Quaternion.Euler(Random.value*Mathf.Rad2Deg,angle*Mathf.Rad2Deg,Random.value*Mathf.Rad2Deg);
    fx.Tick=(p,dt)=>{float t=fx.Age;fx.transform.position=t<.16f?Vector3.Lerp(start,apex,1-Mathf.Pow(1-t/.16f,2)):Vector3.Lerp(apex,end,Mathf.Pow(Mathf.Clamp01((t-.16f)/.26f),2));fx.transform.localScale=Vector3.one*scale*(1-Mathf.Clamp01((t-1.07f)/.35f));};
   }
   for(int i=0;i<22;i++)
   {
    var dir=Quaternion.Euler(0,Random.Range(0,360),0)*Vector3.forward;var start=pos+dir*radius*Random.Range(.1f,.5f)+Vector3.up*.18f;var velocity=dir*Random.Range(.8f,2.2f)+Vector3.up*Random.Range(.3f,.85f);var fx=Sheet("Impact dust",start,Vector3.one*.7f,"dust",1.1f,new Color(.43f,.40f,.36f,.65f));
    fx.Tick=(p,dt)=>{float t=fx.Age;fx.transform.position=start+velocity*t+Vector3.down*.4f*t*t;fx.transform.rotation=Game.Cam.transform.rotation;fx.transform.localScale=Vector3.one*Mathf.Lerp(.6f,2.3f,p);};
   }
  }
 }
 public sealed class OwnedVfxMesh:MonoBehaviour
 {
  public Mesh Mesh;void OnDestroy(){if(Mesh)Destroy(Mesh);}
 }
}
