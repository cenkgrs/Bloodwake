using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using Newtonsoft.Json.Linq;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 public static class RevenantDashReview
 {
  const string Output="/tmp/bloodwake-dash-review",Request="Library/RevenantDashReview.request";
  const BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static BloodwakeGame game;static Enemy enemy;
  static Dictionary<Transform,Vector3> originalScales;
  static Dictionary<Transform,float> originalLengths;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static void Set(string name,object value)=>typeof(BloodwakeGame).GetField(name,Flags).SetValue(game,value);
  static T Get<T>(string name)=>(T)typeof(BloodwakeGame).GetField(name,Flags).GetValue(game);
  static void Check(bool ok,string message){if(!ok)throw new Exception("DASH_REVIEW_FAILED: "+message);}
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Poll;}
  static void Poll()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying||!File.Exists(Request))return;
   game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||game.Screen!="playing"||game.Enemies.Count==0)return;
   File.Delete(Request);Run();
  }
  [MenuItem("Bloodwake/Tests/Revenant dash review")]
  public static void Run()
  {
   game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!game||!EditorApplication.isPlaying)return;
    Directory.CreateDirectory(Output);File.Delete(Output+"/failure.txt");File.Delete(Output+"/result.txt");game.enabled=false;
   try
   {
    Set("waves",null);Set("combatPractice",false);Set("practiceDashImpact",false);Set("hitStop",0f);
    game.Run.Stats["criticalChance"]=0;game.Run.Stats["revenantDashImpact"]=0;
    enemy=game.Enemies[0];enemy.View.TickEmergence(2);enemy.View.Animator.enabled=false;if(enemy.Agent)enemy.Agent.enabled=false;enemy.Hp=enemy.MaxHp=1000;
    game.Player.Animator.enabled=false;Get<List<Bounds>>("blockers").Clear();
    game.Player.Animator.Play(game.Player.Clip("Idle"),0,0);game.Player.Animator.Update(0);
    var baseline=game.Player.Animator.GetComponentsInChildren<Transform>();
    originalScales=baseline.ToDictionary(t=>t,t=>t.localScale);
    originalLengths=baseline.Where(t=>new[]{"RightForeArm","LeftForeArm","RightHand","LeftHand","RightLeg","LeftLeg","RightFoot","LeftFoot"}.Any(s=>t.name.EndsWith(s))).ToDictionary(t=>t,t=>Vector3.Distance(t.position,t.parent.position));
    ClearEffects();CheckProgression();
    var origin=new Vector3(0,0,2);var direction=Vector3.back;
    foreach(float fps in new[]{30,60,144,360})
    {
     Ready(origin);Check((bool)Call("TryRevenantDash",direction),"Dash refused");float elapsed=0;
     while(Get<bool>("revenantDashing")){Step(1/fps);elapsed+=1/fps;Check(game.Player.Visible,"Dash made hero invisible");Check(elapsed<.3f,"Dash stuck");}
     Check(Mathf.Abs(Vector3.Distance(origin,game.Player.transform.position)-3.2f)<.004f,"Dash distance differs at "+fps+" FPS");
     Check(Mathf.Abs(elapsed-.24f)<=1/fps+.001f,"Dash duration differs with FPS");
     Check(!(bool)Call("TryRevenantDash",direction),"Normal cooldown bypassed");
    }
    Ready(origin);enemy.View.transform.position=origin+direction*4.2f;float hp=enemy.Hp;
    Check((bool)Call("TryRevenantDash",direction),"Visual dash refused");
    for(int i=1;i<=12;i++){Step(.02f);if(i==3||i==7||i==11){CheckCloud();Capture("dash-"+i);}}
    Check(enemy.Hp==hp,"Locked talent dealt dash damage");
    Check(game.Player.HasRevenantThrust,"Authored Upward Thrust missing");
    Check(!game.RevenantActionActive&&!game.Player.RevenantPoseActive&&game.Player.PlaybackRate==1,"Dash failed to release pose");
    Step(.3f);Check(!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(f=>f.name=="Dash moving crimson cloud"),"Moving cloud did not dissipate");
    CheckDashPath(origin,direction);Capture("dash-path-054");Step(.95f);
    Check(!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(f=>f.name=="Dash blood ground trace"||f.name=="Dash shedding crimson mist"||f.name=="Dash suspended blood threads"),"Dash path residue leaked");
    float damage=(float)Call("RevenantBasicDamage");
    Ready(origin);enemy.View.transform.position=origin+direction*4.2f;hp=enemy.Hp;
    Call("TryRevenantDash",direction);Step(.24f);Check((bool)Call("BeginRevenantThrust"),"Authored follow-up refused");
    float contact=game.Player.MarkerTime("REV_ClawThrust","DAMAGE"),duration=game.Player.ClipLength("REV_ClawThrust");
    Check(Mathf.Abs(duration-64/60f)<.002f&&Mathf.Abs(contact-.3f)<.002f,"Readable forward arm stroke missing");
    Step(contact-.02f);Check(enemy.Hp==hp,"Thrust hit before contact");Capture("thrust-authored-windup");
    Step(.021f);Check(Mathf.Abs(enemy.Hp-(hp-damage))<.01f,"Thrust damage is not one basic hit");
    Check(Mathf.Abs(enemy.RecoilRemaining-.96f)<.001f&&Vector3.Dot(enemy.RecoilDirection,direction)>.99f,"Thrust is not double its previous push");
    Check(UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Count(f=>f.name=="Thrust straight claw impact")==4,"Thrust target claw marks missing");
    var cutShader=Resources.Load<Shader>("Vfx/claw_cut");
    Check(cutShader&&!ShaderUtil.GetShaderMessages(cutShader).Any(m=>m.severity==UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error),"Transparent claw shader failed");
    var bones=game.Player.Animator.GetComponentsInChildren<Transform>();
    var finger1=bones.First(t=>t.name.EndsWith("RightHandIndex1"));var finger2=bones.First(t=>t.name.EndsWith("RightHandIndex2"));var finger3=bones.First(t=>t.name.EndsWith("RightHandIndex3"));
    Check(game.Player.RevenantPoseActive,"Contact silhouette was dropped before it could render");CheckAuthoredPose(contact);Capture("thrust-authored-contact");
    var beforePush=enemy.View.transform.position;
    for(int n=0;n<18;n++){Call("TickRecoil",enemy,.02f);Step(.02f);if(n==2||n==5)Capture("thrust-impact-"+n);}
    Check(Vector3.Dot(enemy.View.transform.position-beforePush,direction)>.90f,"Thrust recoil did not physically move victim");
    Check(!game.RevenantActionActive&&Get<float>("attackCd")==0&&game.Player.Locked<=0,"Recovery lock survived contact hold: active="+game.RevenantActionActive+" cd="+Get<float>("attackCd")+" locked="+game.Player.Locked+" age="+Get<float>("revenantThrustAge"));
    Capture("thrust-authored-recovery");Step(duration);
    Check(!game.RevenantActionActive&&!game.Player.RevenantPoseActive&&game.Player.PlaybackRate==1,"Thrust did not release");
    Check(Mathf.Abs(enemy.Hp-(hp-damage))<.01f,"Thrust contacted twice");
    // Frame-by-frame dash → thrust → idle capture, including real skinned size.
    Ready(origin);enemy.View.transform.position=origin+Vector3.right*5;
    Call("TryRevenantDash",direction);Set("thrustQueued",true);
    for(int frame=0;frame<45;frame++)
    {Step(1/30f);if(frame>=34)game.Player.Animator.Update(1/30f);CheckSize();Capture("sequence-"+frame.ToString("D3"));}
    // Talent on; emerging immunity and landing only.
    Ready(origin);game.Run.Stats["revenantDashImpact"]=1;hp=enemy.Hp;enemy.View.transform.position=origin+direction*3.5f;
    Call("TryRevenantDash",direction);Step(.24f);Check(Mathf.Abs(enemy.Hp-(hp-damage*.65f))<.01f,"Unlocked landing damage absent");Capture("dash-talent");
    Ready(origin);enemy.View.BeginEmergence();hp=enemy.Hp;Call("TryRevenantDash",direction);Step(.24f);Check(enemy.Hp==hp,"Dash damaged emerging enemy");enemy.View.TickEmergence(2);
    game.Run.Stats["revenantDashImpact"]=0;
    // Buffered attack, paused state, hit-stop and wall collision.
    Ready(origin);Call("TryRevenantDash",direction);game.Screen="pause";Call("TickRevenantDash",.1f);Check(game.Player.transform.position==origin,"Pause advanced dash");game.Screen="playing";
    Set("hitStop",.1f);Call("TickRevenantDash",.1f);Check(game.Player.transform.position==origin,"Hit stop advanced dash");Set("hitStop",0f);
    Set("thrustQueued",true);Step(.24f);Check(Get<bool>("revenantThrusting"),"Buffered authored thrust lost at arrival");
    Ready(origin);var wall=new Bounds(origin+direction*1.5f,new Vector3(5,3,.25f));Get<List<Bounds>>("blockers").Add(wall);
    Call("TryRevenantDash",direction);Step(.24f);Check(Vector3.Distance(origin,game.Player.transform.position)<1.05f,"Dash tunneled through wall");Get<List<Bounds>>("blockers").Clear();
    Ready(origin);Call("TryRevenantDash",direction);Step(.24f);Step(.5f);Check(!(bool)Call("BeginRevenantThrust"),"Expired combo still usable");
    Ready(origin);string cls=game.Run.ClassId;game.Run.ClassId="warrior";Check(!(bool)Call("TryRevenantDash",direction),"Dash leaked to Warrior");game.Run.ClassId=cls;
    Call("TryRevenantDash",direction);game.Run.Stats["hp"]=0;Call("TickRevenantDash",.01f);Check(!game.RevenantActionActive&&!game.Player.RevenantPoseActive,"Death didn't cancel dash");game.Run.Stats["hp"]=game.Run.Stats["maxHp"].DeepClone();
    CheckGlass(origin,direction);
    File.WriteAllText(Output+"/result.txt","PASS: idle scales/limb lengths retained; .30s forward stroke + .07s visible contact pose, no recovery animation; contact matches authored pose; recoil .96m, physical movement >.90m; four transparent tapered target claw marks; one hit; 45-frame render; FPS/buffering/wall/pause/death/E regressions. This is mechanical verification, NOT aesthetic approval.\n");
    Debug.Log("REVENANT_DASH_REVIEW_PASSED "+Output);
   }
   catch(Exception e){File.WriteAllText(Output+"/failure.txt",e.ToString());Debug.LogException(e);}
   finally{Set("combatPractice",true);Call("Start");game.enabled=true;game=null;}
  }
  static void Ready(Vector3 origin){Call("ResetRevenantDash");Set("hitStop",0f);Set("dashCd",0f);Set("attackCd",0f);game.Player.Play("Idle",0);game.Player.Animator.Update(0);game.Player.transform.position=origin;game.Player.transform.rotation=Quaternion.LookRotation(Vector3.back);ClearEffects();}
  static void Step(float dt)
  {
   Set("hitStop",0f);Call("TickRevenantDash",dt);game.Player.Tick(dt,false);game.Player.ApplyRevenantPose();CheckSize();
   foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))
   {fx.enabled=false;fx.Age+=dt;float p=Mathf.Clamp01(fx.Age/fx.Duration);fx.Block.SetFloat("_Progress",p);fx.Block.SetFloat("_Clock",fx.Age);fx.Tick?.Invoke(p,dt);fx.Apply();if(fx.Age>=fx.Duration)UnityEngine.Object.DestroyImmediate(fx.gameObject);}
  }
  static void CheckSize()
  {
   foreach(var pair in originalScales)Check(Vector3.Distance(pair.Key.localScale,pair.Value)<.0001f,"Animation resizes "+pair.Key.name+": "+pair.Key.localScale+" vs idle "+pair.Value);
   foreach(var pair in originalLengths)Check(Mathf.Abs(Vector3.Distance(pair.Key.position,pair.Key.parent.position)/pair.Value-1)<.003f,"Animation changes limb length "+pair.Key.name);
  }
  static void CheckProgression()
  {
   var meta=new Progression();Check(meta.Import("{\"levels\":{\"revenant_crimson_arrival\":9}}"),"Save import failed");
   Check((int)meta.Data["levels"]["revenant_crimson_arrival"]==1,"Talent rank not clamped");
   Check(new RunState("revenant",meta).Stats.N("revenantDashImpact")==1,"Talent lost on new run");
   Check(new RunState("warrior",meta).Stats.N("revenantDashImpact")==0,"Revenant talent applied to Warrior");
   var empty=new Progression();Check(new RunState("revenant",empty).Stats.N("revenantDashImpact")==0,"New save auto-unlocks dash damage");
  }
  static void CheckCloud()
  {
   var shader=Resources.Load<Shader>("Vfx/dash_mist");Check(shader&&!ShaderUtil.GetShaderMessages(shader).Any(m=>m.severity==UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error),"Dash mist shader failed");
   var effects=UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None);
   var cloud=effects.Where(f=>f.name=="Dash moving crimson cloud").ToArray();Check(cloud.Length==8,"Missing attached body cloud");
   foreach(var f in cloud)
   {
    var delta=f.transform.position-game.Player.transform.position;delta.y=0;
    Check(delta.magnitude<.9f,"Body mist stayed behind the moving character");
    Check(f.transform.localScale.x>game.Player.Height*.7f,"Body mist is only a small ground stamp");
   }
   Check(effects.Count(f=>f.name=="Dash blood droplet")>=8,"Missing blood spray during travel");
  }
  static void CheckGlass(Vector3 origin,Vector3 direction)
  {
   Ready(origin);game.Player.Play("REV_BloodClap",1);
   game.Player.Animator.Play("REV_BloodClap",0,game.Player.MarkerTime("REV_BloodClap","CLAP_DAMAGE")/game.Player.ClipLength("REV_BloodClap"));game.Player.Animator.Update(0);
   var fx=(RevenantVfx)typeof(BloodwakeGame).GetProperty("RevFx",Flags).GetValue(game);fx.BloodBomb(game.Player.ClapPosition(),direction,4);
   var effects=UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None);
   Check(!effects.Any(f=>f.name=="Blood bomb glass shard"),"Rejected rigid shards still active");
   var volume=effects.Single(f=>f.name=="Blood bomb liquid pressure wave");
   Check(volume.GetComponent<MeshRenderer>().sharedMaterial.name=="Wet blood","E doesn't use Space liquid material");
   Check(effects.Count(f=>f.name=="Blood bomb droplet")==64,"Dense spray missing");
   Step(.08f);Capture("e-liquid-08");Step(.08f);Capture("e-liquid-16");
   var mesh=volume.GetComponent<MeshFilter>().sharedMesh;Check(mesh.vertexCount==43*21*8,"Missing liquid branches");
   Check(mesh.bounds.size.x>4.2f&&mesh.bounds.size.z>3.3f,"Liquid wave doesn't fill a broad forward area");
   foreach(var v in mesh.vertices)Check(v.z>=-.08f&&Mathf.Abs(v.x)<=v.z+.25f&&new Vector2(v.x,v.z).magnitude<4.15f,"Liquid volume escaped 90-degree attack envelope");
   Step(.16f);Capture("e-liquid-32");Step(.6f);
   Check(!UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None).Any(f=>f.name=="Blood bomb liquid pressure wave"||f.name=="Blood bomb droplet"),"E liquid lifetime leaked");
  }
  static void CheckDashPath(Vector3 origin,Vector3 direction)
  {
   var effects=UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None);
   var mist=effects.Where(f=>f.name=="Dash shedding crimson mist").ToArray();
   var marks=effects.Where(f=>f.name=="Dash blood ground trace").ToArray();
   Check(mist.Length>=14&&marks.Length>=7,"Full path mist/trace missing after arrival");
   foreach(float distance in new[]{0,.8f,1.6f,2.4f,3.1f})
   {
    var point=origin+direction*distance;
    Check(mist.Any(f=>{var d=f.transform.position-point;d.y=0;return d.magnitude<.6f;}),"Gap in persistent dash mist");
    Check(marks.Any(f=>Vector3.Distance(f.transform.position,point)<.5f),"Gap in dash ground trace");
   }
   Check(effects.Count(f=>f.name=="Dash suspended blood threads")>=7,"Missing characteristic blood threads");
   var shader=Resources.Load<Shader>("Vfx/dash_trace");Check(shader&&!ShaderUtil.GetShaderMessages(shader).Any(m=>m.severity==UnityEditor.Rendering.ShaderCompilerMessageSeverity.Error),"Ground trace shader failed");
  }
  static void CheckAuthoredPose(float time)
  {
   var reference=ActorView.Create("revenant",false,game.Player.Height,game.Player.transform.parent);
   try
   {
    reference.Animator.enabled=false;reference.transform.SetPositionAndRotation(game.Player.transform.position,game.Player.transform.rotation);
    var clip=game.Player.Animator.runtimeAnimatorController.animationClips.Single(c=>c.name=="REV_ClawThrust");clip.SampleAnimation(reference.Animator.gameObject,time);
    var expected=reference.Animator.GetComponentsInChildren<Transform>();var actual=game.Player.Animator.GetComponentsInChildren<Transform>();
    foreach(var suffix in new[]{"RightHand","RightForeArm","Spine2","RightFoot","LeftFoot"})
    {
     var a=actual.First(t=>t.name.EndsWith(suffix));var b=expected.First(t=>t.name.EndsWith(suffix));
     Check(Vector3.Distance(a.position,b.position)<.01f&&Quaternion.Angle(a.rotation,b.rotation)<1,"Runtime pose differs from authored FBX: "+suffix);
    }
   }
   finally{UnityEngine.Object.DestroyImmediate(reference.gameObject);}
  }
  static void ClearEffects(){foreach(var fx in UnityEngine.Object.FindObjectsByType<VfxLifetime>(FindObjectsSortMode.None))UnityEngine.Object.DestroyImmediate(fx.gameObject);}
  static void Capture(string name)
  {
   var old=game.Cam.targetTexture;var active=RenderTexture.active;var rt=new RenderTexture(1280,960,24);var image=new Texture2D(1280,960,TextureFormat.RGB24,false);
   try{game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,960),0,0);image.Apply();File.WriteAllBytes(Output+"/"+name+".png",image.EncodeToPNG());}
   finally{game.Cam.targetTexture=old;RenderTexture.active=active;UnityEngine.Object.DestroyImmediate(rt);UnityEngine.Object.DestroyImmediate(image);}
  }
 }
}
