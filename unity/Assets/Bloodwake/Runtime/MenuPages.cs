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
   string[] names={"PLAY","SETTINGS","EXIT"},details={"Choose your oath.\nEnter the cursed town.","Sound, display\nand camera.","Leave the night.\nYour progression is saved."};
   for(int i=0;i<3;i++){int index=i;float x=280+i*355;Plate(page,names[i],x,310,330,360,panel);Frame(page,x,310,330,360,false);Label(page,new[]{"I","II","III"}[i],x+50,355,230,90,56,true,TextAnchor.MiddleCenter).color=blood;Label(page,details[i],x+35,475,260,85,22,false,TextAnchor.MiddleCenter);Button(page,names[i],x+25,585,280,58,()=>{if(index==0)Screen="classes";else if(index==1)Screen="settings";else Application.Quit();});}
   Label(page,$"BLOOD ESSENCE  {Meta.Essence}",450,760,700,45,23,true,TextAnchor.MiddleCenter);
   Label(page,"WASD · MOUSE · SPACE   /   CONTROLLER SUPPORTED",350,822,900,35,16,false,TextAnchor.MiddleCenter);
  }
  void DrawClasses()
  {
   string[] ids={"revenant","vesper","warrior","mage"};var cls=GameData.Rules["classes"][SelectedClass];var dim=new Color(.62f,.58f,.54f);
   // Left: the chosen oath in full, its painting sinking into the dark at the edges.
   var art=Resources.Load<Texture2D>("ui/portraits/"+SelectedClass);
   if(art){float h=760,w=h*art.width/art.height;var hero=Rect(page,"Hero art",330-w/2,120,w,h).gameObject.AddComponent<RawImage>();hero.texture=art;hero.raycastTarget=false;
    // Feather every edge into the backdrop: the ramp is rotated so its opaque end faces outward.
    void Feather(float x,float y,float fw,float fh,float angle){var r=Rect(page,"Hero feather",x,y,fw,fh);r.pivot=new Vector2(.5f,.5f);r.anchoredPosition+=new Vector2(fw*.5f,-fh*.5f);r.localEulerAngles=new Vector3(0,0,angle);var f=r.gameObject.AddComponent<RawImage>();f.texture=FadeRamp;f.color=new Color(.02f,.015f,.02f,1);f.raycastTarget=false;}
    float left=330-w/2,band=w*.28f;
    Feather(left,120+h*.62f,w,h*.38f,0);Feather(left,120,w,h*.22f,180);
    Feather(left-(h-band)*.5f,120+(h-band)*.5f,h,band,-90);Feather(left+w-band-(h-band)*.5f,120+(h-band)*.5f,h,band,90);}
   // Right: oath selector.
   const float rx=640,rw=880;
   for(int i=0;i<ids.Length;i++)
   {
    string id=ids[i];bool on=SelectedClass==id;float x=rx+i*(rw/4),cw=rw/4-18;
    var card=Plate(page,id,x,145,cw,120,new Color(0,0,0,.6f));card.raycastTarget=true;var select=card.gameObject.AddComponent<Button>();select.targetGraphic=card;select.onClick.AddListener(()=>{SelectedClass=id;Sound("ui_click");drawnScreen=null;});
    var thumb=Rect(card.transform,"Thumb",4,4,cw-8,112);thumb.gameObject.AddComponent<RectMask2D>();var tex=Resources.Load<Texture2D>("ui/portraits/"+id);
    if(tex){float tw=cw-8,th=tw*tex.height/tex.width;var img=Rect(thumb,"Face",0,-th*.06f,tw,th).gameObject.AddComponent<RawImage>();img.texture=tex;img.raycastTarget=false;img.color=on?Color.white:new Color(.55f,.5f,.5f);}
    Frame(card.transform,0,0,cw,120,false);
    Label(page,GameData.Rules["classes"][id].S("name").ToUpperInvariant(),x,270,cw,30,18,true,TextAnchor.MiddleCenter).color=on?gold:dim;if(on)Plate(page,"Selected",x+cw*.3f,300,cw*.4f,2,gold);
   }
   // Dossier.
   Label(page,cls.S("name").ToUpperInvariant(),rx,330,rw,62,52,true);Label(page,cls.S("tag"),rx+4,392,rw,28,17,true).color=new Color(.86f,.3f,.3f);
   Plate(page,"Dossier rule",rx,428,rw,2,new Color(gold.r,gold.g,gold.b,.4f));
   Label(page,cls.S("description",cls.S("blurb")),rx,442,rw,56,19).color=new Color(.85f,.81f,.76f);
   // Stats as bars, scaled against the strongest oath.
   var all=ids.Select(GameData.Stats).ToArray();var stats=GameData.Stats(SelectedClass);
   (string label,string key,string fmt)[] rows={("HEALTH","maxHp","0"),("DAMAGE","damage","0.00"),("SPEED","moveSpeed","0"),("CRITICAL","criticalChance","0%")};
   for(int i=0;i<rows.Length;i++)
   {
    var r=rows[i];float x=rx+(i%2)*(rw/2),y=512+(i/2)*36,v=stats.N(r.key),max=Mathf.Max(.0001f,all.Max(s=>s.N(r.key)));
    Label(page,r.label,x,y,120,28,16,true).color=dim;Plate(page,"Bar back",x+130,y+10,230,8,new Color(.12f,.08f,.08f));Plate(page,"Bar",x+130,y+10,230*Mathf.Clamp01(v/max),8,new Color(.62f,.05f,.08f));
    Label(page,r.key=="criticalChance"?(v*100).ToString("0")+"%":v.ToString(r.fmt),x+368,y,70,28,16).color=ink;
   }
   // Abilities.
   Frame(page,rx-14,598,rw+28,192);
   for(int i=0;i<3;i++)
   {
    string id=i==2?cls.S("ability"):(string)cls["skills"][i];var ability=GameData.Row("abilities",id);float x=rx+12+i*(rw/3);
    Art(page,"ui/class_screen/abilities/"+id,x,622,74,74);Label(page,i==2?"SPACE":i==0?"Q":"E",x,698,74,24,14,true,TextAnchor.MiddleCenter).color=gold;
    Label(page,ability.S("name").ToUpperInvariant(),x+86,620,rw/3-104,30,19,true).color=ink;Label(page,ability.S("description"),x+86,652,rw/3-104,120,15).color=new Color(.78f,.74f,.7f);
   }
   Button(page,"BACK",rx,810,260,60,()=>Screen="menu");Button(page,"BEGIN THE HUNT",rx+rw-420,810,420,60,()=>BeginCharacterIntro(SelectedClass));
  }
  void DrawMaps()
  {
   int i=0;foreach(var map in GameData.Maps["maps"]){float y=200+i++*500;Art(page,"ui/maps/"+map.S("id"),160,y,710,455);Frame(page,145,y-15,740,485,false);Label(page,map.S("name"),940,y+40,490,100,38,true);Label(page,map.S("description"),940,y+160,490,140,23);Button(page,"ENTER DISTRICT",940,y+340,490,68,()=>BeginCharacterIntro(Run.ClassId,map));}Back("hub");
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
   var rows=GameData.Rows("skills").Where(r=>r.S("class")==""||r.S("class")== (Run?.ClassId??SelectedClass)).ToArray();var levels=(JObject)Meta.Data["levels"];var content=ScrollBody(Mathf.Ceil(rows.Length/3f)*165);
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
   Button(page,"FULLSCREEN / WINDOWED",500,420,580,60,()=>UnityEngine.Screen.fullScreen=!UnityEngine.Screen.fullScreen);Button(page,"CAMERA DISTANCE · "+Cam.orthographicSize.ToString("0.0"),500,520,580,60,()=>{Cam.orthographicSize=Cam.orthographicSize>=8.6f?DefaultZoom-1:Cam.orthographicSize+1.2f;PlayerPrefs.SetFloat("zoom",Cam.orthographicSize);});Back(Run==null?"menu":"pause");
  }
 }
}
