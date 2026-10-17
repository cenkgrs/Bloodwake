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
  // UI kit pieces cut from the art-direction sheet (art/ui-concepts/kit.webp). Borders are source pixels:
  // left, bottom, right, top. Only the plain metal between the corners stretches.
  static readonly System.Collections.Generic.Dictionary<string,Vector4> kitBorders=new()
  {
   ["panel_large"]=new Vector4(95,95,95,95),["panel_small"]=new Vector4(80,80,80,80),["dialogue_box"]=new Vector4(345,95,95,100),
   ["button_primary"]=new Vector4(70,0,70,0),["button_primary_hover"]=new Vector4(70,0,70,0),["button_primary_pressed"]=new Vector4(70,0,70,0),
   ["button_secondary"]=new Vector4(70,0,70,0),["button_secondary_hover"]=new Vector4(70,0,70,0),
   ["slot"]=new Vector4(40,40,40,40),["slot_active"]=new Vector4(44,44,44,44),["slot_hollow"]=new Vector4(40,40,40,40),["slot_active_hollow"]=new Vector4(44,44,44,44),
   ["bar_frame"]=new Vector4(80,0,30,0),["bar_fill_blood"]=new Vector4(0,0,24,0),["bar_fill_ember"]=new Vector4(0,0,24,0),
  };
  Sprite SlicedSprite(string path,Vector4 border)
  {
   if(slicedSprites.TryGetValue(path,out var sprite)&&sprite)return sprite;var tex=Resources.Load<Texture2D>(path);if(!tex)return null;
   sprite=Sprite.Create(tex,new UnityEngine.Rect(0,0,tex.width,tex.height),new Vector2(.5f,.5f),100,0,SpriteMeshType.FullRect,border);sprite.name=path;slicedSprites[path]=sprite;return sprite;
  }
  Sprite KitSprite(string name)=>SlicedSprite("ui/kit/"+name,kitBorders.TryGetValue(name,out var b)?b:Vector4.zero);
  // 9-slice: ornate corners keep their painted proportions at any panel size; only the plain edges stretch.
  // border is in source pixels; scale shrinks the corners on the 1600x900 canvas.
  Image Sliced(Transform parent,string path,float x,float y,float w,float h,Vector4 border,float scale)
  {
   var sprite=SlicedSprite(path,border);if(!sprite)return null;
   var image=Rect(parent,path,x,y,w,h).gameObject.AddComponent<Image>();image.sprite=sprite;image.type=Image.Type.Sliced;image.pixelsPerUnitMultiplier=scale;image.raycastTarget=false;return image;
  }
  Image Kit(Transform parent,string name,float x,float y,float w,float h,float scale=1)
  {
   var image=Rect(parent,name,x,y,w,h).gameObject.AddComponent<Image>();image.sprite=KitSprite(name);image.raycastTarget=false;
   if(kitBorders.ContainsKey(name)){image.type=Image.Type.Sliced;image.pixelsPerUnitMultiplier=scale;}return image;
  }
  // Panel: black lacquer with forged-silver corners; its own fill is opaque.
  Image Frame(Transform parent,float x,float y,float w,float h,bool fill=true)=>Kit(parent,w*h>220000?"panel_large":"panel_small",x,y,w,h,w*h>220000?1.6f:2);
  // Silver hairline with a blood diamond at its centre.
  void Rule(Transform parent,float x,float y,float w,float alpha=.45f)
  {
   Plate(parent,"Rule",x,y,w,1,new Color(.78f,.72f,.66f,alpha));Kit(parent,"diamond",x+w/2-6,y-10,12,20);
  }
  // A keyboard key drawn as a thin silver outline, as in the art-direction HUD and dialogue frames.
  Text KeyCap(Transform parent,string key,float x,float y,float h=30)
  {
   float w=Mathf.Max(h,12+key.Length*11);var line=new Color(.7f,.66f,.62f,.75f);
   Plate(parent,"Key fill",x,y,w,h,new Color(0,0,0,.55f));Plate(parent,"Key top",x,y,w,1,line);Plate(parent,"Key bottom",x,y+h-1,w,1,line);Plate(parent,"Key left",x,y,1,h,line);Plate(parent,"Key right",x+w-1,y,1,h,line);
   var t=Label(parent,key,x,y+1,w,h-2,Mathf.RoundToInt(h*.5f),true,TextAnchor.MiddleCenter);t.color=ink;return t;
  }
  float KeyWidth(string key,float h=30)=>Mathf.Max(h,12+key.Length*11);
  void Button(Transform parent,string text,float x,float y,float w,float h,Action action)=>KitButton(parent,text,x,y,w,h,action,text!="BACK"&&text!="CLOSE"&&text!="−"&&text!="+");
  // The painted plaque is the clickable graphic, so nothing square shows behind its pointed ends.
  Button KitButton(Transform parent,string text,float x,float y,float w,float h,Action action,bool primary=true)
  {
   string kind=primary?"button_primary":"button_secondary";
   var image=Kit(parent,kind,x,y,w,h,84f/h);image.name=text;image.raycastTarget=true;
   var button=image.gameObject.AddComponent<Button>();button.targetGraphic=image;button.transition=Selectable.Transition.SpriteSwap;
   button.spriteState=new SpriteState{highlightedSprite=KitSprite(kind+"_hover"),selectedSprite=KitSprite(kind+"_hover"),pressedSprite=KitSprite(primary?"button_primary_pressed":kind)};
   var label=Label(image.transform,text,w*.14f,2,w*.72f,h-4,Mathf.RoundToInt(Mathf.Min(24,h*.4f)),true,TextAnchor.MiddleCenter);label.color=primary?new Color(.96f,.9f,.84f):ink;
   image.gameObject.AddComponent<MenuHover>().Entered=HoverSound;
   button.onClick.AddListener(()=>{ClickSound(text);action();drawnScreen=null;});return button;
  }
  // A click rebuilds the page under a still pointer, which would fire a hover right after it.
  float lastUiClick;
  void ClickSound(string text){lastUiClick=Time.unscaledTime;Sound(text is "BACK" or "CLOSE"?"ui_back":text=="BEGIN THE HUNT"?"ui_begin_hunt":text=="ENTER THE DISTRICT"?"ui_enter_district":"ui_click");}
  void HoverSound(){if(Time.unscaledTime-lastUiClick>.35f)Sound("ui_hover");}
  // Text-only menu entry; hovering turns it red and shows the sigil, like the title screen frames.
  void MenuItem(Transform parent,string text,float x,float y,float w,float h,int size,Action action)
  {
   var hit=Plate(parent,text,x-70,y,w+70,h,Color.clear);hit.raycastTarget=true;
   var marker=Rect(hit.transform,"Hover",0,0,w+70,h).gameObject;
   Kit(marker.transform,"diamond",22,h/2-14,17,28);
   var label=Label(hit.transform,text,70,0,w,h,size,true,TextAnchor.MiddleLeft);
   var hover=hit.gameObject.AddComponent<MenuHover>();hover.Label=label;hover.Marker=marker;hover.Normal=new Color(.78f,.74f,.7f);hover.Hot=new Color(.93f,.24f,.22f);hover.Entered=HoverSound;marker.SetActive(false);label.color=hover.Normal;
   var button=hit.gameObject.AddComponent<Button>();button.targetGraphic=hit;button.transition=Selectable.Transition.None;button.onClick.AddListener(()=>{ClickSound(text);action();drawnScreen=null;});
  }
  static Shader softEdgeShader;
  // Painting whose rectangle melts into the backdrop; feather is (left, bottom, right, top) fractions.
  static Material SoftEdge(Vector4 feather){if(!softEdgeShader)softEdgeShader=Resources.Load<Shader>("Presentation/SoftEdgeUI");var m=new Material(softEdgeShader){name="Soft edge"};m.SetVector("_Feather",feather);return m;}
  // Full-bleed painting, cover-cropped to the real screen, optionally darkened.
  void Backdrop(string path,float dim)
  {
   var bg=Resources.Load<Texture2D>(path);if(!bg)return;var img=Bleed(Rect(page,"Backdrop",0,0,1600,900).gameObject.AddComponent<RawImage>());img.texture=bg;img.raycastTarget=false;
   var size=img.rectTransform.sizeDelta;float screenAspect=size.x/size.y,artAspect=bg.width/(float)bg.height;
   img.uvRect=screenAspect>artAspect?new UnityEngine.Rect(0,(1-artAspect/screenAspect)*.5f,1,artAspect/screenAspect):new UnityEngine.Rect((1-screenAspect/artAspect)*.5f,0,screenAspect/artAspect,1);
   if(dim>0)Bleed(Plate(page,"Backdrop dim",0,0,1600,900,new Color(.01f,.008f,.01f,dim)));
  }
  void LateUpdate()
  {
   RebuildCargoNavigation();SyncEnemyAgents();
   EnsureUI();if(drawnScreen!=Screen||drawnPad!=ShowPad||(Screen=="playing"&&drawnClass!=Run?.ClassId)){if(page)Destroy(page.gameObject);page=Rect(uiRoot,"Screen "+Screen,0,0,1600,900);drawnScreen=Screen;drawnPad=ShowPad;drawnClass=Run?.ClassId;DrawScreen();}
   if(Screen=="playing"&&Run!=null)UpdateHUD();
   UpdateMenuFocus();
  }
  void UpdateInteractionPrompt()
  {
   if(Screen!="playing"||Run==null||!promptLabel)return;var (text,interact)=InteractionHint();promptLabel.text=text;
   if(!promptKey)return;promptKey.gameObject.SetActive(interact&&text.Length>0);
   if(interact)promptKey.anchoredPosition=new Vector2(800-Mathf.Min(900,promptLabel.preferredWidth)/2-promptKey.sizeDelta.x-14,-700);
  }
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
   if(Screen=="menu"){DrawMainMenu();return;}
   if(Screen=="classes"){DrawClasses();return;}
   if(Screen=="devkit"){DrawDevKit();return;}
   if(Run==null)Backdrop("ui/kit/menu_backdrop",.82f);else Bleed(Plate(page,"Dim world",0,0,1600,900,new Color(.015f,.01f,.015f,.86f)));
   Label(page,Screen=="progression"?"THE BLOOD SAGE":Screen.ToUpperInvariant(),70,48,1460,90,44,true,TextAnchor.MiddleCenter);Rule(page,560,143,480);
   switch(Screen)
   {
    case "hub":Button(page,"ENTER THE DISTRICT",420,240,760,70,EnterDistrict);Button(page,"OATHS / SKILL TREE",420,335,760,70,()=>Screen="progression");Button(page,"ARMORY / LOADOUTS",420,430,760,70,()=>Screen="armory");Back("playing");break;
    case "pause":Button(page,"RESUME",520,300,560,70,()=>Screen="playing");Button(page,"SETTINGS",520,400,560,70,()=>Screen="settings");Button(page,"RETURN TO TITLE",520,500,560,70,ReturnToMenu);break;
    case "upgrade":DrawUpgrades();break;
    case "merchant":DrawMerchant();break;
    case "progression":DrawSkillTree();break;
    case "armory":DrawArmory();break;
    case "settings":DrawSettings();break;
    case "dead":Label(page,$"Kills  {Run.Kills}    Rooms cleared  {Run.RoomsCleared}\nEssence  {Meta.Essence}"+(Run.EssencePending>0?$"    ·    Lost with you  {Run.EssencePending}":""),300,260,1000,130,30,false,TextAnchor.MiddleCenter);Button(page,"RETURN TO SAFEHOUSE",450,470,700,70,()=>StartRun(SelectedClass));Button(page,"RETURN TO TITLE",450,570,700,70,ReturnToMenu);break;
    case "victory":Label(page,"THE BLACK BELL FALLS SILENT",200,190,1200,60,30,true,TextAnchor.MiddleCenter).color=gold;Label(page,$"Kills  {Run.Kills}    Rooms cleared  {Run.RoomsCleared}\nEssence  {Meta.Essence}",300,280,1000,130,30,false,TextAnchor.MiddleCenter);Button(page,"RETURN TO SAFEHOUSE",450,470,700,70,()=>StartRun(SelectedClass));Button(page,"RETURN TO TITLE",450,570,700,70,ReturnToMenu);break;
   }
  }
  void Back(string target){Button(page,"BACK",70,800,250,55,()=>Screen=target);}
  void ReturnToMenu(){StopAllCoroutines();ReleaseCrowdNavigation();if(actorRoot)Destroy(actorRoot.gameObject);if(roomRoot)Destroy(roomRoot.gameObject);Enemies.Clear();Player=null;Run=null;Screen="menu";SetMusic("music_menu");}
 }
}
