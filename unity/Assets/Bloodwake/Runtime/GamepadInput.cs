using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.DualShock;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // The device the player touched last decides aim, menu focus and the button art on screen.
  bool usingPad,drawnPad;Gamepad litPad;float rumbleUntil;int lastMenuFrame=-10;
  Vector3 moveIntent;
  bool ShowPad=>usingPad&&Gamepad.current!=null;
  bool PlayStationPad=>Gamepad.current is DualShockGamepad;
  // A press that closed a menu or dialogue must not also cast, dash or attack on the frame it lands in the fight.
  bool FreshGameplayInput=>Time.frameCount-lastMenuFrame>1;
  void TrackInputDevice()
  {
   var pad=Gamepad.current;
   if(pad!=null&&pad!=litPad){litPad=pad;if(pad is DualShockGamepad ps)ps.SetLightBarColor(new Color(.55f,.02f,.04f));}
   bool padUsed=false;
   if(pad!=null)
   {
    padUsed=pad.leftStick.ReadValue().sqrMagnitude>.12f||pad.rightStick.ReadValue().sqrMagnitude>.12f;
    if(!padUsed)foreach(var control in pad.allControls)if(control is ButtonControl button&&button.wasPressedThisFrame){padUsed=true;break;}
   }
   var mouse=Mouse.current;
   // A few pixels of mouse drift (a nudged desk) should not pull the screen back to keyboard prompts.
   bool desktopUsed=Keyboard.current?.anyKey.wasPressedThisFrame==true||mouse!=null&&(mouse.delta.ReadValue().sqrMagnitude>36||mouse.leftButton.wasPressedThisFrame||mouse.rightButton.wasPressedThisFrame);
   if(padUsed)usingPad=true;else if(desktopUsed||pad==null)usingPad=false;
  }
  // Gamepad attacks go where the left stick points (or the facing); a foe just off that line pulls the swing onto it.
  void PadFacing()
  {
   if(!ShowPad||!Player)return;
   bool melee=Run.ClassId is "warrior" or "revenant" or "vesper";
   var from=Player.transform.position;var ahead=moveIntent.sqrMagnitude>.01f?moveIntent.normalized:Player.transform.forward;
   float range=melee?4.2f:12,cone=melee?35:20;Enemy best=null;float bestScore=float.MaxValue;
   foreach(var e in Enemies)
   {
    if(e.Emerging||e.Hp<=0||!e.View)continue;var to=e.View.transform.position-from;to.y=0;float distance=to.magnitude,angle=Vector3.Angle(ahead,to);
    if(distance<.01f||distance>range||angle>cone)continue;float score=distance*(1+angle/45f);if(score<bestScore){bestScore=score;best=e;}
   }
   if(best!=null){var to=best.View.transform.position-from;to.y=0;ahead=to.normalized;}
   if(ahead.sqrMagnitude<.01f)return;aim=ahead;Player.transform.rotation=Quaternion.LookRotation(ahead);
  }
  bool RumbleEnabled=>PlayerPrefs.GetInt("rumble",1)==1;
  void Rumble(float low,float high,float seconds)
  {
   var pad=Gamepad.current;if(pad==null||!usingPad||!RumbleEnabled)return;
   pad.SetMotorSpeeds(Mathf.Clamp01(low),Mathf.Clamp01(high));rumbleUntil=Mathf.Max(rumbleUntil,Time.unscaledTime+seconds);
  }
  void TickRumble(bool paused)
  {
   if(rumbleUntil<=0||!paused&&Time.unscaledTime<rumbleUntil)return;rumbleUntil=0;Gamepad.current?.SetMotorSpeeds(0,0);
  }
  void OnApplicationQuit()=>InputSystem.ResetHaptics();

  // ---- Menus: something is always focused while the gamepad drives them.
  static readonly HashSet<string> menuScreens=new(){"menu","classes","hub","maps","pause","upgrade","merchant","progression","armory","settings","dead","victory"};
  bool MenuScreen=>menuScreens.Contains(Screen);
  string focusScreen;int focusIndex=-1;GameObject focused;
  static readonly string[] preferredFocus={"BEGIN THE HUNT","RESUME","NEW RUN","CLAIM","ENTER THE DISTRICT","ENTER DISTRICT","RETURN TO SAFEHOUSE"};
  Selectable[] PageSelectables()=>page?page.GetComponentsInChildren<Selectable>().Where(s=>s.interactable&&s.gameObject.activeInHierarchy).ToArray():new Selectable[0];
  void UpdateMenuFocus()
  {
   if(Screen!="playing")lastMenuFrame=Time.frameCount;
   var events=EventSystem.current;if(!events)return;var current=events.currentSelectedGameObject;
   if(!MenuScreen){if(current)events.SetSelectedGameObject(null);return;}
   if(!ShowPad)return;
   if(current&&page&&current.transform.IsChildOf(page))
   {
    if(current!=focused){focused=current;focusScreen=Screen;focusIndex=System.Array.IndexOf(PageSelectables(),current.GetComponent<Selectable>());}
    KeepVisible(current);return;
   }
   var options=PageSelectables();if(options.Length==0)return;
   int index=-1;
   // A page rebuilt by its own button (buying, toggling) keeps the same entry focused.
   if(focusScreen==Screen&&focusIndex>=0)index=Mathf.Min(focusIndex,options.Length-1);
   else foreach(string name in preferredFocus){index=System.Array.FindIndex(options,s=>s.name==name);if(index>=0)break;}
   if(index<0)index=System.Math.Max(0,System.Array.FindIndex(options,s=>s.name!="BACK"));
   lastUiClick=Time.unscaledTime;events.SetSelectedGameObject(options[index].gameObject);
  }
  static readonly Vector3[] focusCorners=new Vector3[4];
  // Scroll lists slide just far enough to keep the focused entry inside the viewport.
  void KeepVisible(GameObject selected)
  {
   var scroll=selected.GetComponentInParent<ScrollRect>();if(!scroll||!scroll.content||!scroll.viewport)return;
   var view=scroll.viewport;((RectTransform)selected.transform).GetWorldCorners(focusCorners);
   float top=view.InverseTransformPoint(focusCorners[1]).y,bottom=view.InverseTransformPoint(focusCorners[0]).y;const float margin=12;
   float shift=top>view.rect.yMax-margin?top-(view.rect.yMax-margin):bottom<view.rect.yMin+margin?bottom-(view.rect.yMin+margin):0;
   if(Mathf.Abs(shift)>.5f){scroll.StopMovement();scroll.content.anchoredPosition-=new Vector2(0,shift);}
  }
  // Circle / B / Esc backs out of a page through its own BACK or LEAVE button.
  void MenuBack()
  {
   if(Screen=="pause"){Screen="playing";Sound("ui_back");return;}
   if(!page)return;
   foreach(var button in page.GetComponentsInChildren<Button>())if(button.name is "BACK" or "CLOSE" or "LEAVE THE STALL"){button.onClick.Invoke();return;}
  }
  void MenuInput(Keyboard keys,Gamepad pad)
  {
   if(!MenuScreen)return;
   if(pad?.buttonEast.wasPressedThisFrame==true||Screen!="pause"&&keys?.escapeKey.wasPressedThisFrame==true)MenuBack();
   if(Screen=="classes"&&pad!=null&&(pad.leftShoulder.wasPressedThisFrame||pad.rightShoulder.wasPressedThisFrame))
   {
    string[] ids={"warrior","revenant","vesper","mage"};int i=System.Array.IndexOf(ids,SelectedClass);
    SelectedClass=ids[(i+(pad.rightShoulder.wasPressedThisFrame?1:ids.Length-1))%ids.Length];Sound("ui_click");drawnScreen=null;
   }
  }

  // ---- Button prompts in the current device's art.
  static string KeyFor(string action)=>action switch{"skill0"=>"Q","skill1"=>"E","skill2"=>"SPACE","dash"=>"SHIFT","interact"=>"F","confirm"=>"F","pause"=>"ESC","back"=>"ESC","attack"=>"LMB","heavy"=>"RMB",_=>action};
  // Face buttons by position (south = Cross / A); shoulders, triggers and Options as text.
  static string PadFor(string action)=>action switch{"skill0"=>"north","skill1"=>"east","skill2"=>"south","interact"=>"south","confirm"=>"south","back"=>"east","dash"=>"west","attack"=>"R1","heavy"=>"R2","pause"=>"OPTIONS","prev"=>"L1","next"=>"R1",_=>action};
  static bool FaceButton(string control)=>control is "south" or "east" or "west" or "north";
  string PadLabel(string control)=>PlayStationPad?control:control switch{"L1"=>"LB","R1"=>"RB","L2"=>"LT","R2"=>"RT","OPTIONS"=>"MENU",_=>control};
  float CapWidth(string action,float h=30){if(!ShowPad)return KeyWidth(KeyFor(action),h);string control=PadFor(action);return FaceButton(control)?h:KeyWidth(PadLabel(control),h);}
  void InputCap(Transform parent,string action,float x,float y,float h=30)
  {
   if(!ShowPad){KeyCap(parent,KeyFor(action),x,y,h);return;}
   string control=PadFor(action);if(!FaceButton(control)){KeyCap(parent,PadLabel(control),x,y,h);return;}
   Glyph(parent,"disc",x,y,h,new Color(0,0,0,.6f));Glyph(parent,"ring",x,y,h,new Color(.7f,.66f,.62f,.75f));
   if(PlayStationPad)
   {
    var (shape,tint)=control switch{"south"=>("cross",new Color(.56f,.7f,.92f)),"east"=>("circle",new Color(.92f,.48f,.48f)),"west"=>("square",new Color(.86f,.6f,.8f)),_=>("triangle",new Color(.45f,.84f,.66f))};
    Glyph(parent,shape,x+h*.2f,y+h*.2f,h*.6f,tint);
   }
   else
   {
    var (letter,tint)=control switch{"south"=>("A",new Color(.5f,.8f,.45f)),"east"=>("B",new Color(.92f,.45f,.42f)),"west"=>("X",new Color(.45f,.62f,.92f)),_=>("Y",new Color(.92f,.8f,.4f))};
    Label(parent,letter,x,y+1,h,h-2,Mathf.RoundToInt(h*.55f),true,TextAnchor.MiddleCenter).color=tint;
   }
  }
  void Glyph(Transform parent,string shape,float x,float y,float size,Color tint)
  {var image=Rect(parent,"Pad "+shape,x,y,size,size).gameObject.AddComponent<RawImage>();image.texture=PadGlyph(shape);image.color=tint;image.raycastTarget=false;}
  static readonly Dictionary<string,Texture2D> padGlyphs=new();
  // PlayStation shapes and the round cap behind them, drawn once as anti-aliased white outlines and tinted per button.
  static Texture2D PadGlyph(string shape)
  {
   if(padGlyphs.TryGetValue(shape,out var texture)&&texture)return texture;
   const int n=64;texture=new Texture2D(n,n,TextureFormat.RGBA32,false){name="Pad "+shape,wrapMode=TextureWrapMode.Clamp};var pixels=new Color32[n*n];
   for(int y=0;y<n;y++)for(int x=0;x<n;x++)
   {
    var p=new Vector2((x+.5f)/n*2-1,(y+.5f)/n*2-1);
    float d=shape switch
    {
     "disc"=>p.magnitude-.96f,
     "ring"=>Mathf.Abs(p.magnitude-.92f)-.04f,
     "circle"=>Mathf.Abs(p.magnitude-.62f)-.12f,
     "cross"=>Mathf.Min(Segment(p,new Vector2(-.6f,-.6f),new Vector2(.6f,.6f)),Segment(p,new Vector2(-.6f,.6f),new Vector2(.6f,-.6f)))-.13f,
     "square"=>Mathf.Abs(Mathf.Max(Mathf.Abs(p.x),Mathf.Abs(p.y))-.56f)-.12f,
     _=>Mathf.Min(Segment(p,new Vector2(0,.7f),new Vector2(-.7f,-.52f)),Mathf.Min(Segment(p,new Vector2(-.7f,-.52f),new Vector2(.7f,-.52f)),Segment(p,new Vector2(.7f,-.52f),new Vector2(0,.7f))))-.12f,
    };
    pixels[y*n+x]=new Color32(255,255,255,(byte)(Mathf.Clamp01(.5f-d*n*.5f)*255));
   }
   texture.SetPixels32(pixels);texture.Apply(false,true);padGlyphs[shape]=texture;return texture;
  }
  static float Segment(Vector2 p,Vector2 a,Vector2 b){var ab=b-a;float t=Mathf.Clamp01(Vector2.Dot(p-a,ab)/ab.sqrMagnitude);return (p-(a+ab*t)).magnitude;}
 }
}
