using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame:MonoBehaviour
 {
  public RunState Run;public readonly Progression Meta=new();public ActorView Player;public Camera Cam;
  public readonly List<Enemy> Enemies=new();Transform roomRoot,actorRoot;JObject room;
  public string Screen="menu",SelectedClass="warrior";Vector3 aim=Vector3.forward;Vector2 half;
  float attackCd,dashCd,invulnerable,hitStop,spawnTimer;int waveIndex,spawnCursor;JArray waves;
  bool roomClear;readonly List<Bounds> blockers=new();readonly List<JToken> offers=new();
  AudioSource audioSource,music;readonly Dictionary<string,AudioClip> sounds=new();
  void Awake()
  {
   Meta.Load();Cam=Camera.main;
   if(Cam==null){Cam=new GameObject("Gameplay Camera").AddComponent<Camera>();Cam.tag="MainCamera";Cam.gameObject.AddComponent<AudioListener>();}
   Cam.orthographic=true;Cam.orthographicSize=PlayerPrefs.GetFloat("zoom",7.2f);Cam.farClipPlane=140;Cam.clearFlags=CameraClearFlags.SolidColor;Cam.backgroundColor=new Color(.025f,.025f,.035f);AudioListener.volume=PlayerPrefs.GetFloat("volume",.8f);
   Cam.GetUniversalAdditionalCameraData().renderPostProcessing=true;
   audioSource=gameObject.AddComponent<AudioSource>();music=gameObject.AddComponent<AudioSource>();music.loop=true;music.volume=.15f;
   foreach(var clip in Resources.LoadAll<AudioClip>("audio"))sounds[clip.name]=clip;
   foreach(var clip in Resources.LoadAll<AudioClip>("audio/polished"))sounds[clip.name]=clip;
   var light=new GameObject("Moon key").AddComponent<Light>();light.type=LightType.Directional;light.transform.rotation=Quaternion.Euler(58,-12,0);light.intensity=.65f;light.color=new Color(.62f,.70f,.84f);light.shadows=LightShadows.Soft;
   var fill=new GameObject("Warm sky fill").AddComponent<Light>();fill.type=LightType.Directional;fill.transform.rotation=Quaternion.Euler(65,145,0);fill.intensity=.85f;fill.color=new Color(1,.88f,.75f);fill.shadows=LightShadows.None;
   var volume=new GameObject("Color and exposure").AddComponent<Volume>();volume.isGlobal=true;volume.profile=ScriptableObject.CreateInstance<VolumeProfile>();
   var tone=volume.profile.Add<Tonemapping>();tone.mode.Override(TonemappingMode.ACES);
   var bloom=volume.profile.Add<Bloom>();bloom.intensity.Override(.18f);bloom.threshold.Override(1.1f);
   RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.ambientLight=new Color(.5f,.47f,.44f);
   var ambient=new SphericalHarmonicsL2();ambient.AddAmbientLight(new Color(.5f,.47f,.44f));RenderSettings.ambientProbe=ambient;SetMusic("music_menu");
   if(Environment.GetCommandLineArgs().Contains("--smoke"))StartCoroutine(Smoke());
  }
  public void StartRun(string id)
  {
   StopAllCoroutines();if(actorRoot)Destroy(actorRoot.gameObject);if(roomRoot)Destroy(roomRoot.gameObject);Enemies.Clear();
   attackCd=dashCd=invulnerable=hitStop=0;combo=0;markChain=0;comboExpires=0;bossReward=false;merchantVisit="";merchantStock=null;pickups.Clear();
   Run=new RunState(id,Meta);SelectedClass=id;actorRoot=new GameObject("Actors").transform;
   Player=ActorView.Create(id,false,2.05f,actorRoot);var map=GameData.Maps["maps"][0];Run.Plan=map["route"].Values<string>().ToList();Run.Plan.Add(map.S("boss"));Run.Plan.Add(map.S("interlude"));EnterRoom("town_safehouse");Screen="playing";
  }
  readonly Dictionary<string,float> soundTimes=new();readonly List<AudioSource> soundVoices=new();
  void Sound(string id)
  {
   var data=GameData.Rules["audio"]?[id];if(soundTimes.TryGetValue(id,out float last)&&Time.unscaledTime-last<data.N("gap"))return;
   var files=data?["files"] as JArray;string name=files==null?id:(string)files[UnityEngine.Random.Range(0,files.Count)];if(!sounds.TryGetValue(name,out var clip))return;
   var voice=soundVoices.FirstOrDefault(s=>!s.isPlaying);if(voice==null){if(soundVoices.Count>=32)return;voice=gameObject.AddComponent<AudioSource>();soundVoices.Add(voice);}
   voice.clip=clip;voice.volume=Mathf.Clamp01(Mathf.Pow(10,data.N("db",-5)/20));voice.pitch=data?["pitch"] is JArray pitch?UnityEngine.Random.Range((float)pitch[0],(float)pitch[1]):1;voice.Play();soundTimes[id]=Time.unscaledTime;
  }
  void SetMusic(string id){if(sounds.TryGetValue(id,out var clip)&&music.clip!=clip){music.clip=clip;music.Play();}}
 }
}
