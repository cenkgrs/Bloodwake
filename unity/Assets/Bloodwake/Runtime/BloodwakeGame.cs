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
  void OnDestroy(){ReleaseCrowdNavigation();Effects.Release();}
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
   ResetRevenantDash();practiceDashImpact=false;
   StopAllCoroutines();if(actorRoot)Destroy(actorRoot.gameObject);if(roomRoot)Destroy(roomRoot.gameObject);Enemies.Clear();
   attackCd=dashCd=invulnerable=hitStop=0;combo=0;markChain=0;comboExpires=0;bossReward=false;merchantVisit="";merchantStock=null;pickups.Clear();
   Run=new RunState(id,Meta);SelectedClass=id;actorRoot=new GameObject("Actors").transform;
   Player=ActorView.Create(id,false,2.05f*CombatActorScale,actorRoot);playerFill=new GameObject("Player fill light").AddComponent<Light>();playerFill.transform.SetParent(Player.transform);playerFill.type=LightType.Point;playerFill.color=RevenantVfx.Tone("d1def0");playerFill.intensity=4;playerFill.range=7;playerFill.shadows=LightShadows.None;playerFill.GetUniversalAdditionalLightData().renderingLayers=2u;var map=GameData.Maps["maps"][0];Run.Plan=map["route"].Values<string>().ToList();Run.Plan.Add(map.S("boss"));Run.Plan.Add(map.S("interlude"));EnterRoom("town_safehouse");Screen="playing";
  }
  readonly Dictionary<string,float> soundTimes=new();readonly List<AudioSource> soundVoices=new();
  sealed class VoiceMix{public string Id;public float Gain,Started,Release=1;public bool Signature,Releasing;}
  readonly Dictionary<AudioSource,VoiceMix> voiceMix=new();
  float duckUntil,duckTarget=1,duckGain=1;
  // Revenant blood abilities carry their own claw/impact transient in the cast
  // sound; the generic sword-on-flesh hit must not land on top of it.
  bool bakedImpactSound;
  void Sound(string id)=>SoundFrom(id,0);
  void SoundFrom(string id,float startSeconds)
  {
   var data=GameData.Rules["audio"]?[id];if(soundTimes.TryGetValue(id,out float last)&&Time.unscaledTime-last<data.N("gap"))return;
   var files=data?["files"] as JArray;string name=files==null?id:(string)files[UnityEngine.Random.Range(0,files.Count)];if(!sounds.TryGetValue(name,out var clip))return;
   bool signature=data?["priority"]?.Value<bool>()==true;
   // Honour the authored voice limit: a re-trigger releases its oldest copy
   // (short fade, no click) instead of stacking phase-smeared duplicates.
   int limit=(int)data.N("voices");
   if(limit>0){var same=soundVoices.Where(s=>s.isPlaying&&voiceMix.TryGetValue(s,out var m)&&m.Id==id&&!m.Releasing).OrderBy(s=>voiceMix[s].Started).ToList();for(int i=0;i<=same.Count-limit;i++)voiceMix[same[i]].Releasing=true;}
   var voice=soundVoices.FirstOrDefault(s=>!s.isPlaying);
   if(voice==null&&soundVoices.Count<32){voice=gameObject.AddComponent<AudioSource>();voice.playOnAwake=false;soundVoices.Add(voice);}
   // A full pool never drops a signature ability sound: steal the oldest ordinary voice.
   if(voice==null&&signature)voice=soundVoices.Where(s=>!voiceMix.TryGetValue(s,out var m)||!m.Signature).OrderBy(s=>voiceMix.TryGetValue(s,out var m)?m.Started:0).FirstOrDefault();
   if(voice==null)return;
   float gain=Mathf.Clamp01(Mathf.Pow(10,data.N("db",-5)/20))*(id=="revenant_swing"?.72f:1);
   voiceMix[voice]=new VoiceMix{Id=id,Gain=gain,Started=Time.unscaledTime,Signature=signature};
   voice.Stop();voice.clip=clip;voice.priority=signature?0:128;voice.volume=gain*(signature?1:duckGain);voice.pitch=data?["pitch"] is JArray pitch?UnityEngine.Random.Range((float)pitch[0],(float)pitch[1]):1;voice.time=Mathf.Clamp(startSeconds,0,Mathf.Max(0,clip.length-.001f));voice.Play();soundTimes[id]=Time.unscaledTime;
   // Signature casts duck the rest of the effects mix while their body plays.
   if(data?["duck"] is JObject duck){duckTarget=Mathf.Min(duckTarget,Mathf.Pow(10,duck.N("db")/20));duckUntil=Mathf.Max(duckUntil,Time.unscaledTime+duck.N("seconds"));}
  }
  void TickSoundMix()
  {
   float dt=Time.unscaledDeltaTime,now=Time.unscaledTime;if(now>=duckUntil)duckTarget=1;
   // Fast attack (~25 ms) so the cast transient is clear; slower release (~180 ms).
   duckGain=Mathf.MoveTowards(duckGain,duckTarget,dt*(duckTarget<duckGain?40f:5.5f));
   foreach(var voice in soundVoices)
   {
    if(!voice.isPlaying||!voiceMix.TryGetValue(voice,out var m))continue;
    if(m.Releasing){m.Release=Mathf.MoveTowards(m.Release,0,dt/.04f);if(m.Release<=0){voice.Stop();m.Releasing=false;continue;}}
    voice.volume=m.Gain*m.Release*(m.Signature?1:duckGain);
   }
  }
  void SetMusic(string id){if(id=="")musicBlend.Set("",null);else if(sounds.TryGetValue(id,out var clip))musicBlend.Set(id,clip);}
 }
}
