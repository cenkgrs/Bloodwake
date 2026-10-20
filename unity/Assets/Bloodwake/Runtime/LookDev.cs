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
   yield return new WaitForSeconds(.5f);
   StartRun("mage");EnterRoom(Run.Plan[0]);spawnTimer=999;yield return new WaitForSeconds(1.2f);
   // Toward the middle of the room (open floor), seen at the game's own default zoom.
   var dir=Vector3.ProjectOnPlane(-Player.transform.position,Vector3.up);if(dir.sqrMagnitude<1)dir=Quaternion.Euler(0,-70,0)*Vector3.ProjectOnPlane(-cameraOffset,Vector3.up);dir.Normalize();
   Cam.orthographicSize=DefaultZoom;
   // Arrival and room intros hold the player for a moment: keep trying until the glide is allowed.
   float giveUp=Time.time+8;while(!TryMageGlide(dir)){if(Time.time>giveUp){Debug.Log("BLOODWAKE_GLIDE could not start: screen="+Screen);yield break;}yield return null;}
   float t0=Time.time;
   foreach(float at in new[]{.04f,.15f,.3f,.45f,.62f,.8f})
   {
    while(Time.time-t0<at)yield return null;
    yield return new WaitForEndOfFrame();
    var names=FindObjectsByType<Transform>(FindObjectsSortMode.None).Select(x=>x.name).Where(n=>n.StartsWith("Glide")).GroupBy(n=>n).Select(g=>g.Key+" x"+g.Count());
    Debug.Log("BLOODWAKE_GLIDE t="+at+" state="+Player.Animator.GetCurrentAnimatorClipInfo(0).FirstOrDefault().clip?.name+" y="+Player.transform.position.y.ToString("0.00")+" fx: "+string.Join(", ",names));
    var target=new RenderTexture(1600,900,24);target.Create();var old=Cam.targetTexture;Cam.targetTexture=target;Cam.Render();
    var active=RenderTexture.active;RenderTexture.active=target;var texture=new Texture2D(1600,900,TextureFormat.RGB24,false);texture.ReadPixels(new Rect(0,0,1600,900),0,0);texture.Apply();
    System.IO.File.WriteAllBytes("/tmp/bloodwake-glide-"+Mathf.RoundToInt(at*1000).ToString("000")+".png",texture.EncodeToPNG());
    RenderTexture.active=active;Cam.targetTexture=old;target.Release();Destroy(texture);
   }
   Debug.Log("BLOODWAKE_GLIDE_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#endif
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
   yield return new WaitForEndOfFrame();
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
 }
}
