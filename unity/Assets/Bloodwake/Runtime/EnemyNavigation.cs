using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  NavMeshData crowdMesh;NavMeshDataInstance crowdMeshInstance;int nextCrowdId;
  void ReleaseCrowdNavigation()
  {
   foreach(var e in Enemies)if(e.Agent)e.Agent.enabled=false;
   if(crowdMeshInstance.valid)crowdMeshInstance.Remove();
   if(crowdMesh)Destroy(crowdMesh);crowdMesh=null;
  }
  void BuildCrowdNavigation()
  {
   ReleaseCrowdNavigation();nextCrowdId=0;
   var settings=NavMesh.GetSettingsByIndex(0);settings.agentRadius=.65f;settings.agentHeight=2.5f;
   settings.agentClimb=.15f;settings.overrideVoxelSize=true;settings.voxelSize=.12f;
   var sources=new List<NavMeshBuildSource>{new NavMeshBuildSource{shape=NavMeshBuildSourceShape.Box,
    transform=Matrix4x4.TRS(new Vector3(0,-.15f,0),Quaternion.identity,Vector3.one),size=new Vector3(half.x*2,.3f,half.y*2),area=0}};
   foreach(var b in blockers)sources.Add(new NavMeshBuildSource{shape=NavMeshBuildSourceShape.Box,
    transform=Matrix4x4.TRS(b.center,Quaternion.identity,Vector3.one),size=b.size,area=1});
   crowdMesh=NavMeshBuilder.BuildNavMeshData(settings,sources,new Bounds(Vector3.zero,new Vector3(half.x*2+2,10,half.y*2+2)),Vector3.zero,Quaternion.identity);
   if(crowdMesh)crowdMeshInstance=NavMesh.AddNavMeshData(crowdMesh);
  }
  static float BodyRadius(Enemy e)=>e.Id=="boss"?.8f:e.Id=="tank"||e.Id=="grunt"?.65f:.56f;
  Vector3 FreeEnemySpawn(Vector3 origin,float radius)
  {
   for(int ring=0;ring<=12;ring++)for(int i=0;i<(ring==0?1:24);i++)
   {
    var p=origin+Quaternion.Euler(0,i*15,0)*Vector3.forward*(ring*.45f);p.y=0;
    if(!NavSegmentClear(p,p,radius))continue;
    if(crowdMesh&&(!NavMesh.SamplePosition(p,out var sample,.3f,NavMesh.AllAreas)||Mathf.Abs(sample.position.y)>.3f))continue;
    bool free=true;foreach(var other in Enemies)if(other.Hp>0&&Vector3.Distance(other.View.transform.position,p)<radius+BodyRadius(other)+.06f){free=false;break;}
    if(free)return p;
   }
   return origin; // Dense/invalid spawns are also protected by the movement guard.
  }
  void AttachEnemyAgent(Enemy e)
  {
   e.CrowdId=nextCrowdId++;e.ApproachSlot=-1;
   if(!crowdMesh||!NavMesh.SamplePosition(e.View.transform.position,out var hit,1,NavMesh.AllAreas))return;
   // Keep gameplay at y=0; the agent's baked surface can have a small voxel offset.
   var agent=e.View.gameObject.AddComponent<NavMeshAgent>();e.Agent=agent;
   agent.updatePosition=false;agent.updateRotation=false;agent.updateUpAxis=false;
   // Avoidance needs a soft margin outside the hard gameplay contact radius.
   agent.radius=BodyRadius(e)+.1f;agent.height=e.View.Height;agent.acceleration=14;
   agent.angularSpeed=0;agent.autoBraking=true;agent.stoppingDistance=.08f;
   agent.obstacleAvoidanceType=ObstacleAvoidanceType.HighQualityObstacleAvoidance;
   agent.avoidancePriority=30+e.CrowdId%40;var position=e.View.transform.position;agent.Warp(hit.position);e.View.transform.position=position;
  }
  bool TryApproachSlot(Enemy e,out Vector3 goal)
  {
   goal=Player.transform.position;int warriors=0;foreach(var other in Enemies)if(other.Id=="grunt"&&other.Hp>0)warriors++;
   if(e.Id!="grunt"||warriors<2){e.ApproachSlot=-1;return false;}
   const int sectors=24;
   Vector3 Slot(int index)=>Player.transform.position+Quaternion.Euler(0,index%sectors*15,0)*Vector3.forward*(1.6f+index/sectors*1.4f);
   bool Available(int index)
   {
    foreach(var other in Enemies)if(other!=e&&other.Hp>0&&other.ApproachSlot>=0&&Vector3.Distance(Slot(other.ApproachSlot),Slot(index))<BodyRadius(e)+BodyRadius(other)+.1f)return false;
    var p=Slot(index);if(!NavSegmentClear(p,p,BodyRadius(e)))return false;
    foreach(var other in Enemies)if(other!=e&&other.Hp>0&&Vector3.Distance(p,other.View.transform.position)<BodyRadius(e)+BodyRadius(other)+.1f)return false;
    return !crowdMesh||NavMesh.SamplePosition(p,out var hit,.25f,NavMesh.AllAreas);
   }
   bool innerAvailable=false;if(e.ApproachSlot>=sectors)for(int i=0;i<sectors;i++)if(Available(i)){innerAvailable=true;break;}
   // Do not drag an old world-space slot behind a moving player indefinitely.
   bool retarget=(e.ApproachAnchor-Player.transform.position).sqrMagnitude>1||e.StuckTime>.65f;
   if(e.ApproachSlot<0||!Available(e.ApproachSlot)||innerAvailable||(retarget&&e.ApproachTimer<=0))
   {
    e.ApproachAnchor=Player.transform.position;e.ApproachTimer=.8f;
    e.ApproachSlot=-1;float best=float.PositiveInfinity;
    for(int i=0;i<sectors*3;i++)if(Available(i))
    {
     // Never prefer an easy waiting point over an available attack point.
     if(e.ApproachSlot>=0&&i/sectors>e.ApproachSlot/sectors)break;
     var route=Slot(i)-e.View.transform.position;
     float score=route.sqrMagnitude+i/sectors*16;
     // A slightly longer open shoulder is preferable to another fighter's back.
     if((MoveEnemy(e,route)-Slot(i)).sqrMagnitude>.04f)score+=12;
     if(score<best){best=score;e.ApproachSlot=i;}
    }
   }
   if(e.ApproachSlot<0)return false;goal=Slot(e.ApproachSlot);return true;
  }
  Vector3 EnemyWish(Enemy e,Vector3 fallback,Vector3 goal,float speed,float dt)
  {
   var a=e.Agent;if(!a||!a.enabled||!a.isOnNavMesh)return fallback;
   a.nextPosition=e.View.transform.position;a.speed=speed;a.isStopped=fallback.sqrMagnitude<.0001f;
   if(a.isStopped)return Vector3.zero;
   e.PathTimer-=dt;
   if(e.PathTimer<=0||(goal-e.PathGoal).sqrMagnitude>.16f)
   {
    e.PathTimer=.15f;e.PathGoal=goal;
    if(NavMesh.SamplePosition(goal,out var hit,1,NavMesh.AllAreas))a.SetDestination(hit.position);
   }
   if(a.pathPending||!a.hasPath)return fallback;
   var velocity=a.desiredVelocity;velocity.y=0;
   return velocity/Mathf.Max(.01f,speed);
  }
  bool WarriorEngagement(Enemy e,float distance,float dt,out Vector3 goal,out Vector3 wish)
  {
   var position=e.View.transform.position;var player=Player.transform.position;
   goal=player;wish=Vector3.zero;e.ApproachTimer-=dt;
   bool close=distance<=1.68f&&NavSegmentClear(position,player,.05f);
   if(e.StepPending)
   {
    e.StepPending=false;
    // One brief, local flank adjustment between pairs of attacks. Never orbit the map.
    if(close&&TryCombatStep(e,out var step)){e.StepGoal=step;e.StepTime=.7f;}
   }
   if(e.StepTime>0)
   {
    e.StepTime-=dt;var step=e.StepGoal-position;step.y=0;
    if(distance>2.15f||step.magnitude<.13f||e.StuckTime>.25f)e.StepTime=0;
    else{e.Intent=WarriorIntent.Reposition;goal=e.StepGoal;wish=step.normalized;return true;}
   }
   if(close)
   {
    // Facing/attacking wins over slot alignment and the avoidance velocity.
    e.Intent=WarriorIntent.FaceTarget;e.ApproachSlot=-1;e.StuckTime=0;return false;
   }
   e.Intent=WarriorIntent.Approach;
   if(TryApproachSlot(e,out var approach))
   {
    goal=approach;
    var radial=position-player;radial.y=0;var targetRadial=goal-player;targetRadial.y=0;
    float angle=Vector3.SignedAngle(radial,targetRadial,Vector3.up);
    // Approach the free side around the engaged fighters, not through their backs.
    // This local arc is capped at 2.8m from the player, not a roaming destination.
    if(distance<3.2f&&Mathf.Abs(angle)>40&&(MoveEnemy(e,goal-position)-goal).sqrMagnitude>.04f)
    {
     var waypoint=player+Quaternion.Euler(0,Mathf.Clamp(angle,-35,35),0)*radial.normalized*Mathf.Max(2.8f,distance);
     if(NavSegmentClear(position,waypoint,BodyRadius(e)))goal=waypoint;
    }
   }
   var delta=goal-position;delta.y=0;wish=delta.sqrMagnitude>.01f?delta.normalized:ChaseDirection(position);
   return true;
  }
  bool TryCombatStep(Enemy e,out Vector3 goal)
  {
   var radial=e.View.transform.position-Player.transform.position;radial.y=0;
   if(radial.sqrMagnitude<.1f)radial=-e.View.transform.forward;
   for(int attempt=0;attempt<2;attempt++)
   {
    float sign=((e.CrowdId+e.AttackCount/2)&1)==0?1:-1;if(attempt==1)sign=-sign;
    goal=Player.transform.position+Quaternion.Euler(0,sign*24,0)*radial.normalized*1.5f;
    if(!NavSegmentClear(e.View.transform.position,goal,BodyRadius(e)))continue;
    bool free=true;foreach(var other in Enemies)if(other!=e&&other.Hp>0&&Vector3.Distance(goal,other.View.transform.position)<BodyRadius(e)+BodyRadius(other)+.12f){free=false;break;}
    if(free)return true;
   }
   goal=e.View.transform.position;return false;
  }
  void HoldEnemyAgent(Enemy e)
  {
   if(e.Agent&&e.Agent.enabled&&e.Agent.isOnNavMesh){e.Agent.isStopped=true;e.Agent.nextPosition=e.View.transform.position;}
  }
  Vector3 UnstickCrowdWish(Enemy e,Vector3 wish,Vector3 goal)
  {
   if(wish.magnitude>.15f&&e.StuckTime<.25f)return wish;
   var direction=goal-e.View.transform.position;direction.y=0;
   if(e.Agent&&e.Agent.enabled&&e.Agent.isOnNavMesh&&e.Agent.hasPath)
   {var corner=e.Agent.steeringTarget-e.View.transform.position;corner.y=0;if(corner.sqrMagnitude>.16f)direction=corner;}
   if(direction.sqrMagnitude<.01f)return wish;direction.Normalize();
   // RVO can yield zero velocity for a close group. Probe only short, reachable
   // steps toward the route, so a free shoulder can make progress without teleporting.
   for(int i=0;i<13;i++)
   {
    float side=(e.CrowdId&1)==0?1:-1;if(i%2==0)side=-side;
    float angle=((i+1)/2)*15*side;
    var candidate=Quaternion.Euler(0,angle,0)*direction;var from=e.View.transform.position;
    if(NavSegmentClear(from,from+candidate*.65f,BodyRadius(e))&&(MoveEnemy(e,candidate*.65f)-from).magnitude>.6f)return candidate;
   }
   return wish;
  }
  // Keep manual animation/recoil motion authoritative, but never walk through a body.
  Vector3 MoveEnemy(Enemy e,Vector3 delta)
  {
   var from=e.View.transform.position;var next=Move(from,delta,BodyRadius(e));var step=next-from;step.y=0;
   float length=step.magnitude;if(length<.000001f)return next;
   var direction=step/length;float allowed=length;
   foreach(var other in Enemies)
   {
    if(other==e||other.Hp<=0)continue;
    var offset=from-other.View.transform.position;offset.y=0;float radius=BodyRadius(e)+BodyRadius(other)+.025f;
    float along=Vector3.Dot(offset,direction),c=offset.sqrMagnitude-radius*radius;
    if(c<0){if(along<0)allowed=0;continue;} // Existing contact may move outward, never deeper.
    if(along>=0)continue;float discriminant=along*along-c;
    if(discriminant>=0)allowed=Mathf.Min(allowed,Mathf.Max(0,-along-Mathf.Sqrt(discriminant)-.001f));
   }
   return from+direction*allowed;
  }
  void SyncEnemyAgents()
  {
   foreach(var e in Enemies)if(e.Agent&&e.Agent.enabled&&e.Agent.isOnNavMesh)
   {
    e.Agent.nextPosition=e.View.transform.position;
    if(arrivalActive||Screen!="playing"||hitStop>0||e.Turning||e.Casting||e.Stagger>0||e.RecoilTime>0||e.View.Locked>0)e.Agent.isStopped=true;
   }
  }
 }
}
