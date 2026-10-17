using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  JToken dialogueHost;int dialogueLine;DialoguePortrait dialoguePortrait;
  static Texture2D fadeRamp;
  // Vertical alpha ramp, transparent at the top and opaque at the bottom.
  static Texture2D FadeRamp{get{if(fadeRamp)return fadeRamp;fadeRamp=new Texture2D(1,64,TextureFormat.RGBA32,false){wrapMode=TextureWrapMode.Clamp,name="Dialogue fade"};for(int i=0;i<64;i++){float a=1-i/63f;fadeRamp.SetPixel(0,i,new Color(1,1,1,a*a*(3-2*a)));}fadeRamp.Apply();return fadeRamp;}}
  int DialogueCount=>(dialogueHost?["lines"] as JArray)?.Count??0;
  // Hosts with authored lines talk first; the last page hands over to their service.
  bool OpenDialogue(JToken host)
  {
   if(!(host["lines"] is JArray lines)||lines.Count==0)return false;
   dialogueHost=host;dialogueLine=0;Screen="dialogue";Sound("ui_select");
   // Painted art wins; otherwise a live bust of the host's own rig stands in.
   // The stage is parented to the room so leaving the room or the run clears it.
   if(dialoguePortrait)Destroy(dialoguePortrait.gameObject);dialoguePortrait=PaintedPortrait(host)?null:DialoguePortrait.Create(host.S("model"),roomRoot);return true;
  }
  // Drop-in art: Resources/ui/npc/<model>.png, a transparent bust, face near (.5,.82) unless "portraitFace" says otherwise.
  static Texture2D PaintedPortrait(JToken host)=>Resources.Load<Texture2D>("ui/npc/"+host.S("model"));
  void AdvanceDialogue(){if(dialogueHost==null)return;if(dialogueLine<DialogueCount-1){dialogueLine++;Sound("dialogue_advance");drawnScreen=null;}else{var host=dialogueHost;EndDialogue();OpenHost(host);}}
  void CloseDialogue(){EndDialogue();Screen="playing";}
  void EndDialogue(){dialogueHost=null;if(dialoguePortrait)Destroy(dialoguePortrait.gameObject);dialoguePortrait=null;}
  void DialogueInput(UnityEngine.InputSystem.Keyboard keys,UnityEngine.InputSystem.Gamepad pad)
  {
   if(keys?.escapeKey.wasPressedThisFrame==true||pad?.buttonEast.wasPressedThisFrame==true){CloseDialogue();return;}
   if(keys!=null&&(keys.fKey.wasPressedThisFrame||keys.spaceKey.wasPressedThisFrame||keys.enterKey.wasPressedThisFrame)||pad?.buttonSouth.wasPressedThisFrame==true)AdvanceDialogue();
  }
  void DrawDialogue()
  {
   if(dialogueHost==null){Screen="playing";return;}
   Texture portrait=PaintedPortrait(dialogueHost);UnityEngine.Rect faceUv=default;bool last=dialogueLine>=DialogueCount-1;
   if(portrait){var at=dialogueHost["portraitFace"] as JArray;float cx=at!=null?(float)at[0]:.5f,cy=at!=null?(float)at[1]:.82f,cw=.36f,ch=cw*portrait.width/portrait.height;faceUv=new UnityEngine.Rect(cx-cw*.5f,cy-ch*.5f,cw,ch);}
   else if(dialoguePortrait){portrait=dialoguePortrait.Texture;faceUv=dialoguePortrait.FaceUv;}
   // Layout follows art/ui-concepts/dialogue.webp: the speaker's bust on the left, a wide box along the bottom.
   Bleed(Plate(page,"Dialogue veil",0,0,1600,900,new Color(.015f,.01f,.015f,.62f)));
   if(portrait)
   {
    float h=860,w=h*portrait.width/portrait.height;var bust=Rect(page,"Speaker bust",330-w/2,40,w,h).gameObject.AddComponent<RawImage>();bust.texture=portrait;bust.raycastTarget=false;
    // The bust is cut at the waist; let it sink into the veil instead of ending on a hard edge.
    bust.material=SoftEdge(new Vector4(.18f,.4f,.22f,.04f));
   }
   const float x=124,y=598,w2=1354,h2=250;
   var box=Kit(page,"dialogue_box",x,y,w2,h2,.82f);box.raycastTarget=true;var advance=box.gameObject.AddComponent<Button>();advance.transition=Selectable.Transition.None;advance.onClick.AddListener(AdvanceDialogue);
   Label(page,dialogueHost.S("name").ToUpperInvariant(),x+58,y+10,330,52,25,true,TextAnchor.MiddleLeft).color=new Color(.88f,.8f,.72f);
   Label(page,(string)dialogueHost["lines"][dialogueLine],x+110,y+92,w2-240,100,26).color=ink;
   // Key prompts, bottom right; both are clickable.
   string next=last?dialogueHost.S("verb"):"Continue";
   void Prompt(string input,string text,float px,System.Action action)
   {
    var hit=Plate(page,text,px,y+h2-74,CapWidth(input)+14+text.Length*11,32,Color.clear);hit.raycastTarget=true;var b=hit.gameObject.AddComponent<Button>();b.transition=Selectable.Transition.None;b.onClick.AddListener(()=>action());
    InputCap(page,input,px,y+h2-74);Label(page,text,px+CapWidth(input)+12,y+h2-74,text.Length*12+20,32,19,false,TextAnchor.MiddleLeft).color=new Color(.78f,.74f,.7f);
   }
   float escX=x+w2-250;Prompt("back","Leave",escX,CloseDialogue);
   Prompt("confirm",next.Length>0?char.ToUpper(next[0])+next.Substring(1).ToLowerInvariant():"Continue",escX-60-next.Length*12-CapWidth("confirm"),AdvanceDialogue);
   Kit(page,"diamond",x+w2-112,y+h2-76,16,27);
  }
 }
}
