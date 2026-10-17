using System.Linq;
using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  string merchantVisit="";int merchantRefreshes;System.Collections.Generic.List<JToken> merchantStock;
  // Layouts follow art/ui-concepts (1672x941 frames, x0.957 onto the 1600x900 canvas).
  void DrawMainMenu()
  {
   Backdrop("ui/kit/menu_backdrop",0);
   Art(page,"ui/kit/logo",78,40,672,187);
   Label(page,"SURVIVE THE NIGHT.  CLAIM THE DAWN.",120,228,580,32,19,true,TextAnchor.MiddleCenter).color=new Color(.8f,.76f,.72f);
   Rule(page,150,272,520,.35f);
   string[] names={"NEW RUN","SETTINGS","EXIT"};System.Action[] actions={NewRun,()=>Screen="settings",Application.Quit};
   for(int i=0;i<names.Length;i++)
   {
    float y=330+i*66;MenuItem(page,names[i],136,y,260,54,27,actions[i]);
    if(i<names.Length-1)Plate(page,"Menu rule",136,y+60,190,1,new Color(.78f,.72f,.66f,.22f));
   }
   Art(page,"ui/kit/icon_essence",70,793,28,40);
   Label(page,"BLOOD ESSENCE",110,797,170,34,17,true,TextAnchor.MiddleLeft).color=new Color(.8f,.76f,.72f);
   Label(page,Meta.Essence.ToString(),272,797,120,34,22,true,TextAnchor.MiddleLeft).color=ink;
   Label(page,"v"+Application.version,1430,858,150,28,15,false,TextAnchor.MiddleRight).color=new Color(.55f,.52f,.5f);
  }
  void DrawClasses()
  {
   string[] ids={"warrior","revenant","vesper","mage"};var cls=GameData.Rules["classes"][SelectedClass];var dim=new Color(.62f,.58f,.54f);
   Backdrop("ui/kit/menu_backdrop",.72f);
   // Left: the chosen oath in full, its painting sinking into the dark at the edges.
   var art=Resources.Load<Texture2D>("ui/portraits/"+SelectedClass);
   if(art){float h=830,w=h*art.width/art.height;var hero=Rect(page,"Hero art",470-w/2,70,w,h).gameObject.AddComponent<RawImage>();hero.texture=art;hero.raycastTarget=false;
    hero.material=SoftEdge(new Vector4(.3f,.28f,.3f,.14f));}
   Label(page,"CHOOSE YOUR OATH",74,34,560,62,44,true).color=new Color(.9f,.86f,.82f);
   Rule(page,84,104,470,.4f);
   if(ShowPad){InputCap(page,"prev",84,122,28);InputCap(page,"next",84+CapWidth("prev",28)+8,122,28);Label(page,"CHANGE OATH",84+CapWidth("prev",28)+CapWidth("next",28)+22,122,240,28,16,true,TextAnchor.MiddleLeft).color=dim;}
   // Oath tabs, top right.
   const float tabX=968,tabW=140,tabH=164,tabGap=12;
   for(int i=0;i<ids.Length;i++)
   {
    string id=ids[i];bool on=SelectedClass==id;float x=tabX+i*(tabW+tabGap),y=26;
    var hit=Plate(page,id,x,y,tabW,tabH,new Color(0,0,0,.75f));hit.raycastTarget=true;var select=hit.gameObject.AddComponent<Button>();select.targetGraphic=hit;select.transition=Selectable.Transition.None;select.onClick.AddListener(()=>{SelectedClass=id;Sound("ui_click");drawnScreen=null;});
    var thumb=Rect(hit.transform,"Thumb",8,8,tabW-16,tabH-46);thumb.gameObject.AddComponent<RectMask2D>();var tex=Resources.Load<Texture2D>("ui/portraits/"+id);
    if(tex){float tw=(tabW-16)*1.9f,th=tw*tex.height/tex.width;var img=Rect(thumb,"Face",(tabW-16-tw)*.5f,-th*.035f,tw,th).gameObject.AddComponent<RawImage>();img.texture=tex;img.raycastTarget=false;img.color=on?Color.white:new Color(.5f,.46f,.46f);}
    Kit(hit.transform,on?"slot_active_hollow":"slot_hollow",on?-6:0,on?-6:0,tabW+(on?12:0),tabH+(on?12:0),on?2.2f:2.4f);
    var tabName=Label(hit.transform,GameData.Rules["classes"][id].S("name").ToUpperInvariant(),0,tabH-38,tabW,30,16,true,TextAnchor.MiddleCenter);
    var tabHover=hit.gameObject.AddComponent<MenuHover>();tabHover.Label=tabName;tabHover.Normal=on?ink:dim;tabHover.Hot=new Color(.93f,.24f,.22f);tabHover.Entered=HoverSound;tabName.color=tabHover.Normal;
    if(on)Kit(page,"diamond",x+tabW/2-7,y+tabH-4,14,23);
   }
   // Dossier panel.
   const float px=955,py=200,pw=626,ph=690,cx=px+62,cw=pw-124;
   Frame(page,px,py,pw,ph);
   Label(page,cls.S("name").ToUpperInvariant(),cx,py+30,cw,70,60,true).color=new Color(.92f,.89f,.86f);
   Label(page,cls.S("tag"),cx+2,py+100,cw,28,19,true).color=new Color(.86f,.18f,.2f);
   Label(page,cls.S("blurb",cls.S("description")),cx+2,py+132,cw,48,15).color=new Color(.82f,.78f,.74f);
   // Stats as bars, scaled against the strongest oath.
   var all=ids.Select(GameData.Stats).ToArray();var stats=GameData.Stats(SelectedClass);
   (string label,string key)[] rows={("HEALTH","maxHp"),("POWER","damage"),("SPEED","moveSpeed"),("CRITICAL","criticalChance")};
   for(int i=0;i<rows.Length;i++)
   {
    var r=rows[i];float y=py+190+i*27,v=stats.N(r.key),max=Mathf.Max(.0001f,all.Max(s=>s.N(r.key)));
    Kit(page,"diamond",cx+6,y+3,10,17);
    Label(page,r.label,cx+30,y,120,24,15,true,TextAnchor.MiddleLeft).color=dim;
    Plate(page,"Bar back",cx+150,y+8,cw-160,8,new Color(.09f,.06f,.06f));Plate(page,"Bar edge",cx+150,y+16,cw-160,1,new Color(.5f,.46f,.44f,.35f));
    Plate(page,"Bar",cx+150,y+8,(cw-160)*Mathf.Clamp01(v/max),8,new Color(.62f,.05f,.08f));
   }
   Rule(page,cx-20,py+308,cw+40,.3f);
   // Abilities.
   for(int i=0;i<3;i++)
   {
    string id=i==2?cls.S("ability"):(string)cls["skills"][i];var ability=GameData.Row("abilities",id);float y=py+322+i*78;string input="skill"+i;
    var mask=Rect(page,"Icon mask",cx+12,y+13,50,50);mask.gameObject.AddComponent<PortraitMask>();mask.gameObject.AddComponent<Mask>().showMaskGraphic=false;
    var icon=Resources.Load<Texture2D>("ui/class_screen/abilities/"+id);if(icon){var img=Rect(mask,"Icon",-4,-4,58,58).gameObject.AddComponent<RawImage>();img.texture=icon;img.raycastTarget=false;}
    Art(page,"ui/kit/ring_hollow",cx-3,y-2,80,79);
    InputCap(page,input,cx+92,y+22,32);
    float tx=cx+92+CapWidth(input,32)+18;
    Label(page,ability.S("name").ToUpperInvariant(),tx,y+8,cx+cw-tx,28,17,true).color=ink;
    Label(page,ability.S("description"),tx,y+34,cx+cw-tx,42,14).color=new Color(.74f,.7f,.66f);
    if(i<2)Plate(page,"Ability rule",cx,y+76,cw,1,new Color(.78f,.72f,.66f,.14f));
   }
   // From the Ashen Mirror the oath is taken in the hall; from the title it starts the hunt.
   if(mirrorMode){KitButton(page,"TAKE THIS OATH",px+40,py+ph-96,pw-80,66,TakeMirrorOath);MenuItem(page,"BACK",44,826,160,46,20,LeaveMirror);}
   else{KitButton(page,"BEGIN THE HUNT",px+40,py+ph-96,pw-80,66,()=>BeginCharacterIntro(SelectedClass));MenuItem(page,"BACK",44,826,160,46,20,()=>Screen="menu");}
  }
  void DrawUpgrades()
  {
   for(int i=0;i<offers.Count;i++){var row=offers[i];float x=180+i*425;Plate(page,row.S("id"),x,240,390,440,panel);Label(page,row.S("rarity").ToUpperInvariant(),x+30,275,330,40,20);Label(page,row.S("name"),x+30,335,330,110,36,true);Label(page,row.S("description"),x+30,470,330,110);Button(page,"CLAIM",x+30,590,330,60,()=>{if(!Run.Upgrade(row.S("id")))return;if(Run.PendingLevels>0)Run.PendingLevels--;else{bossReward=false;Run.Claimed.Add(Run.Night+":"+Run.RoomIndex);}Sound("upgrade_pick");if(Run.PendingLevels>0||bossReward)PrepareReward();else Screen="playing";});}
  }
  RectTransform ScrollBody(float height)
  {
   var viewport=Rect(page,"Scroll viewport",120,205,1360,480);var hit=viewport.gameObject.AddComponent<Image>();hit.color=Color.clear;viewport.gameObject.AddComponent<RectMask2D>();var scroll=viewport.gameObject.AddComponent<ScrollRect>();scroll.horizontal=false;scroll.movementType=ScrollRect.MovementType.Clamped;scroll.scrollSensitivity=35;
   var content=Rect(viewport,"Content",0,0,1320,Mathf.Max(570,height));scroll.viewport=viewport;scroll.content=content;return content;
  }
  void DrawMerchant()
  {
   string visit=Run.Night+":"+Run.RoomIndex;if(merchantVisit!=visit||merchantStock==null){merchantVisit=visit;merchantRefreshes=0;merchantStock=Run.MerchantOffers();}
   var rows=merchantStock.ToArray();var content=ScrollBody(Mathf.Ceil(rows.Length/3f)*170);
   for(int i=0;i<rows.Length;i++){var row=rows[i];float x=i%3*440,y=i/3*170;float prior=Run.ItemGrades.GetValueOrDefault(row.S("id"));int cost=Mathf.RoundToInt(row.N("cost")*(Run.Grade-prior))+(prior>0?5:0);Label(content,row.S("name"),x,y,420,35,26,true);Label(content,row.S("description"),x,y+36,420,68,18);Button(content,prior>=Run.Grade?"OWNED":$"{(prior>0?"TEMPER":"BUY")} · {cost} GOLD",x,y+108,400,48,()=>{if(Run.Buy(row.S("id")))Sound("purchase");});}
   int refreshCost=Mathf.RoundToInt(20*Run.Grade);Button(page,$"NEW STOCK · {refreshCost} GOLD ({merchantRefreshes}/3)",130,700,600,55,()=>{if(merchantRefreshes>=3||Run.Gold<refreshCost)return;Run.Gold-=refreshCost;merchantRefreshes++;merchantStock=Run.MerchantOffers();});
   Label(page,$"GOLD {Run.Gold}  ·  GRADE {Run.Grade:0.0}",650,800,600,50);Button(page,"LEAVE THE STALL",1200,800,300,55,()=>Screen="playing");
  }
  void DrawArmory()
  {
   for(int i=0;i<3;i++){int index=i;Button(page,$"LOADOUT {i+1}"+((int)Meta.Data["activeLoadout"]==i?" · ACTIVE":""),420+i*280,150,260,45,()=>{Meta.Data["activeLoadout"]=index;Meta.Save();});}
   var rows=GameData.Rows("equipment").ToArray();var content=ScrollBody(Mathf.Ceil(rows.Length/3f)*165);var owned=(JArray)Meta.Data["ownedEquipment"];
   for(int i=0;i<rows.Length;i++){var row=rows[i];string id=row.S("id");bool has=owned.Any(x=>(string)x==id);float x=i%3*440,y=i/3*165;Label(content,row.S("name"),x,y,420,40,26,true);Label(content,row.S("description"),x,y+42,410,55,18);Button(content,has?"EQUIP":$"BUY · {row.N("cost")} ESSENCE",x,y+100,400,50,()=>{if(!has&&Meta.Essence>=row.N("cost")){Meta.Essence-=(int)row.N("cost");owned.Add(id);has=true;}if(has){Meta.Data["loadouts"][(int)Meta.Data["activeLoadout"]][row.S("slot")]=id;Meta.Save();}});}
   Label(page,$"ESSENCE {Meta.Essence}  ·  APPLIES ON NEXT RUN",450,810,1000,45);Back("hub");
  }
  void DrawSettings()
  {
   Label(page,$"MASTER VOLUME  {AudioListener.volume*100:0}%",500,250,600,50,28);Button(page,"−",500,315,140,55,()=>{AudioListener.volume=Mathf.Max(0,AudioListener.volume-.1f);PlayerPrefs.SetFloat("volume",AudioListener.volume);});Button(page,"+",940,315,140,55,()=>{AudioListener.volume=Mathf.Min(1,AudioListener.volume+.1f);PlayerPrefs.SetFloat("volume",AudioListener.volume);});
   Button(page,"FULLSCREEN / WINDOWED",500,420,580,60,()=>UnityEngine.Screen.fullScreen=!UnityEngine.Screen.fullScreen);Button(page,"CAMERA DISTANCE · "+Cam.orthographicSize.ToString("0.0"),500,520,580,60,()=>{Cam.orthographicSize=Cam.orthographicSize>=8.6f?DefaultZoom-1:Cam.orthographicSize+1.2f;PlayerPrefs.SetFloat("zoom",Cam.orthographicSize);});Button(page,"RENDER QUALITY · "+GameplayLighting.RenderScaleNames[GameplayLighting.RenderQuality],500,700,580,60,()=>GameplayLighting.RenderQuality=(GameplayLighting.RenderQuality+1)%GameplayLighting.RenderScales.Length);
   Button(page,"VIBRATION · "+(RumbleEnabled?"ON":"OFF"),500,620,580,60,()=>{PlayerPrefs.SetInt("rumble",RumbleEnabled?0:1);if(RumbleEnabled)Rumble(.4f,.6f,.18f);});
   Back(Run==null?"menu":"pause");
  }
 }
}
