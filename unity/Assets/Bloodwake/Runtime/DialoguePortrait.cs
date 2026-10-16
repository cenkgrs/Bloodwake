using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 // A small lit stage far below the level: the host's own rig plays its idle
 // and a bust camera renders it into a transparent texture for the dialogue UI.
 public sealed class DialoguePortrait:MonoBehaviour
 {
  static readonly Vector3 StageOrigin=new(0,-500,0);
  public RenderTexture Texture {get;private set;}
  public Rect FaceUv {get;private set;}
  Camera bust;Transform head,hips;Animator animator;
  public static DialoguePortrait Create(string model,Transform parent)
  {
   var prefab=Resources.Load<GameObject>("Actors/enemy_"+model);if(!prefab)return null;
   var stage=new GameObject("Dialogue portrait stage").AddComponent<DialoguePortrait>();stage.transform.SetParent(parent,false);stage.transform.position=StageOrigin;
   stage.Build(prefab);return stage;
  }
  void Build(GameObject prefab)
  {
   var actor=Instantiate(prefab,transform);actor.transform.localPosition=Vector3.zero;
   // Three-quarter view reads better than a straight-on mugshot.
   actor.transform.localRotation=Quaternion.Euler(0,-24,0);
   animator=actor.GetComponentInChildren<Animator>();if(animator){animator.applyRootMotion=false;animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;animator.Rebind();animator.Update(0);}
   var bones=actor.GetComponentsInChildren<Transform>();head=bones.FirstOrDefault(b=>b.name.EndsWith("Head"));hips=bones.FirstOrDefault(b=>b.name.EndsWith("Hips"));
   Texture=new RenderTexture(860,1000,24,RenderTextureFormat.ARGB32){antiAliasing=4,name="Dialogue portrait"};
   bust=new GameObject("Bust camera").AddComponent<Camera>();bust.transform.SetParent(transform,false);bust.fieldOfView=22;bust.nearClipPlane=.1f;bust.farClipPlane=12;
   bust.clearFlags=CameraClearFlags.SolidColor;bust.backgroundColor=new Color(0,0,0,0);bust.targetTexture=Texture;bust.depth=-10;
   var data=bust.GetUniversalAdditionalCameraData();data.renderPostProcessing=false;data.renderShadows=false;
   // Warm key from the front-left, cool rim behind, low fill so the far side keeps some form.
   Lamp("Key",new Vector3(-1.4f,2.4f,1.9f),new Color(1f,.82f,.66f),9,5);
   Lamp("Rim",new Vector3(1.2f,2.3f,-1.4f),new Color(.62f,.72f,1f),11,4);
   Lamp("Fill",new Vector3(1.6f,1.1f,1.8f),new Color(.75f,.55f,.55f),2.2f,5);
   Frame();
  }
  void Lamp(string name,Vector3 at,Color color,float intensity,float range)
  {
   var light=new GameObject(name+" light").AddComponent<Light>();light.transform.SetParent(transform,false);light.transform.localPosition=at;
   light.type=LightType.Point;light.color=color;light.intensity=intensity;light.range=range;light.shadows=LightShadows.None;
  }
  // Head to waist, framed once from the idle's first pose so the camera holds still while the body breathes.
  void Frame()
  {
   if(!head||!hips)return;var top=head.position+Vector3.up*.2f;var bottom=Vector3.Lerp(hips.position,head.position,-.12f);
   var centre=(top+bottom)*.5f;float extent=(top.y-bottom.y)*1.22f;float distance=extent*.5f/Mathf.Tan(bust.fieldOfView*.5f*Mathf.Deg2Rad);
   bust.transform.position=centre+Vector3.forward*distance+Vector3.up*extent*.06f;bust.transform.LookAt(centre);
   var face=bust.WorldToViewportPoint(head.position+Vector3.up*.06f);float w=.42f,h=w*Texture.width/Texture.height;FaceUv=new Rect(face.x-w*.5f,face.y-h*.5f,w,h);
  }
  void OnDestroy(){if(bust)bust.targetTexture=null;if(Texture){Texture.Release();Destroy(Texture);}}
 }
}
