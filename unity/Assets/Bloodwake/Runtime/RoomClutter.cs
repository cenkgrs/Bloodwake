using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 // A second, denser dressing pass for the walls' foot: varied cargo heaps from the kit pieces, so the
 // edges read as a lived-in town while the middle stays open to fight in. Also ash in the air and
 // embers over every fire. Adds no lights (they are the expensive part on this GPU).
 public sealed partial class BloodwakeGame
 {
  void DressEdges(string id)
  {
   var random=new System.Random(id.Aggregate(91,(h,c)=>h*37+c));float R(float a,float b)=>a+(float)random.NextDouble()*(b-a);
   var root=new GameObject("Edge clutter").transform;root.SetParent(roomRoot,false);
   var keep=new List<(Vector3 at,float radius)>();
   foreach(var door in (room["doors"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())keep.Add((Point(door.Value["at"]),4.4f));
   foreach(var marker in (room["markers"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())
    if(marker.Value is JArray list&&list.Count>0&&list[0] is JArray)foreach(var p in list)keep.Add((Point(p),1.6f));else keep.Add((Point(marker.Value),2.6f));
   // Fires and lanterns keep only a small clearing, so cargo can crowd around them as it would.
   foreach(var light in roomRoot.GetComponentsInChildren<Light>().Where(l=>l.type==LightType.Point))keep.Add((light.transform.position,.35f));
   int outside=0,kept=0,blocked=0;
   bool Free(Vector3 p,float radius)
   {
    if(Mathf.Abs(p.x)>half.x-.3f||Mathf.Abs(p.z)>half.y-.3f){outside++;return false;}
    if(!keep.All(k=>Vector3.Distance(new Vector3(p.x,0,p.z),new Vector3(k.at.x,0,k.at.z))>k.radius+radius)){kept++;return false;}
    if(!blockers.All(b=>{var e=b;e.Expand(new Vector3(radius*1.1f,0,radius*1.1f));return !e.Contains(new Vector3(p.x,b.center.y,p.z));})){blocked++;return false;}
    return true;
   }
   // Two bands along every wall: tight against it, and a sparser one a step further in at the corners.
   var spots=new List<(Vector3 at,Vector3 inward)>();
   void Band(float inset,float step)
   {
    for(float x=-half.x+inset;x<=half.x-inset;x+=step){spots.Add((new Vector3(x,0,-half.y+inset),Vector3.forward));spots.Add((new Vector3(x,0,half.y-inset),Vector3.back));}
    for(float z=-half.y+inset+step;z<=half.y-inset-step;z+=step){spots.Add((new Vector3(-half.x+inset,0,z),Vector3.right));spots.Add((new Vector3(half.x-inset,0,z),Vector3.left));}
   }
   Band(1.15f,2.1f);Band(2.4f,3.3f);
   foreach(var corner in new[]{new Vector3(-1,0,-1),new Vector3(1,0,-1),new Vector3(-1,0,1),new Vector3(1,0,1)})
    for(int i=0;i<3;i++)spots.Add((new Vector3(corner.x*(half.x-1.9f-R(0,1.6f)),0,corner.z*(half.y-1.9f-R(0,1.6f))),-corner.normalized));
   int placed=0,budget=Mathf.Clamp(Mathf.RoundToInt((half.x+half.y)*1.1f),14,34);
   foreach(var (spot,inward) in spots.OrderBy(_=>random.Next()))
   {
    if(placed>=budget)break;var p=spot+new Vector3(R(-.35f,.35f),0,R(-.35f,.35f));float yaw=Quaternion.LookRotation(inward).eulerAngles.y+R(-25,25);
    var along=Quaternion.Euler(0,yaw,0)*Vector3.right;
    switch(random.Next(6))
    {
     case 0: // Three barrels huddled together, one tipped over in front.
      if(!Free(p,1.1f))continue;
      Piece(root,"barrel",p,new Vector3(.68f,.92f,.68f),R(0,360),true);Piece(root,"barrel",p+along*.72f,new Vector3(.64f,.88f,.64f),R(0,360),true);
      var tipped=Piece(root,"barrel",p+along*.35f+inward*.75f,new Vector3(.64f,.88f,.64f),yaw,false);if(tipped)tipped.transform.parent.rotation=Quaternion.Euler(0,yaw+R(-30,30),90)*Quaternion.identity;
      if(tipped){var tp=tipped.transform.parent;tp.position=p+along*.35f+inward*.75f+Vector3.up*.32f;blockers.Add(new Bounds(tp.position,new Vector3(.9f,.7f,.9f)));}
      break;
     case 1: // Crates on crates with a sheet thrown over the top one.
      if(!Free(p,1f))continue;
      Piece(root,"crate",p,new Vector3(1.05f,1f,1.05f),yaw,true);Piece(root,"crate",p+along*1.05f,new Vector3(.9f,.85f,.9f),yaw+R(-8,8),true);
      Piece(root,"crate",p+Vector3.up*1f+along*.15f,new Vector3(.85f,.8f,.85f),yaw+R(10,30),false);
      Piece(root,"cloth",p+Vector3.up*1.0f+along*.15f,new Vector3(1.05f,.75f,1.05f),yaw+R(10,30),false);
      break;
     case 2: // A run of mixed cargo hugging the wall.
      if(!Free(p,1.3f))continue;
      for(int k=0;k<3;k++){var at=p+along*(k-1)*1.0f;if(random.NextDouble()<.5)Piece(root,"barrel",at,new Vector3(.62f,.86f,.62f),R(0,360),true);else Piece(root,"crate",at,new Vector3(.88f,R(.7f,.95f),.88f),yaw+R(-12,12),true);}
      break;
     case 3: // Lone barrel and a low crate, the cheap filler between the bigger heaps.
      if(!Free(p,.7f))continue;
      Piece(root,"barrel",p,new Vector3(.62f,.86f,.62f),R(0,360),true);Piece(root,"crate",p+along*.85f+inward*.2f,new Vector3(.7f,.55f,.7f),yaw+R(-20,20),true);
      break;
     case 4: // Covered goods: a draped table-high heap.
      if(!Free(p,1f))continue;
      Piece(root,"cloth",p,new Vector3(1.6f,1.05f,1.1f),yaw,true);Piece(root,"barrel",p+along*1.15f,new Vector3(.6f,.84f,.6f),R(0,360),true);
      break;
     default: // Tall stack in a corner of the band.
      if(!Free(p,.8f))continue;
      Piece(root,"crate",p,new Vector3(1f,1f,1f),yaw,true);Piece(root,"crate",p+Vector3.up,new Vector3(.9f,.9f,.9f),yaw+R(-15,15),false);Piece(root,"crate",p+Vector3.up*1.9f,new Vector3(.75f,.75f,.75f),yaw+R(-25,25),false);
      break;
    }
    keep.Add((p,1.2f));placed++;
   }
   Debug.Log($"BLOODWAKE_CLUTTER {id} heaps={placed}/{budget} spots={spots.Count} outside={outside} kept={kept} blocked={blocked} blockers={blockers.Count} half={half}");
   GroundDetail(root,random);
   AmbientParticles(root);
  }
  // Ground-level wear that never blocks a step: cracked flags, moss in the joints, mud, scattered straw.
  static Material crackMaterial,mossMaterial,mudMaterial,strawMaterial;
  void GroundDetail(Transform root,System.Random random)
  {
   float R(float a,float b)=>a+(float)random.NextDouble()*(b-a);
   if(!crackMaterial)
   {
    crackMaterial=DecalMaterial("Crack decal",Cracks(256,3),new Color(.02f,.018f,.018f,1),.2f);
    mossMaterial=DecalMaterial("Moss decal",Speckle(256,5,.5f),new Color(.16f,.22f,.09f,.95f),.1f);
    mudMaterial=DecalMaterial("Mud decal",Speckle(256,9,.75f),new Color(.11f,.08f,.06f,.8f),.55f);
    strawMaterial=DecalMaterial("Straw decal",Straw(256,11),new Color(.62f,.5f,.26f,1),.05f);
   }
   float fx=half.x-.6f,fz=half.y-.6f;int area=Mathf.RoundToInt(half.x*half.y);
   void Scatter(string name,Material m,int count,float min,float max,float edgeBias)
   {
    for(int i=0;i<count;i++)
    {
     // edgeBias pulls toward the walls, where grime gathers.
     float u=R(-1,1),v=R(-1,1);u=Mathf.Sign(u)*Mathf.Pow(Mathf.Abs(u),1-edgeBias);v=Mathf.Sign(v)*Mathf.Pow(Mathf.Abs(v),1-edgeBias);
     var d=Decal(root,name,new Vector3(u*fx,0,v*fz),R(min,max),R(0,360),m,.004f+i*.0002f);d.transform.localScale=Vector3.Scale(d.transform.localScale,new Vector3(1,R(.6f,1.2f),1));
    }
   }
   Scatter("Cracked flags",crackMaterial,Mathf.Clamp(area/6,6,22),1.2f,3.2f,0);
   Scatter("Moss",mossMaterial,Mathf.Clamp(area/8,5,16),1.2f,2.6f,.55f);
   Scatter("Mud",mudMaterial,Mathf.Clamp(area/12,3,10),1.6f,3.4f,.3f);
   Scatter("Straw",strawMaterial,Mathf.Clamp(area/14,3,9),1f,2f,.6f);
  }
  // Branching hairline cracks.
  static Texture2D Cracks(int size,int seed)
  {
   var a=new float[size*size];var rnd=new System.Random(seed);
   for(int c=0;c<5;c++)
   {
    float x=size*(.3f+.4f*(float)rnd.NextDouble()),y=size*(.3f+.4f*(float)rnd.NextDouble()),dir=(float)rnd.NextDouble()*6.283f;
    for(int s=0;s<size*.55f;s++)
    {
     dir+=((float)rnd.NextDouble()-.5f)*.6f;x+=Mathf.Cos(dir);y+=Mathf.Sin(dir);if(x<2||y<2||x>size-3||y>size-3)break;
     float w=1.4f*(1-s/(size*.55f));for(int oy=-2;oy<=2;oy++)for(int ox=-2;ox<=2;ox++){int ix=(int)x+ox,iy=(int)y+oy;float d=Mathf.Sqrt(ox*ox+oy*oy);a[iy*size+ix]=Mathf.Max(a[iy*size+ix],Mathf.Clamp01(w+.6f-d));}
     if(rnd.NextDouble()<.03){float bx=x,by=y,bd=dir+((float)rnd.NextDouble()<.5?1:-1)*.9f;for(int k=0;k<size*.15f;k++){bd+=((float)rnd.NextDouble()-.5f)*.5f;bx+=Mathf.Cos(bd);by+=Mathf.Sin(bd);if(bx<1||by<1||bx>size-2||by>size-2)break;a[(int)by*size+(int)bx]=Mathf.Max(a[(int)by*size+(int)bx],.8f);}}
    }
   }
   return FromAlpha(size,a,"Cracks");
  }
  // Patchy speckle inside a soft blob: moss (sparse) or mud (dense).
  static Texture2D Speckle(int size,int seed,float density)
  {
   var a=new float[size*size];float o=seed*11.7f;
   for(int y=0;y<size;y++)for(int x=0;x<size;x++)
   {
    float u=x/(float)size,v=y/(float)size,r=Vector2.Distance(new Vector2(u,v),new Vector2(.5f,.5f));
    float blob=Mathf.Clamp01((.42f+.08f*Mathf.PerlinNoise(u*3+o,v*3+o)-r)/.12f);
    float grain=Mathf.PerlinNoise(u*22+o,v*22+o)*.6f+Mathf.PerlinNoise(u*60+o,v*60+o)*.4f;
    a[y*size+x]=blob*Mathf.Clamp01((grain-(1-density))*3);
   }
   return FromAlpha(size,a,"Speckle");
  }
  // Short scattered stalks.
  static Texture2D Straw(int size,int seed)
  {
   var a=new float[size*size];var rnd=new System.Random(seed);
   for(int k=0;k<140;k++)
   {
    float ang=(float)rnd.NextDouble()*6.283f,rr=(float)System.Math.Sqrt(rnd.NextDouble())*size*.36f;float x=size*.5f+Mathf.Cos(ang)*rr,y=size*.5f+Mathf.Sin(ang)*rr,dir=(float)rnd.NextDouble()*6.283f,len=size*(.04f+.06f*(float)rnd.NextDouble());
    for(float t=0;t<len;t+=.5f){int ix=(int)(x+Mathf.Cos(dir)*t),iy=(int)(y+Mathf.Sin(dir)*t);if(ix<0||iy<0||ix>=size||iy>=size)continue;a[iy*size+ix]=Mathf.Max(a[iy*size+ix],.9f);}
   }
   return FromAlpha(size,a,"Straw");
  }
  static Texture2D FromAlpha(int size,float[] a,string name)
  {
   var t=new Texture2D(size,size,TextureFormat.RGBA32,true){wrapMode=TextureWrapMode.Clamp,name=name};var px=new Color32[size*size];
   for(int i=0;i<px.Length;i++)px[i]=new Color(1,1,1,a[i]);t.SetPixels32(px);t.Apply(true);return t;
  }
  static Texture2D emberDot;static Material ambientMaterial;
  // Ash drifting across the court, and embers lifting off every fire.
  void AmbientParticles(Transform root)
  {
   var source=Resources.Load<Material>("Vfx/ambient_particle");if(!source)return;
   if(!emberDot){const int n=32;emberDot=new Texture2D(n,n,TextureFormat.RGBA32,false){name="Soft dot",wrapMode=TextureWrapMode.Clamp};var px=new Color32[n*n];for(int y=0;y<n;y++)for(int x=0;x<n;x++){float d=Vector2.Distance(new Vector2(x+.5f,y+.5f),new Vector2(n*.5f,n*.5f))/(n*.5f);px[y*n+x]=new Color(1,1,1,Mathf.Pow(Mathf.Clamp01(1-d),2));}emberDot.SetPixels32(px);emberDot.Apply();}
   if(!ambientMaterial){ambientMaterial=new Material(source){name="Ambient particles"};ambientMaterial.SetTexture("_BaseMap",emberDot);}var material=ambientMaterial;
   ParticleSystem System(string name,Vector3 at,Transform parent)
   {
    var go=new GameObject(name);go.transform.SetParent(parent,false);go.transform.position=at;var ps=go.AddComponent<ParticleSystem>();ps.Stop();
    var r=go.GetComponent<ParticleSystemRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;return ps;
   }
   var ash=System("Drifting ash",Vector3.up*1.2f,root);
   {var main=ash.main;main.loop=true;main.startLifetime=new ParticleSystem.MinMaxCurve(5,9);main.startSpeed=new ParticleSystem.MinMaxCurve(.05f,.2f);main.startSize=new ParticleSystem.MinMaxCurve(.025f,.06f);
    main.startColor=new ParticleSystem.MinMaxGradient(new Color(.55f,.5f,.48f,.35f),new Color(.8f,.45f,.3f,.45f));main.maxParticles=260;main.simulationSpace=ParticleSystemSimulationSpace.World;
    var em=ash.emission;em.rateOverTime=(half.x*half.y)*.18f;var sh=ash.shape;sh.shapeType=ParticleSystemShapeType.Box;sh.scale=new Vector3(half.x*2,2.2f,half.y*2);
    var noise=ash.noise;noise.enabled=true;noise.strength=.25f;noise.frequency=.25f;var vel=ash.velocityOverLifetime;vel.enabled=true;vel.x=new ParticleSystem.MinMaxCurve(.15f,.35f);vel.y=new ParticleSystem.MinMaxCurve(-.05f,.08f);vel.z=new ParticleSystem.MinMaxCurve(-.05f,.05f);
    var col=ash.colorOverLifetime;col.enabled=true;var g=new Gradient();g.SetKeys(new[]{new GradientColorKey(Color.white,0),new GradientColorKey(Color.white,1)},new[]{new GradientAlphaKey(0,0),new GradientAlphaKey(1,.2f),new GradientAlphaKey(1,.8f),new GradientAlphaKey(0,1)});col.color=g;
    ash.Simulate(6,true,true);ash.Play();}
   foreach(var light in roomRoot.GetComponentsInChildren<Light>().Where(l=>l.type==LightType.Point&&(l.name.Contains("Brazier")||l.name.Contains("Lantern"))))
   {
    var embers=System("Embers",light.transform.position+Vector3.down*.15f,root);
    var main=embers.main;main.loop=true;main.startLifetime=new ParticleSystem.MinMaxCurve(1.2f,2.6f);main.startSpeed=new ParticleSystem.MinMaxCurve(.3f,.9f);main.startSize=new ParticleSystem.MinMaxCurve(.02f,.05f);
    main.startColor=new ParticleSystem.MinMaxGradient(new Color(1,.55f,.15f,1),new Color(1,.25f,.05f,1));main.maxParticles=40;main.simulationSpace=ParticleSystemSimulationSpace.World;main.gravityModifier=-.05f;
    var em=embers.emission;em.rateOverTime=light.name.Contains("Brazier")?7:3;var sh=embers.shape;sh.shapeType=ParticleSystemShapeType.Cone;sh.angle=18;sh.radius=.18f;sh.rotation=new Vector3(-90,0,0);
    var noise=embers.noise;noise.enabled=true;noise.strength=.5f;noise.frequency=.8f;
    var col=embers.colorOverLifetime;col.enabled=true;var g=new Gradient();g.SetKeys(new[]{new GradientColorKey(new Color(1,.8f,.4f),0),new GradientColorKey(new Color(1,.25f,.05f),1)},new[]{new GradientAlphaKey(1,0),new GradientAlphaKey(.8f,.6f),new GradientAlphaKey(0,1)});col.color=g;
    embers.Simulate(2,true,true);embers.Play();
   }
  }
 }
}
