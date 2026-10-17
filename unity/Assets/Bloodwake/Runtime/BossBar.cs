using System.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 // A Bellwarden's health runs across the top of the screen under its name, not over its head. A pale
 // band trails the blood fill so every hit shows how much it took.
 public sealed partial class BloodwakeGame
 {
  RectTransform bossBarRoot;Image bossBarFill,bossBarTrail;Text bossBarName;float bossTrail=1,bossTrailHold;
  const float BossBarX=330,BossBarY=34,BossBarWidth=940,BossFillInset=128,BossFillWidth=BossBarWidth-BossFillInset-52;
  void UpdateBossBar()
  {
   var boss=Enemies.FirstOrDefault(e=>e.Id=="boss"&&e.Hp>0&&e.View&&!e.Emerging);
   if(boss==null||arrivalActive){if(bossBarRoot)bossBarRoot.gameObject.SetActive(false);bossTrail=1;return;}
   if(!bossBarRoot)
   {
    bossBarRoot=Rect(page,"Boss health",0,0,1600,140);
    bossBarName=Label(bossBarRoot,"",BossBarX,BossBarY-4,BossBarWidth,34,26,true,TextAnchor.MiddleCenter);bossBarName.color=gold;
    var frameY=BossBarY+30;
    Plate(bossBarRoot,"Boss bar back",BossBarX+BossFillInset,frameY+21,BossFillWidth,20,new Color(.05f,.02f,.025f,.92f));
    bossBarTrail=Plate(bossBarRoot,"Boss bar trail",BossBarX+BossFillInset,frameY+21,BossFillWidth,20,new Color(.95f,.86f,.7f,.85f));
    bossBarFill=Kit(bossBarRoot,"bar_fill_blood",BossBarX+BossFillInset,frameY+21,BossFillWidth,20,1.7f);
    Kit(bossBarRoot,"bar_frame",BossBarX,frameY,BossBarWidth,62,1.45f);
   }
   bossBarRoot.gameObject.SetActive(true);bossBarName.text=BossVariant.S("name");
   float f=Mathf.Clamp01(boss.Hp/boss.MaxHp);
   bossBarFill.rectTransform.sizeDelta=new Vector2(Mathf.Max(f>0?14:0,BossFillWidth*f),20);bossBarFill.enabled=f>0;
   // The trail waits a moment after each hit, then drains down to the fill.
   if(bossTrail<f){bossTrail=f;bossTrailHold=0;}
   else if(bossTrail>f+.0001f){bossTrailHold+=Time.unscaledDeltaTime;if(bossTrailHold>.45f)bossTrail=Mathf.MoveTowards(bossTrail,f,Time.unscaledDeltaTime*.35f);}
   else bossTrailHold=0;
   bossBarTrail.rectTransform.sizeDelta=new Vector2(BossFillWidth*bossTrail,20);
  }
 }
}
