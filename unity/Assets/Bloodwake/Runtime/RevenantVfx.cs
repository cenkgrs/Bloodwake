using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Bloodwake
{
 // Geometry and shader equations were ported from the original fx.gd. This component
 // owns its materials; transient renderers use property blocks, never .material.
 public sealed partial class RevenantVfx:MonoBehaviour
 {
  public BloodwakeGame Game;
  readonly Dictionary<string,Material> materials=new();
  static Mesh quad,sphere,prism;
  public static Color Tone(string hex){ColorUtility.TryParseHtmlString("#"+hex,out var c);return c;}
  Material Material(string name)
  {
   if(materials.TryGetValue(name,out var m))return m;
   var shader=Resources.Load<Shader>("Vfx/"+name);if(!shader)throw new InvalidOperationException("Missing VFX shader "+name);
   m=new Material(shader){name="Shared VFX "+name};materials.Add(name,m);return m;
  }
  void OnDestroy(){foreach(var m in materials.Values)if(m)Destroy(m);}
  static Mesh Quad()
  {
   if(quad)return quad;
   quad=new Mesh{name="VFX unit quad"};quad.vertices=new[]{new Vector3(-.5f,-.5f,0),new Vector3(.5f,-.5f,0),new Vector3(.5f,.5f,0),new Vector3(-.5f,.5f,0)};
   quad.uv=new[]{Vector2.zero,Vector2.right,Vector2.one,Vector2.up};quad.triangles=new[]{0,1,2,0,2,3};quad.RecalculateNormals();quad.RecalculateBounds();return quad;
  }
  public VfxLifetime Sheet(string name,Vector3 position,Vector3 scale,string shader,float life,Color tone,bool ground=false)
  {
   var go=new GameObject(name);go.transform.SetParent(transform);go.transform.position=position;go.transform.localScale=scale;
   go.transform.rotation=ground?Quaternion.Euler(90,0,0):Game.Cam.transform.rotation;
   go.AddComponent<MeshFilter>().sharedMesh=Quad();var r=go.AddComponent<MeshRenderer>();r.sharedMaterial=Material(shader);r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
   var fx=Life(go,life);fx.Block.SetColor("_Tone",tone);fx.Apply();return fx;
  }
  VfxLifetime Life(GameObject go,float duration){var fx=go.AddComponent<VfxLifetime>();fx.Game=Game;fx.Duration=Mathf.Max(.01f,duration);return fx;}
  public VfxLifetime Surface(Vector3 pos,float radius,Color tone,float life,int shape=3,float energy=1)
  {
   var fx=Sheet("Blood sigil",pos+Vector3.up*.05f,Vector3.one*radius*2,"combat_surface",life,tone,true);
   fx.Block.SetFloat("_Shape",shape);fx.Block.SetFloat("_Energy",energy);fx.Apply();return fx;
  }
  public void Flash(Vector3 pos,Color tone,float energy,float radius,float life)
  {
   var go=new GameObject("Blood light");go.transform.SetParent(transform);go.transform.position=pos+Vector3.up*.8f;
   var light=go.AddComponent<Light>();light.type=LightType.Point;light.color=tone;light.range=radius;light.intensity=energy;light.shadows=LightShadows.None;
   Life(go,life).Tick=(p,dt)=>light.intensity=energy*(1-p);
  }
  public VfxLifetime Glow(Vector3 pos,Color tone,float size,float energy,float life)
  {
   var fx=Sheet("Blood glow",pos,Vector3.one*size,"glow",life,tone);fx.Block.SetFloat("_Energy",energy);fx.Apply();fx.transform.rotation=Game.Cam.transform.rotation;
   fx.Tick=(p,dt)=>{fx.transform.rotation=Game.Cam.transform.rotation;};return fx;
  }
  VfxLifetime Authored(string asset,Vector3 pos,Vector3 scale,float life)
  {
   var prefab=Resources.Load<GameObject>("Vfx/"+asset);if(!prefab)throw new InvalidOperationException("Import Revenant VFX first: "+asset);
   var go=Instantiate(prefab,transform);go.name=asset;go.transform.position=pos;go.transform.localScale=scale;return Life(go,life);
  }
  public void Claws(Vector3 pos,Vector3 direction,float sourceRadius,bool backhand,bool wide)
  {
   var fx=Authored("revenant_claws",pos+Vector3.up*.15f,new Vector3(sourceRadius*2,2.8f,sourceRadius*2),.42f);
   fx.transform.rotation=Quaternion.LookRotation(direction.sqrMagnitude>.001f?direction:Vector3.forward);
   fx.Block.SetFloat("_ReverseSweep",backhand?1:0);fx.Apply();
   // The rake lights the ground and whatever it tears: a short arterial-red flash out along the swing.
   var swing=direction.sqrMagnitude>.001f?direction.normalized:Vector3.forward;Flash(pos+swing*sourceRadius*.6f,Tone(wide?"ff2442":"e01834"),wide?2.2f:1.4f,sourceRadius*1.6f+1.2f,wide?.16f:.11f);

  }
  public void Fountain(Vector3 pos,float radius,float height,float life){var authored=Authored("revenant_burst",pos,new Vector3(radius,height,radius),life);authored.Block.SetFloat("_Opacity",.28f);authored.Apply();BloodVolume(pos,radius,height,life);}
  public void Gate(Vector3 pos,float radius)
  {
   Fountain(pos,radius,1.5f,.45f);Flash(pos,Tone("c80e2e"),.6f,2,.16f);
  }
  public void Travel(Vector3 start,Vector3 end)
  {
   var delta=end-start;if(delta.sqrMagnitude<.01f)return;
   var fx=Sheet("Blood teleport trail",(start+end)*.5f+Vector3.up*.5f,new Vector3(.9f,delta.magnitude,1),"glow",.32f,Tone("ae102d"),true);
   fx.transform.rotation=Quaternion.LookRotation(Vector3.up,delta.normalized);
   for(int i=1;i<=5;i++)Sparks(Vector3.Lerp(start,end,i/6f)+Vector3.up*.7f,Tone("b30b28"),3,.3f,1.3f,3.4f);
  }
  public void Charge(Vector3 pos,float radius,float life)
  {
   var actor=Game.Player;Transform left=null,right=null;
   foreach(var bone in actor.Animator.GetComponentsInChildren<Transform>())
   {if(bone.name.EndsWith("LeftHand"))left=bone;else if(bone.name.EndsWith("RightHand"))right=bone;}
   // Blood is drawn toward the animated hands, with no floor decal or orbit ring.
   for(int i=0;i<28;i++)
   {
    var hand=i%2==0?left:right;
    var offset=UnityEngine.Random.insideUnitSphere;offset.y=Mathf.Abs(offset.y)*1.2f+.15f;offset.x*=1.25f;offset.z*=1.25f;
    var from=pos+offset;float size=UnityEngine.Random.Range(.035f,.075f),delay=(i%7)*.055f;
    var drop=Particle(from,Vector3.one*size,Tone("820819"),life,false,true);drop.Block.SetFloat("_Smoothness",.85f);drop.Apply();
    drop.Tick=(p,dt)=>
    {
     if(!actor){Destroy(drop.gameObject);return;}
     float t=Mathf.Clamp01((p-delay)/(1-delay));var destination=hand?hand.position:actor.transform.position+Vector3.up*1.1f;
     var point=Vector3.Lerp(from,destination,t*t)+Vector3.up*Mathf.Sin(t*Mathf.PI)*.22f;
     var direction=destination-point;drop.transform.position=point;
     if(direction.sqrMagnitude>.0001f)drop.transform.rotation=Quaternion.FromToRotation(Vector3.up,direction.normalized);
     float fade=Mathf.Sin(t*Mathf.PI);drop.transform.localScale=new Vector3(size,size*2.8f,size)*fade;
    };
   }
   foreach(var hand in new[]{left,right})
   {
    var glow=Glow(hand?hand.position:pos+Vector3.up,Tone("ad1022"),.18f,.5f,life);
    glow.Tick=(p,dt)=>{if(!actor){Destroy(glow.gameObject);return;}glow.transform.position=hand?hand.position:actor.transform.position+Vector3.up;glow.transform.rotation=Game.Cam.transform.rotation;glow.transform.localScale=Vector3.one*Mathf.Lerp(.12f,.3f,p);};
   }
  }

  public void BloodBomb(Vector3 hands,Vector3 forward,float radius)
  {
   forward.y=0;forward=forward.sqrMagnitude>.001f?forward.normalized:Vector3.forward;
   var facing=Quaternion.LookRotation(forward);
   // Instant aerial detonation. No fountain, delayed acceleration or floor sigil.
   var core=Particle(hands,Vector3.one*.55f,Tone("9c1026"),.12f,false,true);core.name="Blood bomb core";
   core.Tick=(p,dt)=>core.transform.localScale=Vector3.one*Mathf.Lerp(.55f,.08f,p);
   var flash=Glow(hands,Tone("e8213b"),1.5f,1.8f,.14f);flash.name="Blood bomb flash";
   flash.Tick=(p,dt)=>{flash.transform.rotation=Game.Cam.transform.rotation;flash.transform.localScale=Vector3.one*Mathf.Lerp(1.5f,2,p);};
   BloodVolume(hands,radius,1.9f,.78f,true,facing);
   // Dense supporting spray surrounds Space-style sheets and tapering liquid jets.
   for(int i=0;i<64;i++)
   {
    float angle=Mathf.Lerp(-Mathf.PI/4,Mathf.PI/4,(i+UnityEngine.Random.value)/64);
    var direction=facing*new Vector3(Mathf.Sin(angle),UnityEngine.Random.Range(-.3f,.45f),Mathf.Cos(angle)).normalized;
    var start=hands+direction*.06f;var velocity=direction*UnityEngine.Random.Range(radius*3.5f,radius*5f);
    float size=UnityEngine.Random.Range(.035f,.085f);
    var drop=Particle(start,new Vector3(size,size*5,size),Tone(i%4==0?"ae132b":"700b1b"),.85f,false,true);
    drop.name="Blood bomb droplet";drop.transform.rotation=Quaternion.FromToRotation(Vector3.up,direction);
    bool landed=false;
    drop.Tick=(p,dt)=>
    {
     float t=drop.Age;
     // Fast initial spray settles inside the blast footprint, then falls.
     var point=start+velocity*((1-Mathf.Exp(-5*t))/5)-Vector3.up*4.9f*t*t;
     if(point.y<=.03f)
     {
      if(!landed){landed=true;Stain(point,size*4,2.5f,.6f);}drop.transform.localScale=Vector3.zero;return;
     }
     drop.transform.position=point;
     var tangent=velocity*Mathf.Exp(-5*t)-Vector3.up*9.8f*t;
     if(tangent.sqrMagnitude>.001f)drop.transform.rotation=Quaternion.FromToRotation(Vector3.up,tangent.normalized);
     drop.transform.localScale=new Vector3(size,size*Mathf.Lerp(5,1,p),size)*(1-p*.6f);
    };
   }
  }
  public void Burst(Vector3 pos,float radius,float height=3.5f)
  {
   Fountain(pos,radius,height,.85f);
   for(int i=0;i<55;i++){var dir=Quaternion.Euler(0,UnityEngine.Random.Range(0,360),0)*Vector3.forward;var start=pos+dir*UnityEngine.Random.Range(.2f,.65f)+Vector3.up*.5f;float size=UnityEngine.Random.Range(.035f,.095f);var drop=Particle(start,Vector3.one*size,Tone("6e0818"),UnityEngine.Random.Range(.65f,1.05f),false,true);var velocity=dir*UnityEngine.Random.Range(1.4f,4f)+Vector3.up*UnityEngine.Random.Range(2,5f);drop.Tick=(p,dt)=>{float t=drop.Age;var current=velocity-Vector3.up*9.8f*t;var point=start+velocity*t-Vector3.up*4.9f*t*t;point.y=Mathf.Max(.028f,point.y);drop.transform.position=point;drop.transform.rotation=Quaternion.FromToRotation(Vector3.up,current.normalized);float shrink=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.7f,1,p));drop.transform.localScale=new Vector3(size,size*(1+current.magnitude*.2f),size)*shrink;};}
   Stain(pos,radius*2,2.5f,.6f);BurstRing(pos,radius,Tone("d71435"),32,5.5f,.7f);Flash(pos,Tone("d71435"),.9f,radius,.25f);
  }
  public void Impact(Vector3 pos,float stainHold=0)
  {
   var tone=Tone("ef1931");Sparks(pos,tone,12,.3f,1.3f,3.4f);var flare=Glow(pos,tone,.38f,1.4f,.16f);
   flare.Tick=(p,dt)=>{flare.transform.localScale=Vector3.one*.38f*Mathf.Lerp(1,1.7f,p);flare.transform.rotation=Game.Cam.transform.rotation;};
   Flash(pos,tone,.65f,1.8f,.12f);Stain(pos,.85f,stainHold,stainHold>0?.6f:1.4f);
  }
  public void Stain(Vector3 pos,float size,float hold,float dry)
  {
   pos.y=.025f;var fx=Sheet("Blood stain",pos,Vector3.one*size,"revenant_blood",hold+dry,Color.white,true);
   fx.transform.Rotate(Vector3.forward,UnityEngine.Random.Range(0,360),Space.Self);
   fx.Tick=(p,dt)=>fx.Block.SetFloat("_Progress",Mathf.Clamp01((fx.Age-hold)/dry));
  }
  static Mesh ParticleMesh(bool spike)
  {
   if(spike)
   {
    if(prism)return prism;prism=new Mesh{name="VFX prism"};
    prism.vertices=new[]{new Vector3(-.5f,-.5f,-.5f),new Vector3(.5f,-.5f,-.5f),new Vector3(0,.5f,-.5f),new Vector3(-.5f,-.5f,.5f),new Vector3(.5f,-.5f,.5f),new Vector3(0,.5f,.5f)};
    prism.triangles=new[]{0,2,1,3,4,5,0,1,4,0,4,3,1,2,5,1,5,4,2,0,3,2,3,5};prism.RecalculateNormals();prism.RecalculateBounds();return prism;
   }
   if(sphere)return sphere;var vertices=new List<Vector3>();var indices=new List<int>();const int segments=6,rings=5;
   for(int y=0;y<=rings;y++)for(int x=0;x<=segments;x++){float a=Mathf.PI*y/rings,b=2*Mathf.PI*x/segments;vertices.Add(new Vector3(Mathf.Sin(a)*Mathf.Cos(b),Mathf.Cos(a),Mathf.Sin(a)*Mathf.Sin(b))*.5f);}
   for(int y=0;y<rings;y++)for(int x=0;x<segments;x++){int a=y*(segments+1)+x,b=a+segments+1;indices.AddRange(new[]{a,a+1,b,a+1,b+1,b});}
   sphere=new Mesh{name="VFX low polygon sphere"};sphere.SetVertices(vertices);sphere.SetTriangles(indices,0);sphere.RecalculateNormals();sphere.RecalculateBounds();return sphere;
  }
  VfxLifetime Particle(Vector3 pos,Vector3 size,Color tone,float life,bool spike=false,bool lit=false)
  {
   var go=new GameObject(spike?"Blood spark":"Blood particle");go.transform.SetParent(transform);go.transform.position=pos;go.transform.localScale=size;go.AddComponent<MeshFilter>().sharedMesh=ParticleMesh(spike);
   var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=lit?Effects.Mat(tone):Material(spike?"particle_opaque":"particle");renderer.shadowCastingMode=ShadowCastingMode.Off;renderer.receiveShadows=false;
   var fx=Life(go,life);fx.Block.SetColor("_Tone",tone);if(lit)fx.Block.SetFloat("_Smoothness",.25f);fx.Apply();return fx;
  }
  public void Splatter(Vector3 pos,Vector3 direction)
  {
   direction.y=0;if(direction.sqrMagnitude<.001f)direction=Vector3.forward;direction.Normalize();var side=Vector3.Cross(direction,Vector3.up);
   // A burst of red mist where the blood leaves the body.
   var puff=Sheet("Blood mist puff",pos+direction*.2f,Vector3.one*.4f,"dust",.34f,new Color(.55f,.03f,.06f,.7f));var drift=direction*.9f+Vector3.up*.25f;
   puff.Tick=(p,dt)=>{puff.transform.position=pos+direction*.2f+drift*puff.Age;puff.transform.localScale=Vector3.one*Mathf.Lerp(.4f,1.5f,p);puff.transform.rotation=Game.Cam.transform.rotation;};
   for(int i=0;i<16;i++)
   {
    var end=pos+direction*UnityEngine.Random.Range(.9f,2.1f)+side*UnityEngine.Random.Range(-.4f,.4f);end.y=.024f;
    var start=pos+direction*.3f+Vector3.up*UnityEngine.Random.Range(.95f,1.4f)+side*UnityEngine.Random.Range(-.12f,.12f);
    float life=UnityEngine.Random.Range(.32f,.48f),height=UnityEngine.Random.Range(.2f,.5f);
    float size=UnityEngine.Random.Range(.045f,.11f);var fx=Particle(start,new Vector3(size,size*2.2f,size),Tone(UnityEngine.Random.value<.4f?"b0102a":"6e0712"),life,false,true);
    fx.Tick=(p,dt)=>{fx.transform.position=Vector3.Lerp(start,end,p)+Vector3.up*(4*p*(1-p)*height);var velocity=(end-start)+Vector3.up*(4*(1-2*p)*height);fx.transform.rotation=Quaternion.FromToRotation(Vector3.up,velocity.normalized);};
    fx.Completed=()=>Stain(end,UnityEngine.Random.Range(.12f,.3f),UnityEngine.Random.Range(4,6),1.25f);
   }
  }
  public void Sparks(Vector3 pos,Color color,int count,float life,float minSpeed,float maxSpeed)
  {
   for(int i=0;i<count;i++)
   {
    var velocity=UnityEngine.Random.onUnitSphere*UnityEngine.Random.Range(minSpeed,maxSpeed);
    var fx=Particle(pos+UnityEngine.Random.insideUnitSphere*.09f,new Vector3(.025f,.09f,.018f)*UnityEngine.Random.Range(.45f,1),color,life,true);
    fx.Tick=(p,dt)=>{float t=fx.Age;fx.transform.position=pos+velocity*t+Vector3.down*2.75f*t*t;fx.transform.rotation=Game.Cam.transform.rotation;};
   }
  }
  public void BurstRing(Vector3 pos,float radius,Color color,int count,float speed,float life)
  {
   for(int i=0;i<count;i++)
   {
    var dir=Quaternion.Euler(0,UnityEngine.Random.Range(0,360),0)*Vector3.forward;
    var start=pos+dir*radius*UnityEngine.Random.Range(.2f,.55f);float v=UnityEngine.Random.Range(.3f,.6f)*speed,accel=UnityEngine.Random.Range(1.6f,2.6f)*speed;
    float scale=.044f*UnityEngine.Random.Range(.5f,1.1f);var fx=Particle(start,Vector3.one*scale,color,life);
    fx.Tick=(p,dt)=>{float t=fx.Age;fx.transform.position=start+dir*accel*t*t*.5f+Vector3.up*(v*t-1.5f*t*t);fx.transform.localScale=Vector3.one*scale*(1-p);};
   }
  }
  public void Mark(Transform target,Color tone)
  {
   var fx=Glow(target.position+Vector3.up*2.1f,tone,1.1f,1.6f,float.PositiveInfinity);fx.name="RuinMark";
   fx.transform.SetParent(target,true);fx.Tick=(p,dt)=>{fx.transform.position=target.position+Vector3.up*2.1f;fx.transform.rotation=Game.Cam.transform.rotation;fx.transform.localScale=Vector3.one*1.1f*Mathf.Lerp(1,1.35f,(1-Mathf.Cos(fx.Age*Mathf.PI/.45f))*.5f);};
   Sparks(target.position+Vector3.up*.25f,tone,7,.28f,.4f,1.2f);
  }
  public void Hands(ActorView actor)
  {
   if(actor.Kind!="revenant")return;
   foreach(var bone in actor.Animator.GetComponentsInChildren<Transform>())
   {
    if(!(bone.name.EndsWith("RightHand")||bone.name.EndsWith("LeftHand")||bone.name=="hand_l"||bone.name=="hand_r"))continue;
    float next=0;var fx=Glow(bone.position,Tone("ab102b"),.23f,.55f,float.PositiveInfinity);fx.name="Blood hand";
    fx.Tick=(p,dt)=>
    {
     if(!actor||!bone||actor.IsDead){Destroy(fx.gameObject);return;}
     fx.transform.position=bone.position;fx.transform.rotation=Game.Cam.transform.rotation;
     fx.Block.SetColor("_Tone",actor.Visible?Tone("ab102b"):Color.clear);
     next-=dt;if(!actor.Visible||next>0)return;next=.38f/8;
     float scale=.0432f*UnityEngine.Random.Range(.6f,1);var mote=Particle(bone.position+UnityEngine.Random.insideUnitSphere*.024f,Vector3.one*scale,Tone("c51634"),.38f);
     var origin=bone.position;var velocity=UnityEngine.Random.insideUnitSphere*.12f;
     mote.Tick=(progress,delta)=>{mote.transform.position=origin+velocity*mote.Age;mote.transform.localScale=Vector3.one*scale*(1-progress);mote.Block.SetColor("_Tone",new Color(.773f,.086f,.204f,1-progress));};
    };
   }
  }
  public void Dissolve(ActorView actor)
  {
   var dissolve=actor.gameObject.AddComponent<RevenantDissolve>();dissolve.Game=Game;
   dissolve.Begin(Resources.Load<Shader>("Vfx/revenant_dissolve"));
  }
  public void DamageText(Vector3 pos,float amount,Color color)
  {
   var go=new GameObject("Damage number");go.transform.SetParent(transform);var start=pos+new Vector3(UnityEngine.Random.Range(-.2f,.2f),2,0);go.transform.SetPositionAndRotation(start,Game.Cam.transform.rotation);
   var label=go.AddComponent<TextMesh>();label.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");label.fontSize=38;label.characterSize=.08f;label.anchor=TextAnchor.MiddleCenter;label.alignment=TextAlignment.Center;label.text=Mathf.RoundToInt(amount).ToString();label.color=color;
   label.font.RequestCharactersInTexture("0123456789",38);var m=Material("damage_text");m.SetTexture("_MainTex",label.font.material.mainTexture);go.GetComponent<MeshRenderer>().sharedMaterial=m;
   Life(go,.55f).Tick=(p,dt)=>{go.transform.position=start+Vector3.up*.6f*p;go.transform.rotation=Game.Cam.transform.rotation;label.color=new Color(color.r,color.g,color.b,1-p);m.SetTexture("_MainTex",label.font.material.mainTexture);};
  }
  public void Death(Vector3 pos){Fountain(pos,1.5f,2.1f,1.15f);BurstRing(pos,1,Tone("9c1027"),28,2.5f,1);}
 }
 public sealed class RevenantDissolve:MonoBehaviour
 {
  public BloodwakeGame Game;float elapsed;readonly List<Material> owned=new();
  public void Begin(Shader shader)
  {
   foreach(var renderer in GetComponentsInChildren<SkinnedMeshRenderer>())
   {
    var list=renderer.sharedMaterials;
    for(int i=0;i<list.Length;i++)
    {
     var source=list[i];var m=new Material(shader);
     if(source.HasProperty("_BaseMap"))m.SetTexture("_BaseMap",source.GetTexture("_BaseMap"));
     if(source.HasProperty("_BaseColor"))m.SetColor("_BaseColor",source.GetColor("_BaseColor"));
     owned.Add(m);list[i]=m;
    }
    renderer.sharedMaterials=list;
   }
  }
  void Update(){if(!Game)return;elapsed+=Game.VfxDelta;float p=Mathf.Clamp01((elapsed-(51f/60+.15f))/1.55f);foreach(var m in owned)m.SetFloat("_Progress",p);}
  void OnDestroy(){foreach(var m in owned)if(m)Destroy(m);}
 }
 public sealed class VfxLifetime:MonoBehaviour
 {
  public BloodwakeGame Game;public float Duration,Age;public Action<float,float> Tick;public Action Completed;
  MaterialPropertyBlock block;public MaterialPropertyBlock Block=>block??=new MaterialPropertyBlock();Renderer[] renderers;
  public void Apply(){renderers??=GetComponentsInChildren<Renderer>();foreach(var r in renderers)if(r)r.SetPropertyBlock(Block);}
  void Update()
  {
   if(!Game){Destroy(gameObject);return;}float dt=Game.VfxDelta;if(dt<=0)return;Age+=dt;float p=Mathf.Clamp01(Age/Duration);
   Block.SetFloat("_Progress",p);Block.SetFloat("_Clock",Age);Tick?.Invoke(p,dt);Apply();if(Age>=Duration){Completed?.Invoke();Destroy(gameObject);}
  }
 }
 public sealed partial class BloodwakeGame
 {
  RevenantVfx revenantFx;
  public float VfxDelta=>(Screen=="playing"||Screen=="dying"||Screen=="death_transition"||Screen=="dead")&&hitStop<=0?Time.deltaTime:0;
  RevenantVfx RevFx
  {
   get{if(!revenantFx){var go=new GameObject("Combat effects");go.transform.SetParent(roomRoot,false);revenantFx=go.AddComponent<RevenantVfx>();revenantFx.Game=this;}return revenantFx;}
  }
 }
}
