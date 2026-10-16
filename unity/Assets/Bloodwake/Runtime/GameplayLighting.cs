using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Bloodwake
{
 // Gameplay presentation is independent of the Godot VFX/animation reference.
 public sealed class GameplayLighting:MonoBehaviour
 {
  Material sky,previousSky;VolumeProfile profile;
  public void Configure(Camera camera)
  {
   camera.allowHDR=true;
   var data=camera.GetUniversalAdditionalCameraData();data.renderPostProcessing=true;
   data.antialiasing=AntialiasingMode.SubpixelMorphologicalAntiAliasing;
   data.antialiasingQuality=AntialiasingQuality.High;
   var key=Directional("Moon key",new Vector3(50,45,0),new Color(.69f,.79f,1),.85f,true);
   RenderSettings.sun=key; // Keep the shadow-casting light as URP's main light.
   Directional("Warm bounce",new Vector3(65,145,0),new Color(1,.72f,.48f),.18f,false);
   Directional("Cool silhouette",new Vector3(25,130,0),new Color(.53f,.7f,1),.25f,false);
   // Rendering layer 2 is reserved for actor readability. It cannot wash out
   // the courtyard; normal world lights still illuminate these renderers.
   var portrait=Directional("Actor soft fill",new Vector3(38,145,0),new Color(.9f,.91f,1),1.6f,false);
   portrait.GetUniversalAdditionalLightData().renderingLayers=2u;
   // A warm rim from behind the actors, travelling toward the isometric camera,
   // separates dark armour from dark stone the way the art-direction frames do.
   var rim=Directional("Actor rim",Quaternion.LookRotation(new Vector3(-.6f,-.35f,.8f)).eulerAngles,new Color(1,.52f,.4f),2.4f,false);
   rim.GetUniversalAdditionalLightData().renderingLayers=2u;
   previousSky=RenderSettings.skybox;
   sky=new Material(Resources.Load<Shader>("Presentation/TownSky")){name="Town reflection sky"};
   RenderSettings.skybox=sky;RenderSettings.reflectionIntensity=.85f;
   RenderSettings.ambientMode=AmbientMode.Flat;
   RenderSettings.ambientLight=new Color(.08f,.09f,.12f);
   var ambient=new SphericalHarmonicsL2();ambient.AddAmbientLight(RenderSettings.ambientLight);RenderSettings.ambientProbe=ambient;
   var volume=gameObject.AddComponent<Volume>();volume.isGlobal=true;volume.priority=10;
   profile=ScriptableObject.CreateInstance<VolumeProfile>();volume.sharedProfile=profile;
   profile.Add<Tonemapping>().mode.Override(TonemappingMode.ACES);
   var bloom=profile.Add<Bloom>();bloom.intensity.Override(.42f);bloom.threshold.Override(.95f);bloom.scatter.Override(.62f);
   var grade=profile.Add<ColorAdjustments>();grade.contrast.Override(16);grade.saturation.Override(8);grade.postExposure.Override(.35f);
   // Cold moonlit shadows against warm firelit highlights.
   var split=profile.Add<SplitToning>();split.shadows.Override(new Color(.42f,.46f,.54f));split.highlights.Override(new Color(1,.76f,.56f));split.balance.Override(0);
   var vignette=profile.Add<Vignette>();vignette.intensity.Override(.3f);vignette.smoothness.Override(.5f);vignette.color.Override(new Color(.02f,0,.01f));
  }
  Light Directional(string label,Vector3 angles,Color color,float intensity,bool shadows)
  {
   var lamp=new GameObject(label).AddComponent<Light>();lamp.transform.SetParent(transform,false);
   lamp.type=LightType.Directional;lamp.transform.rotation=Quaternion.Euler(angles);lamp.color=color;lamp.intensity=intensity;
   lamp.shadows=shadows?LightShadows.Soft:LightShadows.None;lamp.shadowStrength=.85f;return lamp;
  }
  void OnDestroy()
  {
   if(RenderSettings.skybox==sky)RenderSettings.skybox=previousSky;
   if(sky)Destroy(sky);if(profile){foreach(var component in profile.components)Destroy(component);Destroy(profile);}
  }
 }
 public sealed class RoomReflection:MonoBehaviour
 {
  public Vector2 HalfSize;
  IEnumerator Start()
  {
   // Capture only once, after deferred destruction of the previous room.
   // Unity owns the texture and filters its roughness mip chain.
   yield return null;
   var probe=new GameObject("Room reflections").AddComponent<ReflectionProbe>();probe.transform.SetParent(transform,false);
   probe.transform.localPosition=new Vector3(0,3,0);probe.size=new Vector3(HalfSize.x*2+12,24,HalfSize.y*2+12);
   probe.mode=ReflectionProbeMode.Realtime;probe.refreshMode=ReflectionProbeRefreshMode.ViaScripting;
   probe.timeSlicingMode=ReflectionProbeTimeSlicingMode.AllFacesAtOnce;
   probe.boxProjection=true;probe.blendDistance=2;probe.resolution=128;probe.hdr=true;
   probe.nearClipPlane=.2f;probe.farClipPlane=100;probe.clearFlags=ReflectionProbeClearFlags.Skybox;
   probe.RenderProbe();

  }
 }
}
