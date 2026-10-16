using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
namespace Bloodwake.Editor
{
 // Can run in an isolated batch editor, or via the menu in the practice scene.
 public static class EnemyEmergenceReview
 {
  const string Key="Bloodwake.EnemyEmergenceReview",Output="/tmp/bloodwake-enemy-emergence-soft";
  static BloodwakeGame game;static Enemy enemy;static int frame;static Vector3 spawn;
  static bool batch;static float hp;static double deadline;
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static void Set(string name,object value)=>typeof(BloodwakeGame).GetField(name,Flags).SetValue(game,value);
  static void Check(bool ok,string message){if(!ok)throw new Exception("EMERGENCE_FAILED: "+message);}
  public static void RunBatch(){Begin(true);}
  [MenuItem("Bloodwake/Tests/Enemy emergence review")]
  public static void RunMenu(){Begin(false);}
  static void Begin(bool isBatch)
  {
   SessionState.SetBool(Key,true);SessionState.SetBool(Key+".batch",isBatch);
   if(!EditorApplication.isPlaying){EditorSceneManager.OpenScene("Assets/Bloodwake/Scenes/GateyardCombatPractice.unity");EditorApplication.isPlaying=true;}
  }
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(!EditorApplication.isCompiling&&!EditorApplication.isUpdating&&File.Exists("Library/EnemyEmergenceReview.request"))
   {File.Delete("Library/EnemyEmergenceReview.request");Begin(false);}
   if(!SessionState.GetBool(Key,false)||EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   if(!EditorApplication.isPlaying)return;
   try
   {
    if(!game)
    {
     game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();
     if(!game||game.Screen!="playing"||game.Enemies.Count==0){game=null;return;}
     batch=SessionState.GetBool(Key+".batch",false);Directory.CreateDirectory(Output);
     deadline=EditorApplication.timeSinceStartup+90;frame=0;game.enabled=false;
     Set("combatPractice",false);Set("hitStop",0f);Set("waves",null);
     enemy=game.Enemies[0];enemy.View.BeginEmergence();spawn=enemy.View.transform.position;hp=enemy.Hp;
     game.Player.transform.position=spawn+new Vector3(3,0,2);
     foreach(var e in game.Enemies)e.View.Animator.enabled=false;
     var shader=Resources.Load<Shader>("Vfx/spawn_rift");Check(shader,"Rift shader asset missing");
     Check(!ShaderUtil.GetShaderMessages(shader).Any(m=>m.severity==UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error),"Rift shader compile error");
     Check(enemy.Emerging&&!enemy.View.Visible&&enemy.View.VisualSpawnOffset< -enemy.View.Height,"Body must start below ground and hidden");
     Check(UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(f=>f.name=="Enemy spawn rift"),"SpawnEnemy failed to create rift");
     game.Screen="pause";Check(game.VfxDelta==0,"Pause must freeze effect clock");game.Screen="playing";
     Set("hitStop",.05f);Check(game.VfxDelta==0,"Hit stop must freeze effect clock");Set("hitStop",0f);
     foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None)){fx.enabled=false;fx.Age=0;}
     Debug.Log("EMERGENCE_REVIEW_STARTED");
    }
    if(EditorApplication.timeSinceStartup>deadline)throw new Exception("Emergence review timed out");
    const float dt=1f/60;
    if(frame<75)
    {
     Call("DamageEnemy",enemy,10f,true);Call("StartAreaRecoil",enemy,game.Player.transform.position,2.5f);
     Check(enemy.Hp==hp&&enemy.RecoilTime==0&&enemy.Stagger==0,"Rising body received damage/recoil/stagger");
    }
    Call("TickEnemies",dt);
    if(frame<74)
    {
     Check(enemy.View.transform.position==spawn&&enemy.AttackCount==0,"Body moved or attacked before emergence finished");
     if(frame<20)Check(!enemy.View.Visible,"Body appeared before warning delay");
     if(frame==30)Check(enemy.View.Visible&&enemy.View.VisualSpawnOffset<-.1f,"Body did not rise from below street");
     if(enemy.Agent)Check(enemy.Agent.isOnNavMesh&&enemy.Agent.isStopped,"Ground agent lost its surface or moved during rise");
    }
    if(frame==76)
    {
     Check(!enemy.Emerging&&enemy.View.Visible&&enemy.View.VisualSpawnOffset==0,"Body failed to settle exactly at ground level");
     Call("DamageEnemy",enemy,1f,false);Check(enemy.Hp==hp-1,"Body remains invulnerable after rise");
    }
    foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))
    {
     fx.enabled=false;fx.Age+=dt;float p=Mathf.Clamp01(fx.Age/fx.Duration);
     fx.Block.SetFloat("_Progress",p);fx.Block.SetFloat("_Clock",fx.Age);fx.Tick?.Invoke(p,dt);fx.Apply();
     if(fx.Age>=fx.Duration)UnityEngine.Object.DestroyImmediate(fx.gameObject);
    }
    foreach(var e in game.Enemies)e.View.Animator.Update(dt);
    if(new[]{8,29,44,71,140}.Contains(frame)&&SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Null)Capture(frame);
    frame++;
    if(frame<145)return;
    Check(!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(f=>f.name.StartsWith("Enemy spawn")),"Spawn effects leaked beyond their lifetime");
    foreach(float fps in new[]{30,60,144,360})
    {
     enemy.View.BeginEmergence();float age=0,previous=enemy.View.VisualSpawnOffset;
     while(enemy.Emerging){enemy.View.TickEmergence(1/fps);age+=1/fps;Check(enemy.View.VisualSpawnOffset>=previous-.00001f,"Rise not monotonic");previous=enemy.View.VisualSpawnOffset;Check(age<1.35f,"Rise stuck");}
     Check(Mathf.Abs(age-1.25f)<=1/fps+.0001f&&previous==0,"Rise duration/ground offset differs with frame rate");
    }
    CheckSpaceTrim();
    File.WriteAllText(Output+"/result.txt","PASS: soft-rift-shader/delay/rise/root-stability/navigation/no-early-AI/damage/recoil/cleanup/pause-clock/30-60-144-360fps/Space-15%-trim-marker-audio\n");
    Debug.Log("EMERGENCE_REVIEW_PASSED "+Output);Finish(0);
   }
   catch(Exception e){Debug.LogException(e);File.WriteAllText(Output+"/failure.txt",e.ToString());Finish(1);}
  }
  static void CheckSpaceTrim()
  {
   var actor=game.Player;bool wasEnabled=actor.Animator.enabled;actor.Animator.enabled=false;
   try
   {
    actor.Play("Idle",0);actor.Animator.Update(.2f);Set("hitStop",0f);actor.Locked=0;game.Run.Cooldowns.Clear();
    float offset=actor.ActionStartTime("Ultimate"),length=actor.ClipLength("Ultimate");
    Check(Mathf.Abs(offset-length*.15f)<.0001f&&Mathf.Abs(offset-.185f)<.002f,"Space skip is not exactly 15% of source clip");
    float damageAt=actor.MarkerTime("Ultimate","ULT_DAMAGE");
    Check(Mathf.Abs(damageAt-(50f/60-offset))<.002f&&actor.MarkerTime("Ultimate","ULT_TELEGRAPH_START")==0,"Space event times not rebased");
    Call("Cast",2);Check(Mathf.Abs(actor.Locked-length*.85f)<.002f,"Space action lock still includes removed preparation");
    var audio=game.GetComponents<AudioSource>().FirstOrDefault(a=>a.isPlaying&&a.clip&&a.clip.name=="revenant_space_blood_burst");
    Check(audio&&Mathf.Abs(audio.time-offset)<.05f&&Mathf.Abs(audio.pitch-1)<.001f,"Space audio did not skip the same lead-in at original pitch");
    int hits=0;float firedAt=-1,elapsed=0;actor.OnMarker("ULT_DAMAGE",()=>{hits++;firedAt=elapsed;});
    for(int i=0;i<100;i++){elapsed=(i+1)/120f;actor.Tick(1f/120,false);actor.Animator.Update(1f/120);if(elapsed<damageAt-.035f)Check(hits==0,"Space contact fired before hand-opening pose");}
    Check(hits==1&&Mathf.Abs(firedAt-damageAt)<.04f,"Actual animation event no longer matches shortened Space contact");
    audio.Stop();Debug.Log($"SPACE_TRIM_PASSED skip={offset:F4}s contact={firedAt:F4}s lock={length*.85f:F4}s audio-pitch=1");
   }
   finally{actor.Animator.enabled=wasEnabled;}
  }
  static void Capture(int index)
  {
   var old=game.Cam.targetTexture;var active=RenderTexture.active;var rt=new RenderTexture(1280,960,24);
   var image=new Texture2D(1280,960,TextureFormat.RGB24,false);
   try{game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,960),0,0);image.Apply();File.WriteAllBytes(Output+"/spawn-"+index.ToString("D3")+".png",image.EncodeToPNG());}
   finally{game.Cam.targetTexture=old;RenderTexture.active=active;UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(image);}
  }
  static void Finish(int code)
  {
   SessionState.SetBool(Key,false);
   if(game){Set("combatPractice",true);Call("Start");game.enabled=true;}
   game=null;if(batch)EditorApplication.Exit(code);
  }
 }
}
