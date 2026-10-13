using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  int[] navCost;bool[] navSolid;int navWidth,navHeight,navTarget=-1;float navTimer;
  void BuildNavigation()
  {
   navWidth=Mathf.CeilToInt(half.x*2);navHeight=Mathf.CeilToInt(half.y*2);navCost=new int[navWidth*navHeight];navSolid=new bool[navCost.Length];navTarget=-1;navTimer=0;
   for(int i=0;i<navCost.Length;i++){var p=NavPosition(i);foreach(var b in blockers){var expanded=b;expanded.Expand(new Vector3(.8f,0,.8f));if(expanded.Contains(new Vector3(p.x,b.center.y,p.z))){navSolid[i]=true;break;}}}
  }
  int NavIndex(Vector3 p)=>Mathf.Clamp(Mathf.FloorToInt(p.z+half.y),0,navHeight-1)*navWidth+Mathf.Clamp(Mathf.FloorToInt(p.x+half.x),0,navWidth-1);
  Vector3 NavPosition(int i)=>new Vector3(i%navWidth-half.x+.5f,0,i/navWidth-half.y+.5f);
  void UpdateNavigation(float dt)
  {
   if(navCost==null)return;navTimer-=dt;int target=NavIndex(Player.transform.position);if(target==navTarget||navTimer>0)return;navTimer=.2f;navTarget=target;
   System.Array.Fill(navCost,int.MaxValue);var queue=new Queue<int>();navCost[target]=0;queue.Enqueue(target);
   while(queue.Count>0){int here=queue.Dequeue(),x=here%navWidth,z=here/navWidth;foreach(var step in new[]{Vector2Int.left,Vector2Int.right,Vector2Int.up,Vector2Int.down}){int nx=x+step.x,nz=z+step.y;if(nx<0||nz<0||nx>=navWidth||nz>=navHeight)continue;int next=nz*navWidth+nx;if(navSolid[next]||navCost[next]!=int.MaxValue)continue;navCost[next]=navCost[here]+1;queue.Enqueue(next);}}
  }
  Vector3 ChaseDirection(Vector3 p)
  {
   if(navCost==null)return (Player.transform.position-p).normalized;int here=NavIndex(p),best=here,x=here%navWidth,z=here/navWidth;
   foreach(var step in new[]{Vector2Int.left,Vector2Int.right,Vector2Int.up,Vector2Int.down}){int nx=x+step.x,nz=z+step.y;if(nx<0||nz<0||nx>=navWidth||nz>=navHeight)continue;int next=nz*navWidth+nx;if(navCost[next]<navCost[best])best=next;}
   var target=best==here?Player.transform.position:NavPosition(best);return (target-p).normalized;
  }
 }
}
