using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  readonly Dictionary<Enemy,Image> worldBars=new();
  readonly List<(string id,Image sweep,Text count)> skillSlots=new();
  Text dashLabel;Image dashSweep;Text dashCount;RectTransform promptKey;
  static Sprite whiteSprite;
  static Sprite WhiteSprite=>whiteSprite?whiteSprite:whiteSprite=Sprite.Create(Texture2D.whiteTexture,new UnityEngine.Rect(0,0,4,4),new Vector2(.5f,.5f));
  // Inner opening of bar_frame (source x 76-530, y 30-56) at the 330x53 size drawn below.
  const float HealthWidth=266;
  // Layout follows art/ui-concepts/hud.webp: vitals top-left, run state top-right, abilities bottom-centre, nothing over the fight.
  void DrawHUD()
  {
   worldBars.Clear();skillSlots.Clear();dashLabel=null;dashSweep=null;dashCount=null;
   // The HUD hugs the real screen edges: the page stretches and each group keeps a 1600x900 frame pinned to its corner.
   page.anchorMin=Vector2.zero;page.anchorMax=Vector2.one;page.sizeDelta=Vector2.zero;page.anchoredPosition=Vector2.zero;
   RectTransform Corner(float ax,float ay){var r=Rect(page,"HUD frame",0,0,1600,900);r.anchorMin=r.anchorMax=r.pivot=new Vector2(ax,ay);r.anchoredPosition=Vector2.zero;return r;}
   var topLeft=Corner(0,1);var topRight=Corner(1,1);var bottom=Corner(.5f,0);var bottomRight=Corner(1,0);
   DrawVitalityHUD(topLeft);
   runLabel=Label(topRight,"",1000,14,580,30,19,true,TextAnchor.UpperRight);runLabel.color=new Color(.9f,.87f,.83f);
   roomLabel=Label(topRight,"",1000,46,580,26,16,false,TextAnchor.UpperRight);roomLabel.color=new Color(.78f,.74f,.7f);
   Rule(topRight,1390,80,190,.3f);
   promptLabel=Label(bottom,"",350,690,900,50,22,false,TextAnchor.MiddleCenter);
   promptKey=Rect(bottom,"Prompt key",0,700,CapWidth("interact"),30);InputCap(promptKey,"interact",0,0);promptKey.gameObject.SetActive(false);
   var cls=GameData.Rules["classes"][Run.ClassId];bool dash=Run.ClassId=="revenant"||Run.ClassId=="vesper";
   int count=dash?4:3;const float size=80,gap=22;float x0=800-(count*size+(count-1)*gap)/2;
   for(int i=0;i<count;i++)
   {
    float x=x0+i*(size+gap),y=752;string action=i==3?"dash":"skill"+i;
    string id=i==3?null:i==2?cls.S("ability"):(string)cls["skills"][i];
    Plate(bottom,"Slot back",x+6,y+6,size-12,size-12,Color.black);
    Art(bottom,id==null?"ui/kit/icon_dash":"ui/class_screen/abilities/"+id,x+8,y+8,size-16,size-16);
    var sweep=Rect(bottom,"Cooldown",x+8,y+8,size-16,size-16).gameObject.AddComponent<Image>();sweep.sprite=WhiteSprite;sweep.type=Image.Type.Filled;sweep.fillMethod=Image.FillMethod.Radial360;sweep.fillOrigin=(int)Image.Origin360.Top;sweep.fillClockwise=false;sweep.color=new Color(0,0,0,.72f);sweep.raycastTarget=false;sweep.fillAmount=0;
    Art(bottom,"ui/kit/slot_hollow",x-4,y-4,size+8,size+8);
    var countText=Label(bottom,"",x,y,size,size,24,true,TextAnchor.MiddleCenter);countText.color=ink;
    InputCap(bottom,action,x+size/2-CapWidth(action,24)/2,y+size+4,24);
    if(id==null){dashSweep=sweep;dashCount=countText;}else skillSlots.Add((id,sweep,countText));
   }
   // Legend, bottom right, laid out from the screen edge leftward.
   float edge=1580;
   foreach(var (action,text) in ShowPad?new[]{("pause","Pause"),("autofire","Auto-attack"),("attack","Attack")}:new[]{("pause","Pause"),("interact","Interact")})
   {
    float w=text.Length*9+6;Label(bottomRight,text,edge-w,856,w,28,16,false,TextAnchor.MiddleLeft).color=new Color(.6f,.57f,.54f);
    float cw=CapWidth(action,24);InputCap(bottomRight,action,edge-w-8-cw,858,24);edge-=w+8+cw+26;
   }
   if(combatPractice&&Run.ClassId=="revenant")dashLabel=Label(bottomRight,"",1180,820,400,30,15,false,TextAnchor.MiddleRight);
  }
  Text roomLabel;
  void DrawVitalityHUD(RectTransform page)
  {
   const float x=14,y=8;
   // Portrait inside the ring frame.
   // ring_hollow opening: 119 px across, centred at (109,107) of 219x215.
   const float ring=152,ringH=ring*215/219,hole=ring*119/219+4,cx=x+ring*109/219,cy=y+ringH*107/215;
   var portrait=Rect(page,"Oath portrait",cx-hole/2,cy-hole/2,hole,hole);portrait.gameObject.AddComponent<PortraitMask>();portrait.gameObject.AddComponent<Mask>().showMaskGraphic=false;
   var image=Rect(portrait,"Portrait",0,0,hole,hole).gameObject.AddComponent<RawImage>();image.texture=Resources.Load<Texture2D>("ui/portraits/"+Run.ClassId);image.raycastTarget=false;
   // Each source is a full-body 2:3 painting. Crop around its own face, preserving the pixels' aspect ratio.
   var face=Run.ClassId switch{"warrior"=>new Vector2(.59f,.855f),"mage"=>new Vector2(.53f,.85f),"revenant"=>new Vector2(.59f,.87f),"vesper"=>new Vector2(.5f,.86f),_=>new Vector2(.41f,.85f)};
   // Head and shoulders: a wider crop, centred a little above the face so the hair stays inside the ring.
   float cropWidth=.34f,cropHeight=cropWidth*(image.texture.width/(float)image.texture.height);
   image.uvRect=new UnityEngine.Rect(face.x-cropWidth*.5f,Mathf.Clamp(face.y+.035f-cropHeight*.5f,0,1-cropHeight),cropWidth,cropHeight);
   Art(page,"ui/kit/ring_hollow",x,y,ring,ringH);
   // Health: the forged frame with a blood fill that keeps its pointed end at any width.
   Kit(page,"bar_frame",x+ring-14,cy-26,330,53,1.7f);
   healthFill=Kit(page,"bar_fill_blood",x+ring-14+45,cy-26+18,HealthWidth,16,2.1f);
   healthLabel=Label(page,"",x+ring+324,cy-16,140,32,19,true,TextAnchor.MiddleLeft);healthLabel.color=ink;
  }
  void UpdateHUD()
  {
   float hp=Run.Stats.N("hp"),max=Run.Stats.N("maxHp");healthLabel.text=$"{hp:0} / {max:0}";
   float f=Mathf.Clamp01(hp/max);healthFill.rectTransform.sizeDelta=new Vector2(Mathf.Max(f>0?12:0,HealthWidth*f),16);healthFill.enabled=f>0;
   runLabel.text=$"{(room?.S("type")=="safehouse"?room.S("name"):DistrictName)}  ·  LEVEL {Run.Level}  ·  GOLD {Run.Gold}";
   roomLabel.text=$"{room.S("name")}  ·  {Enemies.Count} {(Enemies.Count==1?"enemy":"enemies")}";
   UpdateWorldBars();UpdateSkillLabels();
  }
  void UpdateSkillLabels()
  {
   UpdateInteractionPrompt();
   if(dashLabel)dashLabel.text="F9 · DASH DAMAGE "+(DashImpactUnlocked?"ON":"OFF");
   if(dashSweep){float total=Mathf.Max(.01f,RevenantDashCooldown);dashSweep.fillAmount=Mathf.Clamp01(dashCd/total);dashCount.text=dashCd>0?dashCd.ToString("0.0"):"";}
   foreach(var (id,sweep,count) in skillSlots)
   {
    float cd=Run.Cooldowns.GetValueOrDefault(id),total=Mathf.Max(.01f,GameData.Row("abilities",id).N("cooldown",cd));
    sweep.fillAmount=cd>0?Mathf.Clamp01(cd/total):0;count.text=cd>0?cd.ToString("0.0"):"";
   }
  }
  void UpdateWorldBars()
  {
   foreach(var enemy in worldBars.Keys.Where(e=>!Enemies.Contains(e)||e.Hp<=0||!e.View).ToArray()){if(worldBars[enemy])Destroy(worldBars[enemy].transform.parent.gameObject);worldBars.Remove(enemy);}
   foreach(var enemy in Enemies)
   {
    if(!worldBars.TryGetValue(enemy,out var fill))
    {
     var back=Plate(page,"Enemy missing health",0,0,64,7,new Color(.05f,.03f,.03f,.85f));
     Plate(back.transform,"Enemy bar edge",-1,-1,66,1,new Color(.7f,.65f,.6f,.4f));Plate(back.transform,"Enemy bar edge",-1,7,66,1,new Color(.7f,.65f,.6f,.4f));
     fill=Plate(back.transform,"Enemy current health",0,0,64,7,new Color(.72f,.04f,.07f));worldBars[enemy]=fill;
    }
    var screen=Cam.WorldToScreenPoint(enemy.View.transform.position+Vector3.up*(enemy.Id=="boss"?3.7f:2.45f));
    RectTransformUtility.ScreenPointToLocalPointInRectangle(page,screen,null,out var local);var rect=(RectTransform)fill.transform.parent;
    rect.anchoredPosition=new Vector2(local.x-page.rect.xMin-32,local.y-page.rect.yMax);rect.gameObject.SetActive(screen.z>0&&!enemy.Emerging);fill.rectTransform.sizeDelta=new Vector2(64*Mathf.Clamp01(enemy.Hp/enemy.MaxHp),7);
   }
  }
 }
}
