using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  sealed class Pickup{public GameObject Body;public string Kind;public int Amount;}
  readonly List<Pickup> pickups=new();
  void Drop(Vector3 point,string kind,int amount)
  {
   if(amount<=0)return;var go=GameObject.CreatePrimitive(PrimitiveType.Sphere);Destroy(go.GetComponent<Collider>());go.transform.SetParent(roomRoot);go.transform.position=point+Vector3.up*.18f;go.transform.localScale=Vector3.one*.15f;go.GetComponent<Renderer>().sharedMaterial=Effects.Mat(kind=="xp"?new Color(.45f,.65f,.95f):kind=="gold"?new Color(.8f,.55f,.15f):new Color(.65f,.03f,.05f));pickups.Add(new Pickup{Body=go,Kind=kind,Amount=amount});
  }
  void TickPickups(float dt)
  {
   for(int i=pickups.Count-1;i>=0;i--){var p=pickups[i];if(!p.Body){pickups.RemoveAt(i);continue;}var target=Player.transform.position+Vector3.up*.2f;float distance=Vector3.Distance(p.Body.transform.position,target);if(distance<Run.Stats.N("pickupRadius")*.02f)p.Body.transform.position=Vector3.MoveTowards(p.Body.transform.position,target,dt*8);if(distance>.5f)continue;if(p.Kind=="xp")Run.AddXp(p.Amount);else if(p.Kind=="gold")Run.Gold+=p.Amount;else Run.Stats["hp"]=Mathf.Min(Run.Stats.N("maxHp"),Run.Stats.N("hp")+p.Amount);Destroy(p.Body);pickups.RemoveAt(i);}
  }
  void Blood(Vector3 position)
  {
   Vector3 away=(position-Player.transform.position).normalized;
   for(int i=0;i<5;i++){var go=GameObject.CreatePrimitive(PrimitiveType.Sphere);Destroy(go.GetComponent<Collider>());go.name="Blood drop";go.transform.SetParent(roomRoot);go.transform.position=position+away*Random.Range(.2f,.8f)+new Vector3(Random.Range(-.3f,.3f),.025f,Random.Range(-.3f,.3f));float size=Random.Range(.09f,.25f);go.transform.localScale=new Vector3(size,.012f,size*1.3f);go.GetComponent<Renderer>().sharedMaterial=Effects.Mat(new Color(.22f,.012f,.018f));Destroy(go,12);}
  }
 }
}
