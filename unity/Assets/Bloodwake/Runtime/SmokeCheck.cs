using System.Collections;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  bool smokeFailed;
  IEnumerator Smoke()
  {
   Application.logMessageReceived+=OnSmokeLog;
   foreach(string id in new[]{"warrior","revenant","vesper","mage"})
   {
    // The driver runs on a separate object because room changes cancel combat coroutines.
    new GameObject("Smoke driver").AddComponent<SmokeDriver>().Begin(this,id);
    yield break;
   }
  }
  void OnSmokeLog(string message,string trace,LogType type){if(type==LogType.Exception||type==LogType.Error)smokeFailed=true;}
  public IEnumerator SmokeClasses()
  {
   Screen="menu";yield return new WaitForSeconds(.5f);yield return Capture("menu");Screen="classes";yield return new WaitForSeconds(.2f);yield return Capture("classes");
   foreach(string id in new[]{"warrior","revenant","vesper","mage"})
   {
    BeginCharacterIntro(id);BeginCharacterIntro(id);yield return new WaitForSeconds(1);CheckSmoke(introActive&&Screen=="loading","cinematic locks controls "+id);yield return Capture(id+"-intro");yield return new WaitForSeconds(4);CheckSmoke(!introActive&&Screen=="playing"&&Run.ClassId==id,"cinematic enters safehouse "+id);yield return Capture(id+"-safehouse");EnterRoom(Run.Plan[0]);Screen="playing";yield return null;
    if(Player==null||Player.Animator.runtimeAnimatorController==null){Debug.LogError("SMOKE missing "+id);break;}
    SpawnEnemy("grunt",Player.transform.position+Player.transform.forward);
    Attack();yield return new WaitForSeconds(1.5f);Player.Locked=0;Cast(0);yield return new WaitForSeconds(1.5f);
    yield return Capture(id+"-combat");Debug.Log("BLOODWAKE_RUNTIME_CLASS "+id+" OK");
   }
   yield return SmokeParity();yield return SmokeRoute();
   Debug.Log(smokeFailed?"BLOODWAKE_RUNTIME_SMOKE_FAILED":"BLOODWAKE_RUNTIME_SMOKE_PASSED");Application.Quit(smokeFailed?1:0);
  }
  void CheckSmoke(bool ok,string message){if(!ok){smokeFailed=true;Debug.LogError("CONTRACT_FAILED "+message);}else Debug.Log("CONTRACT_PASSED "+message);}
  IEnumerator SmokeParity()
  {
   StartRun("warrior");EnterRoom(Run.Plan[0]);spawnTimer=999;
   Run.Stats["criticalChance"]=0;Run.Stats["maxHp"]=1000;Run.Stats["hp"]=100;Run.Stats["lifesteal"]=.1f;
   var p=Player.transform.position;SpawnEnemy("grunt",p+Vector3.forward);SpawnEnemy("grunt",p+Vector3.forward*2);var victim=Enemies[0];victim.Hp=10;victim.Mark=float.PositiveInfinity;int goldBefore=Run.Gold;DamageEnemy(victim,1000);
   CheckSmoke(Mathf.Approximately(Run.Stats.N("hp"),101),"lifesteal excludes overkill");CheckSmoke(Run.Gold>goldBefore,"gold awarded immediately");CheckSmoke(Enemies[0].Mark>0&&markChain==1,"mark inherited after kill");
   var next=Enemies[0];next.Mark=0;next.Hp=100;next.Burn=3;next.BurnDps=7;hitStop=0;TickEnemies(.1f);CheckSmoke(Mathf.Abs(next.Hp-99.3f)<.01f,"burn damage per second");CheckSmoke(hitStop==0,"damage over time does not hit stop");
   CheckSmoke(SegmentDistance(new Vector3(5,0,0),Vector3.zero,new Vector3(10,0,0))<.001f,"fast projectile swept hit");
   var save=new Progression();save.Essence=123;CheckSmoke(!save.Import("{\"essence\":25,\"levels\":\"bad\"}")&&save.Essence==123,"invalid import leaves progression unchanged");
   foreach(string screen in new[]{"armory","progression","settings"}){Screen=screen;yield return null;yield return Capture(screen.Replace(' ','-'));}
   EnterDistrict();yield return new WaitForSeconds(5);yield return Capture("district-arrival");yield return new WaitForSeconds(4);CheckSmoke(Screen=="playing"&&room.S("id")==Run.Plan[0],"war table cinematic enters district");
  }
  IEnumerator SmokeRoute()
  {
   StartRun("warrior");Run.Stats["maxHp"]=1000000;Run.Stats["hp"]=1000000;Run.Gold=1000;Run.Upgrade("sharpened");float damage=Run.Stats.N("damage");
   CheckSmoke(Run.Plan.Count==7,"five combat rooms, boss, merchant");
   Run.RoomIndex=0;EnterRoom(Run.Plan[0]);
   for(int roomNumber=0;roomNumber<7;roomNumber++)
   {
    CheckSmoke(room.S("id")==Run.Plan[roomNumber],"route room "+roomNumber);CheckSmoke(roomRoot.Find("Imported town geometry")!=null,"converted geometry "+roomNumber);
    if(!roomClear)
    {
     int safety=0;while(!roomClear&&safety++<300){spawnTimer=0;TickWaves(.1f);foreach(var enemy in Enemies.ToArray())DamageEnemy(enemy,100000000);yield return null;}
     CheckSmoke(roomClear,"encounter completed "+roomNumber);Run.PendingLevels=0;
     if(room.S("type")=="boss"){Player.transform.position=Point(room["markers"]["RewardPoint"]);Interact();CheckSmoke(Screen=="upgrade"&&bossReward,"boss spoils gate");bossReward=false;Run.Claimed.Add(Run.Night+":"+Run.RoomIndex);Screen="playing";}
    }
    else{Player.transform.position=Point(room["hosts"][0]["at"]);Interact();CheckSmoke(Screen=="merchant","merchant interaction");yield return null;yield return Capture("merchant");}
    NextRoom();yield return null;CheckSmoke(Mathf.Approximately(Run.Stats.N("damage"),damage),"upgrade survives room transition");
   }
   CheckSmoke(Run.Night==2&&Run.RoomIndex==0,"night wraps after merchant");CheckSmoke(Mathf.Approximately(Run.Grade,1.6f),"night two merchant grade");
   Screen="pause";yield return null;yield return Capture("pause");Screen="playing";
   Run.Night=FinalDistrict;Run.RoomIndex=Run.Plan.Count-2;EnterRoom(Run.Plan[Run.RoomIndex]);
   int guard=0;while(!roomClear&&guard++<300){spawnTimer=0;TickWaves(.1f);foreach(var enemy in Enemies.ToArray())DamageEnemy(enemy,100000000);yield return null;}
   yield return new WaitForSeconds(3);CheckSmoke(Screen=="victory","last district boss ends the run");yield return Capture("victory");
  }
  IEnumerator Capture(string name)
  {
   // Off-screen rendering keeps unfinished QA builds off the user's desktop.
   yield return null;EnsureUI();var canvas=uiRoot.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=Cam;canvas.planeDistance=1;
   var target=new RenderTexture(1600,900,24);target.Create();var old=Cam.targetTexture;Cam.targetTexture=target;Cam.aspect=1600f/900;
   // Capture gameplay without an overlay camera: URP clears the color buffer
   // for a separately rendered base camera even when its clearFlags is Depth.
   bool worldOnly=Screen=="playing";canvas.enabled=!worldOnly;
   yield return null;Canvas.ForceUpdateCanvases();Cam.Render();canvas.enabled=true;
   var active=RenderTexture.active;RenderTexture.active=target;var texture=new Texture2D(1600,900,TextureFormat.RGB24,false);texture.ReadPixels(new Rect(0,0,1600,900),0,0);texture.Apply();System.IO.File.WriteAllBytes("/tmp/bloodwake-"+name+".png",texture.EncodeToPNG());RenderTexture.active=active;Cam.targetTexture=old;target.Release();Destroy(target);Destroy(texture);canvas.renderMode=RenderMode.ScreenSpaceOverlay;
  }
 }
 public sealed class SmokeDriver:MonoBehaviour
 {
  public void Begin(BloodwakeGame game,string unused){StartCoroutine(game.SmokeClasses());}
 }
}
