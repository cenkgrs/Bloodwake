using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  RectTransform uiRoot,page;string drawnScreen,drawnClass;Font titleFont,bodyFont;Text healthLabel,runLabel,promptLabel;Image healthFill;
  readonly Color ink=new Color(.91f,.87f,.82f),gold=new Color(.84f,.68f,.39f),panel=new Color(.055f,.042f,.044f,.96f),blood=new Color(.42f,.025f,.05f);
  void EnsureUI()
  {
   if(uiRoot)return;
   var go=new GameObject("Bloodwake UI",typeof(RectTransform),typeof(Canvas),typeof(CanvasScaler),typeof(GraphicRaycaster));uiRoot=(RectTransform)go.transform;
   go.GetComponent<Canvas>().renderMode=RenderMode.ScreenSpaceOverlay;
   var scaler=go.GetComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;scaler.referenceResolution=new Vector2(1600,900);scaler.screenMatchMode=CanvasScaler.ScreenMatchMode.Expand;
   if(EventSystem.current==null)new GameObject("UI Input",typeof(EventSystem),typeof(InputSystemUIInputModule));
   titleFont=Resources.Load<Font>("art/title");bodyFont=Resources.Load<Font>("fonts/spectral");if(!bodyFont)bodyFont=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");if(!titleFont)titleFont=bodyFont;
  }
  RectTransform Rect(Transform parent,string name,float x,float y,float w,float h)
  {
   var r=(RectTransform)new GameObject(name,typeof(RectTransform)).transform;r.SetParent(parent,false);r.anchorMin=r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(x,-y);r.sizeDelta=new Vector2(w,h);
   // Screen roots keep the 1600x900 layout whole and centred; the canvas expands around it on non-16:9 screens.
   if(parent==uiRoot){r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,.5f);r.anchoredPosition=Vector2.zero;}
   return r;
  }
  // Full-screen backgrounds reach past the 1600x900 layout to the real screen edges.
  T Bleed<T>(T graphic) where T:Graphic{var r=graphic.rectTransform;r.anchorMin=r.anchorMax=r.pivot=new Vector2(.5f,.5f);r.anchoredPosition=Vector2.zero;r.sizeDelta=uiRoot.rect.size+new Vector2(4,4);return graphic;}
  Image Plate(Transform parent,string name,float x,float y,float w,float h,Color color)
  {var r=Rect(parent,name,x,y,w,h);var image=r.gameObject.AddComponent<Image>();image.color=color;image.raycastTarget=false;return image;}
  Text Label(Transform parent,string text,float x,float y,float w,float h,int size=22,bool title=false,TextAnchor align=TextAnchor.UpperLeft)
  {var r=Rect(parent,text.Split('\n')[0],x,y,w,h);var t=r.gameObject.AddComponent<Text>();t.font=title?titleFont:bodyFont;t.text=text;t.color=ink;t.fontSize=size;t.resizeTextForBestFit=true;t.resizeTextMinSize=Mathf.Min(size,14);t.resizeTextMaxSize=size;t.alignment=align;t.raycastTarget=false;return t;}
  void Art(Transform parent,string path,float x,float y,float w,float h,float alpha=1)
  {var tex=Resources.Load<Texture2D>(path);if(!tex)return;var r=Rect(parent,path,x,y,w,h);var image=r.gameObject.AddComponent<RawImage>();image.texture=tex;image.color=new Color(1,1,1,alpha);image.raycastTarget=false;}
  static readonly System.Collections.Generic.Dictionary<string,Sprite> slicedSprites=new();
  // 9-slice: ornate corners keep their painted proportions at any panel size; only the plain edges stretch.
  // border is in source pixels; scale shrinks the corners on the 1600x900 canvas.
  Image Sliced(Transform parent,string path,float x,float y,float w,float h,Vector4 border,float scale)
  {
   if(!slicedSprites.TryGetValue(path,out var sprite)||!sprite){var tex=Resources.Load<Texture2D>(path);if(!tex)return null;sprite=Sprite.Create(tex,new UnityEngine.Rect(0,0,tex.width,tex.height),new Vector2(.5f,.5f),100,0,SpriteMeshType.FullRect,border);slicedSprites[path]=sprite;}
   var image=Rect(parent,path,x,y,w,h).gameObject.AddComponent<Image>();image.sprite=sprite;image.type=Image.Type.Sliced;image.pixelsPerUnitMultiplier=scale;image.raycastTarget=false;return image;
  }
  // Panel: dark fill inset under an ornate sliced frame.
  Image Frame(Transform parent,float x,float y,float w,float h,bool fill=true)
  {
   if(fill)Plate(parent,"Panel fill",x+10,y+10,w-20,h-20,panel);
   return Sliced(parent,"ui/class_screen/panel_frame_9",x,y,w,h,new Vector4(170,170,170,170),2.6f);
  }
  void Button(Transform parent,string text,float x,float y,float w,float h,Action action)
  {
   // The painted button itself is the clickable graphic, so nothing square shows behind its pointed ends.
   var image=Sliced(parent,"ui/class_screen/button_frame_9",x,y,w,h,new Vector4(300,0,300,0),297f/h);image.name=text;image.raycastTarget=true;var button=image.gameObject.AddComponent<Button>();button.targetGraphic=image;
   var colors=button.colors;colors.normalColor=Color.white;colors.highlightedColor=new Color(1.8f,1.5f,1.3f);colors.pressedColor=new Color(.9f,.25f,.25f);button.colors=colors;
   Label(image.transform,text,w*.16f,4,w*.68f,h-8,20,true,TextAnchor.MiddleCenter);
   button.onClick.AddListener(()=>{Sound("ui_click");action();drawnScreen=null;});
  }
  void LateUpdate()
  {
   RebuildCargoNavigation();SyncEnemyAgents();
   EnsureUI();if(drawnScreen!=Screen||(Screen=="playing"&&drawnClass!=Run?.ClassId)){if(page)Destroy(page.gameObject);page=Rect(uiRoot,"Screen "+Screen,0,0,1600,900);drawnScreen=Screen;drawnClass=Run?.ClassId;DrawScreen();}
   if(Screen=="playing"&&Run!=null){healthLabel.text=$"{Run.Stats.N("hp"):0} / {Run.Stats.N("maxHp"):0}";healthFill.rectTransform.sizeDelta=new Vector2(320*Mathf.Clamp01(Run.Stats.N("hp")/Run.Stats.N("maxHp")),24);runLabel.text=$"NIGHT {Run.Night}   •   LEVEL {Run.Level}   •   GOLD {Run.Gold}\n{room.S("name")}   •   {Enemies.Count} enemies";promptLabel.text=roomClear?(room.S("type")=="safehouse"?"F  ·  WAR TABLE / ARMORY":room.S("type")=="merchant"?"F  ·  MERCHANT":"F  ·  CLAIM REWARD / CONTINUE"):"";UpdateWorldBars();UpdateSkillLabels();}
  }
  void UpdateInteractionPrompt(){if(Screen=="playing"&&Run!=null&&promptLabel)promptLabel.text=InteractionHint();}
  void DrawScreen()
  {
   if(Screen=="loading"||Screen=="dying")return;
   if(Screen=="death_transition")
   {
    Bleed(Plate(page,"Death veil",0,0,1600,900,new Color(.015f,.01f,.015f,.65f)));
    Label(page,"YOU DIED",200,345,1200,120,76,true,TextAnchor.MiddleCenter).color=new Color(.78f,.26f,.29f);
    Label(page,"THE NIGHT CLAIMED YOU",350,485,900,60,26,true,TextAnchor.MiddleCenter);return;
   }
   if(Screen=="playing"){DrawHUD();return;}
   if(Screen=="dialogue"){DrawDialogue();return;}
   if(Screen=="menu"||Screen=="classes")
   {
    // Cover-crop the square backdrop instead of stretching it to 16:9.
    var bg=Resources.Load<Texture2D>("art/arena");if(bg){var img=Bleed(Rect(page,"Backdrop",0,0,1600,900).gameObject.AddComponent<RawImage>());img.texture=bg;img.raycastTarget=false;var size=img.rectTransform.sizeDelta;float v=Mathf.Min(1,size.y/size.x*bg.width/bg.height);img.uvRect=new UnityEngine.Rect(0,(1-v)*.5f,1,v);}
    Bleed(Plate(page,"Scrim",0,0,1600,900,new Color(.02f,.015f,.02f,Screen=="classes"?.9f:.8f)));
   }
   else Bleed(Plate(page,"Dim world",0,0,1600,900,new Color(.015f,.01f,.015f,.9f)));
   if(Screen=="classes"){Label(page,"CHOOSE YOUR OATH",640,48,880,70,40,true);Plate(page,"Heading rule",640,118,880,2,gold);}
   else{Label(page,Screen=="menu"?"BLOODWAKE":Screen.ToUpperInvariant(),70,48,1460,90,Screen=="menu"?74:44,true,TextAnchor.MiddleCenter);Plate(page,"Heading rule",560,143,480,2,gold);}
   switch(Screen)
   {
    case "menu":DrawMainMenu();break;
    case "classes":DrawClasses();break;
    case "hub":Button(page,"WAR TABLE — THE CURSED TOWN",420,240,760,70,()=>Screen="maps");Button(page,"OATHS / SKILL TREE",420,335,760,70,()=>Screen="progression");Button(page,"ARMORY / LOADOUTS",420,430,760,70,()=>Screen="armory");Back("playing");break;
    case "maps":DrawMaps();break;
    case "pause":Button(page,"RESUME",520,300,560,70,()=>Screen="playing");Button(page,"SETTINGS",520,400,560,70,()=>Screen="settings");Button(page,"RETURN TO TITLE",520,500,560,70,ReturnToMenu);break;
    case "upgrade":DrawUpgrades();break;
    case "merchant":DrawMerchant();break;
    case "progression":DrawProgression();break;
    case "armory":DrawArmory();break;
    case "settings":DrawSettings();break;
    case "dead":Label(page,$"Kills  {Run.Kills}    Rooms cleared  {Run.RoomsCleared}\nEssence  {Meta.Essence}",300,260,1000,130,30,false,TextAnchor.MiddleCenter);Button(page,"RETURN TO SAFEHOUSE",450,470,700,70,()=>StartRun(SelectedClass));Button(page,"RETURN TO TITLE",450,570,700,70,ReturnToMenu);break;
   }
  }
  void Back(string target){Button(page,"BACK",70,800,250,55,()=>Screen=target);}
  void ReturnToMenu(){StopAllCoroutines();ReleaseCrowdNavigation();if(actorRoot)Destroy(actorRoot.gameObject);if(roomRoot)Destroy(roomRoot.gameObject);Enemies.Clear();Player=null;Run=null;Screen="menu";SetMusic("music_menu");}
 }
}
