using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 // The Warlock: the mage's body in sickly teal. It throws a fan of five bolts across 30 degrees (much
 // harder to slip than one orb), and every few casts it draws a binding sigil under the hunter: caught
 // in it when it snaps shut, the hunter is chained in place for a second.
 public sealed partial class ActorView
 {
  static Texture2D warlockAlbedo;
  static void WarlockSkin(GameObject model)
  {
   if(!warlockAlbedo)warlockAlbedo=Resources.Load<Texture2D>("Models/enemy_mage/warlock_albedo");if(!warlockAlbedo)return;
   // HitFlash has already given every renderer its own material instances; retexture those.
   foreach(var r in model.GetComponentsInChildren<Renderer>())foreach(var m in r.materials)
   {
    if(!m.HasProperty("_BaseMap"))continue;var current=m.GetTexture("_BaseMap");
    if(current&&current.name.Contains("mage_character")){m.SetTexture("_BaseMap",warlockAlbedo);if(m.HasProperty("_BaseColor"))m.SetColor("_BaseColor",new Color(.86f,.95f,.93f));}
   }
  }
 }
 public sealed partial class BloodwakeGame
 {
  static readonly Color WarlockTone=new(.25f,.88f,.74f),WarlockAccent=new(.05f,.32f,.3f);
  // The orb a warlock holds between casts takes its teal too.
  void TintWarlockHands(ActorView view){foreach(var rig in RevFx.GetComponentsInChildren<ArcaneOrbRig>())if(rig.Owner==view){rig.Tone=WarlockTone;rig.Accent=WarlockAccent;var l=rig.GetComponentInChildren<Light>();if(l)l.color=WarlockTone;}}
  float rootedUntil;
  public bool Rooted=>Time.time<rootedUntil;

  void WarlockCast(Enemy e,Vector3 dir,float distance)
  {
   e.Pattern++;
   if(e.Pattern%3==0&&e.RuneCooldown<=0&&distance<8.5f){e.RuneCooldown=e.Data.N("bindCooldown",7);StartCoroutine(BindingSigil(e));}
   else StartCoroutine(WarlockArc(e,dir));
  }
  IEnumerator WarlockArc(Enemy e,Vector3 dir)
  {
   int impact=e.ImpactVersion;e.Casting=true;Sound(Voice("warlock_attack","mage_attack"));yield return Delay(.38f);
   if(e.Hp>0&&impact==e.ImpactVersion&&e.View)
   {
    int bolts=(int)e.Data.N("arcBolts",5);float spread=e.Data.N("arcDegrees",30);var from=e.View.MagicPalmPosition();
    for(int i=0;i<bolts;i++){float angle=bolts==1?0:Mathf.Lerp(-spread*.5f,spread*.5f,i/(bolts-1f));StartCoroutine(WarlockBolt(from,Quaternion.Euler(0,angle,0)*dir,e.Damage*.75f,e.Data.N("projectileSpeed",380)*.02f,13));}
   }
   yield return Delay(.32f);e.Casting=false;
  }
  IEnumerator WarlockBolt(Vector3 origin,Vector3 dir,float damage,float speed,float range)
  {
   dir.y=0;dir.Normalize();var orb=RevFx.Orb(origin,true,true);orb.Tone=WarlockTone;orb.Accent=WarlockAccent;var glowLamp=orb.GetComponentInChildren<Light>();if(glowLamp)glowLamp.color=WarlockTone;orb.transform.localScale*=.8f;orb.transform.rotation=Quaternion.LookRotation(dir);
   float travelled=0,trail=0;
   while(orb&&travelled<range)
   {
    if(Screen!="playing"||hitStop>0){yield return null;continue;}
    float step=Mathf.Min(range-travelled,speed*Time.deltaTime);var previous=orb.transform.position;var next=previous+dir*step;
    var flat=new Vector3(next.x,0,next.z);if(Vector3.Distance(Move(new Vector3(previous.x,0,previous.z),dir*step,.1f),flat)>.15f){RevFx.Glow(next,WarlockTone,.5f,1.4f,.15f);break;}
    orb.transform.position=next;travelled+=step;
    if((trail-=Time.deltaTime)<=0){trail=.04f;RevFx.Glow(next,WarlockTone,.18f,.9f,.22f);}
    if(SegmentDistance(Player.transform.position+Vector3.up,previous,next)<.5f){RevFx.Glow(next,WarlockTone,.7f,2f,.18f);RevFx.Sparks(next,WarlockTone,10,.3f,1.5f,3.5f);HurtPlayer(damage);break;}
    yield return null;
   }
   if(orb)Destroy(orb.gameObject);
  }

  // The sigil is drawn under the hunter; it snaps shut after its fuse.
  IEnumerator BindingSigil(Enemy e)
  {
   int impact=e.ImpactVersion;e.Casting=true;e.View.Play("Cast",.9f);Sound(Voice("warlock_bind_cast","mage_attack"));
   var at=Player.transform.position;at.y=0;float radius=e.Data.N("bindRadius",72)*.02f,fuse=e.Data.N("bindFuse",.75f);
   var sigil=RevFx.BindingSigil(at,radius,fuse,WarlockTone);
   float age=0;while(age<fuse){if(Screen=="playing"&&hitStop<=0)age+=Time.deltaTime;yield return null;}
   e.Casting=false;
   // A dying caster's sigil still closes: the spell is already loose.
   var d=Player.transform.position-at;d.y=0;
   if(Screen=="playing"&&d.magnitude<=radius+.3f&&invulnerable<=0&&Run.Stats.N("hp")>0)
   {
    float seconds=e.Data.N("bindSeconds",1);rootedUntil=Time.time+seconds;HurtPlayer(e.Damage*.5f);
    RevFx.BindingChains(Player,at,radius,seconds,WarlockTone);Sound(Voice("warlock_bind_snap","ui_error"));Rumble(.6f,.3f,.25f);ShakeCamera(.3f,Vector3.zero);
   }
   else RevFx.Glow(at+Vector3.up*.2f,WarlockTone,radius,1.6f,.2f);
  }
 }
 public sealed partial class RevenantVfx
 {
  // A ring of turning runes on the stone that tightens as its fuse runs out.
  public VfxLifetime BindingSigil(Vector3 at,float radius,float fuse,Color tone)
  {
   var ring=Surface(at,radius,tone,fuse+.15f,2,1.6f);RuneCircle(at,radius,fuse,tone);
   var runes=new List<VfxLifetime>();
   for(int i=0;i<6;i++){var rune=Glow(at,tone,.22f,2.2f,fuse+.1f);runes.Add(rune);}
   ring.Tick=(p,dt)=>
   {
    float t=Mathf.Clamp01(ring.Age/fuse),spin=ring.Age*(90+220*t);
    ring.transform.localScale=Vector3.one*radius*2*Mathf.Lerp(1.12f,.96f,t*t);ring.Block.SetFloat("_Energy",Mathf.Lerp(1.2f,3.2f,t));ring.Apply();
    for(int i=0;i<runes.Count;i++)if(runes[i]){float a=(spin+i*60)*Mathf.Deg2Rad;runes[i].transform.position=at+new Vector3(Mathf.Cos(a),.25f+.15f*Mathf.Sin(ring.Age*9+i),Mathf.Sin(a))*radius*Mathf.Lerp(1.05f,.9f,t);runes[i].transform.rotation=Game.Cam.transform.rotation;}
   };
   return ring;
  }
  // The painted rune circle on the ground, turning faster and burning brighter as its fuse runs out.
  // It is a warning, so it stays at full strength until the fuse ends and only then fades (over .25 s).
  public VfxLifetime RuneCircle(Vector3 at,float radius,float fuse,Color tone)
  {
   if(!SheetTexture("rune_circle"))return null;at.y=.06f;
   var rune=Textured("Rune circle",at,Vector3.one*radius*2.15f,"rune_circle",fuse+.25f,new Color(tone.r,tone.g,tone.b,1),false,1,false,true);
   rune.Tick=(p,dt)=>
   {
    float t=Mathf.Clamp01(rune.Age/fuse);rune.transform.rotation=Quaternion.Euler(90,rune.Age*Mathf.Lerp(25,140,t*t),0);
    rune.Block.SetFloat("_Opacity",Mathf.Lerp(.9f,2.2f,t));rune.Block.SetFloat("_Progress",rune.Age<fuse?.5f:.7f+.3f*(rune.Age-fuse)/.25f);
   };
   return rune;
  }
  // Chains of light lash up from the ring to the hunter and hold while the bind lasts, then shatter.
  public void BindingChains(ActorView target,Vector3 at,float radius,float seconds,Color tone)
  {
   var go=new GameObject("Binding chains");go.transform.SetParent(transform);var chains=go.AddComponent<BindChains>();bool painted=SheetTexture("chain_strip");chains.Init(this,target,at,radius,seconds,tone,painted?TexturedMaterial("chain_strip"):Material("arcane_energy"),painted);
   Flash(target.transform.position,tone,2.4f,3.5f,.25f);Glow(target.transform.position+Vector3.up,tone,1.2f,2.6f,.2f);
  }
  internal void ChainShatter(Vector3 at,Color tone){Sparks(at,tone,14,.4f,2,5);Glow(at,tone,.6f,2,.15f);}
 }
 public sealed class BindChains:MonoBehaviour
 {
  RevenantVfx owner;ActorView target;Vector3 at;float radius,seconds,age;Color tone;bool painted;readonly List<LineRenderer> links=new();readonly List<Vector3> anchors=new();MaterialPropertyBlock block;Transform chest;
  public void Init(RevenantVfx fx,ActorView t,Vector3 centre,float r,float s,Color c,Material material,bool paintedChain)
  {
   owner=fx;painted=paintedChain;target=t;at=centre;radius=r;seconds=s;tone=c;block=new MaterialPropertyBlock();
   chest=t.Animator.GetComponentsInChildren<Transform>().FirstOrDefault(b=>b.name.EndsWith("Spine2"))??t.transform;
   for(int i=0;i<6;i++)
   {
    float a=i*60*Mathf.Deg2Rad+.3f;anchors.Add(at+new Vector3(Mathf.Cos(a),0,Mathf.Sin(a))*radius);
    var line=new GameObject("Chain").AddComponent<LineRenderer>();line.transform.SetParent(transform);line.positionCount=12;line.useWorldSpace=true;line.sharedMaterial=material;
    line.widthCurve=new AnimationCurve(new Keyframe(0,.1f),new Keyframe(1,.05f));line.shadowCastingMode=ShadowCastingMode.Off;line.numCapVertices=2;links.Add(line);
    // The painted chain strip (about 3.2:1) repeats along the line once per link-length instead of stretching.
    if(painted){line.numCapVertices=0;line.widthCurve=new AnimationCurve(new Keyframe(0,.2f),new Keyframe(1,.14f));line.textureMode=LineTextureMode.Tile;line.textureScale=new Vector2(1/(.17f*3.2f),1);}
   }
   Update();
  }
  void Update()
  {
   age+=Time.deltaTime;if(!target||age>=seconds){if(owner&&target)owner.ChainShatter(target.transform.position+Vector3.up,tone);Destroy(gameObject);return;}
   // Shot up in the first moment, taut while held, flickering just before they break.
   float reach=Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.08f)),flicker=age>seconds-.2f?(Mathf.Sin(age*80)>0?1:.35f):1;
   var top=chest.position;
   for(int c=0;c<links.Count;c++)
   {
    var line=links[c];var start=anchors[c];var end=Vector3.Lerp(start,top,reach);
    for(int i=0;i<line.positionCount;i++){float t=i/(line.positionCount-1f);var sag=Vector3.down*Mathf.Sin(t*Mathf.PI)*.18f;var link=(painted?0:(i&1)==0?1:-1)*.03f*Vector3.Cross((end-start).normalized,Vector3.up);line.SetPosition(i,Vector3.Lerp(start,end,t)+sag+link);}
    block.SetColor("_Tone",painted?new Color(1.2f,1.25f,1.25f,1):new Color(tone.r*1.6f,tone.g*1.6f,tone.b*1.6f,1));block.SetFloat("_Opacity",flicker);line.SetPropertyBlock(block);
   }
  }
 }
}
