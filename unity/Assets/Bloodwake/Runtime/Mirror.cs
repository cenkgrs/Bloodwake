using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 // The Ashen Mirror on the sanctuary's east wall: step up to it and take another oath without
 // leaving the hall.
 public sealed partial class BloodwakeGame
 {
  bool mirrorMode;
  static Material mirrorGlass,mirrorRim;
  void BuildMirror(JToken host)
  {
   var at=Point(host["at"]);var root=new GameObject("Ashen mirror").transform;root.SetParent(roomRoot,false);
   // Stone surround against the wall, the dark glass and a blood-red rim inside it, all facing into the hall.
   var wallX=SanctuaryHalf-WallDepth*.5f;var face=new Vector3(wallX-.32f,0,at.z);
   Piece(root,"wall",new Vector3(wallX-.12f,0,at.z),new Vector3(2.1f,3.05f,.36f),90,true);
   if(!mirrorGlass){mirrorGlass=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Ashen mirror glass"};mirrorGlass.SetColor("_BaseColor",new Color(.05f,.045f,.06f));mirrorGlass.SetFloat("_Metallic",1);mirrorGlass.SetFloat("_Smoothness",.96f);}
   if(!mirrorRim){mirrorRim=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Ashen mirror rim"};mirrorRim.SetColor("_BaseColor",new Color(.2f,.01f,.02f));mirrorRim.EnableKeyword("_EMISSION");mirrorRim.SetColor("_EmissionColor",new Color(.75f,.04f,.08f)*1.6f);}
   Quad(root,"Mirror rim",face+Vector3.up*1.42f,new Vector2(1.62f,2.42f),mirrorRim);
   Quad(root,"Mirror glass",face+new Vector3(-.015f,1.42f,0),new Vector2(1.44f,2.24f),mirrorGlass);
   // Lit after RoomPresentation has given the hall's lamps their flames, so this glow stays bare.
   var glow=new GameObject("Mirror glow").AddComponent<Light>();glow.transform.SetParent(root,false);glow.transform.position=face+new Vector3(-1.1f,1.6f,0);
   glow.type=LightType.Point;glow.color=new Color(.9f,.18f,.24f);glow.intensity=3.2f;glow.range=4.5f;glow.shadows=LightShadows.None;
  }
  static void Quad(Transform root,string name,Vector3 at,Vector2 size,Material material)
  {
   var quad=GameObject.CreatePrimitive(PrimitiveType.Quad);quad.name=name;Destroy(quad.GetComponent<Collider>());quad.transform.SetParent(root,false);
   // A quad shows its face toward -Z; turned 90 degrees it faces -X, into the hall.
   quad.transform.SetPositionAndRotation(at,Quaternion.Euler(0,90,0));quad.transform.localScale=new Vector3(size.x,size.y,1);
   var r=quad.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
  }
  void OpenMirror(){mirrorMode=true;Screen="classes";}
  // Taking a new oath rebuilds the hunter in the hall, standing before the glass.
  void TakeMirrorOath()
  {
   mirrorMode=false;if(Run!=null&&SelectedClass==Run.ClassId){Screen="playing";return;}
   var host=room?["hosts"]?.FirstOrDefaultRole("mirror");StartRun(SelectedClass);
   if(host!=null){Player.transform.position=Point(host["at"])+new Vector3(-1.4f,0,0);Player.transform.rotation=Quaternion.LookRotation(Vector3.right);PositionCamera(true);}
   RevFx.Flash(Player.transform.position+Vector3.up,new Color(.9f,.18f,.24f),2.2f,3,.4f);Sound("ui_begin_hunt");
  }
  void LeaveMirror(){mirrorMode=false;Screen="playing";}
 }
 static class HostQuery
 {
  public static JToken FirstOrDefaultRole(this JToken hosts,string role){foreach(var h in hosts)if(h.S("role")==role)return h;return null;}
 }
}
