using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // Per-actor material instances enable emission without modifying shared asset materials.
 // Property blocks keep every texture/PBR map intact and avoid per-hit allocations.
 public sealed class HitFlash:MonoBehaviour
 {
  sealed class Surface{public Renderer renderer;public int index;public Material material;public Color color,emission;}
  readonly List<Surface> surfaces=new();readonly List<Material> owned=new();
  MaterialPropertyBlock block;float remaining,duration,strength;int pulseFrame;bool playerPulse=true;
  static readonly int Base=Shader.PropertyToID("_BaseColor"),Emission=Shader.PropertyToID("_EmissionColor"),EmissionMap=Shader.PropertyToID("_EmissionMap");
  public bool Active=>remaining>0;
  public void Initialize(Renderer[] renderers)
  {
   foreach(var renderer in renderers)
   {
    var materials=renderer.materials;
    for(int i=0;i<materials.Length;i++)
    {
     var material=materials[i];owned.Add(material);
     if(!material.HasProperty(Base)||!material.HasProperty(Emission))continue;
     material.EnableKeyword("_EMISSION");
     surfaces.Add(new Surface{renderer=renderer,index=i,material=material,color=material.GetColor(Base),emission=material.GetColor(Emission)});
    }
   }
  }
  // Re-tint every surface (the keep's spectral garrison) and remember it as the resting look the flash returns to.
  public void Restyle(Color tint,Color glow)
  {
   foreach(var s in surfaces){s.color=new Color(s.color.r*tint.r,s.color.g*tint.g,s.color.b*tint.b,s.color.a);s.emission=glow;s.material.SetColor(Base,s.color);s.material.SetColor(Emission,s.emission);}
   Apply(0);
  }
  public void Pulse(bool player){playerPulse=player;duration=player?.09f:.15f;strength=player?.12f:.62f;remaining=duration;pulseFrame=Time.frameCount;Apply(strength);}
  // A hit late in a long frame must still be rendered once at its intended peak.
  void LateUpdate(){if(remaining<=0||Time.frameCount==pulseFrame)return;Advance(Time.unscaledDeltaTime);}
  void Advance(float dt)
  {
   remaining=Mathf.Max(0,remaining-dt);
   // Brief, restrained white contact that preserves armor detail; player curve unchanged.
   float fade=playerPulse?Mathf.Pow(remaining/duration,2):Mathf.SmoothStep(0,1,Mathf.Clamp01(remaining/(duration-.025f)));
   Apply(strength*fade);
  }
  void Apply(float value)
  {
   block??=new MaterialPropertyBlock();
   foreach(var s in surfaces)if(s.renderer)
   {
    s.renderer.GetPropertyBlock(block,s.index);
    block.SetColor(Base,Color.Lerp(s.color,Color.white,value*.35f));
    block.SetColor(Emission,s.emission+(playerPulse?new Color(1,.83f,.76f):Color.white)*value);
    // Dark emission masks otherwise swallow the flash on textured armor.
    // Override only during enemy hits; restore the actor's original map afterwards.
    if(!playerPulse&&s.material.HasProperty(EmissionMap))block.SetTexture(EmissionMap,value>0?Texture2D.whiteTexture:s.material.GetTexture(EmissionMap)??Texture2D.whiteTexture);
    s.renderer.SetPropertyBlock(block,s.index);
   }
  }
  void OnDisable(){remaining=0;Apply(0);}
  void OnDestroy(){foreach(var material in owned)if(material)Destroy(material);}
 }
}
