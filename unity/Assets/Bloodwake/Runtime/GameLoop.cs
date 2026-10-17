using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.InputSystem;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  void Update()
  {
   TrackInputDevice();TickRumble(Screen!="playing");
   if(arrivalActive)return;
   var keys=Keyboard.current;var pad=Gamepad.current;
   if(keys?.f11Key.wasPressedThisFrame==true)UnityEngine.Screen.fullScreen=!UnityEngine.Screen.fullScreen;
   if(keys?.escapeKey.wasPressedThisFrame==true||pad?.startButton.wasPressedThisFrame==true){if(Screen=="playing"){Screen="pause";Sound("ui_pause_open");}else if(Screen=="pause"){Screen="playing";Sound("ui_back");}}
   MenuInput(keys,pad);DevKitInput(keys,pad);
   if(Screen=="dialogue")DialogueInput(keys,pad);
   PositionCamera(false);if(playerFill&&Player)playerFill.transform.position=Player.transform.position+new Vector3(-1.8f,2.4f,2.4f);
   bool paused=Screen!="playing"&&Screen!="dead"&&Screen!="dying"&&Screen!="death_transition";if(Player)Player.Animator.speed=paused?0:Player.PlaybackRate;foreach(var e in Enemies)e.View.Animator.speed=paused?0:e.View.PlaybackRate;
   if(Screen!="playing"||Run==null||Run.Stats.N("hp")<=0)return;
   float dt=Time.deltaTime;if(hitStop>0){comboExpires+=dt;hitStop=Mathf.Max(0,hitStop-dt);Player.Animator.speed=0;foreach(var e in Enemies)e.View.Animator.speed=0;return;}
   Player.Animator.speed=Player.PlaybackRate;foreach(var e in Enemies)e.View.Animator.speed=e.View.PlaybackRate;
   attackCd-=dt;dashCd-=dt;invulnerable-=dt;foreach(string id in Run.Cooldowns.Keys.ToArray())Run.Cooldowns[id]=Mathf.Max(0,Run.Cooldowns[id]-dt);TickDevKit();
   bool fresh=FreshGameplayInput;
   if(combatPractice&&keys?.f8Key.wasPressedThisFrame==true)TogglePracticeCrowd();
   if(combatPractice&&Run.ClassId=="revenant"&&keys?.f9Key.wasPressedThisFrame==true)practiceDashImpact=!practiceDashImpact;
   Vector2 input=pad?.leftStick.ReadValue()??Vector2.zero;if(keys!=null){input.x+=(keys.dKey.isPressed||keys.rightArrowKey.isPressed?1:0)-(keys.aKey.isPressed||keys.leftArrowKey.isPressed?1:0);input.y+=(keys.wKey.isPressed||keys.upArrowKey.isPressed?1:0)-(keys.sKey.isPressed||keys.downArrowKey.isPressed?1:0);}input=Vector2.ClampMagnitude(input,1);
   Vector3 forward=Vector3.ProjectOnPlane(Cam.transform.forward,Vector3.up).normalized,right=Cam.transform.right;right.y=0;var move=forward*input.y+right*input.x;
   // The mouse aims while it is the active device; on a gamepad the hunter acts where the left stick points (else where she faces).
   if(!usingPad&&Mouse.current!=null&&!Application.isBatchMode){var ray=Cam.ScreenPointToRay(Mouse.current.position.ReadValue());if(new Plane(Vector3.up,0).Raycast(ray,out float distance)){var target=ray.GetPoint(distance)-Player.transform.position;if(target.sqrMagnitude>.01f)aim=target.normalized;}}
   moveIntent=move;if(usingPad)aim=move.sqrMagnitude>.01f?move.normalized:Player.transform.forward;
   // Light attack: left mouse / R1. Heavy attack: right mouse / R2. Dash: Shift / Square.
   bool lightPressed=Mouse.current?.leftButton.wasPressedThisFrame==true||pad?.rightShoulder.wasPressedThisFrame==true;
   bool lightHeld=Mouse.current?.leftButton.isPressed==true||pad?.rightShoulder.isPressed==true;
   bool heavyPressed=Mouse.current?.rightButton.wasPressedThisFrame==true||pad?.rightTrigger.wasPressedThisFrame==true;
   // Vesper L1 + R2 (left Alt + right mouse): flame breath from the left hand; any other action ends it.
   bool offHandHeld=pad?.leftShoulder.isPressed==true||keys?.leftAltKey.isPressed==true;
   bool dashPressed=keys?.leftShiftKey.wasPressedThisFrame==true||keys?.rightShiftKey.wasPressedThisFrame==true||pad?.buttonWest.wasPressedThisFrame==true;
   bool skillPressed=pad!=null&&(pad.buttonNorth.wasPressedThisFrame||pad.buttonEast.wasPressedThisFrame||pad.buttonSouth.wasPressedThisFrame)||keys!=null&&(keys.qKey.wasPressedThisFrame||keys.eKey.wasPressedThisFrame||keys.spaceKey.wasPressedThisFrame);
   if(flameBreathing&&fresh&&(lightPressed||dashPressed||skillPressed||heavyPressed&&!offHandHeld))StopFlameBreath();
   if(fresh&&Run.ClassId=="vesper"&&offHandHeld&&heavyPressed&&!flameBreathing){BeginFlameBreath();heavyPressed=false;}
   if(fresh&&(keys?.leftShiftKey.wasPressedThisFrame==true||keys?.rightShiftKey.wasPressedThisFrame==true||pad?.buttonWest.wasPressedThisFrame==true)){var dashDir=move.sqrMagnitude>.01f?move:aim;if(!TryRevenantDash(dashDir))TryMageGlide(dashDir);}
   if(fresh&&revenantDashing&&lightPressed)thrustQueued=true;
   bool actionFrame=RevenantActionActive;TickRevenantDash(dt);
   // Measured planted-foot stride: new Sneak Walk 1.962 m/s, legacy Swagger .89.
   // Match that stride to the displayed body size; upgrades scale speed and playback together.
   bool walking=Run.ClassId=="revenant"&&(keys?.leftCtrlKey.isPressed==true||(pad!=null&&input.sqrMagnitude>.01f&&input.magnitude<.65f));float walkStride=Player.NobleRevenant?1.96218f:.89f;float locomotionScale=walking?(walkStride*Player.Height/1.8f)/(GameData.Stats("revenant").N("moveSpeed")*.02f):1;
   bool canMove=!actionFrame&&!RevenantActionActive&&!vesperMoveActive&&!Rooted&&(Run.ClassId=="revenant"?!Player.IsCasting:Player.Locked<=.15f);
   if(canMove){Player.transform.position=Move(Player.transform.position,move*Run.Stats.N("moveSpeed")*.02f*dt*locomotionScale);if(move.sqrMagnitude>.01f&&!(Run.ClassId=="revenant"&&Player.ContactPending))Player.transform.rotation=Quaternion.Slerp(Player.transform.rotation,Quaternion.LookRotation(move),dt*16);}
   float motionRate=Run.Stats.N("moveSpeed")/GameData.Stats(Run.ClassId).N("moveSpeed");if(Player.NobleRevenant&&!walking)motionRate=Run.Stats.N("moveSpeed")*.02f/(4.08527f*Player.Height/1.8f);
   Player.Tick(dt,canMove&&move.sqrMagnitude>.01f,motionRate,walking);TickAudioWorld(dt,canMove&&move.sqrMagnitude>.01f,walking);Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+Run.Stats.N("regenPerSecond")*dt);
   if(fresh&&keys!=null){if(keys.qKey.wasPressedThisFrame)Cast(0);if(keys.eKey.wasPressedThisFrame)Cast(1);if(keys.spaceKey.wasPressedThisFrame)Cast(2);if(keys.fKey.wasPressedThisFrame)Interact();}
   // Skills: Triangle, Circle, Cross. Cross talks or claims instead when something is in reach. L1 / L2 are free.
   if(fresh&&pad!=null){if(pad.buttonNorth.wasPressedThisFrame)Cast(0);if(pad.buttonEast.wasPressedThisFrame)Cast(1);if(pad.buttonSouth.wasPressedThisFrame){if(InteractInRange)Interact();else Cast(2);}}
   // R2 is remembered briefly, so R1, R1, R2 lands even when pressed during the second swing.
   if(fresh&&heavyPressed&&HeavyUnlocked)heavyBuffer=.45f;else heavyBuffer-=dt;
   // Tethered Blade: hold L1 (or left Alt) and press R1 (or left mouse).
   bool tetherHeld=Run.ClassId=="vesper"&&Owns("vesper_tethered_blade")&&(pad?.leftShoulder.isPressed==true||keys?.leftAltKey.isPressed==true);
   // Mage L1 + R1 (left Alt + left mouse): seize a foe and hurl it.
   if(fresh&&Run.ClassId=="mage"&&offHandHeld&&lightPressed){MageGrip();lightPressed=false;}
   if(fresh&&tetherHeld&&lightPressed&&attackCd<=0&&!vesperMoveActive&&!bladeThrown&&!RevenantActionActive)StartCoroutine(TetheredBlade());
   else if(fresh&&heavyBuffer>0&&attackCd<=0&&!vesperMoveActive){heavyBuffer=0;Attack(true);}
   else if(fresh&&lightHeld&&!tetherHeld&&!(Run.ClassId=="mage"&&offHandHeld)&&attackCd<=0)Attack();
   UpdateNavigation(dt);TickEnemies(dt);TickWaves(dt);TickPickups(dt);CheckRoomExit();
  }
  void TickWaves(float dt)
  {
   if(roomClear||waves==null||waves.Count==0)return;spawnTimer-=dt;
   var roster=(JArray)waves[waveIndex];int total=rolledWaves?roster.Count:roster.Count+Mathf.Max(0,Run.Night-1)*((room["encounter"]?["perNight"] as JArray)?.Count??0);
   if(spawnCursor<total&&Enemies.Count<(rolledWaves?RolledAliveCap:5)&&spawnTimer<=0)
   {
    string id=spawnCursor<roster.Count||rolledWaves?(string)roster[spawnCursor%roster.Count]:(string)room["encounter"]["perNight"][(spawnCursor-roster.Count)%((JArray)room["encounter"]["perNight"]).Count];
    Vector3 pos;
    if(id=="boss") // Keep the authored boss entrance; ordinary waves surround the player.
    {var points=room["markers"]["EnemySpawn"] as JArray;pos=points!=null?Point(points[spawnCursor%points.Count]):Vector3.zero;}
    else if(!TrySurroundSpawn(id,out pos)){spawnTimer=.4f;return;}
    SpawnEnemy(id,pos);spawnCursor++;spawnTimer=.55f;
   }
   if(spawnCursor>=total&&Enemies.Count==0){if(++waveIndex<waves.Count){spawnCursor=0;bool newCombo=!rolledWaves||comboStarts.Contains(waveIndex);spawnTimer=newCombo?1.6f:.9f;if(newCombo)Run.Wave++;}else{roomClear=true;Run.RoomsCleared++;OnRoomCleared();if(room.S("type")!="boss"&&HasSound("music_explore"))SetMusic("music_explore");Sound(room.S("type")=="boss"?"boss_slain":"wave_clear");if(room.S("type")=="boss"&&Run.Night>=FinalDistrict)StartCoroutine(VictoryTransition());}}
  }
 }
}
