using System.Linq;
using System.Text.RegularExpressions;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 public static class EnvironmentDetails
 {
  static GameObject Spawn(string id,Transform root,Vector3 position,Quaternion rotation)
  {
   string file=id=="gate"?"gate_articulated":id;var source=Resources.Load<GameObject>("Environment/Kit01/"+id+"/"+file);if(!source)return null;
   var go=Object.Instantiate(source,root);go.name="User "+id;go.transform.SetPositionAndRotation(position,rotation);return go;
  }
  static Vector3 Inward(Vector3 p,Vector2 half)=>Mathf.Abs(p.x)-half.x>Mathf.Abs(p.z)-half.y?Vector3.left*Mathf.Sign(p.x):Vector3.back*Mathf.Sign(p.z);
  public static void Apply(Transform room,BloodwakeGame game,Vector2 half,JToken layout)
  {
   var root=new GameObject("User courtyard details").transform;root.SetParent(room,false);
   int walls=0,fires=0,lanterns=0,tables=0,gates=0;
   var slots=room.GetComponentsInChildren<Transform>().ToArray();
   var lamps=room.GetComponentsInChildren<Light>().ToArray();
   foreach(var slot in slots)
   {
    if(!slot.gameObject.activeInHierarchy||slot.IsChildOf(room.Find("User courtyard models")))continue;
    var renderers=slot.GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray();if(renderers.Length==0)continue;
    if(Regex.IsMatch(slot.name,@"^Wall[\d_.]*$"))
    {
     var old=EnvironmentDressing.BoundsOf(renderers);var inward=Inward(old.center,half);bool side=Mathf.Abs(inward.x)>.5f;
     float width=side?old.size.z:old.size.x;int count=Mathf.Max(1,Mathf.RoundToInt(width/2.8f));
     for(int i=0;i<count;i++)
     {
      var obj=Spawn("wall",root,Vector3.zero,Quaternion.LookRotation(inward));if(!obj)continue;
      var b=EnvironmentDressing.BoundsOf(obj.GetComponentsInChildren<Renderer>());
      float widthScale=width/count/(side?b.size.z:b.size.x),heightScale=Mathf.Min(3.4f,old.size.y)/b.size.y;
      obj.transform.localScale=new Vector3(widthScale,heightScale,Mathf.Min(1.1f,(side?old.size.x:old.size.z)/(side?b.size.x:b.size.z)));
      var p=old.center;p.y=0;if(side)p.z=old.min.z+(i+.5f)*width/count;else p.x=old.min.x+(i+.5f)*width/count;obj.transform.position=p;walls++;
     }
     foreach(var r in renderers)r.enabled=false;
    }
    else if(Regex.IsMatch(slot.name,@"^LampPost[\d_.]*$"))
    {
     var obj=Spawn("brazier",root,new Vector3(slot.position.x,0,slot.position.z),Quaternion.identity);if(!obj)continue;
     // Match the original post's 0.3 m collision radius.
     var b=EnvironmentDressing.BoundsOf(obj.GetComponentsInChildren<Renderer>());float scale=Mathf.Min(1,.59f/Mathf.Max(b.size.x,b.size.z));obj.transform.localScale*=scale;
     foreach(var r in renderers)r.enabled=false;
     var light=slot.GetComponentInChildren<Light>();if(light){light.transform.position=obj.transform.position+Vector3.up*1.32f*scale;light.gameObject.name="Brazier light";}
     fires++;
    }
    else if(slot.name=="ExitDoor"||slot.name=="EntranceDoor")
    {
     var obj=Spawn("gate",root,slot.position,Quaternion.LookRotation(Inward(slot.position,half)));if(!obj)continue;
     var b=EnvironmentDressing.BoundsOf(obj.GetComponentsInChildren<Renderer>());bool side=Mathf.Abs(slot.position.x)>=half.x-.5f;
     var old=EnvironmentDressing.BoundsOf(renderers);float width=side?b.size.z:b.size.x;float desired=side?old.size.z:old.size.x;
     obj.transform.localScale=new Vector3(desired/width,Mathf.Min(old.size.y,5.2f)/b.size.y,1.25f);
     foreach(var r in renderers)if(r.bounds.center.y>.05f)r.enabled=false;
     var animated=obj.AddComponent<CourtyardGate>();animated.Game=game;animated.Exit=slot.name=="ExitDoor";animated.Left=obj.transform.Find("Left leaf");animated.Right=obj.transform.Find("Right leaf");gates++;
    }
    else if(slot.name=="WarTable"||(slot.childCount>1&&!slot.GetComponent<Renderer>()&&(layout??new JArray()).Any(r=>r.S("kind")=="stall"&&Vector3.Distance(slot.position,new Vector3(-(float)r["at"][0],0,(float)r["at"][1]))<.02f)))
    {
     var counter=renderers.Where(r=>r.bounds.size.y>.4f&&r.bounds.size.x>.8f&&r.bounds.size.z>.8f&&r.bounds.max.y<2).OrderByDescending(r=>r.bounds.size.x*r.bounds.size.z).FirstOrDefault();if(!counter)continue;
     var obj=Spawn("cloth",root,Vector3.zero,Quaternion.identity);if(!obj)continue;var b=EnvironmentDressing.BoundsOf(obj.GetComponentsInChildren<Renderer>());var old=counter.bounds;
     obj.transform.localScale=new Vector3(old.size.x/b.size.x,old.size.y/b.size.y,old.size.z/b.size.z);obj.transform.position=new Vector3(old.center.x,old.min.y,old.center.z);counter.enabled=false;if(slot.name=="WarTable")foreach(var r in renderers)r.enabled=false;tables++;
    }
   }
   foreach(var lamp in lamps)
   {
    if(lamp.name=="Brazier light")continue;
    var obj=Spawn("lantern",root,lamp.transform.position-Vector3.up*.22f,Quaternion.LookRotation(Inward(lamp.transform.position,half)));if(!obj)continue;obj.transform.localScale=Vector3.one*1.25f;lanterns++;
   }
   // The source boxes represented flames; RoomPresentation provides animated fire.
   foreach(var r in room.GetComponentsInChildren<MeshRenderer>())if(r.enabled&&r.sharedMaterial&&r.sharedMaterial.name.ToLowerInvariant().StartsWith("flame"))r.enabled=false;
   Debug.Log($"BLOODWAKE_DETAILS {room.name} walls={walls} braziers={fires} lanterns={lanterns} tables={tables} gates={gates}");
  }
 }
 public sealed class CourtyardGate:MonoBehaviour
 {
  public BloodwakeGame Game;public bool Exit;public Transform Left,Right;
  float openness;
  void LateUpdate(){float target=!Exit||Game.ExitOpen?1:0;openness=Mathf.MoveTowards(openness,target,Game.VfxDelta*1.7f);Left.localRotation=Quaternion.Euler(0,-105*openness,0);Right.localRotation=Quaternion.Euler(0,105*openness,0);}
 }
}
