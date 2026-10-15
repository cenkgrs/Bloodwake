using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  readonly Dictionary<Enemy,Image> worldBars=new();readonly List<Text> skillLabels=new();
  void DrawHUD()
  {
   worldBars.Clear();skillLabels.Clear();
   DrawVitalityHUD();
   runLabel=Label(page,"",940,42,620,90,21,false,TextAnchor.UpperRight);promptLabel=Label(page,"",350,680,900,65,24,false,TextAnchor.MiddleCenter);
   var cls=GameData.Rules["classes"][Run.ClassId];
   for(int i=0;i<3;i++)
   {
    string id=i==2?cls.S("ability"):(string)cls["skills"][i];float x=590+i*140;
    Plate(page,id,x+24,765,88,86,Color.black);
    Art(page,"ui/class_screen/abilities/"+id,x+25,766,85,84);
    Art(page,"Presentation/HUD/skill-frame-v3",x,741,140,140);
    var text=Label(page,i==2?"SPACE":i==0?"Q":"E",x,877,140,21,15,false,TextAnchor.MiddleCenter);skillLabels.Add(text);
   }
   Label(page,"WASD  MOVE    LMB  ATTACK    RMB / SHIFT + LMB  HEAVY",45,825,535,45,16);Label(page,"F  INTERACT     ESC  PAUSE",1170,840,390,35,17,false,TextAnchor.MiddleRight);
  }
  void DrawVitalityHUD()
  {
   const float x=18,y=4;
   Plate(page,"Empty vitality",x+116,y+67,320,24,new Color(.055f,.007f,.014f));
   healthFill=Plate(page,"Health",x+116,y+67,320,24,new Color(.55f,.012f,.034f));
   var shine=Plate(healthFill.transform,"Blood highlight",0,3,320,4,new Color(1,.12f,.16f,.45f));shine.rectTransform.anchorMax=new Vector2(1,1);shine.rectTransform.sizeDelta=new Vector2(0,4);
   var shade=Plate(healthFill.transform,"Blood lower shadow",0,19,320,5,new Color(.12f,0,.012f,.7f));shade.rectTransform.anchorMax=new Vector2(1,1);shade.rectTransform.sizeDelta=new Vector2(0,5);
   var portrait=Rect(page,"Oath portrait",x+27,y+35,68,90);portrait.gameObject.AddComponent<PortraitMask>();portrait.gameObject.AddComponent<Mask>().showMaskGraphic=false;
   var image=Rect(portrait,"Portrait",0,0,68,90).gameObject.AddComponent<RawImage>();image.texture=Resources.Load<Texture2D>("ui/portraits/"+Run.ClassId);image.raycastTarget=false;
   // Each source is a full-body 2:3 painting. Crop around its own face,
   // preserving pixels' aspect ratio inside the oval rather than stretching it.
   var face=Run.ClassId switch{"warrior"=>new Vector2(.59f,.855f),"mage"=>new Vector2(.53f,.85f),"revenant"=>new Vector2(.59f,.87f),"gunslinger"=>new Vector2(.49f,.855f),_=>new Vector2(.41f,.85f)};
   float cropWidth=Run.ClassId=="gunslinger"?.38f:.30f;
   float cropHeight=cropWidth*(90f/68)*(image.texture.width/(float)image.texture.height);
   image.uvRect=new UnityEngine.Rect(face.x-cropWidth*.5f,Mathf.Clamp(face.y-cropHeight*.5f,0,1-cropHeight),cropWidth,cropHeight);
   Art(page,"Presentation/HUD/vitality-frame-v1",x,y,480,160);
   healthLabel=Label(page,"",x+133,y+67,286,24,16,false,TextAnchor.MiddleCenter);
   Label(page,GameData.Rules["classes"][Run.ClassId].S("name").ToUpperInvariant(),x+122,y+42,285,22,16,true).color=new Color(.75f,.72f,.67f);
  }
  void UpdateSkillLabels()
  {
   UpdateInteractionPrompt();
   var cls=GameData.Rules["classes"][Run.ClassId];for(int i=0;i<skillLabels.Count;i++){string id=i==2?cls.S("ability"):(string)cls["skills"][i];float cd=Run.Cooldowns.GetValueOrDefault(id);skillLabels[i].text=cd>0?cd.ToString("0.0")+" s":i==2?"SPACE":i==0?"Q":"E";skillLabels[i].color=cd>0?Color.gray:gold;}
  }
  void UpdateWorldBars()
  {
   foreach(var enemy in worldBars.Keys.Where(e=>!Enemies.Contains(e)||e.Hp<=0||!e.View).ToArray()){if(worldBars[enemy])Destroy(worldBars[enemy].transform.parent.gameObject);worldBars.Remove(enemy);}
   foreach(var enemy in Enemies)
   {
    if(!worldBars.TryGetValue(enemy,out var fill)){var back=Plate(page,"Enemy missing health",0,0,58,6,new Color(.28f,.26f,.26f));fill=Plate(back.transform,"Enemy current health",0,0,58,6,blood);worldBars[enemy]=fill;}
    var screen=Cam.WorldToScreenPoint(enemy.View.transform.position+Vector3.up*(enemy.Id=="boss"?3.7f:2.45f));
    var canvas=uiRoot.GetComponent<Canvas>();var uiCamera=canvas.renderMode==RenderMode.ScreenSpaceOverlay?null:canvas.worldCamera;RectTransformUtility.ScreenPointToLocalPointInRectangle(page,screen,uiCamera,out var local);var rect=(RectTransform)fill.transform.parent;rect.anchoredPosition=new Vector2(local.x-29,local.y);rect.gameObject.SetActive(screen.z>0);fill.rectTransform.sizeDelta=new Vector2(58*Mathf.Clamp01(enemy.Hp/enemy.MaxHp),6);
   }
  }
 }
}
