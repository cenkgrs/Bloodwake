using UnityEngine;

namespace Bloodwake
{
 public sealed class RoomPresentation:MonoBehaviour
 {
  Material stone,fire,exitMaterial;MeshRenderer exitGlow;BloodwakeGame game;float age;
  public void Apply(Transform environment,BloodwakeGame owner)
  {
   game=owner;
   stone=new Material(Resources.Load<Shader>("Presentation/WetStone")){name="Wet courtyard stone"};
   stone.SetTexture("_BaseMap",Resources.Load<Texture2D>("Presentation/Cobblestone/albedo"));
   stone.SetTexture("_BumpMap",Resources.Load<Texture2D>("Presentation/Cobblestone/normal"));
   stone.SetTexture("_ARM",Resources.Load<Texture2D>("Presentation/Cobblestone/arm"));
   foreach(var r in environment.GetComponentsInChildren<MeshRenderer>())
   {
    if(r.name=="ExitGlow")
    {
     // The exported source alpha plane otherwise renders as an opaque slab.
     exitGlow=r;exitMaterial=new Material(Resources.Load<Shader>("Presentation/ExitGlow")){name="Open gate glow"};
     r.sharedMaterial=exitMaterial;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;r.enabled=false;continue;
    }
    var b=r.bounds;
    // The source room contains a dark 7.2 m circular combat decal. It reads as
    // a permanent ability indicator and competes with actual telegraphs.
    if(b.size.y<.025f&&b.size.x>5&&b.size.x<10&&b.size.z>5&&b.size.z<10&&new Vector2(b.center.x,b.center.z).magnitude<1)
    {r.enabled=false;continue;}
    // Only the room's large horizontal courtyard plane; retain roofs, paving
    // borders, combat sigils, props and the fading outside-world boundary.
    if(r.name!="Outside"&&b.size.y<.05f&&b.size.x>8&&b.size.z>8&&Mathf.Abs(b.center.y)<.2f)r.sharedMaterial=stone;
   }
   foreach(var lamp in environment.GetComponentsInChildren<Light>())
   {
    lamp.color=new Color(1,.46f,.15f);lamp.intensity=lamp.name=="Brazier light"?2.1f:3.2f;lamp.range=lamp.name=="Brazier light"?4.5f:6;
    if(!fire)fire=new Material(Resources.Load<Shader>("Presentation/Flame")){name="Lantern flame"};
    var flame=GameObject.CreatePrimitive(PrimitiveType.Quad);flame.name="Lantern flame";Destroy(flame.GetComponent<Collider>());
    // Imported light parents can carry the FBX centimetre conversion scale.
    // Define the flame in world metres before parenting to preserve its size.
    flame.transform.position=lamp.transform.position+Vector3.up*.1f;flame.transform.localScale=new Vector3(.26f,.55f,1);flame.transform.SetParent(transform,true);
    var renderer=flame.GetComponent<MeshRenderer>();renderer.sharedMaterial=fire;renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
    flame.AddComponent<FlameFacing>();
   }
  }
  void LateUpdate()
  {
   if(!game||!exitGlow)return;exitGlow.enabled=game.ExitOpen;
   age+=game.VfxDelta;exitMaterial.SetFloat("_Clock",age);
  }
  void OnDestroy(){if(stone)Destroy(stone);if(fire)Destroy(fire);if(exitMaterial)Destroy(exitMaterial);}
 }
 public sealed class FlameFacing:MonoBehaviour
 {
  void LateUpdate(){if(Camera.main)transform.rotation=Camera.main.transform.rotation;}
 }
}
