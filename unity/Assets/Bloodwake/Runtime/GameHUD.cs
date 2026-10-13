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
   Plate(page,"Vitality panel",40,34,370,96,panel);Label(page,GameData.Rules["classes"][Run.ClassId].S("name"),58,42,330,36,24,true);
   Plate(page,"Missing health",60,93,320,16,new Color(.23f,.21f,.21f));healthFill=Plate(page,"Health",60,93,320,16,blood);healthLabel=Label(page,"",60,69,320,24,17,false,TextAnchor.MiddleRight);
   runLabel=Label(page,"",940,42,620,90,21,false,TextAnchor.UpperRight);promptLabel=Label(page,"",350,680,900,65,24,false,TextAnchor.MiddleCenter);
   var cls=GameData.Rules["classes"][Run.ClassId];
   for(int i=0;i<3;i++){int index=i;string id=i==2?cls.S("ability"):(string)cls["skills"][i];float x=605+i*140;Plate(page,id,x,765,115,110,panel);Art(page,"ui/class_screen/abilities/"+id,x+20,771,75,75);var text=Label(page,i==2?"SPACE":i==0?"Q":"E",x,845,115,26,18,false,TextAnchor.MiddleCenter);skillLabels.Add(text);}
   Label(page,"WASD  MOVE    LMB  ATTACK    RMB / SHIFT + LMB  HEAVY",45,825,535,45,16);Label(page,"F  INTERACT     ESC  PAUSE",1170,840,390,35,17,false,TextAnchor.MiddleRight);
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
    RectTransformUtility.ScreenPointToLocalPointInRectangle(page,screen,null,out var local);var rect=(RectTransform)fill.transform.parent;rect.anchoredPosition=new Vector2(local.x-29,local.y);rect.gameObject.SetActive(screen.z>0);fill.rectTransform.sizeDelta=new Vector2(58*Mathf.Clamp01(enemy.Hp/enemy.MaxHp),6);
   }
  }
 }
}
