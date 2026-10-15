using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 // Exercises the production AI, marker relay and damage guard in the practice scene.
 public static class WarriorAttackReview
 {
  const string Request="Library/WarriorAttackReview.request";
  static BloodwakeGame game;static Enemy enemy;static string output;static int frame;static double next;
  static Vector3 playerPosition,enemyPosition,cameraPosition;static Quaternion playerRotation,enemyRotation,cameraRotation;
  static float cameraSize;static RenderTexture rt;static Texture2D image;
  static readonly List<string> rows=new();
  static readonly BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static FieldInfo Field(string name)=>typeof(BloodwakeGame).GetField(name,Flags);
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Update;}
  static void Check(bool ok,string message){if(!ok)throw new Exception(message);}
  static void Reset()
  {
   enemy.View.transform.SetPositionAndRotation(Vector3.zero,Quaternion.identity);
   game.Player.transform.position=Vector3.forward*1.2f;
   enemy.Stagger=enemy.RecoilTime=enemy.AreaRecovery=enemy.Slow=enemy.Aura=enemy.View.Locked=0;
   enemy.Turning=false;enemy.Casting=false;enemy.Cooldown=0;enemy.View.Play("Idle",0);enemy.View.Animator.Update(.15f);
   Field("invulnerable").SetValue(game,0f);
  }
  static void Tests()
  {
   Check(enemy.View.HasWarriorSlashes,"New Warrior slashes missing");
   bool practice=(bool)Field("combatPractice").GetValue(game);
   var savedStats=(Newtonsoft.Json.Linq.JObject)game.Run.Stats.DeepClone();
   try
   {
    Field("combatPractice").SetValue(game,false);
    game.Run.Stats["dodgeChance"]=0;game.Run.Stats["hp"]=100000;
    foreach(int fps in new[]{30,60,144})
    {
     enemy.Pattern=0;
     for(int index=0;index<4;index++)
     {
      Reset();string expected=index%2==0?"Warrior_OutwardSlash":"Warrior_InwardSlash";
      float before=game.Run.Stats.N("hp");Call("TickEnemies",1f/fps);
      Check(Mathf.Abs(enemy.View.PlaybackRate-1)<.0001f,"Slash was time-compressed");
      Check(Mathf.Abs(enemy.View.Locked-enemy.View.ClipLength(expected))<.001f,"Wrong lock length");
      int hits=0;float last=before,contact=-1;
      for(int tick=1;tick<=Mathf.CeilToInt(enemy.View.ClipLength(expected)*fps)+1;tick++)
      {
       enemy.Cooldown=999;enemy.View.Animator.Update(1f/fps);
       if(tick==Mathf.CeilToInt(fps*.15f))Check(enemy.View.Animator.GetCurrentAnimatorClipInfo(0).First().clip.name==expected,"Wrong slash order");
       float hp=game.Run.Stats.N("hp");if(hp<last){hits++;contact=tick/(float)fps;}last=hp;
       Call("TickEnemies",1f/fps);
      }
      Check(hits==1,"Expected exactly one slash contact, got "+hits);
      Check(Mathf.Abs(contact-enemy.View.MarkerTime(expected,"DAMAGE"))<2f/fps+.01f,"Contact not synchronized");
      Debug.Log($"WARRIOR_ATTACK_SEQUENCE_PASSED fps={fps} index={index} clip={expected} rate=1 contact={contact:F4}");
     }
    }
    foreach(string guard in new[]{"interrupted","out_of_range","behind","death"})
    {
     Reset();enemy.Pattern=0;Call("TickEnemies",1f/60);float hp=game.Run.Stats.N("hp"),enemyHp=enemy.Hp;
     if(guard=="interrupted"){enemy.ImpactVersion++;enemy.View.Play("Hit",.5f);}
     if(guard=="out_of_range")game.Player.transform.position=Vector3.forward*5;
     if(guard=="behind")game.Player.transform.position=Vector3.back;
     if(guard=="death")enemy.Hp=0;
     for(int i=0;i<70;i++)enemy.View.Animator.Update(1f/60);
     Check(game.Run.Stats.N("hp")==hp,"Invalid slash damage: "+guard);enemy.Hp=enemyHp;
     Debug.Log("WARRIOR_ATTACK_GUARD_PASSED "+guard);
    }
   }
   finally
   {
    game.Run.Stats.RemoveAll();foreach(var property in savedStats.Properties())game.Run.Stats[property.Name]=property.Value.DeepClone();
    Field("combatPractice").SetValue(game,practice);Field("invulnerable").SetValue(game,0f);Reset();enemy.Pattern=0;
   }
  }
  static void TurnTests()
  {
   Check(enemy.View.TurnData!=null,"Turn track missing");
   var bones=enemy.View.Animator.GetComponentsInChildren<Transform>();
   var left=bones.Single(t=>t.name.EndsWith("LeftUpLeg"));var right=bones.Single(t=>t.name.EndsWith("RightUpLeg"));
   foreach(int fps in new[]{30,60,144,240,360})
   {
    Reset();enemy.Cooldown=999;game.Player.transform.position=Vector3.back*5;int pattern=enemy.Pattern;
    Call("UpdateNavigation",1f);Call("TickEnemies",1f/fps);
    Check(enemy.Turning,"Behind-target did not start turn");
    Check(Quaternion.Angle(enemy.View.transform.rotation,Quaternion.identity)<1,"Turn snapped at entry");
    float lastYaw=0,totalYaw=0,maxStep=0;
    for(int i=0;i<Mathf.CeilToInt(fps*1.2f)&&enemy.Turning;i++)
    {
     Call("TickEnemies",1f/fps);enemy.View.Animator.Update(1f/fps);
     float yaw=enemy.View.transform.eulerAngles.y,step=Mathf.DeltaAngle(lastYaw,yaw);lastYaw=yaw;totalYaw+=step;maxStep=Mathf.Max(maxStep,Mathf.Abs(step));
     Check(enemy.Pattern==pattern&&!enemy.View.ContactPending,"Attacked while turning");
     if(i>fps*.15f)
     {
      var bodyForward=Vector3.Cross(right.position-left.position,Vector3.up);bodyForward.y=0;
      // Idle has a sideways fighting stance; only demand neutral pelvis yaw while
      // the turn is active, not while blending back to that authored idle pose.
      float allowed=enemy.Turning?5:35;
      Check(Vector3.Angle(bodyForward,enemy.View.transform.forward)<allowed,$"Skeleton facing mismatch fps={fps} tick={i} turning={enemy.Turning} angle={Vector3.Angle(bodyForward,enemy.View.transform.forward):F2}");
     }
    }
    Check(!enemy.Turning&&Mathf.Abs(Mathf.Abs(totalYaw)-180)<1,"Turn did not finish at 180 degrees");
    Check(maxStep<30,"Turn snapped between frames");
    Check(Vector3.Dot(enemy.View.transform.forward,(game.Player.transform.position-enemy.View.transform.position).normalized)>.97f,"Turn ended facing away");
    var before=enemy.View.transform.position;Call("UpdateNavigation",1f);Call("TickEnemies",1f/fps);
    var moved=enemy.View.transform.position-before;
    Check(moved.sqrMagnitude>1e-8f&&Vector3.Dot(moved.normalized,enemy.View.transform.forward)>.99f,"Walk after turn slides backwards");
    Debug.Log($"WARRIOR_TURN_PASSED fps={fps} totalYaw={totalYaw:F2} maxStep={maxStep:F2}");
   }
   // Side/front targets must keep ordinary walking; no unnecessary 180-degree clip.
   Reset();enemy.Cooldown=999;game.Player.transform.position=Vector3.right*5;Call("UpdateNavigation",1f);Call("TickEnemies",1f/60);
   Check(!enemy.Turning,"Turn wrongly triggered for 90-degree target");
   Reset();enemy.Cooldown=999;game.Player.transform.position=Vector3.back*5;Call("UpdateNavigation",1f);Call("TickEnemies",1f/60);
   for(int i=0;i<15;i++){Call("TickEnemies",1f/60);enemy.View.Animator.Update(1f/60);}
   var interruptedHeading=enemy.View.transform.rotation;enemy.Stagger=.5f;enemy.View.Play("Hit",.5f);Call("TickEnemies",1f/60);
   Check(!enemy.Turning&&Quaternion.Angle(interruptedHeading,enemy.View.transform.rotation)<.1f,"Interrupted turn snapped back");
   Debug.Log("WARRIOR_TURN_GUARDS_PASSED side-target and interruption");Reset();enemy.Pattern=0;
  }
  static void SteeringTests()
  {
   foreach(int fps in new[]{30,60,144,360})
   {
    foreach(float angle in new[]{15f,45,90,120,149,150,151,179,-15,-45,-90,-120,-149,-150,-151,-179})
    {
     Reset();enemy.Cooldown=999;
     game.Player.transform.position=Quaternion.Euler(0,angle,0)*Vector3.forward*1.2f;
     for(int tick=0;tick<fps*2;tick++)
     {
      var rotation=enemy.View.transform.rotation;var position=enemy.View.transform.position;bool wasTurning=enemy.Turning;
      Call("UpdateNavigation",1f/fps);Call("TickEnemies",1f/fps);enemy.View.Animator.Update(1f/fps);
      float step=Quaternion.Angle(rotation,enemy.View.transform.rotation);
      Check(step<=(wasTurning||enemy.Turning?500:240)/(float)fps+.1f,$"Instant yaw jump angle={angle} fps={fps} step={step}");
      var moved=enemy.View.transform.position-position;
      if(!wasTurning&&!enemy.Turning&&moved.sqrMagnitude>.000001f)
       Check(Vector3.Angle(moved,enemy.View.transform.forward)<25.1f,"Sideways movement during steering");
     }
     Check(Vector3.Angle(enemy.View.transform.forward,game.Player.transform.position-enemy.View.transform.position)<13,"Steering failed to align "+angle);
    }
    // Attack entry must use the same bounded facing path, not LookRotation.
    Reset();enemy.Pattern=0;game.Player.transform.position=Vector3.right*1.2f;
    Call("TickEnemies",1f/fps);Check(enemy.Pattern==0,"Attacked before facing the target");
    for(int tick=0;tick<fps&&enemy.Pattern==0;tick++)
    {
     var previous=enemy.View.transform.rotation;Call("TickEnemies",1f/fps);enemy.View.Animator.Update(1f/fps);
     Check(Quaternion.Angle(previous,enemy.View.transform.rotation)<=240f/fps+.1f,"Attack entry snapped facing");
    }
    Check(enemy.Pattern==1,"Aligned Warrior did not attack");
    Debug.Log("WARRIOR_ANGLE_SWEEP_PASSED fps="+fps+" signedAngles=16 plus attack-entry");
   }
   // Target changes sides during a committed turn: leftover yaw must not snap.
   Reset();enemy.Cooldown=999;game.Player.transform.position=Vector3.back*5;Call("UpdateNavigation",1f);Call("TickEnemies",1f/60);
   for(int tick=0;tick<130;tick++)
   {
    if(tick==25)game.Player.transform.position=Vector3.right*3;
    var previous=enemy.View.transform.rotation;bool turning=enemy.Turning;
    Call("UpdateNavigation",1f/60);Call("TickEnemies",1f/60);enemy.View.Animator.Update(1f/60);
    Check(Quaternion.Angle(previous,enemy.View.transform.rotation)<=(turning||enemy.Turning?500:240)/60f+.1f,"Retarget after turn snapped facing");
   }
   Debug.Log("WARRIOR_MOVING_TARGET_TURN_PASSED");Reset();enemy.Pattern=0;
  }
  static void Update()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating)return;
   if(!game)
   {
    if(!File.Exists(Request)||!EditorApplication.isPlaying)return;
    game=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();
    if(!game||game.Screen!="playing"||game.Enemies.Count!=1){game=null;return;}
    output=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(output);
    enemy=game.Enemies[0];playerPosition=game.Player.transform.position;playerRotation=game.Player.transform.rotation;
    enemyPosition=enemy.View.transform.position;enemyRotation=enemy.View.transform.rotation;
    cameraPosition=game.Cam.transform.position;cameraRotation=game.Cam.transform.rotation;cameraSize=game.Cam.orthographicSize;
    game.enabled=false;game.Player.Animator.enabled=false;enemy.View.Animator.enabled=false;
    try{Tests();TurnTests();SteeringTests();}catch(Exception ex){Debug.LogException(ex);Finish(false);return;}
    game.Player.transform.position=Vector3.forward*1.2f;game.Player.transform.rotation=Quaternion.Euler(0,180,0);
    game.Player.Play("Idle",0);game.Player.Animator.Update(.2f);
    rt=new RenderTexture(1280,720,24);image=new Texture2D(1280,720,TextureFormat.RGB24,false);
    frame=0;next=0;rows.Clear();rows.Add("frame,clip,normalized_time,rate,contact_pending,turning,root_yaw");
   }
   if(EditorApplication.timeSinceStartup<next)return;next=EditorApplication.timeSinceStartup+1.0/30;
   try
   {
    if(frame==90)game.Player.transform.position=enemy.View.transform.position+Quaternion.Euler(0,120,0)*enemy.View.transform.forward*3;
    if(frame==180)game.Player.transform.position=enemy.View.transform.position-enemy.View.transform.forward*5;
    if(frame==195)game.Player.transform.position=enemy.View.transform.position+Vector3.right*3;
    if(frame==270)game.Player.transform.position=enemy.View.transform.position+Quaternion.Euler(0,-90,0)*enemy.View.transform.forward*1.2f;
    for(int i=0;i<2;i++){Call("UpdateNavigation",1f/60);Call("TickEnemies",1f/60);enemy.View.Animator.Update(1f/60);game.Player.Animator.Update(1f/60);}
    game.Cam.transform.position=enemy.View.transform.position+new Vector3(5,4,6);game.Cam.transform.LookAt(enemy.View.transform.position+new Vector3(0,1,.5f));game.Cam.orthographicSize=3.4f;
    var info=enemy.View.Animator.GetCurrentAnimatorStateInfo(0);
    var active=enemy.View.Animator.GetCurrentAnimatorClipInfo(0).Concat(enemy.View.Animator.GetNextAnimatorClipInfo(0)).ToArray();
    string clip=active.Length>0?active.OrderByDescending(c=>c.weight).First().clip.name:"transition";
    rows.Add($"{frame},{clip},{info.normalizedTime:F4},{enemy.View.PlaybackRate:F4},{enemy.View.ContactPending},{enemy.Turning},{enemy.View.transform.eulerAngles.y:F3}");
    var oldTarget=game.Cam.targetTexture;var oldActive=RenderTexture.active;
    try
    {
     game.Cam.targetTexture=rt;game.Cam.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
     File.WriteAllBytes(Path.Combine(output,$"frame-{frame:D4}.jpg"),image.EncodeToJPG(90));
    }
    finally{game.Cam.targetTexture=oldTarget;RenderTexture.active=oldActive;}
    if(++frame>=360)Finish(true);
   }
   catch(Exception ex){Debug.LogException(ex);Finish(false);}
  }
  static void Finish(bool success)
  {
   File.WriteAllLines(Path.Combine(output,"attacks.csv"),rows);
   if(game)
   {
    enemy.Turning=false;enemy.View.Play("Idle",0);enemy.Pattern=0;enemy.Cooldown=.9f;
    game.Player.transform.SetPositionAndRotation(playerPosition,playerRotation);enemy.View.transform.SetPositionAndRotation(enemyPosition,enemyRotation);
    game.Cam.transform.SetPositionAndRotation(cameraPosition,cameraRotation);game.Cam.orthographicSize=cameraSize;
    game.Player.Animator.enabled=true;enemy.View.Animator.enabled=true;game.enabled=true;
   }
   if(rt){rt.Release();UnityEngine.Object.DestroyImmediate(rt);}if(image)UnityEngine.Object.DestroyImmediate(image);
   Debug.Log("WARRIOR_ATTACK_REVIEW_"+(success?"PASSED":"FAILED")+" "+output);game=null;
  }
 }
}
