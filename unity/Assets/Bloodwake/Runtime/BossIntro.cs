using System.Collections;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 // Entering a warden's square: the camera leaves the hunter, finds the Bellwarden rising out of the
 // stone, holds on it under its name, then hands control back.
 public sealed partial class BloodwakeGame
 {
  void BeginBossIntro()=>new GameObject("Boss introduction").AddComponent<BossIntroDriver>().Begin(this);
  public IEnumerator BossIntro()
  {
   if(Run==null||room?.S("type")!="boss")yield break;
   // arrivalActive parks Update (input, waves, camera follow) for the whole sequence.
   arrivalActive=true;Screen="loading";
   var marker=room["markers"]["BossSpawn"]??(room["markers"]["EnemySpawn"] as JArray)?[0];
   SpawnEnemy("boss",marker!=null?Point(marker):Vector3.zero);spawnCursor=1;var boss=Enemies[Enemies.Count-1];
   var toPlayer=Player.transform.position-boss.View.transform.position;toPlayer.y=0;if(toPlayer.sqrMagnitude>.01f)boss.View.transform.rotation=Quaternion.LookRotation(toPlayer);
   var variant=BossVariant;
   EnsureUI();var overlay=Rect(uiRoot,"Boss introduction",0,0,1600,900);
   var top=Plate(overlay,"Top letterbox",-400,-400,2400,400,Color.black);var bottom=Plate(overlay,"Bottom letterbox",-400,900,2400,400,Color.black);
   var shade=Bleed(Plate(overlay,"Shade",0,0,1600,900,new Color(0,0,0,0)));
   var district=Label(overlay,DistrictName,250,600,1100,30,20,true,TextAnchor.MiddleCenter);
   var name=Label(overlay,variant.S("name"),150,630,1300,90,64,true,TextAnchor.MiddleCenter);
   var title=Label(overlay,variant.S("title").ToUpperInvariant(),250,724,1100,34,22,true,TextAnchor.MiddleCenter);
   var rule=Plate(overlay,"Rule",560,716,480,1,new Color(.78f,.72f,.66f,0));
   float normalZoom=Cam.orthographicSize;var from=CameraFocus(Player.transform.position);
   const float panIn=1.1f,hold=3.0f,panOut=.8f;float age=0;bool roared=false;
   while(age<panIn+hold+panOut)
   {
    float dt=Time.unscaledDeltaTime;age+=dt;
    if(boss.View&&boss.View.Emerging)boss.View.TickEmergence(dt);
    var bossFocus=boss.View?boss.View.transform.position:from;
    // In: slide to the warden and lean in. Hold: a slow push. Out: back to the hunter.
    float t=age<panIn?Mathf.SmoothStep(0,1,age/panIn):age<panIn+hold?1:1-Mathf.SmoothStep(0,1,(age-panIn-hold)/panOut);
    float push=age<panIn+hold?Mathf.Clamp01((age-panIn)/hold)*.45f:.45f*t;
    Cam.orthographicSize=Mathf.Lerp(normalZoom,5.6f-push,t);
    // Looking at a point just in front of the warden lifts it above the name card.
    var towardCamera=new Vector3(cameraOffset.x,0,cameraOffset.z).normalized;
    var focus=Vector3.Lerp(from,CameraFocus(bossFocus+towardCamera*2.2f),t);cameraRest=focus+cameraOffset;Cam.transform.SetPositionAndRotation(cameraRest,Quaternion.LookRotation(-cameraOffset,Vector3.up));
    if(!roared&&age>panIn*.8f){roared=true;Sound("boss_roar");ShakeCamera(.55f,Vector3.zero);}
    // Letterbox and card fade in over the pan, out at the end.
    float card=age<panIn?Mathf.InverseLerp(.4f,panIn,age):age<panIn+hold?1:1-Mathf.InverseLerp(panIn+hold,panIn+hold+panOut*.6f,age);
    float bars=Mathf.SmoothStep(0,1,t);top.rectTransform.anchoredPosition=new Vector2(-400,400-bars*92);bottom.rectTransform.anchoredPosition=new Vector2(-400,-900+bars*130);
    shade.color=new Color(0,0,0,.25f*card);
    district.color=new Color(.86f,.18f,.2f,card);name.color=new Color(gold.r,gold.g,gold.b,card);title.color=new Color(ink.r,ink.g,ink.b,card*.9f);rule.color=new Color(.78f,.72f,.66f,.45f*card);
    // The name settles from slightly larger as it fades in.
    name.rectTransform.localScale=Vector3.one*Mathf.Lerp(1.08f,1,Mathf.Clamp01(card));
    yield return null;
   }
   Cam.orthographicSize=normalZoom;Destroy(overlay.gameObject);
   if(boss.View)while(boss.View.Emerging)boss.View.TickEmergence(1);
   boss.Cooldown=Mathf.Max(boss.Cooldown,1.2f);arrivalActive=false;Screen="playing";PositionCamera(true);
  }
 }
 public sealed class BossIntroDriver:MonoBehaviour
 {
  public void Begin(BloodwakeGame game){StartCoroutine(Run(game));}
  IEnumerator Run(BloodwakeGame game){yield return game.BossIntro();Destroy(gameObject);}
 }
}
