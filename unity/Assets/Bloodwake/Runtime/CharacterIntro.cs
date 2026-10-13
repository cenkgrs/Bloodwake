using System.Collections;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  bool introActive,arrivalActive;
  public void BeginCharacterIntro(string id,JToken map=null)
  {
   if(introActive)return;
   introActive=true;Screen="loading";
   new GameObject("Character entry transition").AddComponent<CharacterIntroDriver>().Begin(this,id,map);
  }
  public IEnumerator CharacterIntro(string id,JToken map=null)
  {
   EnsureUI();var overlay=Rect(uiRoot,"Character cinematic",0,0,1600,900);var group=overlay.gameObject.AddComponent<CanvasGroup>();
   var curtain=Plate(overlay,"Curtain",0,0,1600,900,new Color(.03f,.035f,.055f));curtain.raycastTarget=true;
   var a=Resources.Load<Texture2D>("ui/loading_cinematics/"+id+"_triptych");var b=Resources.Load<Texture2D>("ui/loading_cinematics/"+id+"_triptych_2");
   var shader=Resources.Load<Shader>("CharacterCinematic");Material material=null;
   if(a&&b&&shader){material=new Material(shader);material.SetTexture("_AtlasA",a);material.SetTexture("_AtlasB",b);var picture=Rect(overlay,"Six frame sequence",0,0,1600,900).gameObject.AddComponent<RawImage>();picture.texture=a;picture.material=material;picture.raycastTarget=false;}
   else Debug.LogError("Missing character cinematic resources: "+id);
   Plate(overlay,"Top letterbox",0,0,1600,108,Color.black);Plate(overlay,"Bottom letterbox",0,792,1600,108,Color.black);
   Label(overlay,GameData.Rules["classes"][id].S("name"),250,786,1100,49,38,true,TextAnchor.MiddleCenter).color=gold;
   string line=id=="warrior"?"STEEL ANSWERS STEEL":id=="revenant"?"BECOMING THE MIST":id=="gunslinger"?"THE HUNT IS LOADED":id=="mage"?"THE VOID TAKES SHAPE":"THE SHADOW MOVES";
   Label(overlay,line,250,836,1100,26,15,true,TextAnchor.MiddleCenter);
   Plate(overlay,"Loading track",550,880,500,2,panel);var progress=Plate(overlay,"Loading progress",550,880,0,2,blood);
   // This coroutine lives outside the game object: room creation cancels combat coroutines.
   // Render the curtain before the synchronous scene instantiation.
   yield return null;
   if(map==null)StartRun(id);
   else{Run.MapId=map.S("id");Run.Plan=map["route"].Values<string>().Concat(new[]{map.S("boss"),map.S("interlude")}).ToList();Run.RoomIndex=0;EnterRoom(Run.Plan[0]);}
   Screen="loading";
   float elapsed=0;while(elapsed<4.1f)
   {
    elapsed+=Time.unscaledDeltaTime;group.alpha=Mathf.Clamp01(elapsed/.35f);
    if(material){material.SetFloat("_Elapsed",elapsed);material.SetFloat("_Aspect",1600f/900);}
    progress.rectTransform.sizeDelta=new Vector2(500*Mathf.Clamp01(elapsed/4.1f),2);yield return null;
   }
   if(map!=null)
   {
    foreach(Transform child in overlay)Destroy(child.gameObject);yield return null;
    group.alpha=1;var shade=Plate(overlay,"Arrival curtain",0,0,1600,900,Color.black);
    var top=Plate(overlay,"Arrival top",0,0,1600,108,Color.black);var bottom=Plate(overlay,"Arrival bottom",0,792,1600,108,Color.black);
    var title=Label(overlay,room.S("name"),250,808,1100,60,28,true,TextAnchor.MiddleCenter);
    var stop=Player.transform.position;var entry=Point(room["markers"]["EntranceDoor"]);entry.x=Mathf.Clamp(entry.x,-half.x+.45f,half.x-.45f);entry.z=Mathf.Clamp(entry.z,-half.y+.45f,half.y-.45f);
    var heading=(stop-entry).normalized;if(heading.sqrMagnitude>.01f)Player.transform.rotation=Quaternion.LookRotation(heading);
    float normalZoom=Cam.orthographicSize;arrivalActive=true;float age=0;
    while(age<3.8f)
    {
     age+=Time.unscaledDeltaTime;Player.transform.position=Vector3.Lerp(entry,stop,Mathf.Clamp01(age/1.8f));Player.Tick(Time.unscaledDeltaTime,age<1.8f,.55f);
     float pullback=Mathf.SmoothStep(0,1,Mathf.InverseLerp(1.7f,3.8f,age));Cam.orthographicSize=Mathf.Lerp(3.6f,normalZoom,pullback);PositionCamera(true);
     shade.color=new Color(0,0,0,1-Mathf.SmoothStep(0,1,Mathf.Clamp01(age/.65f)));float bars=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(2.8f,3.8f,age));top.color=bottom.color=new Color(0,0,0,bars);title.color=new Color(ink.r,ink.g,ink.b,bars);yield return null;
    }
    Cam.orthographicSize=normalZoom;arrivalActive=false;Player.Tick(0,false);spawnTimer=.5f;
   }
   else{float fade=0;while(fade<.45f){fade+=Time.unscaledDeltaTime;group.alpha=1-Mathf.Clamp01(fade/.45f);yield return null;}}
   if(material)Destroy(material);Destroy(overlay.gameObject);introActive=false;Screen="playing";
  }
 }
 public sealed class CharacterIntroDriver:MonoBehaviour
 {
  public void Begin(BloodwakeGame game,string id,JToken map){StartCoroutine(Run(game,id,map));}
  IEnumerator Run(BloodwakeGame game,string id,JToken map){yield return game.CharacterIntro(id,map);Destroy(gameObject);}
 }
}
