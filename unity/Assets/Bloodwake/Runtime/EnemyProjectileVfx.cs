using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake
{
 // Enemy arrows: a real shaft and head with a pale streak behind, readable at gameplay zoom.
 public sealed partial class RevenantVfx
 {
  GameObject Arrow(Vector3 pos,Vector3 dir)
  {
   var go=new GameObject("Hostile arrow");go.transform.SetParent(transform);go.transform.SetPositionAndRotation(pos,Quaternion.LookRotation(dir.sqrMagnitude>.001f?dir:Vector3.forward));
   void Part(string name,Vector3 at,Vector3 size,Color color,Quaternion turn)
   {
    var part=GameObject.CreatePrimitive(PrimitiveType.Cube);part.name=name;Object.Destroy(part.GetComponent<Collider>());part.transform.SetParent(go.transform,false);
    part.transform.localPosition=at;part.transform.localRotation=turn;part.transform.localScale=size;var r=part.GetComponent<MeshRenderer>();r.sharedMaterial=Effects.Mat(color);r.shadowCastingMode=ShadowCastingMode.Off;
   }
   Part("Shaft",new Vector3(0,0,-.3f),new Vector3(.035f,.035f,.82f),new Color(.32f,.22f,.13f),Quaternion.identity);
   Part("Head",new Vector3(0,0,.14f),new Vector3(.075f,.02f,.13f),new Color(.62f,.62f,.66f),Quaternion.identity);
   Part("Fletching",new Vector3(0,0,-.66f),new Vector3(.11f,.012f,.16f),new Color(.45f,.06f,.07f),Quaternion.identity);
   Part("Fletching",new Vector3(0,0,-.66f),new Vector3(.11f,.012f,.16f),new Color(.45f,.06f,.07f),Quaternion.Euler(0,0,90));
   // A pale streak trailing the arrow, so its line can be read and dodged.
   var streak=new GameObject("Arrow streak").AddComponent<LineRenderer>();streak.transform.SetParent(go.transform,false);streak.useWorldSpace=false;streak.positionCount=2;
   streak.SetPositions(new[]{Vector3.back*2.4f,Vector3.back*.65f});streak.widthCurve=new AnimationCurve(new Keyframe(0,0),new Keyframe(1,.07f));
   streak.sharedMaterial=Material("arcane_energy");streak.shadowCastingMode=ShadowCastingMode.Off;
   var lamp=new GameObject("Arrow light").AddComponent<Light>();lamp.transform.SetParent(go.transform,false);lamp.type=LightType.Point;lamp.color=Tone("ffd2a6");lamp.intensity=.9f;lamp.range=1.8f;lamp.shadows=LightShadows.None;
   var fx=Life(go,float.PositiveInfinity);fx.Block.SetColor("_Tone",new Color(1.6f,1.25f,.9f,1));fx.Block.SetFloat("_Opacity",.75f);fx.Apply();
   return go;
  }
 }
}
