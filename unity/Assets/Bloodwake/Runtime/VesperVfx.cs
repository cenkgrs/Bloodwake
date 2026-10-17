using UnityEngine;

namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static readonly Color VesperGold=Tone("ffd43b"),VesperBlack=Tone("130b0b"),VesperBlood=Tone("9f1028");
  static Material flameFlipbook;
  // Painted flame flipbook card: rises, swells and burns out. Additive, camera-facing.
  void FlameCard(Vector3 pos,float height,float life,Vector3 drift,float delay=0)
  {
   if(!flameFlipbook){var shader=Resources.Load<Shader>("Vfx/vesper_flame_flipbook");if(!shader)return;flameFlipbook=new Material(shader){name="Vesper attack flame"};flameFlipbook.SetTexture("_MainTex",Resources.Load<Texture2D>("Vfx/vesper_flame_flipbook"));flameFlipbook.SetColor("_Tint",new Color(1,.86f,.7f));}
   var go=GameObject.CreatePrimitive(PrimitiveType.Quad);go.name="Attack flame";Object.Destroy(go.GetComponent<Collider>());go.transform.SetParent(transform,false);
   var r=go.GetComponent<MeshRenderer>();r.sharedMaterial=flameFlipbook;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.receiveShadows=false;
   var block=new MaterialPropertyBlock();float seed=Random.Range(0,16f),fps=Random.Range(18,26);block.SetFloat("_Offset",seed);block.SetFloat("_Fps",fps);block.SetFloat("_Intensity",0);r.SetPropertyBlock(block);
   go.transform.position=pos;go.transform.localScale=Vector3.zero;
   Life(go,life+delay).Tick=(p,dt)=>
   {
    float age=p*(life+delay)-delay;if(age<0)return;float q=age/life;
    float grow=Mathf.SmoothStep(0,1,q/.18f),fade=1-Mathf.SmoothStep(0,1,(q-.45f)/.55f);
    float h=height*Mathf.Lerp(.55f,1.15f,grow);
    go.transform.position=pos+drift*age+Vector3.up*h*.45f;go.transform.rotation=Game.Cam.transform.rotation;go.transform.localScale=new Vector3(h*.75f,h,1);
    block.SetFloat("_Intensity",2.2f*grow*fade);r.SetPropertyBlock(block);
   };
  }
  public void VesperBladeArc(Vector3 pos,Vector3 dir,float radius,float degrees)
  {
   // Fire licks along the swept arc in swing order, then the dark/gold edge.
   int cards=Mathf.Clamp(Mathf.RoundToInt(degrees/14),6,22);var flat=new Vector3(dir.x,0,dir.z).normalized;
   for(int i=0;i<cards;i++){float a=Mathf.Lerp(-degrees*.5f,degrees*.5f,i/(cards-1f));var at=pos+Quaternion.Euler(0,a,0)*flat*radius*Random.Range(.62f,.9f);FlameCard(at,Random.Range(.55f,.95f),Random.Range(.38f,.55f),Vector3.up*.4f,i*.012f);}
   BladeArc(pos,dir,radius,degrees,VesperBlack,.88f);
   BladeArc(pos+Vector3.up*.035f,dir,radius*.96f,degrees,VesperGold,.92f);
   var contact=pos+dir.normalized*radius*.72f+Vector3.up*.65f;
   Sparks(contact,VesperGold,15,.3f,.8f,3.5f);Sparks(contact,VesperBlack,8,.42f,.35f,1.8f);
  }
  public void VesperCastWarning(Vector3 pos,float radius,float life,bool major)
  {
   Surface(pos,radius,VesperBlack,life,major?5:3,major?1.4f:.85f);
   Surface(pos+Vector3.up*.012f,radius*.82f,VesperGold,life,major?4:2,major?1.1f:.68f);
   Sparks(pos+Vector3.up*.12f,VesperGold,major?22:10,life,.15f,major?1.8f:.9f);
  }
  public void VesperGroundCast(Vector3 pos,float radius,bool major)
  {
   // Eruption: a tall core column and a ring of flames bursting outward.
   for(int i=0;i<(major?5:3);i++)FlameCard(pos+Vector3.Scale(Random.insideUnitSphere,new Vector3(1,0,1))*.3f,major?3.2f:2f,major?.9f:.7f,Vector3.up*.6f,i*.04f);
   int ring=major?26:14;for(int i=0;i<ring;i++){var d=Quaternion.Euler(0,i*360f/ring+Random.Range(-6,6f),0)*Vector3.forward;FlameCard(pos+d*radius*Random.Range(.35f,.6f),Random.Range(.9f,1.5f)*(major?1.3f:1),Random.Range(.55f,.8f),d*radius*.9f+Vector3.up*.3f,Random.Range(0,.08f));}
   float scale=major?1f:.62f;
   Fountain(pos,radius*(major?.78f:.42f),major?4.2f:1.8f,major?1f:.55f);
   BurstRing(pos,radius,VesperBlack,major?42:18,major?6f:3.5f,major?.9f:.55f);
   BurstRing(pos+Vector3.up*.04f,radius*.9f,VesperGold,major?48:22,major?7.5f:4.2f,major?.75f:.48f);
   Sparks(pos+Vector3.up*.18f,VesperGold,major?65:26,major?.75f:.42f,.8f,major?7f:3.6f);
   Sparks(pos+Vector3.up*.1f,VesperBlood,major?38:15,major?.85f:.52f,.45f,major?5f:2.8f);
   Surface(pos,radius,VesperBlood,major?1.15f:.7f,5,1.15f*scale);Flash(pos,VesperGold,major?2.2f:.8f,radius*1.4f,major?.32f:.16f);
  }
  public void VesperDash(Vector3 start,Vector3 end)
  {
   for(int i=0;i<9;i++)FlameCard(Vector3.Lerp(start,end,(i+.5f)/9f),Random.Range(.6f,1f),.5f,Vector3.up*.5f,i*.018f);
   for(int i=0;i<7;i++){var point=Vector3.Lerp(start,end,(i+.5f)/7f)+Vector3.up*.45f;Sparks(point,i%2==0?VesperGold:VesperBlack,4,.3f,.2f,1.5f);}
  }
 }
}
