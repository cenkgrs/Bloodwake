using UnityEngine;
using UnityEngine.AI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  float spawnBearing;int surroundSpawnIndex;
  NavMeshPath spawnPath;
  void ResetSurroundSpawns(){spawnBearing=Random.Range(0,360);surroundSpawnIndex=0;}
  bool TrySurroundSpawn(string id,out Vector3 position)
  {
   position=Vector3.zero;if(!Player)return false;
   spawnPath??=new NavMeshPath();
   float radius=id=="tank"||id=="grunt"?.65f:.56f;
   var centre=Player.transform.position;
   if(!NavMesh.SamplePosition(centre,out var target,1.5f,NavMesh.AllAreas))return false;
   // Golden-angle ordering distributes consecutive spawns around the moving player.
   // Search alternate sectors at walls; never fall back to a distant map corner.
   float preferred=spawnBearing+surroundSpawnIndex*137.50776f;
   for(int ring=0;ring<3;ring++)for(int i=0;i<24;i++)
   {
    int side=i%2==0?1:-1;float angle=preferred+side*((i+1)/2)*15;
    float distance=ring==0?6.5f:ring==1?8:5.5f;
    var candidate=centre+Quaternion.Euler(0,angle,0)*Vector3.forward*distance;
    if(!NavMesh.SamplePosition(candidate,out var hit,.4f,NavMesh.AllAreas))continue;
    candidate=hit.position;candidate.y=0;
    float actual=Vector3.Distance(candidate,centre);
    if(actual<5.1f||actual>8.5f||!NavSegmentClear(candidate,candidate,radius))continue;
    bool clear=true;
    foreach(var other in Enemies)if(other.Hp>0&&Vector3.Distance(candidate,other.View.transform.position)<radius+BodyRadius(other)+.4f){clear=false;break;}
    if(!clear||!NavMesh.CalculatePath(hit.position,target.position,NavMesh.AllAreas,spawnPath)||spawnPath.status!=NavMeshPathStatus.PathComplete)continue;
    float route=0;var corners=spawnPath.corners;for(int j=1;j<corners.Length;j++)route+=Vector3.Distance(corners[j-1],corners[j]);
    if(route>actual*1.7f+1)continue;
    position=candidate;surroundSpawnIndex++;return true;
   }
   return false; // Retry later rather than spawning on the player or inside a wall.
  }
 }
}
