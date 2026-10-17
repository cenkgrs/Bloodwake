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
   var shader=Resources.Load<Shader>("Vfx/vesper_flame_flipbook");var atlas=Resources.Load<Texture2D>("Vfx/vesper_flame_flipbook");
   if(!shader||!atlas){Debug.LogError("Vesper flame flipbook missing");return;}
   var material=new Material(shader){name="Vesper flame flipbook"};material.SetTexture("_MainTex",atlas);material.SetColor("_Tint",new Color(1,.86f,.7f));materials.Add(material);
   var block=new MaterialPropertyBlock();
   for(int i=0;i<CardStops.Length;i++)
   {
    var card=GameObject.CreatePrimitive(PrimitiveType.Quad);card.name="Flame card "+i;Destroy(card.GetComponent<Collider>());card.transform.SetParent(transform,false);
    var r=card.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=ShadowCastingMode.Off;r.receiveShadows=false;
    block.SetFloat("_Offset",i*5.3f);block.SetFloat("_Fps",14+i%3*2.5f);block.SetFloat("_Intensity",i<2?1.1f:1.55f);r.SetPropertyBlock(block);
    cards.Add(card.transform);cardScale.Add(Mathf.Lerp(.85f,1.15f,Mathf.Sin(CardStops[i]*Mathf.PI)));
   }
  }
  TrailRenderer CreateTrail(string title,Color color,float width,float life)
  {
   var go=new GameObject(title);go.transform.SetParent(transform,false);var trail=go.AddComponent<TrailRenderer>();trail.time=life;trail.minVertexDistance=.035f;trail.startWidth=width;trail.endWidth=0;trail.numCapVertices=4;trail.numCornerVertices=3;trail.sharedMaterial=FlameMaterial(title,color);trail.shadowCastingMode=ShadowCastingMode.Off;trail.receiveShadows=false;trail.emitting=false;
   var gradient=new Gradient();gradient.SetKeys(new[]{new GradientColorKey(color,0),new GradientColorKey(color,1)},new[]{new GradientAlphaKey(0,0),new GradientAlphaKey(.6f,.22f),new GradientAlphaKey(1,1)});trail.colorGradient=gradient;return trail;
  }
  void LateUpdate()
  {
   if(!grip||!tip)return;Vector3 start=Vector3.Lerp(grip.position,mid.position,.13f),end=tip.position;var axis=end-start;if(axis.sqrMagnitude<.001f)return;axis.Normalize();
   var view=Camera.main?Camera.main.transform.forward:Vector3.forward;var side=Vector3.Cross(axis,view);if(side.sqrMagnitude<.001f)side=Vector3.Cross(axis,Vector3.up);side.Normalize();var lift=Vector3.Cross(side,axis).normalized;float now=Time.time;
   foreach(var line in flames)
   {
    var driver=line.GetComponent<VesperFlameLine>();for(int i=0;i<line.positionCount;i++){float p=i/(line.positionCount-1f),body=Mathf.Sin(p*Mathf.PI);float wave=Mathf.Sin(now*driver.Speed*4+p*17+driver.Phase)*driver.Flutter*body;float curl=Mathf.Sin(now*driver.Speed*2.7f+p*11+driver.Phase*.7f)*driver.Flutter*.55f*body;line.SetPosition(i,Vector3.Lerp(start,end,p)+side*wave+lift*curl);}
   }
   // Cards stand upright and face the camera: fire rises in world space whatever angle the blade holds.
   var cameraForward=Camera.main?Camera.main.transform.forward:Vector3.forward;var flat=new Vector3(cameraForward.x,0,cameraForward.z);if(flat.sqrMagnitude<.001f)flat=Vector3.forward;
   var facing=Quaternion.LookRotation(flat.normalized,Vector3.up);
   for(int i=0;i<cards.Count;i++){float h=.5f*cardScale[i],w=h*.75f;cards[i].SetPositionAndRotation(Vector3.Lerp(start,end,CardStops[i])+Vector3.up*h*.42f,facing);cards[i].localScale=Vector3.one;cards[i].localScale=new Vector3(w/cards[i].lossyScale.x,h/cards[i].lossyScale.y,1);}
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
  void OnDestroy(){foreach(var material in materials)if(material)Destroy(material);}
 }
 public sealed class VesperFlameLine:MonoBehaviour{public float Phase,Flutter,Speed;}
}
