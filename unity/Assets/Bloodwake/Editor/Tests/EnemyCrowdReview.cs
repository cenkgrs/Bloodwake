using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;
namespace Bloodwake.Editor
{
 // Real engine frames are required: NavMesh avoidance cannot be tested by ticking AI
 // hundreds of times inside a single editor update.
 public static class EnemyCrowdReview
 {
  const string Request="Library/EnemyCrowdReview.request";
  static BloodwakeGame game;static string output;static float age,minGap;static int lastFrame=-1,captures;
  static bool side,behind,engagementChecked;static Vector3 playerPosition;static Quaternion playerRotation;
  static readonly System.Collections.Generic.Dictionary<Enemy,float> lastContact=new();
  static readonly System.Collections.Generic.Dictionary<Enemy,int> contactCounts=new();
  static readonly System.Collections.Generic.Dictionary<Enemy,float> nearbyIdle=new();
  static readonly System.Collections.Generic.Dictionary<Enemy,int> finalPhaseContacts=new();
  static readonly System.Collections.Generic.List<string> rows=new();
  static readonly BindingFlags Flags=BindingFlags.Instance|BindingFlags.NonPublic;
  static object Call(string name,params object[] args)=>typeof(BloodwakeGame).GetMethod(name,Flags).Invoke(game,args);
  static void Set(string name,object value)=>typeof(BloodwakeGame).GetField(name,Flags).SetValue(game,value);
  static void Check(bool ok,string message){if(!ok)throw new Exception("CROWD_REVIEW: "+message);}
  [InitializeOnLoadMethod]static void Init(){EditorApplication.update+=Tick;}
  static void Tick()
  {
   if(EditorApplication.isCompiling||EditorApplication.isUpdating||!EditorApplication.isPlaying)return;
   try
   {
    if(!game)
    {
     if(!File.Exists(Request))return;
     var found=UnityEngine.Object.FindFirstObjectByType<BloodwakeGame>();if(!found||found.Screen!="playing"||found.Enemies.Count!=1)return;
     game=found;output=File.ReadAllText(Request).Trim();File.Delete(Request);Directory.CreateDirectory(output);
     playerPosition=game.Player.transform.position;playerRotation=game.Player.transform.rotation;game.enabled=false;
     age=0;minGap=999;side=behind=engagementChecked=false;captures=0;lastFrame=-1;lastContact.Clear();contactCounts.Clear();nearbyIdle.Clear();finalPhaseContacts.Clear();rows.Clear();
     rows.Add("time,id,intent,distance,attacks,contacts,turning,x,z,slot,desired_speed,stopped,yaw,stuck");SpawnTests();
     game.Player.transform.position=new Vector3(0,0,2);
     var first=game.Enemies[0];first.View.transform.position=new Vector3(0,0,-4);first.View.transform.rotation=Quaternion.identity;
     first.Turning=false;first.Casting=false;first.Stagger=first.RecoilTime=0;first.View.Play("Idle",0);
     game.SpawnEnemy("grunt",new Vector3(0,0,-4));game.SpawnEnemy("grunt",new Vector3(0,0,-4));
     if(output.EndsWith("-surround"))foreach(var e in game.Enemies)
     {
      object[] args={"grunt",Vector3.zero};Check((bool)Call("TrySurroundSpawn",args),"Live surround spawn failed");
      e.View.transform.position=(Vector3)args[1];e.View.transform.rotation=Quaternion.LookRotation(game.Player.transform.position-e.View.transform.position);
     }
     foreach(var e in game.Enemies){e.Hp=e.MaxHp;e.Cooldown=.9f;e.AttackCount=e.ContactCount=0;e.StepPending=false;e.StepTime=e.StuckTime=0;e.ApproachSlot=-1;lastContact[e]=0;contactCounts[e]=0;nearbyIdle[e]=0;Check(e.Agent&&e.Agent.isOnNavMesh,"Native agent missing");}
     FeedbackTests();Debug.Log("CROWD_REVIEW_STARTED three overlapping spawn requests / native avoidance / moving target");
    }
    if(Time.frameCount==lastFrame)return;lastFrame=Time.frameCount;
    float dt=Mathf.Min(Time.deltaTime,.05f);age+=dt;
    if(age>14&&!side){side=true;game.Player.transform.position=new Vector3(3,0,2);}
    if(age>24&&!behind){behind=true;game.Player.transform.position=new Vector3(-2,0,-3);foreach(var e in game.Enemies)finalPhaseContacts[e]=e.ContactCount;}
    Set("invulnerable",0f);Call("UpdateNavigation",dt);Call("TickEnemies",dt);Call("SyncEnemyAgents");
    game.Player.Tick(dt,false);Set("hitStop",0f);
    foreach(var e in game.Enemies)
    {
     if(e.ContactCount!=contactCounts[e]){contactCounts[e]=e.ContactCount;lastContact[e]=age;nearbyIdle[e]=0;}
     float distance=Vector3.Distance(e.View.transform.position,game.Player.transform.position);
     // The old test only checked distance. A nearby enemy that never strikes is broken.
     nearbyIdle[e]=distance<1.75f?nearbyIdle[e]+dt:0;
     Check(nearbyIdle[e]<3.5f,$"Nearby idle Warrior id={e.CrowdId} intent={e.Intent} distance={distance:F2} idleInRange={nearbyIdle[e]:F1}");
    }
    if(age>13&&!engagementChecked){engagementChecked=true;foreach(var e in game.Enemies)Check(e.ContactCount>=3,$"No combat pressure id={e.CrowdId} attacks={e.AttackCount} contacts={e.ContactCount}");}
    for(int i=0;i<game.Enemies.Count;i++)for(int j=i+1;j<game.Enemies.Count;j++)
    {
     float gap=Vector3.Distance(game.Enemies[i].View.transform.position,game.Enemies[j].View.transform.position);minGap=Mathf.Min(minGap,gap);
     Check(gap>=1.3f,"Bodies overlapped: "+gap);
    }
    if(age>captures/15f)
    {
     foreach(var e in game.Enemies)rows.Add($"{age:F3},{e.CrowdId},{e.Intent},{Vector3.Distance(e.View.transform.position,game.Player.transform.position):F3},{e.AttackCount},{e.ContactCount},{e.Turning},{e.View.transform.position.x:F3},{e.View.transform.position.z:F3},{e.ApproachSlot},{e.Agent.desiredVelocity.magnitude:F3},{e.Agent.isStopped},{e.View.transform.eulerAngles.y:F1},{e.StuckTime:F2}");
     Capture();captures++;
    }
    if(age>=38)
    {
     foreach(var e in game.Enemies){Check(Vector3.Distance(e.View.transform.position,game.Player.transform.position)<2,"Warrior failed to reach player: "+e.CrowdId);Check(e.ContactCount>=finalPhaseContacts[e]+2,"Did not attack after final retarget: "+e.CrowdId);}
     Debug.Log($"CROWD_REVIEW_PASSED nativeAgents=3 minimumCentreGap={minGap:F3} captures={captures} contacts={string.Join(",",game.Enemies.Select(e=>e.ContactCount))}");Finish();
    }
   }
   catch(Exception e){Debug.LogException(e);if(game)Finish();}
  }
  static void SpawnTests()
  {
   var original=game.Player.transform.position;
   try
   {
    foreach(var origin in new[]{new Vector3(0,0,2),new Vector3(7,0,2),new Vector3(-7,0,2)})
    {
     if(!UnityEngine.AI.NavMesh.SamplePosition(origin,out var anchor,1,UnityEngine.AI.NavMesh.AllAreas))continue;
     game.Player.transform.position=new Vector3(anchor.position.x,0,anchor.position.z);
     var directions=new System.Collections.Generic.List<Vector3>();
     for(int i=0;i<8;i++)
     {
      object[] args={"grunt",Vector3.zero};Check((bool)Call("TrySurroundSpawn",args),"No nearby reachable spawn at "+origin);
      var delta=(Vector3)args[1]-game.Player.transform.position;
      Check(delta.magnitude>=5.1f&&delta.magnitude<=8.5f,"Spawn outside local ring");directions.Add(delta.normalized);
     }
     Check(directions.Any(d=>Vector3.Dot(d,directions[0])<.2f),"Spawns clustered in one direction");
    }
    Debug.Log("CROWD_SURROUND_SPAWNS_PASSED centre/side positions, 5.1-8.5m, multiple sectors, complete paths");
   }
   finally{game.Player.transform.position=original;}
  }
  static void FeedbackTests()
  {
   var saved=(Newtonsoft.Json.Linq.JObject)game.Run.Stats.DeepClone();
   try
   {
    Set("combatPractice",false);game.Run.Stats["dodgeChance"]=1;
    game.Player.HitFlash.enabled=false;game.Player.HitFlash.enabled=true;Set("invulnerable",0f);Call("HurtPlayer",10f);
    Check(!game.Player.HitFlash.Active,"Dodged hit flashed player");
    game.Run.Stats["dodgeChance"]=0;Set("invulnerable",0f);Call("HurtPlayer",10f);
    Check(game.Player.HitFlash.Active,"Real player damage did not flash");
    game.Player.HitFlash.enabled=false;game.Player.HitFlash.enabled=true;Call("HurtPlayer",10f);
    Check(!game.Player.HitFlash.Active,"Invulnerable hit flashed player");
   }
   finally{game.Run.Stats.RemoveAll();foreach(var p in saved.Properties())game.Run.Stats[p.Name]=p.Value.DeepClone();Set("combatPractice",true);}
   float hp=game.Run.Stats.N("hp");Set("invulnerable",0f);Call("HurtPlayer",10f);
   Check(game.Player.HitFlash.Active,"Practice player hit flash absent");Check(game.Run.Stats.N("hp")==hp,"Practice HP changed");
   var enemy=game.Enemies[0];enemy.View.HitFlash.enabled=false;enemy.View.HitFlash.enabled=true;
   Capture("flash-before.jpg");Call("DamageEnemy",enemy,1f,true);Check(enemy.View.HitFlash.Active,"Enemy flash absent");Capture("flash-hit.jpg");
   var block=new MaterialPropertyBlock();bool emitted=false;
   foreach(var renderer in enemy.View.Animator.GetComponentsInChildren<Renderer>())
   {renderer.GetPropertyBlock(block,0);if(block.GetColor("_EmissionColor").maxColorComponent>.3f)emitted=true;}
   Check(emitted,"Enemy flash has no rendered emission property");
   Call("StartAreaRecoil",enemy,game.Player.transform.position,1.5f);Check(Mathf.Abs(enemy.RecoilRemaining-.72f)<.001f,"E recoil distance");
   Call("StartAreaRecoil",enemy,game.Player.transform.position,2.5f);Check(Mathf.Abs(enemy.RecoilRemaining-1.2f)<.001f,"Space recoil distance");
   enemy.AreaRecovery=0;enemy.Stagger=0;
   enemy.Stagger=enemy.RecoilTime=0;enemy.View.Play("Idle",0);Set("hitStop",0f);
   var shared=Resources.Load<GameObject>("Actors/enemy_warrior").GetComponentsInChildren<Renderer>().First().sharedMaterial;
   Check(enemy.View.Animator.GetComponentsInChildren<Renderer>().First().sharedMaterial!=shared,"Hit flash mutated shared asset material");
   Debug.Log("CROWD_FEEDBACK_PASSED actual-hit/dodge/invulnerability + player/enemy flash + immortal practice + isolated materials");
  }
  static void Capture(string filename=null)
  {
   var camera=game.Cam;var oldPosition=camera.transform.position;var oldRotation=camera.transform.rotation;float oldSize=camera.orthographicSize;
   var oldTarget=camera.targetTexture;var oldActive=RenderTexture.active;var rt=RenderTexture.GetTemporary(960,540,24);var image=new Texture2D(960,540,TextureFormat.RGB24,false);
   try
   {
    camera.transform.position=new Vector3(9,10,12);camera.transform.LookAt(new Vector3(0,.7f,0));camera.orthographicSize=6;
    camera.targetTexture=rt;camera.Render();RenderTexture.active=rt;image.ReadPixels(new Rect(0,0,960,540),0,0);image.Apply();
    File.WriteAllBytes(Path.Combine(output,filename??$"frame-{captures:D4}.jpg"),image.EncodeToJPG(85));
   }
   finally{camera.targetTexture=oldTarget;RenderTexture.active=oldActive;camera.transform.SetPositionAndRotation(oldPosition,oldRotation);camera.orthographicSize=oldSize;RenderTexture.ReleaseTemporary(rt);UnityEngine.Object.DestroyImmediate(image);}
  }
  static void Finish()
  {
   File.WriteAllLines(Path.Combine(output,"combat.csv"),rows);
   foreach(var e in game.Enemies.Skip(1).ToArray()){if(e.Agent)e.Agent.enabled=false;UnityEngine.Object.Destroy(e.View.gameObject);game.Enemies.Remove(e);}
   var first=game.Enemies[0];first.Turning=false;first.StepPending=false;first.StepTime=0;first.View.transform.position=new Vector3(0,0,.3f);first.View.transform.rotation=Quaternion.identity;first.View.Play("Idle",0);first.Cooldown=.9f;first.ApproachSlot=-1;
   game.Player.transform.SetPositionAndRotation(playerPosition,playerRotation);game.enabled=true;game=null;
  }
 }
}
