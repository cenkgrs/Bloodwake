using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  bool autoFire;
  void Update()
  {
   if(arrivalActive)return;
   var keys=Keyboard.current;var pad=Gamepad.current;
   if(keys?.f11Key.wasPressedThisFrame==true)UnityEngine.Screen.fullScreen=!UnityEngine.Screen.fullScreen;
   if(keys?.escapeKey.wasPressedThisFrame==true||pad?.startButton.wasPressedThisFrame==true)Screen=Screen=="playing"?"pause":Screen=="pause"?"playing":Screen;
   PositionCamera(false);
   bool paused=Screen!="playing"&&Screen!="dead";if(Player)Player.Animator.speed=paused?0:Player.PlaybackRate;foreach(var e in Enemies)e.View.Animator.speed=paused?0:e.View.PlaybackRate;
   if(Screen!="playing"||Run==null||Run.Stats.N("hp")<=0)return;
   float dt=Time.deltaTime;if(hitStop>0){hitStop-=dt;Player.Animator.speed=0;foreach(var e in Enemies)e.View.Animator.speed=0;return;}
   Player.Animator.speed=Player.PlaybackRate;foreach(var e in Enemies)e.View.Animator.speed=e.View.PlaybackRate;
   attackCd-=dt;dashCd-=dt;invulnerable-=dt;foreach(string id in Run.Cooldowns.Keys.ToArray())Run.Cooldowns[id]=Mathf.Max(0,Run.Cooldowns[id]-dt);
   if(keys?.tabKey.wasPressedThisFrame==true||pad?.buttonNorth.wasPressedThisFrame==true)autoFire=!autoFire;
   Vector2 input=pad?.leftStick.ReadValue()??Vector2.zero;if(keys!=null){input.x+=(keys.dKey.isPressed||keys.rightArrowKey.isPressed?1:0)-(keys.aKey.isPressed||keys.leftArrowKey.isPressed?1:0);input.y+=(keys.wKey.isPressed||keys.upArrowKey.isPressed?1:0)-(keys.sKey.isPressed||keys.downArrowKey.isPressed?1:0);}input=Vector2.ClampMagnitude(input,1);
   Vector3 forward=Vector3.ProjectOnPlane(Cam.transform.forward,Vector3.up).normalized,right=Cam.transform.right;right.y=0;var move=forward*input.y+right*input.x;
   if(Mouse.current!=null&&!Application.isBatchMode){var ray=Cam.ScreenPointToRay(Mouse.current.position.ReadValue());if(new Plane(Vector3.up,0).Raycast(ray,out float distance)){var target=ray.GetPoint(distance)-Player.transform.position;if(target.sqrMagnitude>.01f)aim=target.normalized;}}
   var stick=pad?.rightStick.ReadValue()??Vector2.zero;if(stick.sqrMagnitude>.1f)aim=(forward*stick.y+right*stick.x).normalized;
   if(Player.Locked<=.15f){Player.transform.position=Move(Player.transform.position,move*Run.Stats.N("moveSpeed")*.02f*dt);if(move.sqrMagnitude>.01f)Player.transform.rotation=Quaternion.Slerp(Player.transform.rotation,Quaternion.LookRotation(move),dt*16);}
   Player.Tick(dt,move.sqrMagnitude>.01f);Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+Run.Stats.N("regenPerSecond")*dt);
   if(keys!=null){if(keys.qKey.wasPressedThisFrame)Cast(0);if(keys.eKey.wasPressedThisFrame)Cast(1);if(keys.spaceKey.wasPressedThisFrame)Cast(2);if(keys.fKey.wasPressedThisFrame)Interact();}
   if(pad!=null){if(pad.buttonWest.wasPressedThisFrame)Cast(0);if(pad.buttonEast.wasPressedThisFrame)Cast(1);if(pad.buttonSouth.wasPressedThisFrame)Cast(2);if(pad.rightShoulder.wasPressedThisFrame)Interact();}
   if((autoFire||Mouse.current?.leftButton.isPressed==true||pad?.rightTrigger.isPressed==true)&&attackCd<=0)Attack();
   UpdateNavigation(dt);TickEnemies(dt);TickWaves(dt);TickPickups(dt);CheckRoomExit();
  }
  void TickWaves(float dt)
  {
   if(roomClear||waves==null||waves.Count==0)return;spawnTimer-=dt;
   var roster=(JArray)waves[waveIndex];int total=roster.Count+Mathf.Max(0,Run.Night-1)*((room["encounter"]?["perNight"] as JArray)?.Count??0);
   if(spawnCursor<total&&Enemies.Count<5&&spawnTimer<=0){string id=spawnCursor<roster.Count?(string)roster[spawnCursor]:(string)room["encounter"]["perNight"][(spawnCursor-roster.Count)%((JArray)room["encounter"]["perNight"]).Count];var points=room["markers"]["EnemySpawn"] as JArray;Vector3 pos=points!=null?Point(points[spawnCursor%points.Count]):Vector3.zero;SpawnEnemy(id,pos);spawnCursor++;spawnTimer=.55f;}
   if(spawnCursor>=total&&Enemies.Count==0){if(++waveIndex<waves.Count){spawnCursor=0;spawnTimer=1.6f;Run.Wave++;}else{roomClear=true;Run.RoomsCleared++;Sound("wave_clear");}}
  }
 }
}
