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
  MusicBlend musicBlend;Light playerFill;readonly Dictionary<string,AudioClip> sounds=new();
  void OnDestroy(){Effects.Release();}
  void Awake()
  {
   Meta.Load();Cam=Camera.main;
   if(Cam==null){Cam=new GameObject("Gameplay Camera").AddComponent<Camera>();Cam.tag="MainCamera";Cam.gameObject.AddComponent<AudioListener>();}
   Cam.orthographic=true;Cam.orthographicSize=PlayerPrefs.GetFloat("zoom",7.2f);Cam.farClipPlane=140;Cam.clearFlags=CameraClearFlags.SolidColor;Cam.backgroundColor=new Color(.025f,.025f,.035f);AudioListener.volume=PlayerPrefs.GetFloat("volume",.8f);
   Cam.GetUniversalAdditionalCameraData().renderPostProcessing=true;
   musicBlend=gameObject.AddComponent<MusicBlend>();musicBlend.Game=this;
   foreach(var clip in Resources.LoadAll<AudioClip>("audio"))sounds[clip.name]=clip;
   foreach(var clip in Resources.LoadAll<AudioClip>("audio/polished"))sounds[clip.name]=clip;
   gameObject.AddComponent<GameplayLighting>().Configure(Cam);SetMusic("music_menu");
   if(Environment.GetCommandLineArgs().Contains("--smoke"))StartCoroutine(Smoke());
  }
  public void StartRun(string id)
  {
   StopAllCoroutines();if(actorRoot)Destroy(actorRoot.gameObject);if(roomRoot)Destroy(roomRoot.gameObject);Enemies.Clear();
   attackCd=dashCd=invulnerable=hitStop=0;combo=0;markChain=0;comboExpires=0;bossReward=false;merchantVisit="";merchantStock=null;pickups.Clear();
   Run=new RunState(id,Meta);SelectedClass=id;actorRoot=new GameObject("Actors").transform;
   Player=ActorView.Create(id,false,2.05f,actorRoot);playerFill=new GameObject("Player fill light").AddComponent<Light>();playerFill.transform.SetParent(Player.transform);playerFill.type=LightType.Point;playerFill.color=RevenantVfx.Tone("d1def0");playerFill.intensity=4;playerFill.range=7;playerFill.shadows=LightShadows.None;playerFill.GetUniversalAdditionalLightData().renderingLayers=2u;var map=GameData.Maps["maps"][0];Run.Plan=map["route"].Values<string>().ToList();Run.Plan.Add(map.S("boss"));Run.Plan.Add(map.S("interlude"));EnterRoom("town_safehouse");Screen="playing";
  }
  readonly Dictionary<string,float> soundTimes=new();readonly List<AudioSource> soundVoices=new();
  void Sound(string id)
  {
   var data=GameData.Rules["audio"]?[id];if(soundTimes.TryGetValue(id,out float last)&&Time.unscaledTime-last<data.N("gap"))return;
   var files=data?["files"] as JArray;string name=files==null?id:(string)files[UnityEngine.Random.Range(0,files.Count)];if(!sounds.TryGetValue(name,out var clip))return;
   var voice=soundVoices.FirstOrDefault(s=>!s.isPlaying);if(voice==null){if(soundVoices.Count>=32)return;voice=gameObject.AddComponent<AudioSource>();soundVoices.Add(voice);}
   voice.clip=clip;voice.volume=Mathf.Clamp01(Mathf.Pow(10,data.N("db",-5)/20));voice.pitch=data?["pitch"] is JArray pitch?UnityEngine.Random.Range((float)pitch[0],(float)pitch[1]):1;voice.Play();soundTimes[id]=Time.unscaledTime;
  }
  void SetMusic(string id){if(id=="")musicBlend.Set("",null);else if(sounds.TryGetValue(id,out var clip))musicBlend.Set(id,clip);}
 }
}
