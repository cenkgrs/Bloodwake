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
  void AdvanceDialogue(){if(dialogueHost==null)return;if(dialogueLine<DialogueCount-1){dialogueLine++;Sound("ui_click");drawnScreen=null;}else{var host=dialogueHost;EndDialogue();Screen=HostScreen(host);}}
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
   Plate(page,"Dialogue veil",0,0,1600,900,new Color(.015f,.01f,.015f,.62f));
   // Left: the host's own rig, live in its idle, framed as a bust.
   if(portrait)
   {
    float h=800,w=h*portrait.width/portrait.height;var bust=Rect(page,"Speaker bust",340-w/2,90,w,h).gameObject.AddComponent<RawImage>();bust.texture=portrait;bust.raycastTarget=false;
    // The bust is cut at the waist; let it sink into the veil instead of ending on a hard edge.
    var fade=Rect(page,"Speaker bust fade",340-w/2,90+h*.6f,w,h*.4f).gameObject.AddComponent<RawImage>();fade.texture=FadeRamp;fade.color=new Color(.015f,.01f,.015f,1);fade.raycastTarget=false;
   }
   // Right: the rectangular speech panel.
   const float x=650,y=470,w2=880,h2=330;
   Plate(page,"Dialogue panel",x,y,w2,h2,panel);Frame(page,x-18,y-18,w2+36,h2+36,false);
   Label(page,dialogueHost.S("name"),x+48,y+38,w2-96,42,32,true).color=gold;
   Plate(page,"Dialogue rule",x+48,y+88,w2-96,2,new Color(gold.r,gold.g,gold.b,.45f));
   Label(page,(string)dialogueHost["lines"][dialogueLine],x+48,y+128,w2-96,112,27);
   Label(page,$"{dialogueLine+1} / {DialogueCount}",x+48,y+h2-52,100,30,17).color=new Color(.62f,.58f,.54f);
   Label(page,"F · NEXT     ESC · CLOSE",x+150,y+h2-52,260,30,15).color=new Color(.62f,.58f,.54f);
   Button(page,last?dialogueHost.S("verb"):"NEXT",x+w2-470,y+h2-72,250,56,AdvanceDialogue);
   Button(page,"CLOSE",x+w2-206,y+h2-72,170,56,CloseDialogue);
  }
 }
}
