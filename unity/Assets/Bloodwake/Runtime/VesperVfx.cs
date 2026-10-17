using UnityEngine;

namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static readonly Color VesperGold=Tone("ffd43b"),VesperBlack=Tone("130b0b"),VesperBlood=Tone("9f1028");
  static Material flameFlipbook;
  // Painted flame flipbook card: rises, swells and burns out. Additive, camera-facing.
  public void FlameCard(Vector3 pos,float height,float life,Vector3 drift,float delay=0,float intensity=2.2f)
  {
   if(!flameFlipbook){var shader=Resources.Load<Shader>("Vfx/vesper_flame_flipbook");if(!shader)return;flameFlipbook=new Material(shader){name="Vesper attack flame"};flameFlipbook.SetTexture("_MainTex",Resources.Load<Texture2D>("Vfx/vesper_flame_flipbook"));flameFlipbook.SetColor("_Tint",new Color(1,.86f,.7f));}
   var go=GameObject.CreatePrimitive(PrimitiveType.Quad);go.name="Attack flame";Object.Destroy(go.GetComponent<Collider>());go.transform.SetParent(transform,false);
   var r=go.GetComponent<MeshRenderer>();r.sharedMaterial=flameFlipbook;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
   var block=new MaterialPropertyBlock();float seed=Random.Range(0,16f),fps=Random.Range(18,26);block.SetFloat("_Offset",seed);block.SetFloat("_Fps",fps);block.SetColor("_Tint",Color.Lerp(new Color(1,.78f,.6f),new Color(1,.95f,.8f),Random.value));float mirror=Random.value<.5f?-1:1,stretch=Random.Range(.75f,1.25f);block.SetFloat("_Intensity",0);r.SetPropertyBlock(block);
   go.transform.position=pos;go.transform.localScale=Vector3.zero;
   Life(go,life+delay).Tick=(p,dt)=>
   {
    float age=p*(life+delay)-delay;if(age<0)return;float q=age/life;
    float grow=Mathf.SmoothStep(0,1,q/.18f),fade=1-Mathf.SmoothStep(0,1,(q-.45f)/.55f);
    float h=height*Mathf.Lerp(.55f,1.15f,grow);
    go.transform.position=pos+drift*age+Vector3.up*h*.45f;go.transform.rotation=Game.Cam.transform.rotation;go.transform.localScale=new Vector3(h*.75f*stretch*mirror,h,1);
    block.SetFloat("_Intensity",intensity*grow*fade);r.SetPropertyBlock(block);
   };
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
   for(int i=0;i<linger;i++){var at=pos+Flat(Random.insideUnitSphere).normalized*radius*Mathf.Sqrt(Random.value)*(major?.95f:.7f);if(Vector3.Distance(Flat(at),Flat(pos))<auraRadius*1.2f)continue;FlameCard(at,Random.Range(.4f,.75f),Random.Range(1f,major?1.9f:1.2f),Vector3.up*.12f,.2f+Random.Range(0,major?.7f:.3f),1.3f);}
   Sparks(pos+Vector3.up*.18f,VesperGold,major?80:26,major?.9f:.42f,.8f,major?8f:3.6f);
   Sparks(pos+Vector3.up*.1f,VesperBlood,major?30:10,major?.85f:.52f,.45f,major?5f:2.8f);
  }
  public void VesperDash(Vector3 start,Vector3 end)
  {
   for(int i=0;i<9;i++)FlameCard(Vector3.Lerp(start,end,(i+.5f)/9f),Random.Range(.6f,1f),.5f,Vector3.up*.5f,i*.018f);
   for(int i=0;i<7;i++){var point=Vector3.Lerp(start,end,(i+.5f)/7f)+Vector3.up*.45f;Sparks(point,i%2==0?VesperGold:VesperBlack,4,.3f,.2f,1.5f);}
  }
 }
}
