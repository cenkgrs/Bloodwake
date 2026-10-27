using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // Delivered models for the keep (Resources/Environment/Kit01/keep_*, see art/ASSET_REQUESTS.md section 4).
 // Where one is present it is used instead of the box version; where not, the boxes stay, so the kit can arrive
 // piece by piece. Walls and parapets come in 2 m sections laid along the stone's edge, front flush with it.
 public sealed partial class BloodwakeGame
 {
  // Extra yaw per model, for any whose decorated front does not face its local +z.
  static readonly Dictionary<string,float> keepFacing=new();
  const float KeepWallDepth=.7f;
  // A kit model with its front turned to yaw; fit stretches it to an exact size (walls), otherwise it keeps the
  // proportions the importer gave it.
  GameObject KeepModel(Transform root,string id,Vector3 at,float yaw,Vector3? fit=null)
  {
   if(!HasKit(id))return null;
   var pivot=new GameObject("Keep model "+id).transform;pivot.SetParent(root,false);
   var model=Instantiate(Resources.Load<GameObject>("Environment/Kit01/"+id+"/"+id),pivot);model.transform.localPosition=Vector3.zero;model.transform.localRotation=Quaternion.identity;
   if(fit is Vector3 size)
   {
    var b=EnvironmentDressing.BoundsOf(model.GetComponentsInChildren<Renderer>());
    model.transform.localScale=Vector3.Scale(model.transform.localScale,new Vector3(size.x/b.size.x,size.y/b.size.y,size.z/b.size.z));
    b=EnvironmentDressing.BoundsOf(model.GetComponentsInChildren<Renderer>());model.transform.localPosition-=new Vector3(b.center.x,b.min.y,b.center.z);
   }
   pivot.SetPositionAndRotation(at,Quaternion.Euler(0,yaw+(keepFacing.TryGetValue(id,out float turn)?turn:0),0));
   return model;
  }
  internal bool RewardWaiting=>RewardReady;
  // What the hunter has to find: a column of gold light and a burning ring where the spoils wait (only while
  // they do), braziers either side of the exit and a warm glow through it once it opens.
  void KeepBeacons(Transform root,float hz)
  {
   var exit=new Vector3(0,0,-hz);
   // Only where the floor runs on past them, so a narrow nave is never pinched shut.
   foreach(int side in new[]{-1,1}){var b=exit+new Vector3(side*3.3f,0,1.3f);if(KeepWalkable(b+Vector3.right*side*1.5f))KeepBrazier(root,b);}
   var open=KeepGlow(root,"Keep exit glow",exit+Vector3.forward*.6f,new Color(1,.62f,.3f),new Vector2(4.2f,5.5f));
   open.AddComponent<KeepBeacon>().Show=()=>ExitOpen;
   if(room["markers"]?["RewardPoint"]==null)return;
   var at=Point(room["markers"]["RewardPoint"]);
   var spoils=KeepGlow(root,"Keep spoils glow",at,new Color(1,.8f,.35f),new Vector2(1.6f,4.5f));
   var ring=Decal(spoils.transform,"Keep spoils ring",at,2.6f,0,medallionGlow??=GlowDecal(),.02f);
   spoils.AddComponent<KeepBeacon>().Show=()=>RewardWaiting;
  }
  static Material medallionGlow;
  static Material GlowDecal()
  {
   EnsureDetailMaterials();var m=new Material(Resources.Load<Shader>("Vfx/vfx_tex_add")){name="Keep spoils ring"};
   m.SetTexture("_MainTex",medallionMaterial.GetTexture("_BaseMap"));m.SetColor("_Tone",new Color(1,.72f,.3f,1));m.SetFloat("_Progress",.5f);m.SetFloat("_Opacity",1);return m;
  }
  // A light and a pair of crossed vertical light planes, so the glow reads from the isometric camera.
  GameObject KeepGlow(Transform root,string name,Vector3 at,Color color,Vector2 size)
  {
   var go=new GameObject(name);go.transform.SetParent(root,false);go.transform.position=at;
   var m=new Material(ShaftMaterial()){name=name};m.SetColor("_Tone",color);m.SetFloat("_Opacity",.8f);
   foreach(float yaw in new[]{45f,135f})
   {
    var q=GameObject.CreatePrimitive(PrimitiveType.Quad);q.name=name+" plane";Destroy(q.GetComponent<Collider>());q.transform.SetParent(go.transform,false);
    q.transform.SetPositionAndRotation(at+Vector3.up*size.y*.5f,Quaternion.Euler(0,yaw,0));q.transform.localScale=new Vector3(size.x,size.y,1);
    var r=q.GetComponent<MeshRenderer>();r.sharedMaterial=m;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
   }
   var light=new GameObject("Keep cold beacon light").AddComponent<Light>();light.transform.SetParent(go.transform,false);light.transform.position=at+Vector3.up*1.6f;
   light.type=LightType.Point;light.color=color;light.intensity=5;light.range=7;light.shadows=LightShadows.None;
   return go;
  }
  static float Yaw(Vector3 facing)=>Quaternion.LookRotation(facing).eulerAngles.y;
  // Wall sections along a list of stone faces (centre of the face, direction into the floor): neighbouring
  // faces pair into one 2 m section, a lone face takes a 1 m one.
  void KeepWallRuns(Transform root,List<(Vector3 face,Vector3 n,bool window)> faces,string id,string windowId,float height)
  {
   if(!HasKit(id))return;
   var used=new bool[faces.Count];int sections=0;
   for(int a=0;a<faces.Count;a++)
   {
    if(used[a])continue;used[a]=true;var (face,n,window)=faces[a];var along=Vector3.Cross(Vector3.up,n);int partner=-1;
    foreach(int side in new[]{1,-1})
    {
     for(int b=0;b<faces.Count&&partner<0;b++)if(!used[b]&&faces[b].n==n&&(faces[b].face-(face+along*side*KeepCell)).sqrMagnitude<.01f)partner=b;
     if(partner>=0)break;
    }
    float width=KeepCell;var centre=face;
    if(partner>=0){used[partner]=true;width=2*KeepCell;centre=(face+faces[partner].face)*.5f;window|=faces[partner].window;}
    string piece=window&&windowId!=null&&HasKit(windowId)?windowId:id;
    KeepModel(root,piece,centre+n*(.04f-KeepWallDepth*.5f),Yaw(n),new Vector3(width,height,KeepWallDepth));sections++;
   }
   Debug.Log("BLOODWAKE_KEEP_KIT "+id+" sections="+sections+" faces="+faces.Count);
  }
 }
 // Shows its children only while the condition holds.
 public sealed class KeepBeacon:MonoBehaviour
 {
  public System.Func<bool> Show;bool shown=true;
  void LateUpdate()
  {
   bool want=Show!=null&&Show();if(want==shown)return;shown=want;
   foreach(Transform child in transform)child.gameObject.SetActive(want);
  }
 }
}
