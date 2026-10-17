using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  void EnterRoom(string id)
  {
   ResetRevenantDash();
   StopAllCoroutines();Player.CancelAction();revenantFx=null;foreach(Transform child in actorRoot)if(child!=Player.transform)Destroy(child.gameObject);Enemies.Clear();pickups.Clear();if(roomRoot)Destroy(roomRoot.gameObject);
   roomRoot=new GameObject(id).transform;blockers.Clear();room=(JObject)GameData.Rooms["rooms"].First(r=>r.S("id")==id);half=new Vector2((float)room["size"][0],(float)room["size"][1])*.5f;
   ColorUtility.TryParseHtmlString("#"+room["light"].S("ground","43434a"),out var ground);
   Box("Courtyard",new Vector3(0,-.15f,0),new Vector3(half.x*2,.3f,half.y*2),ground,false);
   foreach(var block in room["layout"]??new JArray())if(block["size"] is JArray size){var p=Point(block["at"]);float h=block.N("height",1);Box(block.S("kind"),p+Vector3.up*h*.5f,new Vector3((float)size[0],h,(float)size[1]),new Color(.22f,.17f,.13f),true);}
   Box("West wall",new Vector3(-half.x-.3f,1,0),new Vector3(.6f,2,half.y*2),ground*.65f,true);
   Box("East wall",new Vector3(half.x+.3f,1,0),new Vector3(.6f,2,half.y*2),ground*.65f,true);
   foreach(int side in new[]{-1,1})foreach(int edge in new[]{-1,1})Box("Gate wall",new Vector3(side*(half.x+3)*.5f,1,edge*half.y),new Vector3(half.x-3,2,.6f),ground*.65f,true);
   // The FBX and the converted prefab must never share a Resources key.
   var authored=id=="town_safehouse"?null:Resources.Load<GameObject>("Rooms/"+id+"/"+id+"_environment");
   if(authored){foreach(var r in roomRoot.GetComponentsInChildren<Renderer>())r.enabled=false;var environment=Instantiate(authored,roomRoot);environment.name="Imported town geometry";
    var metadata=id=="town_safehouse"?null:Resources.Load<TextAsset>("Rooms/"+id+"/collision");if(metadata){var data=JObject.Parse(metadata.text);blockers.Clear();foreach(var r in data["rects"]){float x=(float)r[0],z=(float)r[1],w=(float)r[2],h=(float)r[3];blockers.Add(new Bounds(new Vector3(-x-w/2,1,z+h/2),new Vector3(w,2,h)));}foreach(var c in data["circles"]){float radius=(float)c[2];blockers.Add(new Bounds(new Vector3(-(float)c[0],1,(float)c[1]),new Vector3(radius*2,2,radius*2)));}var hidden=data["hidden"].Values<string>().ToHashSet();foreach(var t in environment.GetComponentsInChildren<Transform>())if(hidden.Contains(t.name))t.gameObject.SetActive(false);}
   }
   EnvironmentDressing.Apply(roomRoot,half,room["layout"]);
   EnvironmentDetails.Apply(roomRoot,this,half,room["layout"]);
   if(id=="town_safehouse"){BuildSanctuary();SpawnSanctuaryCargo();}else DressRoom(id);ConfigureBreakableCargo();
   roomRoot.gameObject.AddComponent<RoomReflection>().HalfSize=half;
   roomRoot.gameObject.AddComponent<RoomPresentation>().Apply(roomRoot,this);
   SpawnHosts();BuildNavigation();Player.transform.position=Point(room["markers"]["EntrySpawn"]);Player.transform.rotation=Quaternion.LookRotation(Vector3.back);Player.Locked=0;RevFx.Hands(Player);RevFx.HandMagic(Player);if(id=="town_safehouse")SpawnTrainingWarrior();
   float maxSize=Mathf.Min((half.x*2+10)/Cam.aspect,(half.y*2+11)*cameraOffset.normalized.y)/2;Cam.orthographicSize=Mathf.Min(PlayerPrefs.GetFloat("zoom",DefaultZoom),maxSize);PositionCamera(true);
   roomClear=room.S("type")=="merchant"||room.S("type")=="safehouse";waves=room["encounter"]?["waves"] as JArray;
   if(room.S("type")=="boss")waves=new JArray{new JArray("boss")};
   waveIndex=0;spawnCursor=0;spawnTimer=1.5f;attackCd=0;dashCd=0;
   if(!roomClear){Run.Fights++;Run.Wave=Run.Fights;}SetMusic(room.S("type")=="boss"?"music_boss":roomClear?"music_menu":"music_combat");
  }
  static Vector3 Point(JToken v)=>v is JArray a&&a.Count>=2?new Vector3(-(float)a[0],0,(float)a[1]):Vector3.zero;
  void SpawnSanctuaryCargo()
  {
   var crate=Resources.Load<GameObject>("Environment/Kit01/crate/crate");var barrel=Resources.Load<GameObject>("Environment/Kit01/barrel/barrel");if(!crate||!barrel)return;
   Vector3[] spots={new(-8.6f,0,6.2f),new(-9.7f,0,7.5f),new(-8.3f,0,9.7f),new(-6.6f,0,10.4f),new(8.4f,0,6.4f),new(9.7f,0,7.7f),new(7.9f,0,9.9f),new(6.4f,0,10.4f)};
   for(int i=0;i<spots.Length;i++){var go=Instantiate(i%3==0?barrel:crate,roomRoot);go.name="Training breakable "+i;go.transform.position=spots[i];go.transform.rotation=Quaternion.Euler(0,i*37,0);go.AddComponent<BreakableCargo>();}
  }
  void SpawnTrainingWarrior()
  {
   var home=new Vector3(0,0,8.2f);SpawnEnemy("grunt",home);var dummy=Enemies.Last();dummy.Training=true;dummy.TrainingHome=home;dummy.MaxHp=dummy.Hp=250;dummy.Cooldown=float.PositiveInfinity;dummy.View.TickEmergence(10);HoldEnemyAgent(dummy);dummy.View.transform.rotation=Quaternion.LookRotation(Vector3.back);
  }
  void Box(string name,Vector3 pos,Vector3 size,Color color,bool solid)
  {
   var go=GameObject.CreatePrimitive(PrimitiveType.Cube);go.name=name;go.transform.SetParent(roomRoot);go.transform.position=pos;go.transform.localScale=size;go.GetComponent<Renderer>().sharedMaterial=Effects.Mat(color);if(solid)blockers.Add(new Bounds(pos,size));else Destroy(go.GetComponent<Collider>());
  }
  Vector3 Move(Vector3 p,Vector3 delta,float radius=.4f)
  {
   int steps=Mathf.Max(1,Mathf.CeilToInt(delta.magnitude/.15f));for(int i=0;i<steps;i++)p=MoveStep(p,delta/steps,radius);return p;
  }
  Vector3 MoveStep(Vector3 p,Vector3 delta,float radius)
  {
   var next=p+delta;next.x=Mathf.Clamp(next.x,-half.x+radius,half.x-radius);next.z=Mathf.Clamp(next.z,-half.y+radius,half.y-radius);
   foreach(var b in blockers){var expanded=b;expanded.Expand(new Vector3(radius*2,10,radius*2));if(!expanded.Contains(new Vector3(next.x,b.center.y,next.z)))continue;var xOnly=new Vector3(p.x+delta.x,b.center.y,p.z);var zOnly=new Vector3(p.x,b.center.y,p.z+delta.z);if(!expanded.Contains(xOnly))next.z=p.z;else if(!expanded.Contains(zOnly))next.x=p.x;else next=p;}return next;
  }
  bool bossReward;
  string HostScreen(JToken host)=>host.S("role") switch{"builds"=>"armory","skills"=>"progression","merchant"=>"merchant",_=>"hub"};
  // There is one district chain, so the war table sends the hunter straight into it instead of offering a choice.
  void OpenHost(JToken host){if(host.S("role")=="maps"){Sound("ui_enter_district");EnterDistrict();}else Screen=HostScreen(host);}
  void EnterDistrict()=>BeginCharacterIntro(Run.ClassId,GameData.Maps["maps"][0]);
  // Each pass through the route and its boss is one district; beating the last district's boss wins the run.
  JArray Districts=>(JArray)GameData.Maps["maps"][0]["districts"];
  int FinalDistrict=>Districts.Count;
  // The HUD names the district rather than counting it, so the run never reads as a countdown.
  string DistrictName=>(string)Districts[Mathf.Clamp(Run.Night-1,0,Districts.Count-1)];
  void Interact(){var host=NearbyHost();if(host!=null){if(!OpenDialogue(host))OpenHost(host);return;}if(!RewardReady||Vector3.Distance(Player.transform.position,Point(room["markers"]["RewardPoint"]))>=2.4f)return;bossReward=room.S("type")=="boss"&&!Run.Claimed.Contains(Run.Night+":"+Run.RoomIndex);PrepareReward();}
  void PrepareReward(){offers.Clear();offers.AddRange(GameData.Rows("upgrades").Where(r=>Run.Available(r,"upgrades")&&(Run.PendingLevels>0||r.S("rarity")!="common")).OrderBy(_=>Random.value).Take(3));Screen=offers.Count>0?"upgrade":"playing";if(offers.Count==0){Run.PendingLevels=0;bossReward=false;Run.Claimed.Add(Run.Night+":"+Run.RoomIndex);}}
  public void NextRoom(){Run.RoomIndex++;if(Run.RoomIndex>=Run.Plan.Count){Run.RoomIndex=0;Run.Night++;Sound("ui_enter_district");}EnterRoom(Run.Plan[Run.RoomIndex]);Screen="playing";}
 }
}
