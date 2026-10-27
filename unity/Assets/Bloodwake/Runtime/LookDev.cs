using System.Collections;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 // Look-development captures (run the player with --lookdev): the Mage and Vesper side by side in a real fight
 // room with a few enemies, under the current lighting and alternatives, from the game's isometric camera and a
 // third-person one. Writes /tmp/bloodwake-lookdev-<light>-<camera>.png and quits.
 public sealed partial class BloodwakeGame
 {
  public const string LookDevMarker="Temp/bloodwake-lookdev";
  // The editor's Bloodwake/LookDev Capture menu leaves this marker before entering play mode.
  static bool LookDevRequested(){if(!Application.isEditor||!System.IO.File.Exists(LookDevMarker))return false;System.IO.File.Delete(LookDevMarker);return true;}
  public const string GlideCaptureMarker="Temp/bloodwake-glidecapture";
  static bool GlideCaptureRequested(){if(!Application.isEditor||!System.IO.File.Exists(GlideCaptureMarker))return false;System.IO.File.Delete(GlideCaptureMarker);return true;}
  // Glide check: the Mage glides across a fight room; the game camera's view is saved at six moments of the
  // flight (/tmp/bloodwake-glide-<ms>.png) and the live glide effects are listed in the log at each.
  public IEnumerator GlideCapture()
  {
   AudioListener.volume=0;
   yield return new WaitForSeconds(.5f);
   StartRun("mage");EnterRoom(Run.Plan[0]);spawnTimer=999;yield return new WaitForSeconds(1.2f);
   // Toward the middle of the room (open floor), seen at the game's own default zoom.
   // Across the screen (the camera's right or left, whichever way the floor is open), so streaks trailing
   // behind her are seen side on instead of foreshortened into the column under her feet.
   var across=Vector3.ProjectOnPlane(Cam.transform.right,Vector3.up).normalized;var from=Player.transform.position;
   var dir=Vector3.Distance(Move(from,across*4.6f),from)>=Vector3.Distance(Move(from,-across*4.6f),from)?across:-across;
   Cam.orthographicSize=DefaultZoom;
   // Arrival and room intros hold the player for a moment: keep trying until the glide is allowed.
   float giveUp=Time.time+8;while(!TryMageGlide(dir)){if(Time.time>giveUp){Debug.Log("BLOODWAKE_GLIDE could not start: screen="+Screen);yield break;}yield return null;}
   float t0=Time.time;
   foreach(float at in new[]{.04f,.15f,.3f,.45f,.62f,.8f})
   {
    while(Time.time-t0<at)yield return null;
    yield return null;  // batch-mode players never reach end of frame; the shot renders by hand anyway
    var names=FindObjectsByType<Transform>(FindObjectsSortMode.None).Select(x=>x.name).Where(n=>n.StartsWith("Glide")).GroupBy(n=>n).Select(g=>g.Key+" x"+g.Count());
    foreach(var line in FindObjectsByType<LineRenderer>(FindObjectsSortMode.None).Where(l=>l.name=="Glide trail").Take(2))
    {
     var block=new MaterialPropertyBlock();line.GetPropertyBlock(block);
     Debug.Log("BLOODWAKE_GLIDE_LINE n="+line.positionCount+" p0="+line.GetPosition(0)+" pN="+line.GetPosition(Mathf.Max(0,line.positionCount-1))+" width="+line.widthMultiplier+" visible="+line.isVisible+" enabled="+line.enabled+" mat="+(line.sharedMaterial?line.sharedMaterial.name:"none")+" opacity="+block.GetFloat("_Opacity")+" player="+Player.transform.position);
    }
    Debug.Log("BLOODWAKE_GLIDE t="+at+" state="+Player.Animator.GetCurrentAnimatorClipInfo(0).FirstOrDefault().clip?.name+" y="+Player.transform.position.y.ToString("0.00")+" fx: "+string.Join(", ",names));
    var target=new RenderTexture(1600,900,24);target.Create();var old=Cam.targetTexture;Cam.targetTexture=target;Cam.Render();
    var active=RenderTexture.active;RenderTexture.active=target;var texture=new Texture2D(1600,900,TextureFormat.RGB24,false);texture.ReadPixels(new Rect(0,0,1600,900),0,0);texture.Apply();
    System.IO.File.WriteAllBytes("/tmp/bloodwake-glide-"+Mathf.RoundToInt(at*1000).ToString("000")+".png",texture.EncodeToPNG());
    RenderTexture.active=active;Cam.targetTexture=old;target.Release();Destroy(texture);
   }
   Debug.Log("BLOODWAKE_GLIDE_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#else
   Application.Quit(0);
#endif
  }
  // Keep tour (--keeptour): every room of the second map, empty, as an overview of the whole floor and from the
  // game's own camera at the entrance; then the keep's garrison lined up, and its warden in the throne room.
  // Writes /tmp/bloodwake-keep-<room>-<view>.png. Silent.
  // With night 1 (--towntour) it walks the first map's rooms instead, without the lineup.
  public IEnumerator KeepTour(int night=2)
  {
   AudioListener.volume=0;smokeRunning=true;
   yield return new WaitForSeconds(.5f);
   StartRun("mage");invulnerable=99999;Run.Night=night;PlanNight();
   foreach(var id in Run.Plan.ToArray())
   {
    Run.RoomIndex=Run.Plan.IndexOf(id);EnterRoom(id);spawnTimer=999;
    yield return new WaitForSeconds(1.2f);
    Debug.Log("BLOODWAKE_KEEP room="+id+" blockers="+blockers.Count+" lights="+roomRoot.GetComponentsInChildren<Light>().Length+" renderers="+roomRoot.GetComponentsInChildren<Renderer>().Length);
    // Every enemy spawn must have a walkable path to the hunter on the crowd navmesh.
    var entry=Player.transform.position;int ok=0,bad=0;var path=new UnityEngine.AI.NavMeshPath();
    foreach(var sp in (room["markers"]["EnemySpawn"] as Newtonsoft.Json.Linq.JArray)??new Newtonsoft.Json.Linq.JArray())
    {
     var from=Point(sp);
     if(UnityEngine.AI.NavMesh.SamplePosition(from,out var a,1.5f,UnityEngine.AI.NavMesh.AllAreas)&&UnityEngine.AI.NavMesh.SamplePosition(entry,out var b,1.5f,UnityEngine.AI.NavMesh.AllAreas)&&UnityEngine.AI.NavMesh.CalculatePath(a.position,b.position,UnityEngine.AI.NavMesh.AllAreas,path)&&path.status==UnityEngine.AI.NavMeshPathStatus.PathComplete)ok++;
     else{bad++;Debug.Log("BLOODWAKE_KEEP_NOPATH "+id+" from "+sp.ToString(Newtonsoft.Json.Formatting.None));}
    }
    Debug.Log("BLOODWAKE_KEEP_PATHS "+id+" ok="+ok+" bad="+bad);
    PositionCamera(true);yield return null;PositionCamera(true);SaveView("/tmp/bloodwake-keep-"+id+"-game.png");
    // The middle of the room through the game camera, where the fighting happens.
    Cam.transform.position=new Vector3(0,0,0)+cameraOffset;SaveView("/tmp/bloodwake-keep-"+id+"-middle.png");
    float size=Cam.orthographicSize;Cam.orthographicSize=Mathf.Max(half.x,half.y)*.95f;Cam.transform.position=new Vector3(0,0,-1.5f)+cameraOffset;SaveView("/tmp/bloodwake-keep-"+id+"-overview.png");Cam.orthographicSize=size;
    if(id==Run.Plan[0]&&night==2)
    {
     var at=Player.transform.position;var dir=Vector3.ProjectOnPlane(-at,Vector3.up).normalized;var side=Vector3.Cross(Vector3.up,dir);
     string[] kinds={"keep_halberd","keep_knight","keep_crossbow","keep_wraith","keep_chaplain","keep_castellan"};
     for(int i=0;i<kinds.Length;i++)SpawnEnemy(kinds[i],at+dir*4.5f+side*(i-2.5f)*1.7f);
     yield return new WaitForSeconds(2.4f);
     foreach(var e in Enemies){if(e.Agent)e.Agent.enabled=false;}
     for(int i=0;i<Enemies.Count;i++){Enemies[i].View.transform.position=at+dir*4.5f+side*(i-2.5f)*1.7f;Enemies[i].View.transform.rotation=Quaternion.LookRotation(-dir);}
     PositionCamera(true);Cam.transform.position+=dir*2.4f;SaveView("/tmp/bloodwake-keep-garrison.png");
     foreach(var e in Enemies.ToArray())Destroy(e.View.gameObject);Enemies.Clear();
    }
    if(room.S("type")=="boss")
    {
     SpawnEnemy("boss",Point(room["markers"]["BossSpawn"]));yield return new WaitForSeconds(2.6f);
     foreach(var e in Enemies)if(e.Agent)e.Agent.enabled=false;
     Cam.transform.position=Enemies[0].View.transform.position+cameraOffset;SaveView("/tmp/bloodwake-keep-warden.png");
     Debug.Log("BLOODWAKE_KEEP warden="+BossVariant.S("name"));
    }
   }
   Debug.Log("BLOODWAKE_KEEP_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#else
   Application.Quit(0);
#endif
  }
  // Spell check (--spellcapture): the Mage faces three enemies in a fight room and casts R1, R1, R1, then R2, then
  // R1 R1 R2 (the comet); the camera is saved just after each release, at impact and after it
  // (/tmp/bloodwake-spell-<move>-<n>.png), and the hit stop and camera shake are logged. Silent.
  public IEnumerator SpellCapture()
  {
   AudioListener.volume=0;
   yield return new WaitForSeconds(.5f);
   StartRun("mage");EnterRoom(Run.Plan[0]);spawnTimer=999;invulnerable=9999;
   yield return new WaitForSeconds(1.5f);
   var at=Player.transform.position;var dir=Vector3.ProjectOnPlane(-at,Vector3.up);if(dir.sqrMagnitude<1)dir=Vector3.forward;dir.Normalize();
   var side=Vector3.Cross(Vector3.up,dir);Cam.orthographicSize=DefaultZoom;
   void HoldFoes(){foreach(var e in Enemies.ToArray()){if(e.Agent)e.Agent.enabled=false;}}
   var spots=new[]{at+dir*4.2f,at+dir*5.4f+side*1.3f,at+dir*6f-side*1.4f};
   foreach(var spot in spots)SpawnEnemy("grunt",spot);
   yield return new WaitForSeconds(2.2f);
   // They walk in while rising; pin them back at range, facing her, so every spell is seen travelling and landing.
   for(int i=0;i<Enemies.Count&&i<spots.Length;i++){var e=Enemies[i];e.MaxHp=e.Hp=99999;if(e.Agent)e.Agent.enabled=false;e.View.transform.position=spots[i];e.View.transform.rotation=Quaternion.LookRotation(at-spots[i]);}
   Player.transform.position=at;
   IEnumerator Shots(string move,params float[] times)
   {
    float t0=Time.time;
    for(int i=0;i<times.Length;i++)
    {
     while(Time.time-t0<times[i])yield return null;
     yield return null;
     Debug.Log("BLOODWAKE_SPELL "+move+" t="+times[i]+" hitStop="+hitStop.ToString("0.000")+" shake="+shakeTrauma.ToString("0.00")+" state="+Player.Animator.GetCurrentAnimatorClipInfo(0).FirstOrDefault().clip?.name);
     SaveView("/tmp/bloodwake-spell-"+move+"-"+i+".png");
    }
   }
   IEnumerator Cast(string move,System.Action act,params float[] times)
   {
    // Face the first foe, wait out the previous move, cast.
    HoldFoes();for(int i=0;i<Enemies.Count&&i<spots.Length;i++)Enemies[i].View.transform.position=spots[i];Player.transform.position=at;var foe=Enemies.FirstOrDefault();if(foe!=null){var to=foe.View.transform.position-Player.transform.position;to.y=0;Player.transform.rotation=Quaternion.LookRotation(to);}
    float wait=Time.time+3;while((attackCd>0||Player.Locked>.05f||vesperMoveActive)&&Time.time<wait)yield return null;
    act();yield return Shots(move,times);
   }
   comboExpires=0;combo=0;
   yield return Cast("r1a",()=>MageLight(),.12f,.28f,.45f);
   yield return Cast("r1b",()=>MageLight(),.14f,.3f,.48f);
   yield return Cast("r1c",()=>MageLight(),.3f,.45f,.7f);
   yield return new WaitForSeconds(.8f);comboExpires=0;combo=0;
   yield return Cast("r2",()=>MageHeavy(),.22f,.36f,.6f);
   yield return new WaitForSeconds(.8f);comboExpires=0;combo=0;
   yield return Cast("comet1",()=>MageLight(),.1f);
   yield return Cast("comet2",()=>MageLight(),.1f);
   yield return Cast("comet",()=>MageHeavy(),.3f,.55f,.7f,.95f);
   Debug.Log("BLOODWAKE_SPELL_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#else
   Application.Quit(0);
#endif
  }
  void SaveView(string path)
  {
   var target=new RenderTexture(1600,900,24);target.Create();var old=Cam.targetTexture;Cam.targetTexture=target;Cam.Render();
   var active=RenderTexture.active;RenderTexture.active=target;var texture=new Texture2D(1600,900,TextureFormat.RGB24,false);texture.ReadPixels(new Rect(0,0,1600,900),0,0);texture.Apply();
   System.IO.File.WriteAllBytes(path,texture.EncodeToPNG());
   RenderTexture.active=active;Cam.targetTexture=old;target.Release();Destroy(texture);
  }
  // Driven from its own object: StartRun and EnterRoom stop every coroutine on the game.
  public IEnumerator LookDev()
  {
   yield return new WaitForSeconds(.5f);
   StartRun("mage");EnterRoom(Run.Plan[0]);spawnTimer=999;
   var at=Player.transform.position;var forward=Vector3.back;  // toward the open square, away from the entry gate
   var vesper=ActorView.Create("vesper",false,2.05f*CombatActorScale,actorRoot);
   var right=Vector3.Cross(Vector3.up,forward);
   var spots=new[]{at+forward*5f+right*1.8f,at+forward*6.2f-right*1.6f,at+forward*7.4f+right*.2f};
   SpawnEnemy("grunt",spots[0]);SpawnEnemy("mage",spots[1]);SpawnEnemy("archer",spots[2]);
   yield return new WaitForSeconds(2.5f);  // enemies risen from the ground, everyone in idle
   // They have walked meanwhile: put everyone back where the shot wants them.
   Player.transform.position=at;vesper.transform.position=at-right*1.7f+forward*.3f;
   for(int i=0;i<Enemies.Count&&i<spots.Length;i++){var e=Enemies[i];if(e.Agent)e.Agent.enabled=false;e.View.transform.position=spots[i];e.View.transform.rotation=Quaternion.LookRotation(at-spots[i]);}
   // Weapon trails would draw a streak from every placement and turn: they stay off, and each shot waits out
   // the blade ribbon's 0.2 s sweep history.
   void Face(Vector3 dir){Player.transform.rotation=vesper.transform.rotation=Quaternion.LookRotation(dir);foreach(var t in FindObjectsByType<TrailRenderer>(FindObjectsSortMode.None)){t.Clear();t.enabled=false;}}
   Screen="lookdev";  // the game loop stands still: nothing moves, the camera is ours
   var lighting=GetComponent<GameplayLighting>();var volume=GetComponent<Volume>();
   Light Lamp(string name)=>lighting.GetComponentsInChildren<Light>(true).FirstOrDefault(l=>l.name==name);
   var fill=Lamp("Actor soft fill");var rim=Lamp("Actor rim");float fillI=fill.intensity,rimI=rim.intensity;
   var profile=volume.sharedProfile;profile.TryGet(out ColorAdjustments grade);profile.TryGet(out SplitToning split);
   float contrast=grade.contrast.value,saturation=grade.saturation.value;
   // Soft actor-only lights for variant B: a broad front light from the camera side and a gentle back light.
   Light ActorLight(string name,Vector3 dir,Color color,float intensity){var l=new GameObject(name).AddComponent<Light>();l.type=LightType.Directional;l.transform.rotation=Quaternion.LookRotation(dir);l.color=color;l.intensity=intensity;l.shadows=LightShadows.None;l.GetUniversalAdditionalLightData().renderingLayers=2u;l.enabled=false;return l;}
   var soft=new[]{ActorLight("LookDev front",new Vector3(.6f,-.55f,-.8f),new Color(1,.97f,.94f),1.1f),ActorLight("LookDev back",new Vector3(-.3f,-.4f,.9f),new Color(.75f,.82f,1),.6f)};
   foreach(var (name,setup) in new (string,System.Action)[]{
    ("A-simdiki",()=>{}),
    ("B-yumusak",()=>{rim.intensity=1.2f;fill.intensity=1f;foreach(var l in soft)l.enabled=true;grade.contrast.value=6;grade.saturation.value=4;if(split)split.active=false;}),
    ("C-ham",()=>{fill.enabled=rim.enabled=false;volume.enabled=false;}),
    // D: C's honest materials, with the atmosphere coming from a gentle grade and vignette rather than a crushed one.
    ("D-dogal-atmosfer",()=>{fill.enabled=rim.enabled=false;grade.contrast.value=4;grade.saturation.value=0;if(split)split.active=false;}),
    // E: D plus a faint actor light, just enough to lift faces off the ground.
    ("E-dogal-hafif-isik",()=>{fill.intensity=.6f;rim.intensity=1f;grade.contrast.value=4;grade.saturation.value=0;if(split)split.active=false;})})
   {
    setup();
    // Isometric: turned three-quarters toward the camera so faces read. Third person: facing the enemies.
    var toCamera=Vector3.ProjectOnPlane(cameraOffset,Vector3.up).normalized;
    Face(Vector3.Slerp(forward,toCamera,.75f));yield return new WaitForSecondsRealtime(.4f);yield return Shoot(name+"-izometrik",false,at-right*.6f+forward*1.6f);
    Face(forward);yield return new WaitForSecondsRealtime(.4f);yield return Shoot(name+"-tps",true,at);
    fill.enabled=rim.enabled=true;fill.intensity=fillI;rim.intensity=rimI;foreach(var l in soft)l.enabled=false;
    volume.enabled=true;grade.contrast.value=contrast;grade.saturation.value=saturation;if(split)split.active=true;
   }
   Debug.Log("BLOODWAKE_LOOKDEV_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#else
   Application.Quit(0);
#endif
  }
  IEnumerator Shoot(string name,bool thirdPerson,Vector3 at)
  {
   yield return null;  // batch-mode players never reach end of frame; the shot renders by hand anyway
   bool ortho=Cam.orthographic;float size=Cam.orthographicSize,fov=Cam.fieldOfView;
   if(thirdPerson)
   {
    // Behind and above her right shoulder, looking down the room past the enemies.
    var ahead=Player.transform.forward;Cam.orthographic=false;Cam.fieldOfView=50;
    Cam.transform.position=at-ahead*3.4f+Vector3.up*2.4f+Player.transform.right*.9f;
    Cam.transform.LookAt(at+ahead*6f+Vector3.up*1.2f);
   }
   else{Cam.orthographic=true;Cam.orthographicSize=DefaultZoom;Cam.transform.position=at+cameraOffset;Cam.transform.rotation=Quaternion.LookRotation(-cameraOffset,Vector3.up);}
   var target=new RenderTexture(1600,900,24);target.Create();var old=Cam.targetTexture;Cam.targetTexture=target;Cam.aspect=1600f/900;
   Cam.Render();
   var active=RenderTexture.active;RenderTexture.active=target;var texture=new Texture2D(1600,900,TextureFormat.RGB24,false);texture.ReadPixels(new Rect(0,0,1600,900),0,0);texture.Apply();
   System.IO.File.WriteAllBytes("/tmp/bloodwake-lookdev-"+name+".png",texture.EncodeToPNG());
   RenderTexture.active=active;Cam.targetTexture=old;target.Release();Destroy(texture);
   Cam.orthographic=ortho;Cam.orthographicSize=size;Cam.fieldOfView=fov;Cam.ResetAspect();
   Debug.Log("BLOODWAKE_LOOKDEV "+name);
  }
 }
 public sealed class LookDevDriver:MonoBehaviour
 {
  public void Begin(BloodwakeGame game){StartCoroutine(game.LookDev());}
  public void BeginGlide(BloodwakeGame game){StartCoroutine(game.GlideCapture());}
  public void BeginSpells(BloodwakeGame game){StartCoroutine(game.SpellCapture());}
  public void BeginKeepTour(BloodwakeGame game,int night=2){StartCoroutine(game.KeepTour(night));}
 }
}
