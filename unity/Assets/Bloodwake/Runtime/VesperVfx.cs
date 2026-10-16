using UnityEngine;

namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  static readonly Color VesperGold=Tone("ffd43b"),VesperBlack=Tone("130b0b"),VesperBlood=Tone("9f1028");
  public void VesperBladeArc(Vector3 pos,Vector3 dir,float radius,float degrees)
  {
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
   for(int i=0;i<7;i++){var point=Vector3.Lerp(start,end,(i+.5f)/7f)+Vector3.up*.45f;Sparks(point,i%2==0?VesperGold:VesperBlack,4,.3f,.2f,1.5f);}
  }
 }
}
