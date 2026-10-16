using UnityEngine;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  public void EnemyEmergence(Vector3 position,float actorHeight)
  {
   float radius=Mathf.Clamp(actorHeight*.44f,.85f,1.65f);
   const float duration=2.1f;
   var hole=Sheet("Enemy spawn rift",position+Vector3.up*.065f,Vector3.one*radius*2.5f,"spawn_rift",duration,Tone("b51b32"),true);
   // The dark opening stays under the feet, while the model rises independently.
   hole.Block.SetFloat("_Progress",0);hole.Apply();
   for(int i=0;i<18;i++)
   {
    float angle=i*2.399963f;var radial=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
    float delay=(i%6)*.105f,life=1.15f+(i%3)*.12f;
    float spread=radius*(.18f+.055f*(i%5));
    var origin=position+radial*spread+Vector3.up*.12f;
    float size=radius*(.85f+(i%4)*.11f);
    var smoke=Sheet("Enemy spawn crimson mist",origin,Vector3.one*size,"dust",delay+life,new Color(.48f,.055f,.09f,.72f));
    var renderer=smoke.GetComponent<Renderer>();renderer.enabled=false;
    smoke.Tick=(p,dt)=>
    {
     float age=smoke.Age-delay;if(age<0){renderer.enabled=false;return;}renderer.enabled=true;
     float phase=Mathf.Clamp01(age/life),appear=Mathf.SmoothStep(0,1,phase/.14f);
     var swirl=Quaternion.Euler(0,age*38,0)*radial;
     smoke.transform.position=origin+swirl*(age*.17f*radius)+Vector3.up*(age*.72f);
     smoke.transform.rotation=Game.Cam.transform.rotation;
     smoke.transform.localScale=Vector3.one*size*Mathf.Lerp(.6f,1.45f,phase);
     var color=Color.Lerp(new Color(.48f,.055f,.09f,.72f),new Color(.23f,.045f,.065f,.28f),phase);
     color.a*=appear;smoke.Block.SetColor("_Tone",color);smoke.Block.SetFloat("_Progress",phase);
    };
   }
   // Few slow rising embers, not a combat impact burst or a bright white flash.
   for(int i=0;i<8;i++)
   {
    float angle=i*Mathf.PI*.25f;var radial=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle));
    var origin=position+radial*radius*.55f+Vector3.up*.1f;
    var ember=Glow(origin,Tone("bd2038"),.055f,.8f,1.35f+i*.045f);ember.name="Enemy spawn ember";
    ember.Tick=(p,dt)=>{ember.transform.position=origin+radial*Mathf.Sin(p*Mathf.PI)*.15f+Vector3.up*p*1.35f;ember.transform.rotation=Game.Cam.transform.rotation;};
   }
  }
  public GameObject ThreatWarning(Vector3 origin,Vector3 direction,float radius,float arc,float width,float duration,Color tone)
  {
   direction.y=0;direction=direction.sqrMagnitude>.0001f?direction.normalized:Vector3.forward;
   bool lane=width>0;var centre=origin+(lane?direction*radius*.5f:Vector3.zero)+Vector3.up*.06f;
   var fx=Sheet("Enemy danger area",centre,lane?new Vector3(width,radius,1):Vector3.one*radius*2,"enemy_warning",duration,tone,true);
   fx.transform.rotation=Quaternion.LookRotation(Vector3.up,direction);
   fx.Block.SetFloat("_Lane",lane?1:0);fx.Block.SetFloat("_Arc",arc*Mathf.Deg2Rad*.5f);fx.Apply();return fx.gameObject;
  }
  public GameObject BossTelegraph(Vector3 origin,Vector3 direction,float radius,float arc,string attack,float duration)
  {
   var tone=Tone(attack=="cast"?"c86ce5":attack=="summon"?"8fc5a1":attack=="slam"?"ed6555":"e5a463");
   if(attack!="cast")return ThreatWarning(origin,direction,radius,arc,attack=="charge"?2:0,duration,tone);
   var group=new GameObject("Boss projectile lanes");group.transform.SetParent(transform,false);
   for(int i=-1;i<=1;i++){var heading=Quaternion.Euler(0,i*.22f*Mathf.Rad2Deg,0)*direction;ThreatWarning(origin,heading,radius,360,1.1f,duration,tone).transform.SetParent(group.transform,true);}
   return group;
  }
  public void BossContact(string attack,Vector3 origin,Vector3 direction,float radius,float arc)
  {
   if(attack=="attack"||attack=="sweep")
   {
    BladeArc(origin,direction,radius,arc,Tone("d6ab78"),.45f);Sparks(origin+direction*radius*.65f+Vector3.up*.5f,Tone("dcad79"),12,.22f,.6f,2.2f);
    int count=attack=="sweep"?10:4;
    for(int i=0;i<count;i++)ChargeWake(origin+Quaternion.Euler(0,-arc*.5f+arc*i/Mathf.Max(1,count-1),0)*direction*radius*.8f,direction);
   }
   else if(attack=="slam")GroundImpact(origin,radius);
   else if(attack=="cast"){Glow(origin+Vector3.up*1.2f,Tone("c86ce5"),1.1f,1.8f,.2f);Flash(origin,Tone("c86ce5"),2.5f,3,.2f);}
   else if(attack=="summon"){Sparks(origin+Vector3.up*.15f,Tone("8fc5a1"),18,.5f,.5f,1.8f);}
  }
  public void ChargeWake(Vector3 position,Vector3 direction)
  {
   var fx=Sheet("Enemy impact dust",position+Vector3.up*.15f,Vector3.one*.4f,"dust",.6f,new Color(.38f,.34f,.30f,.6f));
   var drift=-direction*.55f+Vector3.up*.25f;
   fx.Tick=(p,dt)=>{fx.transform.position=position+Vector3.up*.15f+drift*fx.Age;fx.transform.localScale=Vector3.one*Mathf.Lerp(.4f,1.35f,p);fx.transform.rotation=Game.Cam.transform.rotation;};
  }
  public void SummonArrival(Vector3 position)
  {
   Sparks(position+Vector3.up*.4f,Tone("8fc5a1"),18,.55f,.7f,2.1f);ChargeWake(position,Vector3.forward);
  }
  public void HostileRuneImpact(Vector3 position,float radius)
  {
   BurstRing(position,radius,Tone("dc68ba"),24,3,.55f);Flash(position,Tone("dc68ba"),2,radius*1.3f,.2f);
   for(int i=0;i<8;i++)ChargeWake(position+Quaternion.Euler(0,i*45,0)*Vector3.forward*radius*.6f,Vector3.forward);
  }
 }
}
