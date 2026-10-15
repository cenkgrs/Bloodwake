using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  public static Color Arcane=>Tone("9b72ff");
  static readonly Mesh[] crystalVariants=new Mesh[3];
  Material crystalMaterial;
  static Mesh Crystal(int variant=0)
  {
   variant%=3;if(crystalVariants[variant])return crystalVariants[variant];
   // Thick broken ice wedges with an off-centre apex and chipped faces.
   // Duplicate face vertices so every fracture keeps a crisp normal.
   var outline=new[]{new Vector2(-.32f,0),new Vector2(-.39f,.3f),new Vector2(-.22f,.67f),new Vector2(.08f+variant*.035f,1),new Vector2(.28f,.57f-variant*.055f),new Vector2(.34f,.08f)};
   var points=new List<Vector3>();var indices=new List<int>();
   void Tri(Vector3 a,Vector3 b,Vector3 c){points.Add(a);points.Add(b);points.Add(c);indices.Add(indices.Count);indices.Add(indices.Count);indices.Add(indices.Count);}
   for(int i=0;i<outline.Length;i++)
   {
    var a=outline[i];var b=outline[(i+1)%outline.Length];
    var af=new Vector3(a.x,a.y,.18f*(1-a.y));var bf=new Vector3(b.x,b.y,.18f*(1-b.y));
    var ab=new Vector3(a.x,a.y,-.25f*(1-a.y*.65f));var bb=new Vector3(b.x,b.y,-.25f*(1-b.y*.65f));
    Tri(new Vector3(-.08f,.38f,.28f),bf,af);Tri(new Vector3(.045f,.4f,-.3f),ab,bb);Tri(af,bf,bb);Tri(af,bb,ab);
   }
   var mesh=new Mesh{name="Fractured ice plate "+variant};mesh.SetVertices(points);mesh.SetTriangles(indices,0);mesh.RecalculateNormals();mesh.RecalculateBounds();crystalVariants[variant]=mesh;return mesh;
  }
  public void ArcaneBlast(Vector3 pos,float radius,bool ice)
  {
   ArcaneFractures(pos,radius,ice);ArcaneCrystals(pos,radius,ice);ArcaneDebris(pos,radius,ice);
   BurstRing(pos,radius,Tone("c7c4ff"),ice?42:28,4.8f,.7f);Flash(pos,Arcane,ice?5:3.5f,radius*1.8f,.32f);
   Glow(pos+Vector3.up*.22f,Tone("d9d9ff"),radius*.7f,2,.14f);
   if(!ice)ArcaneColumn(pos,radius);
  }
  void ArcaneCrystals(Vector3 pos,float radius,bool ice)
  {
   if(!crystalMaterial)crystalMaterial=Material("arcane_crystal");
   int clusters=ice?13:7;
   for(int i=0;i<clusters;i++)
   {
    float angle=Mathf.PI*2*i/clusters+Random.Range(-.14f,.14f);var dir=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));var side=Vector3.Cross(Vector3.up,dir);
    float distance=radius*Random.Range(.55f,.90f);
    for(int shard=0;shard<4;shard++)
    {
     var start=pos+dir*(distance+(shard==1?0:Random.Range(-.3f,.3f)))+side*(shard-1)*.22f;
     var go=new GameObject("Arcane ground crystal");go.transform.SetParent(transform);go.transform.position=start;
     go.transform.rotation=Quaternion.LookRotation(dir)*Quaternion.Euler(Random.Range(18,48),Random.Range(-24,24),Random.Range(-20,20));
     go.AddComponent<MeshFilter>().sharedMesh=Crystal((i+shard)%3);var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=crystalMaterial;renderer.shadowCastingMode=ShadowCastingMode.Off;
     float delay=distance/radius*.16f+shard*.025f,tall=(shard==1&&i%3!=1?Random.Range(ice?1.4f:.7f,ice?2.3f:1.2f):Random.Range(.35f,.9f)),wide=Random.Range(.65f,1.05f);
     go.transform.localScale=Vector3.zero;var fx=Life(go,1.52f+delay);
     fx.Block.SetColor("_Tint",ice?new Color(.55f,.72f,.85f):new Color(.46f,.22f,.75f));
     fx.Tick=(p,dt)=>{float t=fx.Age-delay;float rise=Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.16f));float fall=Mathf.Clamp01((t-.7f)/.8f);go.transform.localScale=new Vector3(wide,tall*rise,1);go.transform.position=start-Vector3.up*fall*tall;fx.Block.SetFloat("_Fade",(1-fall)*rise);};fx.Apply();
    }
   }
   for(int i=0;i<24;i++)
   {
    var direction=Quaternion.Euler(0,i*15+Random.Range(-10,10),0)*Vector3.forward;var start=pos+direction*radius*Random.Range(.25f,.65f)+Vector3.up*.12f;var velocity=direction*radius*Random.Range(.35f,.8f)+Vector3.up*Random.Range(.05f,.2f);
    var fx=Sheet("Arcane ground mist",start,Vector3.one*.8f,"dust",Random.Range(1.05f,1.3f),new Color(.66f,.76f,.88f,.62f));
    fx.Tick=(p,dt)=>{fx.transform.position=start+velocity*fx.Age;fx.transform.localScale=new Vector3(Mathf.Lerp(.8f,3.2f,p),Mathf.Lerp(.35f,.7f,p),1);fx.transform.rotation=Game.Cam.transform.rotation;};
   }
  }
  public void Meteor(Vector3 start,Vector3 end,float travel)
  {
   ArcaneFlight(start,end,travel,true);var orb=Orb(start);orb.name="Arcane meteor";orb.transform.localScale=Vector3.one*1.52f;var fx=Life(orb.gameObject,travel);var apex=end+Vector3.up*6;
   fx.Tick=(p,dt)=>orb.transform.position=p<.45f?Vector3.Lerp(start,apex,Mathf.Sin(p/.45f*Mathf.PI*.5f)):Vector3.Lerp(apex,end+Vector3.up*.2f,Mathf.Pow((p-.45f)/.55f,2));
  }

  public void Muzzle(Vector3 pos,Vector3 dir,bool magic,Transform anchor=null)
  {
   var tone=magic?Arcane:Tone("ffcf8a");
   if(magic){Glow(pos,tone,.35f,1.5f,.07f);Flash(pos,tone,1.7f,1.5f,.07f);return;}
   GunMuzzleBurst(pos,dir,tone,anchor);Sparks(pos+dir*.12f,tone,5,.13f,.7f,1.8f);
   for(int i=0;i<5;i++)
   {
    var velocity=dir*Random.Range(.3f,.9f)+Vector3.up*Random.Range(.2f,.5f);var fx=Sheet("Gun smoke",pos,Vector3.one*.22f,"dust",.78f,new Color(.4f,.38f,.36f,.46f));
    fx.Tick=(p,dt)=>{fx.transform.position=pos+velocity*fx.Age;fx.transform.localScale=new Vector3(Mathf.Lerp(.22f,1.15f,p),Mathf.Lerp(.18f,.82f,p),1);fx.transform.rotation=Game.Cam.transform.rotation;};
   }
  }
  void GunMuzzleBurst(Vector3 pos,Vector3 dir,Color tone,Transform anchor)
  {
   var vertices=new List<Vector3>();var uv=new List<Vector2>();var triangles=new List<int>();
   for(int blade=0;blade<6;blade++)
   {
    float angle=blade*Mathf.PI/3,spread=blade%2==0?.085f:.055f,length=blade%2==0?.48f:.34f;var radial=new Vector3(Mathf.Cos(angle),Mathf.Sin(angle),0)*spread;
    vertices.Add(Vector3.forward*.015f);vertices.Add(Vector3.forward*length+radial);vertices.Add(Vector3.forward*(length*.72f)-radial);
    uv.Add(new Vector2(0,.5f));uv.Add(new Vector2(1,0));uv.Add(new Vector2(1,1));triangles.AddRange(new[]{blade*3,blade*3+1,blade*3+2});
   }
   var mesh=new Mesh{name="Gun muzzle star"};mesh.SetVertices(vertices);mesh.SetUVs(0,uv);mesh.SetTriangles(triangles,0);mesh.RecalculateBounds();
   var rotation=Quaternion.LookRotation(dir.sqrMagnitude>.001f?dir:Vector3.forward,Vector3.up);var go=new GameObject("Gun muzzle star");go.transform.SetParent(transform);go.transform.SetPositionAndRotation(pos,rotation);go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<OwnedVfxMesh>().Mesh=mesh;
   var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=Material("arcane_energy");renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
   var localPoint=anchor?anchor.InverseTransformPoint(pos):Vector3.zero;var localRotation=anchor?Quaternion.Inverse(anchor.rotation)*rotation:Quaternion.identity;
   var fx=Life(go,.085f);fx.Block.SetColor("_Tone",new Color(2.7f,1.45f,.42f,1));fx.Block.SetFloat("_Opacity",1);fx.Tick=(p,dt)=>{if(anchor)go.transform.SetPositionAndRotation(anchor.TransformPoint(localPoint),anchor.rotation*localRotation);fx.Block.SetFloat("_Opacity",(1-p)*(1-p));go.transform.localScale=Vector3.one*Mathf.Lerp(1,.35f,p);};fx.Apply();
  }
  public void Casing(Vector3 pos,Vector3 dir,string hand)
  {
   var side=Vector3.Cross(Vector3.up,dir).normalized*(hand=="L"?-1:1);float size=Random.Range(.75f,1.15f);
   var fx=Particle(pos+side*.06f,new Vector3(.028f,.085f,.026f)*size,Tone("c89b52"),.9f,true,true);fx.name="Spent casing";
   var velocity=side*Random.Range(.65f,1.05f)-dir*Random.Range(.08f,.25f)+Vector3.up*Random.Range(1.2f,1.8f);var spin=Random.onUnitSphere*Random.Range(500,900);
   fx.Tick=(p,dt)=>{float t=fx.Age;var point=pos+velocity*t-Vector3.up*4.9f*t*t;point.y=Mathf.Max(.035f,point.y);fx.transform.position=point;fx.transform.Rotate(spin*dt,Space.World);fx.transform.localScale=new Vector3(.028f,.085f,.026f)*size*(1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.75f,1,p)));};
  }
  public void BallisticTrace(Vector3 start,Vector3 end)
  {
   if((end-start).sqrMagnitude<.04f)return;var go=new GameObject("Ballistic tracer");go.transform.SetParent(transform);var line=go.AddComponent<LineRenderer>();line.useWorldSpace=true;line.positionCount=2;line.SetPositions(new[]{start,end});line.widthMultiplier=.014f;line.widthCurve=new AnimationCurve(new Keyframe(0,.25f),new Keyframe(.15f,1),new Keyframe(1,0));line.sharedMaterial=Material("arcane_energy");line.shadowCastingMode=ShadowCastingMode.Off;line.receiveShadows=false;
   var fx=Life(go,.13f);fx.Block.SetColor("_Tone",new Color(2.8f,1.55f,.48f,1));fx.Block.SetFloat("_Opacity",1);fx.Tick=(p,dt)=>{fx.Block.SetFloat("_Opacity",(1-p)*(1-p));line.widthMultiplier=.014f*(1-.45f*p);};fx.Apply();
  }
  public GameObject ProjectileVisual(Vector3 pos,Vector3 dir,bool magic,bool hostile)
  {
   if(magic){var orb=Orb(pos,hostile,true);orb.transform.rotation=Quaternion.LookRotation(dir);return orb.gameObject;}
   var go=new GameObject(hostile?"Hostile projectile":"Player projectile");go.transform.SetParent(transform);go.transform.position=pos;go.transform.rotation=Quaternion.LookRotation(dir);
   var trail=go.AddComponent<LineRenderer>();trail.useWorldSpace=false;trail.positionCount=3;trail.SetPositions(new[]{Vector3.back*.22f,Vector3.back*.035f,Vector3.forward*.025f});trail.widthMultiplier=.012f;
   trail.widthCurve=new AnimationCurve(new Keyframe(0,0),new Keyframe(.85f,1),new Keyframe(1,.2f));trail.sharedMaterial=Material("arcane_energy");trail.shadowCastingMode=ShadowCastingMode.Off;
   var fx=Life(go,float.PositiveInfinity);fx.Block.SetColor("_Tone",hostile?new Color(2,.55f,.25f):new Color(2.4f,1.45f,.48f));fx.Block.SetFloat("_Opacity",1);fx.Apply();return go;
  }

  public void ProjectileTrail(Vector3 pos,bool magic,bool hostile)
  {
   var fx=Glow(pos,hostile?Tone(magic?"ed46b8":"ff8a72"):magic?Arcane:Tone("dba167"),magic?.17f:.06f,magic?.65f:.8f,magic?.2f:.09f);
   fx.Tick=(p,dt)=>{fx.transform.localScale=Vector3.one*(magic?.17f:.06f)*(1-p);fx.transform.rotation=Game.Cam.transform.rotation;};
  }
  public void ProjectileImpact(Vector3 pos,bool magic,bool hostile,Vector3 direction=default)
  {
   var tone=hostile?Tone(magic?"ed46b8":"ff8a72"):magic?Arcane:Tone("ffcf8a");Sparks(pos,tone,magic?16:hostile?9:14,.3f,1.3f,3.4f);Glow(pos,tone,magic?.75f:.6f,1.15f,.18f);
   if(magic){pos.y=.08f;ArcaneFractures(pos,.9f,false);ArcaneDebris(pos,.45f,false);}
   else if(!hostile){Splatter(pos,direction.sqrMagnitude>.001f?direction:Vector3.forward);for(int i=0;i<3;i++){var velocity=-direction*Random.Range(.08f,.25f)+Vector3.up*Random.Range(.15f,.4f);var smoke=Sheet("Gun impact smoke",pos,Vector3.one*.16f,"dust",.48f,new Color(.35f,.32f,.3f,.4f));smoke.Tick=(p,dt)=>{smoke.transform.position=pos+velocity*smoke.Age;smoke.transform.localScale=Vector3.one*Mathf.Lerp(.16f,.65f,p);smoke.transform.rotation=Game.Cam.transform.rotation;};}}
  }
 }
}
