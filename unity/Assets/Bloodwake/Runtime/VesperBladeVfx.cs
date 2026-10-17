using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace Bloodwake
{
 public sealed class VesperBladeVfx:MonoBehaviour
 {
  Transform grip,mid,tip;readonly List<LineRenderer> flames=new();readonly List<Material> materials=new();TrailRenderer goldTrail,shadowTrail;Vector3 previousTip,previousShadow;bool trailReady;
  static readonly Color Gold=new(1f,.72f,.08f,.92f),Ember=new(1f,.19f,.025f,.78f),Shadow=new(.015f,.008f,.012f,.72f),Core=new(1f,.94f,.55f,.96f);
  void Start()
  {
   var bones=GetComponentsInChildren<Transform>(true);grip=bones.FirstOrDefault(t=>t.name=="VesperSwordGrip");mid=bones.FirstOrDefault(t=>t.name=="VesperSwordMid");tip=bones.FirstOrDefault(t=>t.name=="VesperSwordTip");
   if(!grip||!mid||!tip){Debug.LogError("Vesper sword flame sockets are missing");enabled=false;return;}
   // Painted flame flipbook cards rise from the blade; a thin hot core keeps the edge glowing.
   CreateFlame("Hot blade core",Core,.036f,5.1f,.012f,3.7f);
   CreateFlameCards();
   goldTrail=CreateTrail("Gold slash trail",Gold,.105f,.13f);
   shadowTrail=CreateTrail("Black slash wake",Shadow,.15f,.16f);
  }
  Material FlameMaterial(string title,Color color)
  {
   var shader=Resources.Load<Shader>("Vfx/vesper_blade_flame");if(!shader)throw new System.InvalidOperationException("Missing Vesper blade flame shader");
   var material=new Material(shader){name=title+" material"};material.SetColor("_BaseColor",color);materials.Add(material);return material;
  }
  void CreateFlame(string title,Color color,float width,float phase,float flutter,float speed)
  {
   var go=new GameObject(title);go.transform.SetParent(transform,false);var line=go.AddComponent<LineRenderer>();line.useWorldSpace=true;line.positionCount=10;line.textureMode=LineTextureMode.Stretch;line.alignment=LineAlignment.View;line.numCapVertices=3;line.numCornerVertices=2;line.sharedMaterial=FlameMaterial(title,color);line.shadowCastingMode=ShadowCastingMode.Off;line.receiveShadows=false;
   line.widthCurve=new AnimationCurve(new Keyframe(0,.2f),new Keyframe(.12f,.72f),new Keyframe(.58f,1),new Keyframe(1,.05f));line.widthMultiplier=width;
   var driver=go.AddComponent<VesperFlameLine>();driver.Phase=phase;driver.Flutter=flutter;driver.Speed=speed;flames.Add(line);
  }
  static readonly float[] CardStops={.12f,.26f,.4f,.54f,.68f,.82f,.95f};
  readonly List<Transform> cards=new();readonly List<float> cardScale=new();
  void CreateFlameCards()
  {
   // The blade wears the thin body flame; the broad tongue reads as clutter on a sword.
   var material=RevenantVfx.FlameMaterial("body");if(!material)return;
   var block=new MaterialPropertyBlock();
   for(int i=0;i<CardStops.Length;i++)
   {
    var card=GameObject.CreatePrimitive(PrimitiveType.Quad);card.name="Flame card "+i;Destroy(card.GetComponent<Collider>());card.transform.SetParent(transform,false);
    var r=card.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    block.SetFloat("_Offset",i*5.3f);block.SetFloat("_Fps",14+i%3*2.5f);block.SetFloat("_Intensity",i<2?1.1f:1.55f);r.SetPropertyBlock(block);
    cards.Add(card.transform);cardScale.Add(Mathf.Lerp(.85f,1.15f,Mathf.Sin(CardStops[i]*Mathf.PI)));
   }
  }
  Animator animator;float castGlow;
  // Swept ribbon: the blade's segment over the last ~0.2 s, rebuilt each frame from history.
  struct Sample{public Vector3 a,b;public float time;}
  readonly List<Sample> history=new();Mesh ribbon;Material ribbonMaterial;GameObject ribbonObject;
  void SweepRibbon(Vector3 start,Vector3 end)
  {
   const float span=.2f;float now=Time.time;
   if(!ribbon)
   {
    ribbon=new Mesh{name="Vesper blade flame ribbon"};ribbon.MarkDynamic();var go=ribbonObject=new GameObject("Blade flame ribbon");go.AddComponent<MeshFilter>().sharedMesh=ribbon;
    var r=go.AddComponent<MeshRenderer>();ribbonMaterial=new Material(Resources.Load<Shader>("Vfx/vesper_blade_streak")){name="Vesper blade streak"};materials.Add(ribbonMaterial);r.sharedMaterial=ribbonMaterial;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
   }
   history.Insert(0,new Sample{a=start,b=end,time=now});while(history.Count>2&&now-history[history.Count-1].time>span)history.RemoveAt(history.Count-1);
   // Only a real swing leaves fire: average tip speed across the window.
   float travel=0;for(int i=1;i<history.Count;i++)travel+=Vector3.Distance(history[i-1].b,history[i].b);float age=Mathf.Max(.016f,now-history[history.Count-1].time);
   float strength=Mathf.SmoothStep(0,1,(travel/age-2.5f)/4f);
   int n=history.Count;var verts=new Vector3[n*2];var uv=new Vector2[n*2];var col=new Color[n*2];var tris=new int[(n-1)*6];
   for(int i=0;i<n;i++){float u=Mathf.Clamp01((now-history[i].time)/span);verts[i*2]=history[i].a;verts[i*2+1]=history[i].b;uv[i*2]=new Vector2(u,0);uv[i*2+1]=new Vector2(u,1);col[i*2]=col[i*2+1]=new Color(1,1,1,strength);}
   for(int i=0;i<n-1;i++){int k=i*6,v=i*2;tris[k]=v;tris[k+1]=v+1;tris[k+2]=v+2;tris[k+3]=v+1;tris[k+4]=v+3;tris[k+5]=v+2;}
   ribbon.Clear();ribbon.vertices=verts;ribbon.uv=uv;ribbon.colors=col;ribbon.triangles=tris;ribbon.RecalculateBounds();
  }MaterialPropertyBlock cardBlock;
  // Mixamo's thrust is an upward stab; Vesper drives the greatsword straight ahead, so during
  // DashAttack the grip bone swings the blade level with the character's facing, eased in and out.
  void LevelThrust()
  {
   if(!animator)animator=GetComponentInChildren<Animator>();if(!animator)return;
   var state=animator.IsInTransition(0)?animator.GetNextAnimatorStateInfo(0):animator.GetCurrentAnimatorStateInfo(0);
   if(!state.IsName("DashAttack"))return;float t=state.normalizedTime%1,weight=Mathf.SmoothStep(0,1,t/.22f)*(1-Mathf.SmoothStep(0,1,(t-.82f)/.18f));
   var blade=(tip.position-grip.position).normalized;var forward=transform.forward;forward.y=0;if(forward.sqrMagnitude<.001f)return;
   var target=(forward.normalized+Vector3.down*.06f).normalized;
   grip.rotation=Quaternion.Slerp(Quaternion.identity,Quaternion.FromToRotation(blade,target),weight)*grip.rotation;
  }
  TrailRenderer CreateTrail(string title,Color color,float width,float life)
  {
   var go=new GameObject(title);go.transform.SetParent(transform,false);var trail=go.AddComponent<TrailRenderer>();trail.time=life;trail.minVertexDistance=.035f;trail.startWidth=width;trail.endWidth=0;trail.numCapVertices=4;trail.numCornerVertices=3;trail.sharedMaterial=FlameMaterial(title,color);trail.shadowCastingMode=ShadowCastingMode.Off;trail.receiveShadows=false;trail.emitting=false;
   var gradient=new Gradient();gradient.SetKeys(new[]{new GradientColorKey(color,0),new GradientColorKey(color,1)},new[]{new GradientAlphaKey(0,0),new GradientAlphaKey(.6f,.22f),new GradientAlphaKey(1,1)});trail.colorGradient=gradient;return trail;
  }
  void LateUpdate()
  {
   if(!grip||!tip)return;LevelThrust();Vector3 start=Vector3.Lerp(grip.position,mid.position,.13f),end=tip.position;var axis=end-start;if(axis.sqrMagnitude<.001f)return;axis.Normalize();
   var view=Camera.main?Camera.main.transform.forward:Vector3.forward;var side=Vector3.Cross(axis,view);if(side.sqrMagnitude<.001f)side=Vector3.Cross(axis,Vector3.up);side.Normalize();var lift=Vector3.Cross(side,axis).normalized;float now=Time.time;
   foreach(var line in flames)
   {
    var driver=line.GetComponent<VesperFlameLine>();for(int i=0;i<line.positionCount;i++){float p=i/(line.positionCount-1f),body=Mathf.Sin(p*Mathf.PI);float wave=Mathf.Sin(now*driver.Speed*4+p*17+driver.Phase)*driver.Flutter*body;float curl=Mathf.Sin(now*driver.Speed*2.7f+p*11+driver.Phase*.7f)*driver.Flutter*.55f*body;line.SetPosition(i,Vector3.Lerp(start,end,p)+side*wave+lift*curl);}
   }
   // Cards stand upright and face the camera: fire rises in world space whatever angle the blade holds.
   var cameraForward=Camera.main?Camera.main.transform.forward:Vector3.forward;var flat=new Vector3(cameraForward.x,0,cameraForward.z);if(flat.sqrMagnitude<.001f)flat=Vector3.forward;
   var facing=Quaternion.LookRotation(flat.normalized,Vector3.up);
   // Casting (blade raised in CastQ/Ultimate wind-up) makes the blade blaze; swinging sheds fire that hangs in the air behind it.
   var st=animator?(animator.IsInTransition(0)?animator.GetNextAnimatorStateInfo(0):animator.GetCurrentAnimatorStateInfo(0)):default;
   bool casting=animator&&(st.IsName("CastQ")||st.IsName("Ultimate"));float glow=Mathf.MoveTowards(castGlow,casting?1:0,Time.deltaTime*4);castGlow=glow;
   if(castGlow>.01f){cardBlock??=new MaterialPropertyBlock();foreach(var c in cards){var rr=c.GetComponent<MeshRenderer>();rr.GetPropertyBlock(cardBlock);cardBlock.SetFloat("_Intensity",1.55f+2.6f*castGlow);rr.SetPropertyBlock(cardBlock);}}
   float speed=trailReady?Vector3.Distance(previousTip,end)/Mathf.Max(Time.deltaTime,.001f):0;
   SweepRibbon(start,end);
   for(int i=0;i<cards.Count;i++){float h=.5f*cardScale[i]*(1+.6f*castGlow),w=h*.5f;cards[i].SetPositionAndRotation(Vector3.Lerp(start,end,CardStops[i])+Vector3.up*h*.42f,facing);cards[i].localScale=Vector3.one;cards[i].localScale=new Vector3(w/cards[i].lossyScale.x,h/cards[i].lossyScale.y,1);}
   var shadowPosition=Vector3.Lerp(mid.position,end,.9f);
   if(!trailReady)
   {
    goldTrail.transform.position=end;shadowTrail.transform.position=shadowPosition;previousTip=end;previousShadow=shadowPosition;trailReady=true;return;
   }
   float tipMove=Vector3.Distance(previousTip,end),shadowMove=Vector3.Distance(previousShadow,shadowPosition),dt=Mathf.Max(Time.unscaledDeltaTime,.001f);
   bool snapped=tipMove>.55f||shadowMove>.55f,fast=!snapped&&tipMove/dt>.75f;
   goldTrail.emitting=fast;shadowTrail.emitting=fast;
   if(snapped){goldTrail.Clear();shadowTrail.Clear();}
   goldTrail.transform.position=end;shadowTrail.transform.position=shadowPosition;previousTip=end;previousShadow=shadowPosition;
  }
  void OnDestroy(){if(ribbonObject)Destroy(ribbonObject);if(ribbon)Destroy(ribbon);foreach(var material in materials)if(material)Destroy(material);}
 }
 public sealed class VesperFlameLine:MonoBehaviour{public float Phase,Flutter,Speed;}
}
