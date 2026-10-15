using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  const float NavCell=.5f,NavClearance=.52f;
  static readonly Vector2Int[] NavSteps={new(-1,0),new(1,0),new(0,1),new(0,-1)};
  int[] navCost;bool[] navSolid;int navWidth,navHeight,navTarget=-1;float navTimer;
  void BuildNavigation()
  {
   navWidth=Mathf.CeilToInt(half.x*2/NavCell);navHeight=Mathf.CeilToInt(half.y*2/NavCell);navCost=new int[navWidth*navHeight];navSolid=new bool[navCost.Length];navTarget=-1;navTimer=0;
   System.Array.Fill(navCost,int.MaxValue);
   for(int i=0;i<navCost.Length;i++)navSolid[i]=!NavSegmentClear(NavPosition(i),NavPosition(i),NavClearance);
  }
  int NavIndex(Vector3 p)=>Mathf.Clamp(Mathf.FloorToInt((p.z+half.y)/NavCell),0,navHeight-1)*navWidth+Mathf.Clamp(Mathf.FloorToInt((p.x+half.x)/NavCell),0,navWidth-1);
  Vector3 NavPosition(int i)=>new Vector3((i%navWidth+.5f)*NavCell-half.x,0,(i/navWidth+.5f)*NavCell-half.y);
  bool NavSegmentClear(Vector3 from,Vector3 to,float radius)
  {
   if(Mathf.Abs(to.x)>half.x-radius||Mathf.Abs(to.z)>half.y-radius)return false;
   from.y=to.y=0;var delta=to-from;float length=delta.magnitude;
   foreach(var b in blockers)
   {
    var expanded=b;expanded.Expand(new Vector3(radius*2,0,radius*2));var origin=new Vector3(from.x,b.center.y,from.z);var end=new Vector3(to.x,b.center.y,to.z);
    if(expanded.Contains(origin)||expanded.Contains(end))return false;
    if(length>.0001f&&expanded.IntersectRay(new Ray(origin,delta/length),out float hit)&&hit<=length)return false;
   }
   return true;
  }
  void UpdateNavigation(float dt)
  {
   if(navCost==null)return;navTimer-=dt;int target=NavIndex(Player.transform.position);
   // A player can stand closer to a wall than the navigation clearance.
   if(navSolid[target]){float best=float.PositiveInfinity;int nearest=-1;for(int i=0;i<navCost.Length;i++)if(!navSolid[i]){float distance=(NavPosition(i)-Player.transform.position).sqrMagnitude;if(distance<best){best=distance;nearest=i;}}if(nearest<0)return;target=nearest;}
   if(target==navTarget||navTimer>0)return;navTimer=.15f;navTarget=target;
   System.Array.Fill(navCost,int.MaxValue);var queue=new Queue<int>();navCost[target]=0;queue.Enqueue(target);
   while(queue.Count>0){int here=queue.Dequeue(),x=here%navWidth,z=here/navWidth;foreach(var step in NavSteps){int nx=x+step.x,nz=z+step.y;if(nx<0||nz<0||nx>=navWidth||nz>=navHeight)continue;int next=nz*navWidth+nx;if(navSolid[next]||navCost[next]!=int.MaxValue)continue;navCost[next]=navCost[here]+1;queue.Enqueue(next);}}
  }
  Vector3 ChaseDirection(Vector3 p)
  {
   var goal=Player.transform.position;goal.y=p.y=0;
   if(NavSegmentClear(p,goal,.46f))return (goal-p).normalized;
   if(navCost==null||navTarget<0)return Vector3.zero;
   int here=NavIndex(p),best=-1,x=here%navWidth,z=here/navWidth;float score=float.PositiveInfinity;
   // Visible nearby lower-cost cells smooth the grid path without cutting corners.
   for(int dz=-2;dz<=2;dz++)for(int dx=-2;dx<=2;dx++)
   {
    int nx=x+dx,nz=z+dz;if(nx<0||nz<0||nx>=navWidth||nz>=navHeight)continue;int next=nz*navWidth+nx;
    if(navSolid[next]||navCost[next]==int.MaxValue||navCost[next]>navCost[here])continue;
    var point=NavPosition(next);float distance=Vector3.Distance(p,point);if(distance<.07f||!NavSegmentClear(p,point,.46f))continue;
    float candidate=navCost[next]*NavCell+distance;if(candidate<score){score=candidate;best=next;}
   }
   return best<0?Vector3.zero:(NavPosition(best)-p).normalized;
  }
 }
}
