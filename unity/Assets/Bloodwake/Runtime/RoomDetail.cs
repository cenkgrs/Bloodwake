using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The middle of a room used to be a bare plate: dressing only ringed the walls. This pass gives the floor a
 // structure and a few landmarks to fight around, without closing it. In the town: a flagstone road from gate to
 // gate with kerbs, rope lines with pennants strung across the street overhead, litter, and two or
 // three small set pieces (a wrecked cart, a gibbet, a barricade, a lamp post, a burnt pyre, a wayside shrine).
 // In the keep: pilasters, skirting and torch sconces on the tall walls, merlons on the low ones, a dark border
 // of slabs along every wall, cobwebs in the far corners, worn and bloodied floor, dust in the air, and set
 // pieces per room. Everything keeps clear of doors, markers and existing blockers, and is seeded by the room id.
 public sealed partial class BloodwakeGame
 {
  System.Random detailRandom;
  float DR(float a,float b)=>a+(float)detailRandom.NextDouble()*(b-a);
  List<(Vector3 at,float radius)> detailKeep;
  static Material leafMaterial,paperMaterial,webMaterial,scorchMaterial,medallionMaterial;

  void DetailClearings(float doorRadius,float markerRadius)
  {
   detailKeep=new List<(Vector3,float)>();
   foreach(var door in (room["doors"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())detailKeep.Add((Point(door.Value["at"]),doorRadius));
   foreach(var marker in (room["markers"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())
    if(marker.Value is JArray list&&list.Count>0&&list[0] is JArray)foreach(var p in list)detailKeep.Add((Point(p),markerRadius));else detailKeep.Add((Point(marker.Value),markerRadius+.4f));
  }
  bool DetailFree(Vector3 p,float radius,float blockerGap=.9f)
  {
   if(Mathf.Abs(p.x)>half.x-radius-.4f||Mathf.Abs(p.z)>half.y-radius-.4f)return false;
   foreach(var k in detailKeep)if(Vector2.Distance(new Vector2(p.x,p.z),new Vector2(k.at.x,k.at.z))<k.radius+radius)return false;
   foreach(var b in blockers){var e=b;e.Expand(new Vector3((radius+blockerGap)*2,0,(radius+blockerGap)*2));if(e.Contains(new Vector3(p.x,b.center.y,p.z)))return false;}
   // The way to the exit stays open: nothing solid in the 5 m lane before either door.
   if(room["keep"]!=null&&Mathf.Abs(p.x)<2.5f+radius&&Mathf.Abs(p.z)>half.y-6)return false;
   if(keepWalk!=null&&room["keep"]!=null)
    for(float a=0;a<360;a+=45)if(!KeepWalkable(p+Quaternion.Euler(0,a,0)*Vector3.forward*(radius+blockerGap)))return false;
   return true;
  }

  // ================= Town =================
  void DetailTown(string id)
  {
   detailRandom=new System.Random(id.Aggregate(57,(h,c)=>h*29+c));
   var root=new GameObject("Room detail").transform;root.SetParent(roomRoot,false);
   EnsureDetailMaterials();
   DetailClearings(4.6f,2.4f);
   var arena=room["markers"]?["BossArenaCenter"]!=null?Point(room["markers"]["BossArenaCenter"]):(Vector3?)null;
   var road=TownRoad(root,arena);
   TownLines(root);
   // Set pieces stay off the road and out of the boss's circle.
   foreach(var (a,b) in road)for(float t=0;t<=1;t+=.1f)detailKeep.Add((Vector3.Lerp(a,b,t),2.4f));
   if(arena is Vector3 c)detailKeep.Add((c,7.5f));
   if(room.S("type")!="merchant")TownSetPieces(root,id);
   TownLitter(root);
  }
  // Big worn slabs between the gates, with a kerb either side; the cobbles stay round them.
  List<(Vector3,Vector3)> TownRoad(Transform root,Vector3? arena)
  {
   var segments=new List<(Vector3,Vector3)>();
   var doors=(room["doors"] as JObject)?.Properties().Select(d=>Point(d.Value["at"])).ToList()??new List<Vector3>();
   if(doors.Count<2)return segments;
   var a=doors[0];var b=doors[1];
   // An offset pair of gates meets in a dog-leg through the middle.
   var mid1=new Vector3(a.x,0,0);var mid2=new Vector3(b.x,0,0);
   if(Mathf.Abs(a.x-b.x)>1){segments.Add((a,mid1));segments.Add((mid1,mid2));segments.Add((mid2,b));}else segments.Add((a,b));
   // A few stone tints so neighbouring slabs never match; kerbs a shade lighter than the cobbles.
   var slabs=new[]{.66f,.74f,.82f,.9f}.Select(v=>KMat("flagstone",new Color(v,v*.97f,v*.94f),new Vector2(.35f,.35f))).ToArray();
   var kerb=KMat("ashlar",new Color(.62f,.6f,.6f),new Vector2(1.5f,.15f));
   int tiles=0;
   foreach(var (from,to) in segments)
   {
    var dir=(to-from).normalized;float length=Vector3.Distance(from,to);var side=Vector3.Cross(Vector3.up,dir);var rotation=Quaternion.LookRotation(dir);
    int row=0;
    for(float t=.4f;t<length-.3f;row++)
    {
     float depth=DR(.7f,1.05f);var p=from+dir*(t+depth*.5f);t+=depth+.04f;
     if(arena is Vector3 c&&Vector3.Distance(p,c)<6.5f)continue;
     if(blockers.Any(bl=>{var e=bl;e.Expand(new Vector3(3.2f,0,3.2f));return e.Contains(new Vector3(p.x,bl.center.y,p.z));}))continue;
     if(Mathf.Abs(p.x)>half.x-.5f||Mathf.Abs(p.z)>half.y-.3f)continue;
     // Each row is two or three slabs of uneven width, joints staggered against the row before; now and then one
     // is missing and the cobbles show through.
     float across=-1.5f;int pieces=row%2==0?2:3;
     for(int n=0;n<pieces;n++)
     {
      float w=n==pieces-1?1.5f-across:3f/pieces*DR(.75f,1.25f);float mid=across+w*.5f;across+=w;
      if(detailRandom.NextDouble()<.06)continue;
      KBoxR(root,"Road slab",p+side*mid+Vector3.up*(.012f+DR(0,.012f)),rotation*Quaternion.Euler(DR(-.6f,.6f),DR(-1.2f,1.2f),DR(-.6f,.6f)),new Vector3(w-.05f,.03f,depth),slabs[detailRandom.Next(slabs.Length)]);tiles++;
     }
     foreach(int s in new[]{-1,1})if(detailRandom.NextDouble()>.08)KBoxR(root,"Road kerb",p+side*s*1.6f+Vector3.up*.035f,rotation*Quaternion.Euler(0,DR(-1.5f,1.5f),0),new Vector3(.16f,.07f,depth+.02f),kerb);
    }
   }
   Debug.Log("BLOODWAKE_DETAIL road tiles="+tiles);
   return segments;
  }
  // Ropes across the street between the house fronts, sagging, hung with pennants.
  void TownLines(Transform root)
  {
   var rope=KMat("timber",new Color(.22f,.18f,.14f),Vector2.one);
   var cloths=new[]{KMat("cloth",new Color(.78f,.14f,.1f),Vector2.one),KMat("cloth",new Color(.92f,.86f,.7f),Vector2.one),KMat("cloth",new Color(.62f,.12f,.1f),Vector2.one),KMat("cloth",new Color(.8f,.62f,.32f),Vector2.one)};
   int lines=half.y>13?3:2;
   for(int n=0;n<lines;n++)
   {
    float z=Mathf.Lerp(-half.y*.62f,half.y*.62f,lines==1?.5f:n/(float)(lines-1))+DR(-1.2f,1.2f);
    float height=DR(4.6f,5.4f),sag=DR(.5f,.9f),x0=-half.x-.6f,x1=half.x+.6f;float slope=DR(-.25f,.25f),skew=DR(-.6f,.6f);
    Vector3 At(float u)=>new Vector3(Mathf.Lerp(x0,x1,u),height-sag*4*u*(1-u)+slope*(u-.5f),z+(u-.5f)*skew);
    int steps=24;for(int i=0;i<steps;i++){var p=At(i/(float)steps);var q=At((i+1)/(float)steps);KBoxR(root,"Street rope",(p+q)*.5f,Quaternion.LookRotation(q-p),new Vector3(.035f,.035f,Vector3.Distance(p,q)+.02f),rope);}
    float u2=.04f;
    while(u2<.96f)
    {
     // Pennants twisted by the wind, so most turn their face to the moon (it shines toward +x+z).
     var p=At(u2);
     var flag=GameObject.CreatePrimitive(PrimitiveType.Cube);flag.name="Street pennant";Destroy(flag.GetComponent<Collider>());flag.transform.SetParent(root,false);
     flag.transform.SetPositionAndRotation(p+Vector3.down*.2f,Quaternion.Euler(0,DR(55,85),0)*Quaternion.Euler(DR(-8,8),0,45));flag.transform.localScale=new Vector3(.38f,.38f,.015f);flag.GetComponent<Renderer>().sharedMaterial=cloths[n%2==0?(int)(u2*40)%2:2+(int)(u2*40)%2];
     u2+=.55f/(x1-x0);
    }
   }
  }
  void TownSetPieces(Transform root,string id)
  {
   var kinds=new List<string>{"wreck","gibbet","barricade","lamp","pyre","shrine"};
   int want=half.x*half.y>230?3:2,placed=0;var used=new List<string>();
   // Candidates on a loose grid in the middle band of the room; nearest to a third of the way out first.
   var spots=new List<Vector3>();
   for(float x=-half.x+3;x<=half.x-3;x+=1.5f)for(float z=-half.y+3;z<=half.y-3;z+=1.5f)spots.Add(new Vector3(x+DR(-.4f,.4f),0,z+DR(-.4f,.4f)));
   spots=spots.OrderBy(_=>detailRandom.Next()).ToList();
   var taken=new List<Vector3>();
   foreach(var p in spots)
   {
    if(placed>=want)break;
    if(taken.Any(t=>Vector3.Distance(t,p)<Mathf.Min(half.x,half.y)*.8f))continue;
    var kind=kinds.Where(k=>!used.Contains(k)).OrderBy(_=>detailRandom.Next()).First();
    float r=kind=="lamp"?.6f:kind=="barricade"?2f:kind=="shrine"?1.1f:1.5f;
    if(!DetailFree(p,r))continue;
    float yaw=DR(0,360);
    switch(kind)
    {
     case "wreck":Wreck(root,p,yaw);break;
     case "gibbet":Gibbet(root,p,yaw);break;
     case "barricade":Barricade(root,p,yaw);break;
     case "lamp":LampPost(root,p);break;
     case "pyre":Pyre(root,p,yaw);break;
     case "shrine":Wayside(root,p,yaw);break;
    }
    used.Add(kind);taken.Add(p);detailKeep.Add((p,r+1.2f));placed++;
   }
   Debug.Log("BLOODWAKE_DETAIL "+id+" setpieces="+string.Join(",",used));
  }
  // A cart down on one broken wheel, its load spilled.
  void Wreck(Transform root,Vector3 p,float yaw)
  {
   var rot=Quaternion.Euler(0,yaw,0);
   var cart=Piece(root,"cart",p,new Vector3(2.33f,1.12f,1.59f),yaw,true);if(cart)cart.transform.parent.rotation=Quaternion.Euler(0,yaw,7);
   Piece(root,"sacks",p+rot*new Vector3(1.6f,0,.6f),new Vector3(1.1f,.7f,.86f),yaw+DR(-30,30),true);
   Piece(root,"crate",p+rot*new Vector3(-1.5f,0,.9f),new Vector3(.8f,.8f,.8f),yaw+DR(10,40),true);
   Piece(root,"sacks",p+rot*new Vector3(.4f,0,1.3f),new Vector3(.9f,.5f,.7f),yaw+DR(60,120),false);
   EnsureGroundMaterials();Decal(root,"Spilled straw",p+rot*new Vector3(.6f,0,1),2.4f,DR(0,360),strawMaterial,.006f);
  }
  // A crow cage hung from a timber gallows; bones underneath.
  void Gibbet(Transform root,Vector3 p,float yaw)
  {
   var rot=Quaternion.Euler(0,yaw,0);var timber=KMat("timber",new Color(.42f,.34f,.27f),new Vector2(1,3));var iron=KMat("iron",new Color(.3f,.3f,.32f),Vector2.one);
   var post=p+rot*new Vector3(-1.1f,0,0);
   KBoxR(root,"Gibbet post",post+Vector3.up*1.9f,rot,new Vector3(.28f,3.8f,.28f),timber);PropBlocker(new Bounds(post+Vector3.up,new Vector3(.5f,2,.5f)));
   KBoxR(root,"Gibbet arm",p+rot*new Vector3(-.2f,3.65f,0),rot,new Vector3(2.2f,.22f,.22f),timber);
   KBoxR(root,"Gibbet brace",post+rot*new Vector3(.45f,3.2f,0),rot*Quaternion.Euler(0,0,45),new Vector3(1.1f,.14f,.14f),timber);
   var hang=p+rot*new Vector3(.6f,0,0);
   KBoxR(root,"Gibbet chain",hang+Vector3.up*3.2f,rot,new Vector3(.04f,.8f,.04f),iron);
   var cage=Piece(root,"cage",hang+Vector3.up*1f,new Vector3(.83f,1.85f,1f),yaw+DR(-20,20),false);
   PropBlocker(new Bounds(hang+Vector3.up,new Vector3(.9f,2,.9f)));
   Piece(root,"bones",hang+rot*new Vector3(.3f,0,.5f),new Vector3(1.04f,.2f,.82f),DR(0,360),false);
  }
  // A chest-high line of bales, crates and planks: cover to circle round.
  void Barricade(Transform root,Vector3 p,float yaw)
  {
   var rot=Quaternion.Euler(0,yaw,0);var timber=KMat("timber",new Color(.4f,.32f,.25f),new Vector2(3,1));
   Piece(root,"hay_bale",p+rot*new Vector3(-1.3f,0,0),new Vector3(1.5f,.64f,.86f),yaw,true);
   Piece(root,"hay_bale",p+rot*new Vector3(-1.2f,.64f,.05f),new Vector3(1.3f,.56f,.8f),yaw+DR(-8,8),false);
   Piece(root,"crate",p+rot*new Vector3(.4f,0,0),new Vector3(.95f,.95f,.95f),yaw+DR(-10,10),true);
   Piece(root,"barrel",p+rot*new Vector3(1.4f,0,.1f),new Vector3(.66f,.9f,.66f),0,true);
   foreach(var (o,a) in new[]{(new Vector3(0,.7f,-.5f),12f),(new Vector3(-.4f,.4f,-.55f),-8f)})
    KBoxR(root,"Barricade plank",p+rot*o,rot*Quaternion.Euler(0,0,a),new Vector3(3.6f,.08f,.3f),timber);
   KBoxR(root,"Barricade stake",p+rot*new Vector3(2.1f,.5f,-.3f),rot*Quaternion.Euler(-30,0,0),new Vector3(.12f,1.2f,.12f),timber);
  }
  // An iron post with a lantern on an arm.
  void LampPost(Transform root,Vector3 p)
  {
   var iron=KMat("iron",new Color(.22f,.22f,.24f),Vector2.one);var stone=KMat("ashlar",new Color(.5f,.5f,.54f),Vector2.one);
   KBox(root,"Lamp post base",p+Vector3.up*.2f,new Vector3(.6f,.4f,.6f),stone,true);
   KBox(root,"Lamp post",p+Vector3.up*1.9f,new Vector3(.12f,3.2f,.12f),iron,false);
   var dir=(Vector3.zero-p).normalized;if(dir.sqrMagnitude<.1f)dir=Vector3.forward;
   KBoxR(root,"Lamp post arm",p+dir*.35f+Vector3.up*3.35f,Quaternion.LookRotation(dir),new Vector3(.06f,.06f,.75f),iron);
   var lantern=p+dir*.7f+Vector3.up*2.75f;Piece(root,"lantern",lantern,new Vector3(.32f,.5f,.32f),0,false);Lamp(root,"Lantern light",lantern+Vector3.up*.25f);
   Decal(root,"Puddle",p+dir*.9f,DR(1.6f,2.4f),DR(0,360),puddleMaterial,.008f);
  }
  // Where they burnt something: a ring of scorched stone, charred wood and bones.
  void Pyre(Transform root,Vector3 p,float yaw)
  {
   Decal(root,"Scorch",p,3.6f,yaw,scorchMaterial,.007f);
   Piece(root,"firewood",p,new Vector3(1.4f,.5f,1.15f),yaw,true);
   Piece(root,"bones",p+Quaternion.Euler(0,yaw,0)*new Vector3(.9f,0,.8f),new Vector3(1.04f,.2f,.82f),DR(0,360),false);
   var charred=KMat("timber",new Color(.08f,.07f,.07f),Vector2.one);
   for(int i=0;i<5;i++){float a=yaw+i*72+DR(-15,15),len=DR(1.1f,1.9f);var q=Quaternion.Euler(0,a,0);var lean=q*Quaternion.Euler(-DR(22,34),0,0);KBoxR(root,"Charred stake",p+q*Vector3.forward*.95f+lean*Vector3.up*len*.5f,lean,new Vector3(.12f,len,.12f),charred);}
  }
  // A saint on a plinth with candles at its feet.
  void Wayside(Transform root,Vector3 p,float yaw)
  {
   var stone=KMat("ashlar",new Color(.55f,.55f,.6f),Vector2.one);
   KBoxR(root,"Shrine plinth",p+Vector3.up*.3f,Quaternion.Euler(0,yaw,0),new Vector3(1.3f,.6f,1.3f),stone);PropBlocker(new Bounds(p+Vector3.up,new Vector3(1.3f,2,1.3f)));
   Piece(root,"shrine_statue",p+Vector3.up*.6f,new Vector3(.8f,2.2f,.84f),yaw,false);
   var front=Quaternion.Euler(0,yaw,0)*Vector3.forward;
   Piece(root,"candles",p+front*1.05f,new Vector3(.6f,.42f,.52f),yaw,false);Lamp(root,"Lantern light",p+front*1.05f+Vector3.up*.6f);
  }
  void TownLitter(Transform root)
  {
   float fx=half.x-.8f,fz=half.y-.8f;
   for(int i=0,tries=0;i<14&&tries<120;tries++){var p=new Vector3(DR(-fx,fx),0,DR(-fz,fz));if(!DetailFree(p,0,.1f)&&detailRandom.NextDouble()<.7)continue;Decal(root,"Leaves",p,DR(.9f,1.8f),DR(0,360),leafMaterial,.005f+i*.0002f);i++;}
   for(int i=0;i<6;i++){var p=new Vector3(DR(-fx,fx),0,DR(-fz,fz));Decal(root,"Paper scraps",p,DR(.7f,1.2f),DR(0,360),paperMaterial,.0065f+i*.0002f);}
  }

  // ================= Keep =================
  void DetailKeep(Transform root,string style)
  {
   detailRandom=new System.Random(room.S("id").GetHashCode()^0x5bd1);
   EnsureDetailMaterials();EnsureDecalMaterials();
   DetailClearings(4f,2.2f);
   KeepWallDetail(root);
   KeepFloorDetail(root,style);
   KeepCobwebs(root);
   KeepSetPieces(root,style);
   AmbientParticles(root);
  }
  // Walls: a skirting along the foot of every tall face, a pilaster every few metres, torch sconces between; on
  // the low parapets, merlons on every other block.
  void KeepWallDetail(Transform root)
  {
   var stone=KMat("ashlar",new Color(.72f,.72f,.78f),new Vector2(.4f,1.4f));var dark=KMat("slate",new Color(.3f,.3f,.34f),Vector2.one);var iron=KMat("iron",new Color(.25f,.25f,.27f),Vector2.one);
   int faces=0,pilasters=0,sconces=0,merlons=0;
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    if(keepWalk[i,k])continue;var c=KeepCellCentre(i,k);if(KeepDoorGap(c))continue;
    bool edge=false;foreach(var n in new[]{Vector3.forward,Vector3.left,Vector3.back,Vector3.right})edge|=KeepWalkable(c+n*KeepCell);
    if(!edge)continue;
    float h=StoneHeight(c);
    if(h<2)
    {
     // Merlons on the parapet, alternating.
     if((i+k)%2==0&&!HasKit("keep_parapet")){KBox(root,"Keep merlon",c+Vector3.up*(h+.4f),new Vector3(.62f,.56f,.62f),stone,false);merlons++;}
     continue;
    }
    // The tall stone only ever faces the floor towards the camera (+z or -x).
    foreach(var n in new[]{Vector3.forward,Vector3.left})
    {
     if(!KeepWalkable(c+n*KeepCell))continue;
     bool alongZ=Mathf.Abs(n.x)>.5f;var face=c+n*KeepCell*.5f;
     KBox(root,"Keep skirting",face+n*.06f+Vector3.up*.22f,Size(alongZ,KeepCell+.02f,.44f,.14f),dark,false);
     if(NearWindow(root,face))continue;
     // Between the windows, pilasters and torches alternate.
     faces++;
     if(faces%2==0)
     {
      pilasters++;
      if(KeepModel(root,"keep_pilaster",face+n*.02f,Yaw(n))){continue;}
      KBox(root,"Keep pilaster",face+n*.16f+Vector3.up*h*.5f,Size(alongZ,.62f,h,.32f),stone,false);
      KBox(root,"Keep pilaster base",face+n*.22f+Vector3.up*.35f,Size(alongZ,.84f,.7f,.44f),dark,false);
      KBox(root,"Keep pilaster capital",face+n*.22f+Vector3.up*(h-.3f),Size(alongZ,.84f,.32f,.44f),dark,false);
     }
     else if(faces%4==1)
     {
      // An iron bracket holding a torch, flame lit.
      var at=face+n*.22f+Vector3.up*2.3f;
      if(KeepModel(root,"keep_torch_sconce",face+n*.02f+Vector3.up*1.75f,Yaw(n)))
      {
       if(sconces<14)Lamp(root,"Sconce light",face+n*.3f+Vector3.up*2.5f);sconces++;continue;
      }
      KBox(root,"Keep sconce plate",face+n*.03f+Vector3.up*2.15f,Size(alongZ,.22f,.42f,.05f),iron,false);
      KBoxR(root,"Keep sconce arm",face+n*.13f+Vector3.up*2.05f,Quaternion.LookRotation(n)*Quaternion.Euler(-35,0,0),new Vector3(.05f,.05f,.32f),iron);
      KBox(root,"Keep torch",at+Vector3.down*.12f,new Vector3(.09f,.36f,.09f),KMat("timber",new Color(.25f,.18f,.12f),Vector2.one),false);
      if(sconces<14)Lamp(root,"Sconce light",at+Vector3.up*.12f);
      sconces++;
     }
    }
   }
   Debug.Log($"BLOODWAKE_DETAIL keep walls pilasters={pilasters} sconces={sconces} merlons={merlons}");
  }
  float StoneHeight(Vector3 c)
  {
   var look=new Vector3(-cameraOffset.x,0,-cameraOffset.z).normalized;float first=99;
   for(float t=.5f;t<=7;t+=.25f)if(KeepWalkable(c+look*t)){first=t;break;}
   return Mathf.Clamp((first-.7f)/1.43f,KeepLow,KeepTall);
  }
  bool NearWindow(Transform root,Vector3 face)
  {
   foreach(Transform t in root)if((t.name=="Keep window frame"||t.name=="Keep banner")&&Vector2.Distance(new Vector2(t.position.x,t.position.z),new Vector2(face.x,face.z))<1.1f)return true;
   return false;
  }
  // A border of dark slabs on the floor cells along the walls, an inlaid medallion where the room centres, and
  // the wear: cracks, moss, blood, standing water, straw where men slept or bled.
  void KeepFloorDetail(Transform root,string style)
  {
   var border=KMat("slate",new Color(.34f,.34f,.38f),new Vector2(.5f,.5f));
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    if(!keepWalk[i,k])continue;var c=KeepCellCentre(i,k);
    foreach(var n in new[]{Vector3.forward,Vector3.left,Vector3.back,Vector3.right})
    {
     if(KeepWalkable(c+n*KeepCell)||KeepDoorGap(c+n*KeepCell))continue;bool alongZ=Mathf.Abs(n.x)>.5f;
     KBox(root,"Keep floor border",c+n*.3f+Vector3.up*.006f,Size(alongZ,KeepCell,.012f,.4f),border,false);
    }
   }
   // The medallion: on the room's widest open spot near the middle.
   if(style!="throne"&&style!="cells")
   {
    Vector3 best=Vector3.zero;float bestScore=-1;
    for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
    {
     if(!keepWalk[i,k])continue;var c=KeepCellCentre(i,k);float clear=0;while(clear<6&&Enumerable.Range(0,8).All(a=>KeepWalkable(c+Quaternion.Euler(0,a*45,0)*Vector3.forward*(clear+.5f))))clear+=.5f;
     float score=clear-c.magnitude*.08f;if(score>bestScore){bestScore=score;best=c;}
    }
    if(bestScore>1.5f)Decal(root,"Keep floor medallion",best,Mathf.Min(5.5f,bestScore*1.6f),style=="chapel"?0:45,medallionMaterial,.009f);
   }
   var cells=new List<Vector3>();for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)if(keepWalk[i,k])cells.Add(KeepCellCentre(i,k));
   void Spread(string name,Material m,int count,float min,float max,bool edge)
   {
    for(int n=0,tries=0;n<count&&tries<count*20;tries++)
    {
     var c=cells[detailRandom.Next(cells.Count)]+new Vector3(DR(-.5f,.5f),0,DR(-.5f,.5f));
     if(edge&&Enumerable.Range(0,4).All(a=>KeepWalkable(c+Quaternion.Euler(0,a*90,0)*Vector3.forward*1.5f)))continue;
     var d=Decal(root,"Keep "+name,c,DR(min,max),DR(0,360),m,.004f+n*.00015f);d.transform.localScale=Vector3.Scale(d.transform.localScale,new Vector3(1,DR(.6f,1.2f),1));n++;
    }
   }
   EnsureGroundMaterials();
   int area=cells.Count;
   Spread("cracks",crackMaterial,area/22,1.2f,3f,false);
   Spread("moss",mossMaterial,area/(style=="cells"||style=="undercroft"?20:45),1f,2.4f,true);
   Spread("blood",bloodMaterial,style=="cells"||style=="gatehouse"?8:4,.9f,2.2f,false);
   Spread("puddle",puddleMaterial,style=="cells"?6:2,1.2f,2.6f,true);
   if(style=="cells"||style=="armory"||style=="gatehouse")Spread("straw",strawMaterial,style=="cells"?10:4,1f,2f,true);
   Spread("dust",paperMaterial,3,.6f,1f,true);
  }
  // Webs strung across the far inside corners, where the tall walls meet.
  void KeepCobwebs(Transform root)
  {
   int webs=0;
   for(int i=0;i<keepW&&webs<6;i++)for(int k=0;k<keepH&&webs<6;k++)
   {
    if(!keepWalk[i,k])continue;var c=KeepCellCentre(i,k);
    // The far inside corner: stone on the -z and +x sides of this floor cell.
    if(KeepWalkable(c+Vector3.back)||KeepWalkable(c+Vector3.right)||KeepDoorGap(c+Vector3.back))continue;
    if(StoneHeight(c+Vector3.back)<3||detailRandom.NextDouble()<.35)continue;
    var corner=c+new Vector3(.5f,0,-.5f);
    var q=GameObject.CreatePrimitive(PrimitiveType.Quad);q.name="Keep cobweb";Destroy(q.GetComponent<Collider>());q.transform.SetParent(root,false);
    float s=DR(1.2f,1.9f);q.transform.SetPositionAndRotation(corner+new Vector3(-.4f,DR(2.6f,3.6f),.4f),Quaternion.LookRotation(new Vector3(1,0,-1))*Quaternion.Euler(0,0,DR(-12,12)));
    q.transform.localScale=new Vector3(s*1.4f,s,1);var r=q.GetComponent<MeshRenderer>();r.sharedMaterial=webMaterial;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;webs++;
   }
  }
  void KeepSetPieces(Transform root,string style)
  {
   var spots=new List<Vector3>();
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)if(keepWalk[i,k])spots.Add(KeepCellCentre(i,k)+new Vector3(DR(-.3f,.3f),0,DR(-.3f,.3f)));
   spots=spots.OrderBy(_=>detailRandom.Next()).ToList();
   string[] kinds=style switch
   {
    "gatehouse"=>new[]{"barricade","armour","debris","armour"},
    "armory"=>new[]{"armour","armour","dummy","armour","table"},
    "chapel"=>new[]{"candelabrum","candelabrum","fallen","debris"},
    "hall"=>new[]{"table","chairs","armour","fallen"},
    "cells"=>new[]{"rack","stocks","debris"},
    "throne"=>new[]{"fallen","armour","armour","candelabrum","candelabrum"},
    _=>new[]{"debris","candelabrum"},
   };
   int placed=0;var taken=new List<Vector3>();var log=new List<string>();
   foreach(var kind in kinds)
   {
    float r=kind=="armour"||kind=="candelabrum"||kind=="dummy"?.55f:kind=="debris"||kind=="chairs"?1.1f:1.5f;
    foreach(var p in spots)
    {
     if(taken.Any(t=>Vector3.Distance(t,p)<4.5f))continue;
     if(!DetailFree(p,r,kind=="armour"||kind=="candelabrum"?.5f:1f))continue;
     float yaw=Mathf.Round(DR(0,4))*90+DR(-12,12);
     switch(kind)
     {
      case "armour":ArmourStand(root,p,yaw);break;
      case "dummy":TrainingDummy(root,p,yaw);break;
      case "candelabrum":Candelabrum(root,p);break;
      case "fallen":FallenPillar(root,p,yaw);break;
      case "table":Workbench(root,p,yaw);break;
      case "chairs":Chairs(root,p,yaw);break;
      case "rack":TortureRack(root,p,yaw);break;
      case "stocks":Stocks(root,p,yaw);break;
      case "barricade":Barricade(root,p,yaw);break;
      default:Debris(root,p,yaw);break;
     }
     taken.Add(p);detailKeep.Add((p,r+1));log.Add(kind);placed++;break;
    }
   }
   Debug.Log("BLOODWAKE_DETAIL "+room.S("id")+" setpieces="+string.Join(",",log));
  }
  // A suit of plate on a stand: legs, cuirass, pauldrons, helm, a pike at its side.
  void ArmourStand(Transform root,Vector3 p,float yaw)
  {
   if(KeepModel(root,"keep_armor_stand",p,yaw)){PropBlocker(new Bounds(p+Vector3.up,new Vector3(.8f,2,.8f)));return;}
   var plate=KMat("ashlar",new Color(.95f,.97f,1.05f),new Vector2(.2f,.2f));var wood=KMat("timber",new Color(.45f,.36f,.27f),Vector2.one);var rot=Quaternion.Euler(0,yaw,0);
   KBoxR(root,"Keep stand base",p+Vector3.up*.05f,rot,new Vector3(.7f,.1f,.7f),wood);
   foreach(int s in new[]{-1,1})KBoxR(root,"Keep armour leg",p+rot*new Vector3(s*.13f,.5f,0),rot,new Vector3(.15f,.8f,.17f),plate);
   KBoxR(root,"Keep armour cuirass",p+Vector3.up*1.22f,rot,new Vector3(.5f,.62f,.3f),plate);
   foreach(int s in new[]{-1,1}){KBoxR(root,"Keep armour pauldron",p+rot*new Vector3(s*.33f,1.5f,0),rot*Quaternion.Euler(0,0,s*-20),new Vector3(.24f,.14f,.3f),plate);KBoxR(root,"Keep armour arm",p+rot*new Vector3(s*.33f,1.15f,0),rot,new Vector3(.12f,.55f,.14f),plate);}
   var helm=GameObject.CreatePrimitive(PrimitiveType.Sphere);helm.name="Keep armour helm";Destroy(helm.GetComponent<Collider>());helm.transform.SetParent(root,false);helm.transform.SetPositionAndRotation(p+Vector3.up*1.72f,rot);helm.transform.localScale=new Vector3(.26f,.3f,.28f);helm.GetComponent<Renderer>().sharedMaterial=plate;
   KBoxR(root,"Keep armour visor",p+rot*new Vector3(0,1.72f,.13f),rot,new Vector3(.2f,.03f,.04f),KMat("slate",new Color(.05f,.05f,.06f),Vector2.one));
   KBoxR(root,"Keep pike",p+rot*new Vector3(.5f,1.25f,0),rot,new Vector3(.05f,2.5f,.05f),wood);KBoxR(root,"Keep pike head",p+rot*new Vector3(.5f,2.6f,0),rot*Quaternion.Euler(0,0,45),new Vector3(.12f,.12f,.03f),plate);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(.8f,2,.8f)));
  }
  void TrainingDummy(Transform root,Vector3 p,float yaw)
  {
   if(KeepModel(root,"keep_training_dummy",p,yaw)){PropBlocker(new Bounds(p+Vector3.up,new Vector3(.9f,2,.7f)));return;}
   var wood=KMat("timber",new Color(.4f,.32f,.24f),Vector2.one);var sack=KMat("cloth",new Color(.5f,.44f,.32f),Vector2.one);var rot=Quaternion.Euler(0,yaw,0);
   KBoxR(root,"Keep dummy post",p+Vector3.up*.9f,rot,new Vector3(.14f,1.8f,.14f),wood);KBoxR(root,"Keep dummy arms",p+Vector3.up*1.35f,rot,new Vector3(1.2f,.1f,.1f),wood);
   KBoxR(root,"Keep dummy body",p+Vector3.up*1.15f,rot*Quaternion.Euler(0,0,4),new Vector3(.46f,.6f,.34f),sack);
   var head=GameObject.CreatePrimitive(PrimitiveType.Sphere);head.name="Keep dummy head";Destroy(head.GetComponent<Collider>());head.transform.SetParent(root,false);head.transform.position=p+Vector3.up*1.68f;head.transform.localScale=Vector3.one*.32f;head.GetComponent<Renderer>().sharedMaterial=sack;
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(.7f,2,.7f)));
  }
  // A tall iron stand of candles, lit.
  void Candelabrum(Transform root,Vector3 p)
  {
   if(KeepModel(root,"keep_candelabrum",p,0)){Lamp(root,"Sconce light",p+Vector3.up*2.05f);PropBlocker(new Bounds(p+Vector3.up,new Vector3(.6f,2,.6f)));return;}
   var iron=KMat("iron",new Color(.3f,.27f,.22f),Vector2.one);var wax=KMat("cloth",new Color(.85f,.8f,.68f),Vector2.one);
   KBox(root,"Keep candelabrum foot",p+Vector3.up*.06f,new Vector3(.5f,.12f,.5f),iron,false);KBox(root,"Keep candelabrum stem",p+Vector3.up*.85f,new Vector3(.07f,1.6f,.07f),iron,false);
   KBox(root,"Keep candelabrum bar",p+Vector3.up*1.6f,new Vector3(.8f,.05f,.05f),iron,false);
   foreach(float x in new[]{-.38f,0f,.38f})KBox(root,"Keep candle",p+new Vector3(x,1.72f+(x==0?.06f:0),0),new Vector3(.06f,.2f+(x==0?.12f:0),.06f),wax,false);
   Lamp(root,"Sconce light",p+Vector3.up*1.95f);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(.6f,2,.6f)));
  }
  // A column down across the floor in drums, with its rubble.
  void FallenPillar(Transform root,Vector3 p,float yaw)
  {
   if(KeepModel(root,"keep_fallen_column",p,yaw)){var reach=Quaternion.Euler(0,yaw,0)*new Vector3(3.2f,0,.9f);PropBlocker(new Bounds(p+Vector3.up,new Vector3(Mathf.Abs(reach.x)+.3f,2,Mathf.Abs(reach.z)+.3f)));return;}
   var stone=KMat("ashlar",new Color(.6f,.6f,.66f),new Vector2(1,.6f));var rot=Quaternion.Euler(0,yaw,0);
   for(int d=0;d<3;d++)
   {
    var drum=GameObject.CreatePrimitive(PrimitiveType.Cylinder);drum.name="Keep fallen drum";Destroy(drum.GetComponent<Collider>());drum.transform.SetParent(root,false);
    drum.transform.SetPositionAndRotation(p+rot*new Vector3((d-1)*1.05f,.42f,DR(-.08f,.08f)),rot*Quaternion.Euler(DR(-6,6),0,90));drum.transform.localScale=new Vector3(.84f,.48f,.84f);drum.GetComponent<Renderer>().sharedMaterial=stone;
   }
   KeepPiece(root,"rubble",p+rot*new Vector3(1.9f,0,.5f),new Vector3(1.1f,.5f,.9f),DR(0,180),false);
   var span=rot*new Vector3(3.2f,0,.9f);PropBlocker(new Bounds(p+Vector3.up,new Vector3(Mathf.Abs(span.x)+.3f,2,Mathf.Abs(span.z)+.3f)));
  }
  void Workbench(Transform root,Vector3 p,float yaw)
  {
   var wood=KMat("wood",new Color(.42f,.32f,.24f),new Vector2(2,1));var iron=KMat("iron",new Color(.42f,.42f,.46f),Vector2.one);var rot=Quaternion.Euler(0,yaw,0);
   KBoxR(root,"Keep bench top",p+Vector3.up*.82f,rot,new Vector3(2.4f,.1f,.9f),wood);
   foreach(int a in new[]{-1,1})foreach(int b in new[]{-1,1})KBoxR(root,"Keep bench leg",p+rot*new Vector3(a*1.05f,.4f,b*.35f),rot,new Vector3(.1f,.8f,.1f),wood);
   KBoxR(root,"Keep bench blade",p+rot*new Vector3(-.4f,.9f,0),rot*Quaternion.Euler(0,20,0),new Vector3(1.1f,.03f,.09f),iron);
   KBoxR(root,"Keep bench helm",p+rot*new Vector3(.6f,.98f,.1f),rot,new Vector3(.26f,.24f,.28f),iron);
   KeepPiece(root,"candles",p+rot*new Vector3(.95f,.87f,-.2f),new Vector3(.4f,.28f,.34f),0,false);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(2.5f,2,2.5f)));
  }
  // Chairs knocked over round a spilled cask.
  void Chairs(Transform root,Vector3 p,float yaw)
  {
   var wood=KMat("wood",new Color(.4f,.3f,.22f),Vector2.one);
   for(int i=0;i<3;i++)
   {
    var q=Quaternion.Euler(0,yaw+i*120+DR(-20,20),0);var c=p+q*Vector3.forward*DR(.7f,1.1f);bool down=i!=1;var tilt=q*(down?Quaternion.Euler(80,0,0):Quaternion.identity);
    KBoxR(root,"Keep chair seat",c+Vector3.up*(down?.25f:.45f),tilt,new Vector3(.45f,.06f,.45f),wood);KBoxR(root,"Keep chair back",c+(down?q*Vector3.back*.45f+Vector3.up*.25f:q*Vector3.back*.2f+Vector3.up*.75f),tilt,new Vector3(.45f,.55f,.05f),wood);
   }
   var cask=Piece(root,"barrel",p+Vector3.up*.3f,new Vector3(.6f,.8f,.6f),yaw,false);if(cask){cask.transform.parent.rotation=Quaternion.Euler(0,yaw,90);}
   Decal(root,"Keep spilled wine",p+Quaternion.Euler(0,yaw,0)*Vector3.right*.8f,1.8f,DR(0,360),bloodMaterial,.008f);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(1,2,1)));
  }
  void TortureRack(Transform root,Vector3 p,float yaw)
  {
   if(KeepModel(root,"keep_torture_rack",p,yaw)){PropBlocker(new Bounds(p+Vector3.up,new Vector3(2.5f,2,2.5f)));return;}
   var wood=KMat("timber",new Color(.32f,.25f,.19f),Vector2.one);var iron=KMat("iron",new Color(.3f,.3f,.32f),Vector2.one);var rot=Quaternion.Euler(0,yaw,0);
   foreach(int s in new[]{-1,1})KBoxR(root,"Keep rack rail",p+rot*new Vector3(0,.7f,s*.45f),rot,new Vector3(2.4f,.14f,.14f),wood);
   foreach(int a in new[]{-1,1})foreach(int b in new[]{-1,1})KBoxR(root,"Keep rack leg",p+rot*new Vector3(a*1.1f,.35f,b*.45f),rot,new Vector3(.14f,.7f,.14f),wood);
   foreach(int a in new[]{-1,1})KBoxR(root,"Keep rack roller",p+rot*new Vector3(a*1.05f,.8f,0),rot*Quaternion.Euler(90,0,0),new Vector3(.18f,1f,.18f),wood);
   for(int i=0;i<5;i++)KBoxR(root,"Keep rack slat",p+rot*new Vector3(-.8f+i*.4f,.72f,0),rot,new Vector3(.12f,.04f,.9f),wood);
   KBoxR(root,"Keep rack chain",p+rot*new Vector3(1.2f,.3f,.3f),rot*Quaternion.Euler(0,0,60),new Vector3(.04f,.7f,.04f),iron);
   Decal(root,"Keep blood",p,2f,DR(0,360),bloodMaterial,.008f);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(2.5f,2,2.5f)));
  }
  void Stocks(Transform root,Vector3 p,float yaw)
  {
   if(KeepModel(root,"keep_stocks",p,yaw)){PropBlocker(new Bounds(p+Vector3.up,new Vector3(1.8f,2,1.8f)));return;}
   var wood=KMat("timber",new Color(.38f,.3f,.22f),Vector2.one);var rot=Quaternion.Euler(0,yaw,0);
   foreach(int s in new[]{-1,1})KBoxR(root,"Keep stocks post",p+rot*new Vector3(s*.8f,.6f,0),rot,new Vector3(.16f,1.2f,.16f),wood);
   KBoxR(root,"Keep stocks board",p+Vector3.up*.95f,rot,new Vector3(1.8f,.36f,.12f),wood);
   var dark=KMat("slate",new Color(.04f,.04f,.04f),Vector2.one);foreach(float x in new[]{-.45f,0f,.45f})KBoxR(root,"Keep stocks hole",p+rot*new Vector3(x,.95f,.065f),rot,new Vector3(.16f,.16f,.01f),dark);
   Piece(root,"bones",p+rot*new Vector3(0,0,.6f),new Vector3(1.04f,.2f,.82f),DR(0,360),false);
   PropBlocker(new Bounds(p+Vector3.up,new Vector3(1.8f,2,1.8f)));
  }
  void Debris(Transform root,Vector3 p,float yaw)
  {
   var rot=Quaternion.Euler(0,yaw,0);var stone=KMat("ashlar",new Color(.55f,.55f,.6f),Vector2.one);
   KeepPiece(root,"rubble",p,new Vector3(1.4f,.6f,1.1f),yaw,true);
   for(int i=0;i<4;i++)KBoxR(root,"Keep fallen block",p+rot*new Vector3(DR(-1.2f,1.2f),.18f,DR(-1,1)),Quaternion.Euler(DR(-15,15),DR(0,360),DR(-15,15)),new Vector3(DR(.35f,.6f),DR(.25f,.4f),DR(.3f,.5f)),stone);
   KBoxR(root,"Keep broken beam",p+rot*new Vector3(.4f,.35f,-.6f),rot*Quaternion.Euler(0,30,14),new Vector3(2.2f,.2f,.22f),KMat("timber",new Color(.3f,.24f,.18f),Vector2.one));
  }

  // ---- Shared.
  GameObject KBoxR(Transform root,string name,Vector3 at,Quaternion rotation,Vector3 size,Material material)
  {
   var go=GameObject.CreatePrimitive(PrimitiveType.Cube);go.name=name;Destroy(go.GetComponent<Collider>());go.transform.SetParent(root,false);go.transform.SetPositionAndRotation(at,rotation);go.transform.localScale=size;
   go.GetComponent<Renderer>().sharedMaterial=material;
   if(worldUv.Contains(material))go.GetComponent<MeshFilter>().sharedMesh=WorldUvCube(at,size,rotation);
   return go;
  }
  static void EnsureDetailMaterials()
  {
   EnsureDecalMaterials();
   if(leafMaterial)return;
   leafMaterial=DecalMaterial("Leaf decal",Leaves(256,21),new Color(.36f,.22f,.11f,1),.15f);
   paperMaterial=DecalMaterial("Paper decal",Scraps(256,31),new Color(.55f,.5f,.42f,.9f),.1f);
   scorchMaterial=DecalMaterial("Scorch decal",Scorch(256,41),new Color(.02f,.015f,.012f,1),.05f);
   medallionMaterial=DecalMaterial("Medallion decal",Medallion(512),new Color(.07f,.07f,.09f,.85f),.45f);
   webMaterial=DecalMaterial("Cobweb",Web(256,51),new Color(.75f,.75f,.8f,.55f),0);webMaterial.SetFloat("_Cull",0);
  }
  // Small curled leaves scattered in a drift.
  static Texture2D Leaves(int size,int seed)
  {
   var a=new float[size*size];var rnd=new System.Random(seed);
   for(int n=0;n<60;n++)
   {
    float ang=(float)rnd.NextDouble()*6.283f,rr=(float)System.Math.Sqrt(rnd.NextDouble())*size*.38f;float cx=size*.5f+Mathf.Cos(ang)*rr,cy=size*.5f+Mathf.Sin(ang)*rr,dir=(float)rnd.NextDouble()*3.14f,len=size*(.025f+.025f*(float)rnd.NextDouble()),wid=len*.45f;
    float shade=.55f+.45f*(float)rnd.NextDouble();
    for(int y=(int)(cy-len);y<=cy+len;y++)for(int x=(int)(cx-len);x<=cx+len;x++)
    {
     if(x<0||y<0||x>=size||y>=size)continue;float dx=x-cx,dy=y-cy;float u=dx*Mathf.Cos(dir)+dy*Mathf.Sin(dir),v=-dx*Mathf.Sin(dir)+dy*Mathf.Cos(dir);
     float d=(u*u)/(len*len)+(v*v)/(wid*wid);if(d<1)a[y*size+x]=Mathf.Max(a[y*size+x],shade*Mathf.Clamp01((1-d)*4));
    }
   }
   return FromAlpha(size,a,"Leaves");
  }
  // Torn scraps of paper and cloth.
  static Texture2D Scraps(int size,int seed)
  {
   var a=new float[size*size];var rnd=new System.Random(seed);
   for(int n=0;n<9;n++)
   {
    float cx=size*(.2f+.6f*(float)rnd.NextDouble()),cy=size*(.2f+.6f*(float)rnd.NextDouble()),dir=(float)rnd.NextDouble()*3.14f,w=size*(.05f+.07f*(float)rnd.NextDouble()),h=w*(.5f+.6f*(float)rnd.NextDouble());
    for(int y=0;y<size;y++)for(int x=0;x<size;x++)
    {
     float dx=x-cx,dy=y-cy;float u=dx*Mathf.Cos(dir)+dy*Mathf.Sin(dir),v=-dx*Mathf.Sin(dir)+dy*Mathf.Cos(dir);
     float edge=Mathf.PerlinNoise(x*.15f+n*7,y*.15f)*w*.25f;if(Mathf.Abs(u)<w-edge&&Mathf.Abs(v)<h-edge)a[y*size+x]=.7f+.3f*Mathf.PerlinNoise(x*.05f,y*.05f+n);
    }
   }
   return FromAlpha(size,a,"Scraps");
  }
  // A burnt ring: dense black in the middle breaking up into soot at the edge.
  static Texture2D Scorch(int size,int seed)
  {
   var a=new float[size*size];float o=seed*3.1f;
   for(int y=0;y<size;y++)for(int x=0;x<size;x++)
   {
    float u=x/(float)size-.5f,v=y/(float)size-.5f,r=Mathf.Sqrt(u*u+v*v)*2;float n=Mathf.PerlinNoise(x*.04f+o,y*.04f+o)*.5f+Mathf.PerlinNoise(x*.15f+o,y*.15f)*.5f;
    a[y*size+x]=Mathf.Clamp01((1-r)*1.6f-(1-n)*.7f)*.95f;
   }
   return FromAlpha(size,a,"Scorch");
  }
  // An inlaid floor rose: two rings, eight spokes and a star, as dark joints in the stone.
  static Texture2D Medallion(int size)
  {
   var a=new float[size*size];
   for(int y=0;y<size;y++)for(int x=0;x<size;x++)
   {
    float u=(x+.5f)/size*2-1,v=(y+.5f)/size*2-1,r=Mathf.Sqrt(u*u+v*v),ang=Mathf.Atan2(v,u);float line=0;
    float Ring(float at,float w)=>Mathf.Clamp01(1-Mathf.Abs(r-at)/w);
    line=Mathf.Max(line,Ring(.96f,.012f));line=Mathf.Max(line,Ring(.88f,.008f));line=Mathf.Max(line,Ring(.42f,.01f));line=Mathf.Max(line,Ring(.12f,.012f));
    // Spokes between the rings.
    if(r>.12f&&r<.88f){float s=Mathf.Abs(Mathf.Sin(ang*4))*r;line=Mathf.Max(line,Mathf.Clamp01(1-s/.008f));}
    // An eight-point star inside the inner ring: its edge where r equals a sawtooth of the angle.
    float star=.42f*(.62f+.38f*Mathf.Abs(Mathf.Cos(ang*4)));
    line=Mathf.Max(line,Mathf.Clamp01(1-Mathf.Abs(r-star)/.01f)*(r<.42f?1:0));
    // Filled band between the outer rings.
    if(r>.88f&&r<.96f)line=Mathf.Max(line,.35f);
    a[y*size+x]=line*Mathf.Clamp01((1-r)*40);
   }
   return FromAlpha(size,a,"Medallion");
  }
  // A cobweb fanning from the top corner: radial threads and a sagging spiral.
  static Texture2D Web(int size,int seed)
  {
   var a=new float[size*size];var rnd=new System.Random(seed);
   var corner=new Vector2(size*.5f,size-1);
   void Line(Vector2 p,Vector2 q,float v){int steps=(int)(Vector2.Distance(p,q)*1.5f)+1;for(int i=0;i<=steps;i++){var m=Vector2.Lerp(p,q,i/(float)steps);int ix=(int)m.x,iy=(int)m.y;if(ix<0||iy<0||ix>=size||iy>=size)continue;a[iy*size+ix]=Mathf.Max(a[iy*size+ix],v);}}
   int spokes=9;var ends=new Vector2[spokes];
   for(int s=0;s<spokes;s++){float ang=Mathf.Lerp(200,340,s/(float)(spokes-1))*Mathf.Deg2Rad+((float)rnd.NextDouble()-.5f)*.08f;ends[s]=corner+new Vector2(Mathf.Cos(ang),Mathf.Sin(ang))*size*(.8f+.15f*(float)rnd.NextDouble());Line(corner,ends[s],.9f);}
   for(float t=.12f;t<.95f;t+=.075f)for(int s=0;s<spokes-1;s++)
   {
    var p=Vector2.Lerp(corner,ends[s],t);var q=Vector2.Lerp(corner,ends[s+1],t+.01f);var mid=(p+q)*.5f+Vector2.down*size*.02f*t;Line(p,mid,.6f);Line(mid,q,.6f);
   }
   // A torn strand hanging free.
   Line(ends[3],ends[3]+new Vector2(6,-size*.15f),.5f);
   return FromAlpha(size,a,"Web");
  }
 }
}
