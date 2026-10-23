using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 // Effects for the Mage's moveset: ice shards, the force arc, the falling comet and the grip tether.
 public sealed partial class RevenantVfx
 {
  static readonly Color IceTint=new(.72f,.93f,1.25f);
  // One shard bursting out of the stone, leaning along the wave, then sinking back and fading.
  public void IceSpike(Vector3 at,Vector3 dir,float tall)
  {
   if(!crystalMaterial)crystalMaterial=Material("arcane_crystal");at.y=0;
   var go=new GameObject("Ice shard");go.transform.SetParent(transform);go.transform.position=at;
   go.transform.rotation=Quaternion.LookRotation(dir)*Quaternion.Euler(UnityEngine.Random.Range(10,28),UnityEngine.Random.Range(-28,28),UnityEngine.Random.Range(-14,14));
   go.AddComponent<MeshFilter>().sharedMesh=Crystal(UnityEngine.Random.Range(0,3));var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=crystalMaterial;r.shadowCastingMode=ShadowCastingMode.Off;
   float wide=UnityEngine.Random.Range(.65f,1f);go.transform.localScale=Vector3.zero;var fx=Life(go,.95f);fx.Block.SetColor("_Tint",IceTint);
   fx.Tick=(p,dt)=>
   {
    float t=fx.Age,rise=Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.07f)),sink=Mathf.Clamp01((t-.45f)/.5f);
    // A slight overshoot sells the punch out of the ground.
    float pop=rise*(1+.18f*Mathf.Sin(Mathf.Clamp01(t/.16f)*Mathf.PI));
    go.transform.localScale=new Vector3(wide,tall*pop,1);go.transform.position=at-Vector3.up*sink*tall*.9f;fx.Block.SetFloat("_Fade",(1-sink)*rise);
   };fx.Apply();
   if(UnityEngine.Random.value<.6f)
   {
    var dust=Sheet("Shard frost puff",at+Vector3.up*.15f,Vector3.one*.5f,"dust",.55f,new Color(.75f,.85f,.95f,.55f));
    var drift=Vector3.up*.4f+dir*.3f;dust.Tick=(p,dt)=>{dust.transform.position=at+Vector3.up*.15f+drift*dust.Age;dust.transform.localScale=new Vector3(Mathf.Lerp(.5f,1.6f,p),Mathf.Lerp(.35f,.8f,p),1);dust.transform.rotation=Game.Cam.transform.rotation;};
   }
   if(UnityEngine.Random.value<.35f)Sparks(at+Vector3.up*.3f,new Color(.8f,.92f,1),5,.3f,1.2f,3f);
  }

  // A flat band of violet force sweeping out across a sector, bright at its leading edge.
  public VfxLifetime ForceArc(Vector3 origin,Vector3 dir,float halfAngle,float time,float reach)
  {
   origin.y=.12f;var go=new GameObject("Force arc");go.transform.SetParent(transform);go.transform.SetPositionAndRotation(origin,Quaternion.LookRotation(dir));
   var mesh=new Mesh{name="Force arc band"};mesh.MarkDynamic();go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<OwnedVfxMesh>().Mesh=mesh;
   var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=Material("arcane_energy");r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
   const int segments=36;var vertices=new Vector3[(segments+1)*3];var uv=new Vector2[vertices.Length];var tris=new List<int>();
   for(int i=0;i<segments;i++)for(int band=0;band<2;band++){int a=i*3+band,b=a+3;tris.AddRange(new[]{a,a+1,b,b,a+1,b+1});}
   var fx=Life(go,time+.22f);
   void Shape(float radius,float width)
   {
    for(int i=0;i<=segments;i++)
    {
     float angle=Mathf.Lerp(-halfAngle,halfAngle,i/(float)segments)*Mathf.Deg2Rad;var ray=new Vector3(Mathf.Sin(angle),0,Mathf.Cos(angle));
     // The band thins toward the tips of the arc.
     float taper=Mathf.Sin(Mathf.PI*i/segments)*.7f+.3f;
     vertices[i*3]=ray*Mathf.Max(0,radius-width*1.6f*taper);vertices[i*3+1]=ray*radius+Vector3.up*.18f*taper;vertices[i*3+2]=ray*(radius+width*.35f*taper);
     float u=i/(float)segments;uv[i*3]=new Vector2(u,0);uv[i*3+1]=new Vector2(u,.85f);uv[i*3+2]=new Vector2(u,1);
    }
    mesh.vertices=vertices;mesh.uv=uv;mesh.SetTriangles(tris,0);mesh.RecalculateBounds();
   }
   fx.Tick=(p,dt)=>
   {
    float t=Mathf.Clamp01(fx.Age/time),radius=Mathf.Lerp(.6f,reach,1-(1-t)*(1-t));Shape(radius,Mathf.Lerp(.35f,.8f,t));
    float fade=fx.Age<time?1:1-Mathf.Clamp01((fx.Age-time)/.22f);fx.Block.SetColor("_Tone",new Color(.62f,.3f,1.45f,1));fx.Block.SetFloat("_Opacity",fade*.8f);
   };
   fx.Tick(0,0);fx.Apply();Flash(origin+dir*1.2f,Arcane,2.2f,4.5f,.2f);
   for(int i=-2;i<=2;i++)Sparks(origin+Quaternion.Euler(0,i*halfAngle*.4f,0)*dir*1.2f+Vector3.up*.3f,Tone("c9b5ff"),4,.35f,4f,7f);
   return fx;
  }

  // A jagged boulder of ice falls on the spot; a frost bloom on the ground marks where.
  public void IceComet(Vector3 target,float fall)
  {
   if(!crystalMaterial)crystalMaterial=Material("arcane_crystal");target.y=0;
   var frost=SheetTexture("frost_ground")?Textured("Comet frost mark",target+Vector3.up*.04f,Vector3.one*.5f,"frost_ground",fall+.5f,new Color(.7f,.82f,1,1),false,1,false,true):Sheet("Comet frost mark",target+Vector3.up*.04f,Vector3.one*.5f,"frost_ground",fall+.5f,new Color(.55f,.75f,1,1),true);
   frost.Tick=(p,dt)=>{float t=Mathf.Clamp01(frost.Age/fall);frost.transform.localScale=Vector3.one*Mathf.Lerp(.8f,5.6f,t*t);};
   var rock=new GameObject("Ice comet");rock.transform.SetParent(transform);
   for(int i=0;i<7;i++)
   {
    var shard=new GameObject("Comet shard");shard.transform.SetParent(rock.transform,false);shard.AddComponent<MeshFilter>().sharedMesh=Crystal(i%3);
    var sr=shard.AddComponent<MeshRenderer>();sr.sharedMaterial=crystalMaterial;sr.shadowCastingMode=ShadowCastingMode.On;
    shard.transform.localRotation=Quaternion.Euler(UnityEngine.Random.Range(0,360f),i*51,UnityEngine.Random.Range(0,360f));shard.transform.localPosition=shard.transform.localRotation*Vector3.up*-.25f;shard.transform.localScale=new Vector3(1.4f,1.9f,1.4f);
   }
   var core=Sheet("Comet glow",target,Vector3.one*1.6f,"glow",fall,new Color(.6f,.85f,1.4f,1));core.Block.SetFloat("_Energy",2.4f);core.Apply();
   var start=target+Vector3.up*10+new Vector3(-1.6f,0,1.6f);var fx=Life(rock,fall);fx.Block.SetColor("_Tint",new Color(.7f,.88f,1));fx.Apply();
   fx.Tick=(p,dt)=>
   {
    var pos=Vector3.Lerp(start,target+Vector3.up*.6f,p*p);rock.transform.position=pos;rock.transform.Rotate(new Vector3(210,140,60)*dt,Space.Self);
    core.transform.position=pos;core.transform.rotation=Game.Cam.transform.rotation;
    if(UnityEngine.Random.value<.7f){var trail=Sheet("Comet trail",pos,Vector3.one*.9f,"dust",.4f,new Color(.75f,.88f,1,.6f));trail.Tick=(q,d)=>{trail.transform.localScale=Vector3.one*Mathf.Lerp(.9f,.2f,q);trail.transform.rotation=Game.Cam.transform.rotation;};}
   };
  }

  // A crackling violet line from the palm to the seized foe.
  public TetherFx Tether(Func<Vector3> from,Func<Vector3> to)
  {
   var go=new GameObject("Grip tether");go.transform.SetParent(transform);var line=go.AddComponent<LineRenderer>();line.positionCount=14;line.useWorldSpace=true;
   line.widthCurve=new AnimationCurve(new Keyframe(0,.14f),new Keyframe(.5f,.06f),new Keyframe(1,.16f));line.sharedMaterial=Material("arcane_energy");line.shadowCastingMode=ShadowCastingMode.Off;line.numCapVertices=2;
   var tether=go.AddComponent<TetherFx>();tether.Init(line,from,to,this);return tether;
  }
  internal void TetherSpark(Vector3 at){Glow(at,Arcane,.35f,1.8f,.08f);}
 }
 public sealed class TetherFx:MonoBehaviour
 {
  LineRenderer line;Func<Vector3> from,to;RevenantVfx owner;float fade=1;bool released;MaterialPropertyBlock block;
  public Color Tone=new(.75f,.38f,1.6f,1);
  public void Init(LineRenderer l,Func<Vector3> a,Func<Vector3> b,RevenantVfx fx){line=l;from=a;to=b;owner=fx;block=new MaterialPropertyBlock();Update();}
  public void Release(){released=true;}
  void Update()
  {
   if(released){fade-=Time.deltaTime/.12f;if(fade<=0){Destroy(gameObject);return;}}
   Vector3 a=from(),b=to();var side=Vector3.Cross((b-a).normalized,Vector3.up);if(side.sqrMagnitude<.001f)side=Vector3.right;side.Normalize();
   for(int i=0;i<line.positionCount;i++){float t=i/(line.positionCount-1f),wobble=Mathf.Sin(t*Mathf.PI)*(Mathf.PerlinNoise(Time.time*18,i*.7f)-.5f)*.35f;line.SetPosition(i,Vector3.Lerp(a,b,t)+side*wobble+Vector3.up*wobble*.5f);}
   block.SetColor("_Tone",Tone);block.SetFloat("_Opacity",fade);line.SetPropertyBlock(block);
   if(owner&&UnityEngine.Random.value<.25f)owner.TetherSpark(b);
  }
 }
}
