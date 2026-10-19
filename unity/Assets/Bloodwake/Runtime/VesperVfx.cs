using UnityEngine;

namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static readonly Color VesperGold=Tone("ffd43b"),VesperBlack=Tone("130b0b"),VesperBlood=Tone("9f1028");
  static readonly System.Collections.Generic.Dictionary<string,Material> flameMaterials=new();
  // Flipbooks: "flame" all-purpose tongue, "body" thin flame that sits on a limb, "ground" low wide
  // burning patch, "burst" one-shot impact explosion.
  // A jet card faces the camera but rolls so the texture's left-to-right stream follows the jet on screen.
  Quaternion JetFacing(Vector3 drift){var cam=Game.Cam.transform;var along=Vector3.ProjectOnPlane(drift,cam.forward);if(along.sqrMagnitude<.0001f)return cam.rotation;return Quaternion.LookRotation(cam.forward,Vector3.Cross(cam.forward,along.normalized));}
  // Vesper's flame breath uses its own sheet (Resources/Vfx/vesper_flame_jet, 4x4 frames on black) once it exists.
  public static string JetKind=>Resources.Load<Texture2D>("Vfx/vesper_flame_jet")?"jet":"flame";
  public static Material FlameMaterial(string kind)
  {
   if(flameMaterials.TryGetValue(kind,out var m)&&m)return m;var shader=Resources.Load<Shader>("Vfx/vesper_flame_flipbook");if(!shader)return null;
   m=new Material(shader){name="Vesper "+kind+" flame"};m.SetTexture("_MainTex",Resources.Load<Texture2D>(kind=="flame"?"Vfx/vesper_flame_flipbook":"Vfx/vesper_flame_"+kind));m.SetColor("_Tint",new Color(1,.86f,.7f));flameMaterials[kind]=m;return m;
  }
  static float FlameAspect(string kind)=>kind=="jet"?1.7f:kind=="body"?.5f:kind=="ground"||kind=="burst"?1.25f:.75f;
  // Flipbook card: rises, swells and burns out. Additive, camera-facing. follow keeps it on a bone.
  public void FlameCard(Vector3 pos,float height,float life,Vector3 drift,float delay=0,float intensity=2.2f,string kind="flame",Transform follow=null)
  {
   var material=FlameMaterial(kind);if(!material)return;bool once=kind=="burst";
   var go=GameObject.CreatePrimitive(PrimitiveType.Quad);go.name="Attack flame";Object.Destroy(go.GetComponent<Collider>());go.transform.SetParent(transform,false);
   var r=go.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
   var block=new MaterialPropertyBlock();float seed=Random.Range(0,16f),fps=once?16/life:Random.Range(18,26);block.SetFloat("_Offset",seed);block.SetFloat("_Fps",fps);block.SetFloat("_OneShot",once?1:0);block.SetFloat("_Start",Time.time+delay);
   block.SetColor("_Tint",Color.Lerp(new Color(1,.78f,.6f),new Color(1,.95f,.8f),Random.value));float mirror=Random.value<.5f?-1:1,stretch=once?1:Random.Range(.75f,1.25f),aspect=FlameAspect(kind);
   block.SetFloat("_Intensity",0);r.SetPropertyBlock(block);var offset=follow?pos-follow.position:Vector3.zero;
   go.transform.position=pos;go.transform.localScale=Vector3.zero;
   Life(go,life+delay).Tick=(p,dt)=>
   {
    float age=p*(life+delay)-delay;if(age<0)return;float q=age/life;
    float grow=once?1:Mathf.SmoothStep(0,1,q/.18f),fade=once?1-Mathf.SmoothStep(0,1,(q-.75f)/.25f):1-Mathf.SmoothStep(0,1,(q-.45f)/.55f);
    float h=once?height:height*Mathf.Lerp(.55f,1.15f,grow);var anchor=follow?follow.position+offset:pos;
    go.transform.position=anchor+drift*age+Vector3.up*h*(kind=="ground"||once?.38f:.45f);go.transform.rotation=kind=="jet"?JetFacing(drift):Game.Cam.transform.rotation;go.transform.localScale=new Vector3(h*aspect*stretch*(kind=="jet"?1:mirror),h,1);
    block.SetFloat("_Intensity",intensity*grow*fade);r.SetPropertyBlock(block);
   };
  }
  // One card of the painted fire jet: the sheet's nozzle (left edge) at the palm, its stream laid along the
  // jet on screen, flipbook running, flaring in and dying out over its short life.
  public void FlameJetCard(Vector3 origin,Vector3 dir,float length,float life)
  {
   var material=FlameMaterial("jet");if(!material)return;
   var go=GameObject.CreatePrimitive(PrimitiveType.Quad);go.name="Flame jet";Object.Destroy(go.GetComponent<Collider>());go.transform.SetParent(transform,false);
   var r=go.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
   var block=new MaterialPropertyBlock();block.SetFloat("_Offset",Random.Range(0,16f));block.SetFloat("_Fps",Random.Range(18,24));block.SetFloat("_OneShot",0);block.SetFloat("_Start",Time.time);
   block.SetColor("_Tint",Color.white);block.SetFloat("_Intensity",0);r.SetPropertyBlock(block);
   Life(go,life).Tick=(p,dt)=>
   {
    float grow=Mathf.SmoothStep(0,1,p/.2f),fade=1-Mathf.SmoothStep(0,1,(p-.6f)/.4f);float l=length*Mathf.Lerp(.75f,1.05f,grow);
    var facing=JetFacing(dir);go.transform.rotation=facing;
    // Centre the card on the jet's own line in the world (at hand height, never sunk into the floor when
    // aiming toward the camera) and stretch it only as long as that line looks on screen.
    float onScreen=Vector3.ProjectOnPlane(dir,Game.Cam.transform.forward).magnitude;
    go.transform.position=origin+dir*l*.46f;go.transform.localScale=new Vector3(l*Mathf.Max(.45f,onScreen),l*.42f,1);
    block.SetFloat("_Intensity",1.15f*grow*fade);r.SetPropertyBlock(block);
   };
  }
  // Space sets Vesper herself alight: thin flames ride her limbs and back for a few seconds.
  public void VesperBodyBurn(ActorView actor,float duration)
  {
   if(!actor)return;var bones=actor.GetComponentsInChildren<Transform>();
   foreach(var name in new[]{"LeftArm","RightArm","LeftForeArm","RightForeArm","Spine1","Spine2","LeftShoulder","RightShoulder","LeftUpLeg","RightUpLeg","LeftLeg","RightLeg","Head"})
   {
    var bone=System.Array.Find(bones,b=>b.name=="mixamorig:"+name);if(!bone)continue;
    for(float t=0;t<duration;t+=Random.Range(.28f,.42f))FlameCard(bone.position,Random.Range(.35f,.6f)*(name.Contains("Spine")?1.3f:1),Random.Range(.45f,.65f),Vector3.up*.25f,t,1.7f,"body",bone);
   }
  }
  // The fire itself rides the blade (VesperBladeVfx); the hit only throws sparks at contact. No ground lines.
  public void VesperBladeArc(Vector3 pos,Vector3 dir,float radius,float degrees)
  {
   var contact=pos+dir.normalized*radius*.72f+Vector3.up*.65f;
   Sparks(contact,VesperGold,15,.3f,.8f,3.5f);Sparks(contact,VesperBlack,8,.42f,.35f,1.8f);
  }
  // The raised, glowing blade is the warning now; nothing is drawn on the ground.
  public void VesperCastWarning(Vector3 pos,float radius,float life,bool major){}
  // Blade meets stone: a flash, a flame column, then the ground around catches fire in
  // expanding waves and keeps burning. Cinder Ward is the tight, short version.
  public void VesperGroundCast(Vector3 pos,float radius,bool major)
  {
   Vector3 Flat(Vector3 v)=>new Vector3(v.x,0,v.z);
   Flash(pos,VesperGold,major?2.6f:1.1f,radius*1.4f,major?.3f:.16f);
   FlameCard(pos,radius*(major?.9f:.7f),major?1.1f:.8f,Vector3.zero,0,2.4f,"burst");
   // Vesper herself burns: a ring of flames hugging the body, re-lit for the length of the eruption.
   int aura=major?10:6;float auraRadius=major?1f:.8f;
   for(int k=0;k<(major?2:1);k++)for(int i=0;i<aura;i++){var d=Quaternion.Euler(0,i*360f/aura+k*18+Random.Range(-10,10f),0)*Vector3.forward;FlameCard(pos+d*auraRadius*Random.Range(.9f,1.15f),Random.Range(.9f,1.3f)*(major?1f:.8f),Random.Range(.55f,.75f),d*.25f+Vector3.up*.3f,k*.3f+Random.Range(0,.06f),1.7f);}
   int waves=major?3:1;
   for(int w=0;w<waves;w++)
   {
    float reach=radius*(major?(.45f+.27f*w):.75f);int count=major?12+5*w:10;
    for(int i=0;i<count;i++){var d=Quaternion.Euler(0,i*360f/count+Random.Range(-8,8f),0)*Vector3.forward;FlameCard(pos+d*reach*Random.Range(.75f,1.05f),Random.Range(.7f,1.1f)*(major?1f:.8f),Random.Range(.55f,.8f),d*.5f,w*.12f+Random.Range(0,.05f),1.6f);}
   }
   // Lingering burn across the area.
   int linger=major?18:6;
   for(int i=0;i<linger;i++){var at=pos+Flat(Random.insideUnitSphere).normalized*radius*Mathf.Sqrt(Random.value)*(major?.95f:.7f);if(Vector3.Distance(Flat(at),Flat(pos))<auraRadius*1.2f)continue;FlameCard(at,Random.Range(.45f,.8f),Random.Range(1.2f,major?2.2f:1.4f),Vector3.zero,.2f+Random.Range(0,major?.7f:.3f),1.4f,"ground");}
   Sparks(pos+Vector3.up*.18f,VesperGold,major?80:26,major?.9f:.42f,.8f,major?8f:3.6f);
   Sparks(pos+Vector3.up*.1f,VesperBlood,major?30:10,major?.85f:.52f,.45f,major?5f:2.8f);
  }
  // The same lingering ground fire Bloodfire Rite leaves, laid along a dash path.
  public void VesperTrailBurn(Vector3 pos,Vector3 direction,int count)
  {
   var side=Vector3.Cross(Vector3.up,direction).normalized;
   for(int i=0;i<count;i++)FlameCard(pos+side*Random.Range(-.35f,.35f)+direction.normalized*Random.Range(-.2f,.2f),Random.Range(.4f,.7f),Random.Range(1.1f,1.8f),Vector3.zero,.08f+Random.Range(0,.25f),1.4f,"ground");
  }
  public void VesperDash(Vector3 start,Vector3 end)
  {
   var dir=end-start;dir.y=0;float length=dir.magnitude;if(length>.01f)for(float d=.2f;d<length;d+=.45f)VesperTrailBurn(start+dir/length*d,dir/length,2);
   for(int i=0;i<9;i++)FlameCard(Vector3.Lerp(start,end,(i+.5f)/9f),Random.Range(.6f,1f),.5f,Vector3.up*.5f,i*.018f);
   for(int i=0;i<7;i++){var point=Vector3.Lerp(start,end,(i+.5f)/7f)+Vector3.up*.45f;Sparks(point,i%2==0?VesperGold:VesperBlack,4,.3f,.2f,1.5f);}
  }
 }
}
