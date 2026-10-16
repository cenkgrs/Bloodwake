using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  void SpawnHosts()
  {
   var entry=Point(room["markers"]["EntrySpawn"]);
   foreach(var host in room["hosts"]??new JArray())if(host["model"]!=null)
   {
    var view=ActorView.Create(host.S("model"),true,2*CombatActorScale,roomRoot);view.name="Host · "+host.S("name");view.transform.position=Point(host["at"]);
    // Hosts are solid: the player and the crowd navigation walk around them.
    blockers.Add(new Bounds(view.transform.position+Vector3.up,new Vector3(.8f,2,.8f)));
    // Turn halfway between the arrival path and the isometric camera so the face reads from either.
    var toEntry=entry-view.transform.position;var toCamera=cameraOffset;toEntry.y=toCamera.y=0;
    var facing=toEntry.normalized+toCamera.normalized;view.transform.rotation=Quaternion.LookRotation(facing.sqrMagnitude>.01f?facing:Vector3.back);
    // Hosts stand in dim rooms; light them on the actor-only layer like the player fill.
    var fill=new GameObject("Host fill light").AddComponent<Light>();fill.transform.SetParent(view.transform,false);fill.transform.localPosition=new Vector3(0,2.2f,1.2f);
    fill.type=LightType.Point;fill.color=RevenantVfx.Tone("e6d2b8");fill.intensity=3;fill.range=4.5f;fill.shadows=LightShadows.None;fill.GetUniversalAdditionalLightData().renderingLayers=2u;
   }
  }
  JToken NearbyHost()=> (room["hosts"]??new JArray()).Where(h=>Vector3.Distance(Player.transform.position,Point(h["at"]))<2.4f).OrderBy(h=>Vector3.Distance(Player.transform.position,Point(h["at"]))).FirstOrDefault();
  bool RewardReady=>roomClear&&(Run.PendingLevels>0||room.S("type")=="boss"&&!Run.Claimed.Contains(Run.Night+":"+Run.RoomIndex));
  internal bool ExitOpen=>Run!=null&&room!=null&&roomClear&&room["doors"]?["exit"]!=null&&!(room.S("type")=="boss"&&!Run.Claimed.Contains(Run.Night+":"+Run.RoomIndex));
  void CheckRoomExit()
  {
   if(!roomClear||room["doors"]?["exit"]==null)return;bool locked=room.S("type")=="boss"&&!Run.Claimed.Contains(Run.Night+":"+Run.RoomIndex);
   foreach(var t in roomRoot.GetComponentsInChildren<Transform>())if(t.name=="ExitLeaf_L"||t.name=="ExitLeaf_R")t.localRotation=Quaternion.Euler(0,locked?0:t.name.EndsWith("L")?-100:100,0);
   if(locked)return;var exit=Point(room["doors"]["exit"]["at"]);var d=Player.transform.position-exit;
   bool vertical=Mathf.Abs(exit.z)>=half.y-.5f;if(vertical?Mathf.Abs(d.x)<3&&Mathf.Abs(d.z)<1.2f:Mathf.Abs(d.z)<3&&Mathf.Abs(d.x)<1.2f)NextRoom();
  }
  string InteractionHint()
  {
   var host=NearbyHost();if(host!=null)return "F  ·  "+host.S("verb")+" — "+host.S("name");
   if(RewardReady&&Vector3.Distance(Player.transform.position,Point(room["markers"]["RewardPoint"]))<2.4f)return "F  ·  CLAIM REWARD";
   if(room.S("type")=="safehouse")return "APPROACH THE WAR TABLE, QUARTERMASTER OR BLOOD SAGE";
   return roomClear?(room.S("type")=="boss"&&RewardReady?"CLAIM THE SPOILS TO OPEN THE GATE":"THE WAY ON IS OPEN"):"";
  }
 }
}
