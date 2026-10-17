using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // Developer kit: F1 or the gamepad's Select / Create / View button during play. Toggles persist
 // between sessions; actions act on the current run.
 public sealed partial class BloodwakeGame
 {
  static bool DevFlag(string key)=>PlayerPrefs.GetInt("dev_"+key,0)==1;
  static void SetDevFlag(string key,bool on){PlayerPrefs.SetInt("dev_"+key,on?1:0);PlayerPrefs.Save();}
  bool DevGod=>DevFlag("god");bool DevNoCooldowns=>DevFlag("cooldowns");bool DevOneHit=>DevFlag("onehit");
  void DevKitInput(UnityEngine.InputSystem.Keyboard keys,UnityEngine.InputSystem.Gamepad pad)
  {
   if(keys?.f1Key.wasPressedThisFrame!=true&&pad?.selectButton.wasPressedThisFrame!=true)return;
   if(Screen=="devkit"){Screen="playing";Sound("ui_back");}else if(Screen=="playing"&&Run!=null){Screen="devkit";Sound("ui_select");}
  }
  // Runs every gameplay frame after the cooldowns tick.
  void TickDevKit()
  {
   if(!DevNoCooldowns)return;
   foreach(string id in Run.Cooldowns.Keys.ToArray())Run.Cooldowns[id]=0;dashCd=Mathf.Min(dashCd,0);
  }
  void DrawDevKit()
  {
   Bleed(Plate(page,"Dev veil",0,0,1600,900,new Color(.015f,.01f,.015f,.86f)));
   Label(page,"DEV KIT",70,40,1460,80,44,true,TextAnchor.MiddleCenter);Rule(page,560,128,480);
   int alive=Enemies.Count(e=>!e.Training);
   string where=$"{DistrictName}  ·  district {Run.Night}/{FinalDistrict}  ·  room {Run.RoomIndex+1}/{Run.Plan.Count} ({room?.S("id")})  ·  wave {Mathf.Min(waveIndex+1,waves?.Count??0)}/{waves?.Count??0}  ·  alive {alive}";
   Label(page,where,120,146,1360,32,18,false,TextAnchor.MiddleCenter).color=new Color(.75f,.71f,.67f);
   // Left column: switches. Right column: one-shot actions.
   void Toggle(string label,string key,float y){bool on=DevFlag(key);Button(page,label+"  ·  "+(on?"ON":"OFF"),150,y,580,62,()=>SetDevFlag(key,!on));}
   Toggle("GOD MODE","god",210);Toggle("NO COOLDOWNS","cooldowns",290);Toggle("ONE-HIT KILLS","onehit",370);
   Button(page,"FULL HEAL",150,450,580,62,()=>Run.Stats["hp"]=Run.Stats["maxHp"].DeepClone());
   Button(page,"LEVEL UP (PICK UPGRADE)",150,530,580,62,()=>{Run.PendingLevels++;PrepareReward();});
   Button(page,"+1000 ESSENCE",150,610,280,62,()=>{Meta.Essence+=1000;Meta.Save();});
   Button(page,"+500 GOLD",450,610,280,62,()=>Run.Gold+=500);
   Button(page,"KILL ALL ENEMIES",870,210,580,62,DevKillAll);
   Button(page,"CLEAR ROOM",870,290,580,62,DevClearRoom);
   Button(page,"NEXT ROOM",870,370,580,62,()=>{if(Run.Plan.Count==0)return;Screen="playing";if(room.S("type")=="safehouse"){Run.RoomIndex=0;EnterRoom(Run.Plan[0]);}else NextRoom();});
   Button(page,"JUMP TO BOSS",870,450,580,62,DevJumpToBoss);
   Button(page,"NEXT DISTRICT",870,530,580,62,()=>DevDistrict(1));
   Button(page,"PREVIOUS DISTRICT",870,610,580,62,()=>DevDistrict(-1));
   Label(page,ShowPad?"SELECT / CIRCLE TO CLOSE":"F1 / ESC TO CLOSE",120,700,1360,30,16,true,TextAnchor.MiddleCenter).color=new Color(.6f,.56f,.53f);
   Button(page,"CLOSE",675,760,250,55,()=>Screen="playing");
  }
  void DevKillAll(){foreach(var e in Enemies.ToArray())if(!e.Training)DamageEnemy(e,1e9f,false);Screen="playing";}
  // Marks every round as spawned so the room clears the moment the living enemies die.
  void DevClearRoom(){if(waves!=null&&waves.Count>0){waveIndex=waves.Count-1;spawnCursor=int.MaxValue/2;}DevKillAll();}
  void DevJumpToBoss()
  {
   int index=Run.Plan.FindIndex(id=>GameData.Rooms["rooms"].First(r=>r.S("id")==id).S("type")=="boss");if(index<0)return;
   Run.RoomIndex=index;Screen="playing";EnterRoom(Run.Plan[index]);
  }
  void DevDistrict(int step)
  {
   if(Run.Plan.Count==0)return;Run.Night=Mathf.Clamp(Run.Night+step,1,FinalDistrict);Run.RoomIndex=0;Screen="playing";EnterRoom(Run.Plan[0]);
  }
 }
}
