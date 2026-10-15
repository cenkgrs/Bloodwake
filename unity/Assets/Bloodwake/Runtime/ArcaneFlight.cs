using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  public void ArcaneFlight(Vector3 start,Vector3 end,float travel,bool meteor)
  {
   for(int strand=0;strand<3;strand++)
   {
    int index=strand;var obj=new GameObject("Arcane flight ribbon");obj.transform.SetParent(transform);var line=obj.AddComponent<LineRenderer>();line.positionCount=18;line.useWorldSpace=true;line.sharedMaterial=Material("arcane_energy");line.widthMultiplier=strand==0?.045f:.017f;line.widthCurve=AnimationCurve.Linear(0,0,1,1);line.shadowCastingMode=ShadowCastingMode.Off;
    var fx=Life(obj,travel+.24f);fx.Block.SetColor("_Tone",new Color(.7f,.35f,1.6f,1));
    fx.Tick=(p,dt)=>
    {
     float progress=fx.Age/travel;for(int j=0;j<18;j++)
     {
      float t=Mathf.Clamp01(progress-(1-j/17f)*.55f);Vector3 at;
      if(meteor){var apex=end+Vector3.up*6;at=t<.45f?Vector3.Lerp(start,apex,Mathf.Sin(t/.45f*Mathf.PI*.5f)):Vector3.Lerp(apex,end+Vector3.up*.2f,Mathf.Pow((t-.45f)/.55f,2));}
      else {float lift=t<.45f?Mathf.Sin(t/.45f*Mathf.PI*.5f):1-Mathf.Pow((t-.45f)/.55f,2);at=Vector3.Lerp(start,end,(1-Mathf.Cos(t*Mathf.PI))*.5f)+Vector3.up*(lift*2.6f+.6f);}
      float angle=t*12+index*Mathf.PI*2/3;at+=new Vector3(Mathf.Cos(angle),0,Mathf.Sin(angle))*(.10f+index*.07f);line.SetPosition(j,at);
     }
     fx.Block.SetFloat("_Opacity",1-Mathf.Clamp01((fx.Age-travel)/.24f));
    };fx.Apply();
   }
  }
  void ArcaneColumn(Vector3 pos,float radius)
  {
   for(int i=0;i<5;i++)
   {
    var dir=Quaternion.Euler(0,i*72,0)*Vector3.forward;var points=new Vector3[8];for(int j=0;j<8;j++){float t=j/7f;points[j]=pos+dir*Mathf.Sin(t*Mathf.PI)*radius*.25f+Vector3.up*(.1f+t*2.4f);}
    ArcaneLine(points,.025f,.34f,new Color(.6f,.3f,1.7f,1));
   }
  }
 }
}
