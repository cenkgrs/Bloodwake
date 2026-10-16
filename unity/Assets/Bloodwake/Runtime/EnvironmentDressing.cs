using System.Linq;
using Newtonsoft.Json.Linq;
using System.Text.RegularExpressions;
using UnityEngine;

namespace Bloodwake
{
 // Keep the authored street openings and collision footprints. Replacement
 // models are measured in world metres, independently of imported FBX scale.
 public static class EnvironmentDressing
 {
  public static void Apply(Transform environment,Vector2 half,JToken layout)
  {
   var houses=new[]{Load("house"),Load("house_haunted"),Load("building")};
   if(houses.Any(h=>!h))return;
   var root=new GameObject("User courtyard models").transform;root.SetParent(environment,false);
   var cargoPositions=(layout??new JArray()).Where(r=>r.S("kind")=="cargo").Select(r=>new Vector3(-(float)r["at"][0],0,(float)r["at"][1])).ToArray();
   int buildings=0,cargo=0,clutter=0;
   foreach(var slot in environment.GetComponentsInChildren<Transform>().ToArray())
   {
    if(!slot.gameObject.activeInHierarchy)continue;
    bool backdrop=Regex.IsMatch(slot.name,@"^Backdrop[\d_.]*$");
    bool frontage=Regex.IsMatch(slot.name,@"^House[\d_.]*$");
    if(backdrop||frontage)
    {
     var originals=slot.GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray();if(originals.Length==0)continue;
     var old=BoundsOf(originals);
     // A candidate must actually lie outside the navigable courtyard.
     if(Mathf.Abs(old.center.x)<half.x&&Mathf.Abs(old.center.z)<half.y)continue;
     bool side=Mathf.Abs(old.center.x)-half.x>Mathf.Abs(old.center.z)-half.y;
     Vector3 inward=side?Vector3.left*Mathf.Sign(old.center.x):Vector3.back*Mathf.Sign(old.center.z);
     var prefab=houses[buildings%houses.Length];
     var obj=Object.Instantiate(prefab,root);obj.name="Town building "+buildings+" "+prefab.name;
     obj.transform.rotation=Quaternion.LookRotation(inward);
     var bounds=BoundsOf(obj.GetComponentsInChildren<Renderer>());
     float width=side?old.size.z:old.size.x,modelWidth=side?bounds.size.z:bounds.size.x;
     float scale=Mathf.Min(width*.96f/modelWidth,Mathf.Min(9.5f,old.size.y)/bounds.size.y);
     if(backdrop)scale=Mathf.Min(scale,Mathf.Min(old.size.x/bounds.size.x,old.size.z/bounds.size.z));
     obj.transform.localScale*=scale;bounds=BoundsOf(obj.GetComponentsInChildren<Renderer>());
     Vector3 position=old.center;position.y=-bounds.min.y;
     // Face the court, with the model's nearest extent at the former facade.
     if(frontage)
     {
      if(side)position.x=Mathf.Sign(old.center.x)*(Mathf.Max(half.x+.1f,Mathf.Abs(old.center.x)-old.extents.x)+bounds.extents.x);
      else position.z=Mathf.Sign(old.center.z)*(Mathf.Max(half.y+.1f,Mathf.Abs(old.center.z)-old.extents.z)+bounds.extents.z);
     }
     position.x-=bounds.center.x;position.z-=bounds.center.z;obj.transform.position=position;
     foreach(var r in originals)r.enabled=false;
     buildings++;
    }
    else if(Regex.IsMatch(slot.name,@"^(Clutter|Street)[\d_.]*$"))
    {
     // Replace upright small cargo, preserving carts, wheels and awnings.
     foreach(var old in slot.GetComponentsInChildren<MeshRenderer>().Where(r=>r.enabled))
     {
      var b=old.bounds;var mesh=old.GetComponent<MeshFilter>()?.sharedMesh;
      if(!mesh||b.size.y<.45f||b.size.y>1.25f||b.size.x<.35f||b.size.z<.35f||b.size.x>1.3f||b.size.z>1.3f)continue;
      var source=Load(mesh.vertexCount>40?"barrel":"crate");if(!source)continue;
      var obj=Object.Instantiate(source,root);obj.name="Street cargo detail "+clutter;
      obj.transform.rotation=Quaternion.Euler(0,old.transform.eulerAngles.y,0);
      var size=BoundsOf(obj.GetComponentsInChildren<Renderer>());
      float fit=Mathf.Min(b.size.y/size.size.y,Mathf.Min(b.size.x/size.size.x,b.size.z/size.size.z));obj.transform.localScale*=fit;
      size=BoundsOf(obj.GetComponentsInChildren<Renderer>());obj.transform.position=new Vector3(b.center.x-size.center.x,b.min.y-size.min.y,b.center.z-size.center.z);
      obj.AddComponent<BreakableCargo>();old.enabled=false;clutter++;
     }
    }
    else if(Regex.IsMatch(slot.name,@"^Cargo[\d_.]*$")||(slot!=environment&&slot.childCount>1&&!slot.GetComponent<Renderer>()&&cargoPositions.Any(p=>Vector3.Distance(p,slot.position)<.02f)))
    {
     var originals=slot.GetComponentsInChildren<Renderer>().Where(r=>r.enabled).ToArray();
     var apron=originals.Where(r=>r.bounds.size.y<.15f&&r.bounds.size.x>.8f&&r.bounds.size.z>.8f).OrderBy(r=>r.bounds.size.x*r.bounds.size.z).FirstOrDefault();
     if(!apron)continue;
     var b=apron.bounds;var crate=Load("crate");var barrel=Load("barrel");if(!crate||!barrel)continue;
     Vector2[] pattern={new(-.36f,-.3f),new(-.08f,-.34f),new(.24f,-.27f),new(.39f,.02f),new(.2f,.3f),new(-.12f,.35f),new(-.39f,.17f),new(-.17f,.02f),new(.12f,.04f)};
     int count=Mathf.Clamp(Mathf.RoundToInt(b.size.x*b.size.z/2.05f),4,pattern.Length);
     for(int i=0;i<count;i++)
     {
      var source=(i+cargo*2)%4==0?barrel:crate;var obj=Object.Instantiate(source,root);obj.name="Cargo detail "+cargo+" "+i;
      obj.transform.rotation=Quaternion.Euler(0,((i*47+cargo*19)%31)-15,0);var bounds=BoundsOf(obj.GetComponentsInChildren<Renderer>());
      float fit=Mathf.Min(1.08f,Mathf.Min(b.size.x*.27f/bounds.size.x,b.size.z*.34f/bounds.size.z))*(.84f+(i*17%19)*.01f);obj.transform.localScale*=fit;bounds=BoundsOf(obj.GetComponentsInChildren<Renderer>());
      var n=pattern[(i+cargo*3)%pattern.Length];var position=new Vector3(b.center.x+n.x*b.size.x,b.min.y-bounds.min.y,b.center.z+n.y*b.size.z);obj.transform.position=position;
      var breakable=obj.AddComponent<BreakableCargo>();breakable.Footprint=b;breakable.ReplacesFootprint=true;
      if(source==crate&&i%4==1&&b.size.x>3.2f)
      {
       var upper=Object.Instantiate(crate,root);upper.name="Cargo upper detail "+cargo+" "+i;upper.transform.rotation=Quaternion.Euler(0,obj.transform.eulerAngles.y+31,0);upper.transform.localScale*=fit*.88f;
       var upperBounds=BoundsOf(upper.GetComponentsInChildren<Renderer>());upper.transform.position=new Vector3(position.x+.07f,bounds.max.y-upperBounds.min.y,position.z-.04f);
       upper.transform.SetParent(obj.transform,true); // Supported stack breaks together; no floating upper crate.
      }
     }
     foreach(var r in originals)r.enabled=false;
     cargo++;
    }
   }
   var well=(layout??new JArray()).FirstOrDefault(r=>r.S("kind")=="well");
   if(well!=null)CourtyardWell.Apply(environment,root,new Vector3(-(float)well["at"][0],0,(float)well["at"][1]),(float)well["radius"]);
   Debug.Log("BLOODWAKE_DRESSING "+environment.name+" buildings="+buildings+" cargo="+cargo+" streetCargo="+clutter);
  }
  static GameObject Load(string id)=>Resources.Load<GameObject>("Environment/Kit01/"+id+"/"+id);
  public static Bounds BoundsOf(Renderer[] renderers)
  {
   var bounds=renderers[0].bounds;for(int i=1;i<renderers.Length;i++)bounds.Encapsulate(renderers[i].bounds);return bounds;
  }
 }
}
