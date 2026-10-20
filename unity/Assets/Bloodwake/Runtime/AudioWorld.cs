using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The sound of the place around the music: footsteps, enemies' own voices and armour, a room ambience bed
 // and fires crackling where they stand. Every id is optional; a clip dropped into Resources/audio under
 // that name (or name_1, name_2 ... for variations, see rules.json "audio") is picked up on the next run.
 public sealed partial class BloodwakeGame
 {
  AudioSource ambienceVoice;Transform listener;float playerStep;readonly Dictionary<Enemy,float> enemySteps=new();readonly Dictionary<Enemy,Vector3> enemyLast=new();
  string ambienceId;float ambienceTarget;

  // The listener rides with the hunter, so fires and enemies are heard from where she stands, not from the high camera.
  void EnsureListener()
  {
   if(listener)return;var cameraEar=Cam?Cam.GetComponent<AudioListener>():null;if(cameraEar)cameraEar.enabled=false;
   listener=new GameObject("Hunter ears").transform;listener.gameObject.AddComponent<AudioListener>();
   ambienceVoice=gameObject.AddComponent<AudioSource>();ambienceVoice.loop=true;ambienceVoice.playOnAwake=false;ambienceVoice.volume=0;
  }
  void TickAudioWorld(float dt,bool playerMoving,bool walking)
  {
   EnsureListener();
   if(Player){listener.position=Player.transform.position+Vector3.up*1.6f;listener.rotation=Quaternion.LookRotation(Vector3.ProjectOnPlane(Cam.transform.forward,Vector3.up));}
   // Ambience bed fades between rooms.
   ambienceVoice.volume=Mathf.MoveTowards(ambienceVoice.volume,ambienceTarget,dt*.5f);if(ambienceVoice.volume<=0&&ambienceTarget<=0&&ambienceVoice.isPlaying)ambienceVoice.Stop();
   if(Screen!="playing"||!Player)return;
   // Each step sounds when a foot actually plants (see ActorView.TakeFootfalls); the old fixed .31 s beat ran
   // ahead of the run cycle. The timer stays only for a rig without foot bones.
   int footfalls=Player.TakeFootfalls(dt);
   if(Player.HasFeet){if(playerMoving)for(int i=0;i<footfalls;i++)Sound(walking?"player_step_walk":"player_step");}
   else if(playerMoving){playerStep-=dt;if(playerStep<=0){playerStep=walking?.52f:.31f;Sound(walking?"player_step_walk":"player_step");}}else playerStep=Mathf.Min(playerStep,.08f);
   // Enemies' steps, only for those that are actually covering ground and near enough to matter: measured from
   // how far the body moved, so the warden's lunges and charges thud as well as his walk.
   foreach(var e in Enemies)
   {
    if(e.Emerging||!e.View||dt<=0)continue;var at=e.View.transform.position;bool seen=enemyLast.TryGetValue(e,out var last);enemyLast[e]=at;
    if(!seen||Vector3.Distance(at,Player.transform.position)>(e.Id=="boss"?16:11))continue;
    float speed=Vector3.Distance(at,last)/dt;if(speed<.6f)continue;
    enemySteps.TryGetValue(e,out float t);t-=dt;if(t<=0){t=(e.Id=="tank"||e.Id=="boss"?.6f:.42f)*Mathf.Clamp(3/speed,.45f,1.3f);Sound(e.Id=="boss"?"boss_step":e.Id=="tank"||e.Id=="grunt"?"armored_step":"enemy_step");}enemySteps[e]=t;
   }
   if(enemySteps.Count>40||enemyLast.Count>40){foreach(var gone in enemyLast.Keys.Where(k=>!Enemies.Contains(k)).ToArray()){enemySteps.Remove(gone);enemyLast.Remove(gone);}}
  }
  // A room's bed: interior hearth hush in the sanctuary, wind and the restless town outside, a heavier bed for bosses.
  void SetAmbience(string roomType)
  {
   EnsureListener();
   string id=roomType=="safehouse"?"amb_sanctuary":roomType=="boss"?"amb_boss_square":roomType=="merchant"?"amb_market_night":"amb_town_night";
   if(id==ambienceId)return;ambienceId=id;var clip=PickVariant(id);
   if(!clip){ambienceTarget=0;return;}ambienceVoice.clip=clip;ambienceVoice.volume=0;ambienceVoice.Play();ambienceTarget=GameData.Rules["audio"]?[id]?.N("db",-14) is float db?Mathf.Pow(10,db/20):.2f;
  }
  // Every fire in the room crackles from where it burns.
  void PlaceFireSounds()
  {
   var crackle=PickVariant("amb_fire_crackle");if(!crackle||!roomRoot)return;int i=0;
   var fires=roomRoot.GetComponentsInChildren<Light>().Where(l=>l.type==LightType.Point&&(l.name.Contains("Brazier")||l.name.Contains("Lantern")||l.name.Contains("Hearth"))).ToArray();
   // Level from rules.json, shared out so a room of braziers sounds about as loud as two of them, not the sum.
   float level=Mathf.Pow(10,(GameData.Rules["audio"]?["amb_fire_crackle"]?.N("db",-18)??-18)/20)/Mathf.Sqrt(Mathf.Max(1,fires.Length/2f));
   foreach(var light in fires)
   {
    var src=light.gameObject.AddComponent<AudioSource>();src.clip=crackle;src.loop=true;src.spatialBlend=1;src.rolloffMode=AudioRolloffMode.Linear;src.minDistance=1;src.maxDistance=light.name.Contains("Lantern")?4:6;
    src.volume=level*(light.name.Contains("Lantern")?.5f:1);src.time=(i++*1.37f)%Mathf.Max(.1f,crackle.length);src.Play();
   }
  }
  bool HasSound(string id)=>sounds.ContainsKey(id)||((GameData.Rules["audio"]?[id]?["files"] as Newtonsoft.Json.Linq.JArray)?.Any(f=>sounds.ContainsKey((string)f))??false);
  // A move's own sound once it is delivered, the shared one until then.
  string Voice(string own,string fallback)=>HasSound(own)?own:fallback;
  // name, or any of name_1, name_2 ... that exist.
  AudioClip PickVariant(string id,string avoid=null)
  {
   var options=sounds.Where(kv=>kv.Key==id||kv.Key.StartsWith(id+"_")&&int.TryParse(kv.Key.Substring(id.Length+1),out _)).Select(kv=>kv.Value).ToList();
   if(options.Count>1&&avoid!=null)options.RemoveAll(c=>c.name==avoid);
   return options.Count==0?null:options[Random.Range(0,options.Count)];
  }
 }
}
