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
  void DrawMainMenu()
  {
   Label(page,"SURVIVE THE NIGHT. CLAIM THE DAWN.",250,165,1100,40,23,false,TextAnchor.MiddleCenter);
   string[] names={"PLAY","SETTINGS","EXIT"},details={"Choose your oath.\nEnter the cursed town.","Sound, display\nand progression imports.","Leave the night.\nYour progression is saved."};
   for(int i=0;i<3;i++){int index=i;float x=280+i*355;Plate(page,names[i],x,310,330,360,panel);Art(page,"ui/class_screen/panel_frame",x,310,330,360);Label(page,new[]{"I","II","III"}[i],x+50,355,230,90,56,true,TextAnchor.MiddleCenter).color=blood;Label(page,details[i],x+35,475,260,85,22,false,TextAnchor.MiddleCenter);Button(page,names[i],x+25,585,280,58,()=>{if(index==0)Screen="classes";else if(index==1)Screen="settings";else Application.Quit();});}
   Label(page,$"BLOOD ESSENCE  {Meta.Essence}",450,760,700,45,23,true,TextAnchor.MiddleCenter);
   Label(page,"WASD · MOUSE · SPACE   /   CONTROLLER SUPPORTED",350,822,900,35,16,false,TextAnchor.MiddleCenter);
  }
  void DrawClasses()
  {
   string[] ids={"revenant","warrior","gunslinger","mage","assassin"};
   for(int i=0;i<ids.Length;i++)
   {
    string id=ids[i];float x=260+i*218;var card=Plate(page,id,x,170,204,286,SelectedClass==id?blood:panel);
    Art(card.transform,"ui/portraits/"+id,4,4,196,278);Plate(card.transform,"Name veil",4,226,196,56,new Color(0,0,0,.8f));
    Art(card.transform,"ui/class_screen/panel_frame",0,0,204,286);Label(card.transform,GameData.Rules["classes"][id].S("name"),10,240,184,35,20,true,TextAnchor.MiddleCenter);
    card.raycastTarget=true;var select=card.gameObject.AddComponent<Button>();select.targetGraphic=card;select.onClick.AddListener(()=>{SelectedClass=id;Sound("ui_click");drawnScreen=null;});
    if(SelectedClass==id){Plate(card.transform,"Selected top",6,3,192,3,blood);Plate(card.transform,"Selected bottom",6,280,192,3,blood);}
   }
   var cls=GameData.Rules["classes"][SelectedClass];
   Plate(page,"Character dossier",70,485,465,290,panel);Art(page,"ui/class_screen/panel_frame",70,485,465,290);
   Art(page,"ui/class_screen/classes/"+SelectedClass,100,513,82,82);
   Label(page,cls.S("name"),195,509,300,39,29,true);Label(page,cls.S("tag"),195,548,300,28,15).color=blood;
   Label(page,cls.S("description",cls.S("blurb")),103,604,395,66,18);
   var stats=GameData.Stats(SelectedClass);Label(page,$"HEALTH {stats.N("maxHp"):0}     DAMAGE {stats.N("damage"):0.00} ×\nSPEED {stats.N("moveSpeed"):0}       CRITICAL {stats.N("criticalChance")*100:0}%",103,688,395,58,19);
   Plate(page,"Abilities",565,485,965,290,panel);Art(page,"ui/class_screen/panel_frame",565,485,965,290);
   for(int i=0;i<3;i++)
   {
    string id=i==2?cls.S("ability"):(string)cls["skills"][i];var ability=GameData.Row("abilities",id);float x=599+i*306;
    Label(page,i==2?"SPACE":i==0?"Q":"E",x,507,285,26,16,true,TextAnchor.MiddleCenter);Art(page,"ui/class_screen/abilities/"+id,x+92,542,100,100);
    Label(page,ability.S("name"),x,650,285,42,22,true,TextAnchor.MiddleCenter);Label(page,ability.S("description"),x+12,696,261,58,17,false,TextAnchor.UpperCenter);
   }
   Button(page,"BACK",460,810,270,58,()=>Screen="menu");Button(page,"SELECT CLASS",760,810,380,58,()=>BeginCharacterIntro(SelectedClass));
  }
  void DrawMaps()
  {
   int i=0;foreach(var map in GameData.Maps["maps"]){float y=200+i++*500;Art(page,"ui/maps/"+map.S("id"),160,y,710,455);Art(page,"ui/class_screen/panel_frame",145,y-15,740,485);Label(page,map.S("name"),940,y+40,490,100,38,true);Label(page,map.S("description"),940,y+160,490,140,23);Button(page,"ENTER DISTRICT",940,y+340,490,68,()=>BeginCharacterIntro(Run.ClassId,map));}Back("hub");
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
  void DrawProgression()
  {
   var rows=GameData.Rows("skills").ToArray();var levels=(JObject)Meta.Data["levels"];var content=ScrollBody(Mathf.Ceil(rows.Length/3f)*165);
   for(int i=0;i<rows.Length;i++){var row=rows[i];string id=row.S("id");int level=(int?)levels[id]??0,cost=(int)row.N("baseCost")*(level+1),max=(int)row.N("maxLevel",3);float x=i%3*440,y=i/3*165;Label(content,row.S("name")+$"  {level}/{max}",x,y,420,40,26,true);Label(content,row.S("description"),x,y+42,410,55,18);Button(content,level>=max?"MASTERED":$"UNLOCK · {cost} ESSENCE",x,y+100,400,50,()=>{if(level>=max||Meta.Essence<cost)return;if(row["requires"]!=null&&((int?)levels[row.S("requires")]??0)<=0)return;Meta.Essence-=cost;levels[id]=level+1;Meta.Save();});}
   Label(page,$"ESSENCE {Meta.Essence}",650,810,600,45);Back(Run==null?"menu":"hub");
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
   Button(page,"FULLSCREEN / WINDOWED",500,420,580,60,()=>UnityEngine.Screen.fullScreen=!UnityEngine.Screen.fullScreen);Button(page,"CAMERA DISTANCE · "+Cam.orthographicSize.ToString("0.0"),500,520,580,60,()=>{Cam.orthographicSize=Cam.orthographicSize>=10?6:Cam.orthographicSize+1;PlayerPrefs.SetFloat("zoom",Cam.orthographicSize);});Button(page,"IMPORT GODOT / FLUTTER SAVE",500,620,580,60,()=>Screen="import save");Back(Run==null?"menu":"pause");
  }
  string importPath=System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.Personal),".local/share/godot/app_userdata/Bloodwake/bloodwake_progression.json"),importMessage="";Progression pendingImport;
  void DrawSaveImport()
  {
   Label(page,"Your original save is never modified. Importing replaces Unity progression; a backup is kept.",220,225,1160,90,24,false,TextAnchor.MiddleCenter);
   var box=Plate(page,"Save path",220,350,1160,70,panel);box.raycastTarget=true;var field=box.gameObject.AddComponent<InputField>();field.textComponent=Label(box.transform,"",18,12,1124,46,20);field.text=importPath;field.onValueChanged.AddListener(value=>{importPath=value;pendingImport=null;});
   Button(page,"READ SAVE",500,460,600,65,()=>{try{var candidate=new Progression();if(candidate.Import(System.IO.File.ReadAllText(importPath))){pendingImport=candidate;importMessage=$"Ready: {candidate.Essence} essence. Confirm to replace Unity progression.";}else importMessage="Invalid progression file. Nothing was changed.";}catch(System.Exception){importMessage="Could not read the file. Check its full path.";}});
   Label(page,importMessage,220,555,1160,75,23,false,TextAnchor.MiddleCenter);
   if(pendingImport!=null)Button(page,"CONFIRM REPLACEMENT",500,665,600,65,()=>{var previous=(JObject)Meta.Data.DeepClone();try{Meta.Data=(JObject)pendingImport.Data.DeepClone();Meta.Save();pendingImport=null;importMessage="Progression imported. It applies to the next run.";}catch(System.Exception){Meta.Data=previous;importMessage="Save failed. Current progression was restored.";}});
   Back("settings");
  }
 }
}
