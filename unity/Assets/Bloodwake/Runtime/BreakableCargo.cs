using System.Collections.Generic;
using System.Linq;
using UnityEngine;
namespace Bloodwake
{
 // Added to the actual dressed wooden props, never to walls or scenery as a whole.
 public sealed class BreakableCargo:MonoBehaviour
 {
  public Bounds Footprint;public bool ReplacesFootprint;public bool Broken{get;private set;}
  public Bounds Body=>EnvironmentDressing.BoundsOf(GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray());
  public void Shatter(Vector3 impact,Transform debrisRoot)
  {
   if(Broken)return;var renderers=GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray();
   var bounds=EnvironmentDressing.BoundsOf(renderers);var materials=renderers.SelectMany(r=>r.sharedMaterials).Where(m=>m).ToArray();
   Broken=true;
   int count=Mathf.Min(16,Mathf.Max(0,256-debrisRoot.GetComponentsInChildren<CargoDebris>().Length));
   for(int i=0;i<count;i++)
   {
    var bit=GameObject.CreatePrimitive(PrimitiveType.Cube);bit.name="Wood splinter";bit.transform.SetParent(debrisRoot);
    Destroy(bit.GetComponent<Collider>());bit.GetComponent<Renderer>().sharedMaterial=materials[i%materials.Length];
    float scale=Mathf.Clamp(bounds.size.magnitude*.16f,.12f,.38f);
    bit.transform.localScale=new Vector3(scale*Random.Range(.8f,2.2f),scale*Random.Range(.12f,.28f),scale*Random.Range(.3f,.7f));
    bit.transform.position=bounds.center+Vector3.Scale(Random.insideUnitSphere,bounds.extents*.65f);
    bit.transform.rotation=Random.rotation;
    var away=bounds.center-impact;away.y=0;if(away.sqrMagnitude<.01f)away=Vector3.forward;
    var scatter=Random.insideUnitCircle*2;
    var velocity=away.normalized*Random.Range(1.5f,3.5f)+new Vector3(scatter.x,Random.Range(2,5),scatter.y);
    bit.AddComponent<CargoDebris>().Launch(velocity);
   }
   // Hide synchronously so another damage callback cannot hit it in this frame.
   gameObject.SetActive(false);Destroy(gameObject);
  }
 }
 public sealed class CargoDebris:MonoBehaviour
 {
  Vector3 velocity,spin,size;float age;BloodwakeGame game;
  public void Launch(Vector3 v){velocity=v;spin=Random.insideUnitSphere*520;size=transform.localScale;game=FindFirstObjectByType<BloodwakeGame>();}
  void Update()
  {
   if(!game||game.Screen!="playing")return;
   float dt=Mathf.Min(game.VfxDelta,.05f);if(dt<=0)return;age+=dt;
   velocity.y-=12*dt;transform.position+=velocity*dt;transform.Rotate(spin*dt,Space.World);
   float floor=size.y*.5f+.025f;
   if(transform.position.y<floor)
   {
    var p=transform.position;p.y=floor;transform.position=p;
    velocity=new Vector3(velocity.x*.65f,Mathf.Abs(velocity.y)*.24f,velocity.z*.65f);spin*=.5f;
    if(velocity.sqrMagnitude<.12f){velocity=Vector3.zero;spin=Vector3.zero;}
   }
   if(age>4)transform.localScale=size*Mathf.Clamp01(5-age);
   if(age>=5)Destroy(gameObject);
  }
 }
 public sealed partial class BloodwakeGame
 {
  readonly List<BreakableCargo> cargo=new();readonly List<Bounds> fixedCargoBlockers=new();
  bool cargoNavigationDirty;float lastWoodBreak=-999;
  void ConfigureBreakableCargo()
  {
   cargo.Clear();cargo.AddRange(roomRoot.GetComponentsInChildren<BreakableCargo>());cargoNavigationDirty=false;
   // Imported collision has one broad rectangle per stack. Replace only those
   // explicitly tagged footprints with the remaining physical wooden pieces.
   foreach(var p in cargo.Where(p=>p.ReplacesFootprint))
   {
    var foot=p.Footprint;
    blockers.RemoveAll(b=>new Vector2(b.center.x-foot.center.x,b.center.z-foot.center.z).magnitude<.6f&&
     Mathf.Abs(b.size.x-foot.size.x)<1&&Mathf.Abs(b.size.z-foot.size.z)<1);
   }
   fixedCargoBlockers.Clear();fixedCargoBlockers.AddRange(blockers);RefreshCargoBlockers();
   Debug.Log("CARGO_READY pieces="+cargo.Count);
  }
  void RefreshCargoBlockers()
  {
   blockers.Clear();blockers.AddRange(fixedCargoBlockers);
   foreach(var p in cargo)if(p&&!p.Broken){var b=p.Body;b.center=new Vector3(b.center.x,1,b.center.z);b.size=new Vector3(b.size.x,2,b.size.z);blockers.Add(b);}
  }
  void DamageCargo(Vector3 origin,float radius,Vector3 forward,float arc=360)
  {
   int broken=0;
   foreach(var p in cargo.ToArray())if(p&&!p.Broken)
   {
    var b=p.Body;var near=b.ClosestPoint(new Vector3(origin.x,b.center.y,origin.z));var delta=near-origin;delta.y=0;
    if(delta.magnitude>radius)continue;
    var centre=b.center-origin;centre.y=0;
    // Centre/corners ensure a forward fan can touch the edge of a real box,
    // but never shatter a prop wholly behind the caster.
    bool inside=arc>=360||Vector3.Angle(forward,centre)<=arc*.5f;
    for(int i=0;!inside&&i<4;i++)
    {var corner=new Vector3(i%2==0?b.min.x:b.max.x,origin.y,i<2?b.min.z:b.max.z)-origin;inside=corner.magnitude<=radius&&Vector3.Angle(forward,corner)<=arc*.5f;}
    if(!inside)continue;p.Shatter(origin,roomRoot);cargo.Remove(p);broken++;
   }
   if(broken==0)return;
   RefreshCargoBlockers();cargoNavigationDirty=true;
   if(Time.unscaledTime-lastWoodBreak>.08f){Sound("wood_break");lastWoodBreak=Time.unscaledTime;}
  }
  void DamageCargoSegment(Vector3 from,Vector3 to,float radius)
  {
   // Swept samples, not just the current projectile endpoint (fast shots).
   int steps=Mathf.Max(1,Mathf.CeilToInt(Vector3.Distance(from,to)/.25f));
   for(int i=0;i<=steps;i++)DamageCargo(Vector3.Lerp(from,to,i/(float)steps),radius,Vector3.forward);
  }
  void RebuildCargoNavigation()
  {
   if(!cargoNavigationDirty)return;cargoNavigationDirty=false;
   BuildNavigation(); // Once per blast/frame, not once per splinter or crate.
   foreach(var e in Enemies)if(e.Agent)
   {
    var position=e.View.transform.position;e.Agent.enabled=true;
    if(UnityEngine.AI.NavMesh.SamplePosition(position,out var hit,1,UnityEngine.AI.NavMesh.AllAreas))e.Agent.Warp(hit.position);
    e.View.transform.position=position;e.PathTimer=0;e.ApproachSlot=-1;
   }
   nextCrowdId=Enemies.Count==0?0:Enemies.Max(e=>e.CrowdId)+1;
  }
 }
}
