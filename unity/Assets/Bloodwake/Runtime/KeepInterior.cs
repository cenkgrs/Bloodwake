using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 // The Hollow Keep (second map): castle interiors with their own shapes. Each room's walkable area is a union of
 // rectangles (floor, minus carve, in hollow_keep.json) laid on a 1 m grid; every other cell inside and around
 // the room is solid stone, drawn where it borders the floor and always a blocker, so collision, the crowd navmesh
 // and the spawn search all follow the shape. The camera looks in from -x/+z: stone is drawn as tall as it can be
 // without hiding floor behind it from the camera, so the far sides rise into full castle walls (with pointed
 // windows and banners) while the near sides drop to a low parapet. Each style then adds its own furniture.
 public sealed partial class BloodwakeGame
 {
  const float KeepTall=4.4f,KeepLow=1.1f,KeepCell=1;
  static readonly Dictionary<string,Material> keepMaterials=new();
  static Texture2D shaftTexture;static Material shaftMaterial;
  System.Random keepRandom;
  float KR(float a,float b)=>a+(float)keepRandom.NextDouble()*(b-a);
  // Grid over the room plus one ring of cells outside it: true where the hunter can walk.
  bool[,] keepWalk;int keepW,keepH;float keepX0,keepZ0;
  // Room coordinates (as the markers use them) to world.
  static Vector3 J(float x,float z)=>new Vector3(-x,0,z);

  void BuildKeep()
  {
   // EnterRoom's grey boundary boxes stay as blockers but are not drawn.
   foreach(var r in roomRoot.GetComponentsInChildren<Renderer>())r.enabled=false;
   string style=room.S("keep","hall");keepRandom=new System.Random(room.S("id").GetHashCode());
   var root=new GameObject("Keep "+style).transform;root.SetParent(roomRoot,false);
   float hx=half.x,hz=half.y;
   KeepGrid(hx,hz);
   KeepFloor(root);
   KeepStone(root,hx,hz);
   KeepExitGate(root,new Vector3(0,0,-hz),style=="gatehouse"||style=="cells");
   switch(style)
   {
    case "gatehouse":KeepGatehouse(root);break;
    case "armory":KeepArmory(root);break;
    case "chapel":KeepChapel(root);break;
    case "hall":KeepHall(root);break;
    case "cells":KeepCells(root);break;
    case "throne":KeepThrone(root);break;
    case "undercroft":KeepUndercroft(root);break;
   }
   KeepScatter(root,style);
   DetailKeep(root,style);
   KeepFill(root,style);
   // Every marker must stand on the floor; report any that the shape left inside the stone.
   foreach(var marker in (room["markers"] as JObject)?.Properties()??new List<JProperty>())
   {
    var points=marker.Value is JArray list&&list.Count>0&&list[0] is JArray?list:new JArray(marker.Value);
    foreach(var p in points)if(!KeepWalkable(Point(p)))Debug.LogWarning("BLOODWAKE_KEEP_BAD_MARKER "+room.S("id")+" "+marker.Name+" "+p.ToString(Newtonsoft.Json.Formatting.None));
   }
  }

  // ---- Shape.
  void KeepGrid(float hx,float hz)
  {
   keepX0=-hx-KeepCell;keepZ0=-hz-KeepCell;keepW=Mathf.RoundToInt((hx*2+2*KeepCell)/KeepCell);keepH=Mathf.RoundToInt((hz*2+2*KeepCell)/KeepCell);
   keepWalk=new bool[keepW,keepH];
   var floor=room["floor"] as JArray??new JArray(new JArray(-hx,-hz,hx,hz));var carve=room["carve"] as JArray??new JArray();
   bool In(JArray rects,Vector3 c){foreach(JArray r in rects){var a=J((float)r[0],(float)r[1]);var b=J((float)r[2],(float)r[3]);if(c.x>=Mathf.Min(a.x,b.x)&&c.x<=Mathf.Max(a.x,b.x)&&c.z>=Mathf.Min(a.z,b.z)&&c.z<=Mathf.Max(a.z,b.z))return true;}return false;}
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    var c=KeepCellCentre(i,k);
    keepWalk[i,k]=Mathf.Abs(c.x)<hx&&Mathf.Abs(c.z)<hz&&In(floor,c)&&!In(carve,c);
   }
  }
  Vector3 KeepCellCentre(int i,int k)=>new Vector3(keepX0+(i+.5f)*KeepCell,0,keepZ0+(k+.5f)*KeepCell);
  bool KeepWalkCell(int i,int k)=>i>=0&&k>=0&&i<keepW&&k<keepH&&keepWalk[i,k];
  bool KeepWalkable(Vector3 p)=>KeepWalkCell(Mathf.FloorToInt((p.x-keepX0)/KeepCell),Mathf.FloorToInt((p.z-keepZ0)/KeepCell));
  // The door gaps stay open: stone is neither drawn nor solid in the 5 m in front of either door.
  bool KeepDoorGap(Vector3 c)=>Mathf.Abs(c.x)<2.5f&&Mathf.Abs(c.z)>half.y-1.2f;

  // Flagstones on the walkable cells only, one slab per row run so nothing overlaps.
  void KeepFloor(Transform root)
  {
   for(int k=0;k<keepH;k++)for(int i=0;i<keepW;)
   {
    if(!keepWalk[i,k]){i++;continue;}int start=i;while(i<keepW&&keepWalk[i,k])i++;
    float len=(i-start)*KeepCell;var c=KeepCellCentre(start,k)+Vector3.right*(len-KeepCell)*.5f;
    KBox(root,"Keep floor",c+Vector3.down*.05f,new Vector3(len,.1f,KeepCell),KMat("flagstone",new Color(.9f,.9f,.95f),new Vector2(len*.45f,.45f)),false);
   }
  }
  // Stone everywhere that is not floor. Blockers in row runs; drawn blocks only along the floor's edge, each as
  // tall as the camera allows (it looks down along +x,-z at about 35 degrees, so a block of height h hides
  // ~1.43 h of floor behind it).
  void KeepStone(Transform root,float hx,float hz)
  {
   for(int k=0;k<keepH;k++)for(int i=0;i<keepW;)
   {
    if(keepWalk[i,k]||KeepDoorGap(KeepCellCentre(i,k))){i++;continue;}int start=i;while(i<keepW&&!keepWalk[i,k]&&!KeepDoorGap(KeepCellCentre(i,k)))i++;
    float len=(i-start)*KeepCell;var c=KeepCellCentre(start,k)+Vector3.right*(len-KeepCell)*.5f;
    blockers.Add(new Bounds(c+Vector3.up,new Vector3(len,2,KeepCell)));
   }
   var look=new Vector3(-cameraOffset.x,0,-cameraOffset.z).normalized;
   var stone=KMat("ashlar",new Color(.85f,.85f,.9f),new Vector2(.5f,1.6f));var parapet=KMat("ashlar",new Color(.7f,.7f,.76f),new Vector2(.5f,.5f));var cap=KMat("slate",new Color(.4f,.41f,.46f),Vector2.one);var roof=KMat("slate",new Color(.5f,.5f,.56f),new Vector2(1,1));
   int faces=0;
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    if(keepWalk[i,k])continue;var c=KeepCellCentre(i,k);if(KeepDoorGap(c))continue;
    bool edge=false;for(int di=-1;di<=1&&!edge;di++)for(int dk=-1;dk<=1;dk++)if(KeepWalkCell(i+di,k+dk)){edge=true;break;}
    float first=99;for(float t=.5f;t<=7;t+=.25f)if(KeepWalkable(c+look*t)){first=t;break;}
    float h=Mathf.Clamp((first-.7f)/1.43f,KeepLow,KeepTall);
    // Stone enclosed inside the room (the armoury block, the cell block) is roofed at the height its walls
    // would have, so it reads as a building rather than a hole.
    if(!edge)
    {
     if(Mathf.Abs(c.x)<hx-.5f&&Mathf.Abs(c.z)<hz-.5f)KBox(root,"Keep roof",c+Vector3.up*(h+.06f),new Vector3(KeepCell+.02f,.12f,KeepCell+.02f),roof,false);
     continue;
    }
    KBox(root,h>=KeepTall-.01f?"Keep wall":"Keep parapet",c+Vector3.up*h*.5f,new Vector3(KeepCell,h,KeepCell),h>2?stone:parapet,false);
    KBox(root,"Keep wall cap",c+Vector3.up*(h+.06f),new Vector3(KeepCell+.06f,.12f,KeepCell+.06f),cap,false);
    // Visible faces of the full-height stone (floor on the camera's side of it) carry the windows and banners.
    if(h<KeepTall-.01f)continue;
    foreach(var n in new[]{Vector3.forward,Vector3.left})
    {
     if(!KeepWalkable(c+n*KeepCell))continue;faces++;
     var face=c+n*KeepCell*.5f;
     if(faces%5==2)KeepWindow(root,face,n);
     else if(faces%9==6)KeepBanner(root,face,n,keepRandom.NextDouble()<.6?new Color(.38f,.06f,.07f):new Color(.12f,.13f,.19f));
    }
   }
  }
  // A pointed window on a wall face: a dark frame, a pale glowing pane and arch, a cold light just inside and a
  // shaft of moonlight laid across the floor in front of it.
  void KeepWindow(Transform root,Vector3 at,Vector3 inward)
  {
   bool alongZ=Mathf.Abs(inward.x)>.5f;float sill=1.6f,height=2.1f,width=.75f;
   KBox(root,"Keep window frame",at+inward*.02f+Vector3.up*(sill+height*.5f),Size(alongZ,width+.3f,height+.25f,.08f),KMat("slate",new Color(.2f,.21f,.25f),Vector2.one),false);
   Glass(root,"Keep window pane",at+inward*.07f+Vector3.up*(sill+height*.5f),Quaternion.LookRotation(-inward),new Vector3(width,height,1));
   Glass(root,"Keep window arch",at+inward*.07f+Vector3.up*(sill+height+.18f),Quaternion.LookRotation(-inward)*Quaternion.Euler(0,0,45),Vector3.one*width*.7f);
   var floorAt=new Vector3(at.x,0,at.z)+inward*2.2f;
   if(KeepWalkable(floorAt))Glass(root,"Keep moon shaft",floorAt+Vector3.up*.03f,Quaternion.LookRotation(Vector3.down,inward),new Vector3(width*1.5f,3.8f,1));
   var light=new GameObject("Keep cold window light").AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=at+inward*1.2f+Vector3.up*2.2f;
   light.type=LightType.Point;light.color=new Color(.55f,.66f,1);light.intensity=2.2f;light.range=6;light.shadows=LightShadows.None;
  }
  void Glass(Transform root,string name,Vector3 at,Quaternion rotation,Vector3 scale)
  {
   var q=GameObject.CreatePrimitive(PrimitiveType.Quad);q.name=name;Destroy(q.GetComponent<Collider>());q.transform.SetParent(root,false);q.transform.SetPositionAndRotation(at,rotation);q.transform.localScale=scale;
   var r=q.GetComponent<MeshRenderer>();r.sharedMaterial=ShaftMaterial();r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
  }
  // A long cloth banner hanging on a wall face from an iron rod, with a pointed tail.
  void KeepBanner(Transform root,Vector3 at,Vector3 inward,Color color)
  {
   bool alongZ=Mathf.Abs(inward.x)>.5f;var cloth=KMat("cloth",color,new Vector2(1,2));var p=at+inward*.05f;float length=2.6f;
   KBox(root,"Keep banner",p+Vector3.up*(KeepTall-.5f-length*.5f),Size(alongZ,.8f,length,.04f),cloth,false);
   KBox(root,"Keep banner rod",p+Vector3.up*(KeepTall-.45f),Size(alongZ,1.05f,.06f,.06f),KMat("iron",new Color(.3f,.3f,.32f),Vector2.one),false);
   var tail=GameObject.CreatePrimitive(PrimitiveType.Cube);tail.name="Keep banner tail";Destroy(tail.GetComponent<Collider>());tail.transform.SetParent(root,false);
   tail.transform.position=p+Vector3.up*(KeepTall-.5f-length);tail.transform.rotation=Quaternion.LookRotation(inward)*Quaternion.Euler(0,0,45);tail.transform.localScale=new Vector3(.57f,.57f,.04f);tail.GetComponent<Renderer>().sharedMaterial=cloth;
  }
  // The exit: the town's articulated double gate (it swings open when the room is cleared), or an iron portcullis
  // that rises.
  void KeepExitGate(Transform root,Vector3 at,bool portcullis)
  {
   if(portcullis)
   {
    var iron=KMat("iron",new Color(.35f,.36f,.4f),Vector2.one);var bars=new GameObject("Keep portcullis").transform;bars.SetParent(root,false);bars.position=at;
    for(float x=-2;x<=2.01f;x+=.4f)KBox(bars,"Keep portcullis bar",at+new Vector3(x,1.9f,0),new Vector3(.09f,3.8f,.09f),iron,false);
    for(float y=.5f;y<3.8f;y+=.7f)KBox(bars,"Keep portcullis rail",at+new Vector3(0,y,0),new Vector3(4.2f,.08f,.08f),iron,false);
    bars.gameObject.AddComponent<KeepPortcullis>().Game=this;
    return;
   }
   var source=Resources.Load<GameObject>("Environment/Kit01/gate/gate_articulated");if(!source)return;
   var gate=Instantiate(source,root);gate.name="Keep exit gate";gate.transform.SetPositionAndRotation(at,Quaternion.LookRotation(Vector3.forward));
   var b=EnvironmentDressing.BoundsOf(gate.GetComponentsInChildren<Renderer>());gate.transform.localScale=new Vector3(4.4f/b.size.x,4.2f/b.size.y,1.25f);
   var animated=gate.AddComponent<CourtyardGate>();animated.Game=this;animated.Exit=true;animated.Left=gate.transform.Find("Left leaf");animated.Right=gate.transform.Find("Right leaf");
   if(!animated.Left||!animated.Right)Destroy(animated);
  }

  // ---- Rooms (furniture in room coordinates; anything that would land in stone is skipped).
  void KeepGatehouse(Transform root)
  {
   // Two squat towers flank the choke; braziers light its mouth from both courts.
   foreach(var p in new[]{J(-3.6f,-3.6f),J(3.6f,-3.6f),J(-3.6f,4.6f),J(3.6f,4.6f)})KeepPillar(root,p,KeepTall,true);
   foreach(var p in new[]{J(-4.5f,6.5f),J(4.5f,6.5f),J(-5,-6),J(5,-6)})KeepBrazier(root,p);
   for(float x=-9;x<=9.01f;x+=3.6f)if(Mathf.Abs(x)>3)KeepPiece(root,"weapon_rack",J(x,-12.2f),new Vector3(1.55f,1.36f,.6f),0,true);
   foreach(var p in new[]{J(-6.5f,11.5f),J(6.8f,11.3f),J(-9.5f,-4.2f),J(9.8f,-4.5f)})KeepPiece(root,"rubble",p,new Vector3(1.4f,.6f,1.1f),KR(0,180),true);
  }
  void KeepArmory(Transform root)
  {
   // The armoury block in the middle is solid; its walls are hung with racks facing the corridor.
   for(float x=-5.5f;x<=5.51f;x+=2.2f){KeepPiece(root,"weapon_rack",J(x,5.6f),new Vector3(1.55f,1.36f,.6f),0,true);KeepPiece(root,"weapon_rack",J(x,-5.6f),new Vector3(1.55f,1.36f,.6f),180,true);}
   var iron=KMat("iron",new Color(.3f,.3f,.33f),Vector2.one);
   foreach(int side in new[]{-1,1})
   {
    var a=J(side*10.5f,-8.5f);KBox(root,"Keep anvil",a+Vector3.up*.45f,new Vector3(1.2f,.9f,.6f),iron,true);KeepBrazier(root,a+J(side*-1.6f,-1.2f));
    KeepPiece(root,"crate",J(side*11.8f,4),new Vector3(.95f,.95f,.95f),KR(0,60),true);KeepPiece(root,"barrel",J(side*11.6f,5.6f),new Vector3(.7f,.95f,.7f),0,true);
    KeepBrazier(root,J(side*10,9.5f));
   }
  }
  void KeepChapel(Transform root)
  {
   var wood=KMat("wood",new Color(.42f,.32f,.25f),new Vector2(2,.5f));
   // Pews down both sides of the nave, an aisle between.
   foreach(int side in new[]{-1,1})for(float z=1.5f;z<=12.01f;z+=1.5f)
   {
    var p=J(side*2.6f,z);if(!KeepWalkable(p))continue;
    KBox(root,"Keep pew seat",p+Vector3.up*.45f,new Vector3(2.2f,.12f,.5f),wood,true);KBox(root,"Keep pew back",p+new Vector3(0,.75f,.28f),new Vector3(2.2f,.7f,.08f),wood,false);
   }
   var stone=KMat("ashlar",new Color(.62f,.62f,.68f),Vector2.one);
   KBox(root,"Keep altar",J(0,-12)+Vector3.up*.55f,new Vector3(3.2f,1.1f,1.4f),stone,true);
   KBox(root,"Keep altar cloth",J(0,-12)+Vector3.up*1.12f,new Vector3(3.4f,.04f,1f),KMat("cloth",new Color(.6f,.58f,.5f),Vector2.one),false);
   KeepPiece(root,"shrine_statue",J(0,-14.2f),new Vector3(1f,2.8f,1f),0,true);
   foreach(int side in new[]{-1,1}){KeepPiece(root,"candles",J(side*1.2f,-12)+Vector3.up*1.12f,new Vector3(.6f,.42f,.52f),0,false);Lamp(root,"Lantern light",J(side*1.2f,-12)+Vector3.up*1.6f);}
   foreach(var p in new[]{J(-12,-6.2f),J(12,-6.2f),J(-12,-1.8f),J(12,-1.8f)})KeepPiece(root,"candles",p,new Vector3(.6f,.42f,.52f),KR(0,90),false);
   foreach(int side in new[]{-1,1})KeepBrazier(root,J(side*9,-4));
   // Stained glass: the windows throw coloured light.
   var hues=new[]{new Color(.45f,.55f,1),new Color(.75f,.3f,.85f),new Color(.9f,.35f,.3f)};int h=0;
   foreach(var light in root.GetComponentsInChildren<Light>())if(light.name=="Keep cold window light"){light.color=hues[h%hues.Length];light.intensity=2.8f;h++;}
  }
  void KeepHall(Transform root)
  {
   var wood=KMat("wood",new Color(.45f,.33f,.24f),new Vector2(1,4));var cloth=KMat("cloth",new Color(.42f,.06f,.07f),new Vector2(1,6));
   // A long table down the east side of the hall arm, a carpet up its middle to the exit.
   KBox(root,"Keep carpet",J(1.6f,-1)+Vector3.up*.012f,new Vector3(2.2f,.02f,22),cloth,false);
   var t=J(4.4f,-4.5f);KBox(root,"Keep table",t+Vector3.up*.8f,new Vector3(1.6f,.12f,10),wood,true);
   foreach(int end in new[]{-1,1})foreach(int s2 in new[]{-1,1})KBox(root,"Keep table leg",t+new Vector3(s2*.6f,.4f,end*4.6f),new Vector3(.16f,.8f,.16f),wood,false);
   for(float z=-3.5f;z<=3.51f;z+=3.5f)KeepPiece(root,"candles",t+new Vector3(0,.86f,z),new Vector3(.5f,.36f,.44f),KR(0,90),false);
   Lamp(root,"Lantern light",t+new Vector3(0,1.4f,-2));Lamp(root,"Lantern light",t+new Vector3(0,1.4f,2.5f));
   // The west wing: a hearth at its far end, benches, and the dark the garrison waits in.
   var hearth=J(-13.4f,8);var stoneMat=KMat("ashlar",new Color(.5f,.48f,.48f),Vector2.one);
   KBox(root,"Keep hearth",hearth+Vector3.up*1.4f,new Vector3(.9f,2.8f,3.4f),stoneMat,true);
   KeepPiece(root,"firewood",hearth+J(1,0),new Vector3(1.23f,.56f,1.02f),90,false);Lamp(root,"Brazier light",hearth+J(1.3f,0)+Vector3.up*.9f);
   foreach(float x in new[]{-10f,-6f})KBox(root,"Keep bench",J(x,8)+Vector3.up*.42f,new Vector3(2.6f,.1f,.45f),wood,true);
   KeepChandelier(root,J(2,-8)+Vector3.up*3.6f);KeepChandelier(root,J(2,2)+Vector3.up*3.6f);KeepChandelier(root,J(-8,8)+Vector3.up*3.6f);
  }
  void KeepCells(Transform root)
  {
   var iron=KMat("iron",new Color(.3f,.31f,.33f),Vector2.one);
   // The central cell block (solid stone) shows barred cell fronts to both corridors.
   foreach(int side in new[]{-1,1})for(float z=-3;z<=4.01f;z+=2.4f)
   {
    var front=J(side*5,z);
    for(float b=-1;b<=1.01f;b+=.33f)KBox(root,"Keep cell bar",front+new Vector3(0,1.25f,b),new Vector3(.06f,2.5f,.06f),iron,false);
    KBox(root,"Keep cell rail",front+new Vector3(0,2.45f,0),new Vector3(.1f,.1f,2.2f),iron,false);
   }
   foreach(var p in new[]{J(-3,-11.5f),J(3.5f,-6),J(-6,11.5f),J(5.5f,10)})KeepPiece(root,"cage",p,new Vector3(.83f,1.85f,1f),KR(0,90),true);
   foreach(var p in new[]{J(-9,-6),J(9,-12),J(6.5f,7)})KeepPiece(root,keepRandom.NextDouble()<.5?"coffin":"bones",p,new Vector3(2f,.56f,.64f),KR(0,180),false);
   for(int i=0;i<6;i++){var p=J(KR(-9,9),KR(-12,-5));float len=KR(1.2f,2.6f);KBox(root,"Keep chain",p+Vector3.up*(KeepTall-len*.5f),new Vector3(.05f,len,.05f),iron,false);}
   // Braziers stand in the courts, never in the 3 m corridors they would block.
   foreach(var p in new[]{J(0,-12),J(-8.5f,-5.5f),J(8.5f,-5.5f),J(-6.5f,6.5f),J(6.5f,6.5f),J(0,8)})KeepBrazier(root,p);
   foreach(var light in root.GetComponentsInChildren<Light>())if(light.name=="Keep cold window light"){light.color=new Color(.5f,.85f,.75f);light.intensity=1.8f;}
  }
  void KeepThrone(Transform root)
  {
   var stone=KMat("ashlar",new Color(.58f,.58f,.64f),Vector2.one);var cloth=KMat("cloth",new Color(.38f,.05f,.06f),new Vector2(1,8));var iron=KMat("iron",new Color(.33f,.33f,.36f),Vector2.one);
   KBox(root,"Keep carpet",J(0,2)+Vector3.up*.012f,new Vector3(3.4f,.02f,26),cloth,false);
   // Stepped dais: three rises to the throne.
   for(int step=0;step<3;step++)KBox(root,"Keep dais",J(0,-15.5f+step*.0f)+new Vector3(0,.15f+step*.15f,1.4f-step*.9f),new Vector3(12-step*3,.3f+step*.3f,3-step*.6f),stone,step==2);
   KBox(root,"Keep throne seat",J(0,-15.6f)+Vector3.up*1.2f,new Vector3(1.8f,.9f,1.2f),stone,true);
   KBox(root,"Keep throne back",J(0,-16.3f)+Vector3.up*2.6f,new Vector3(2,3.2f,.4f),iron,false);
   foreach(int side in new[]{-1,1})KBox(root,"Keep throne spire",J(side*1.1f,-16.3f)+Vector3.up*3.7f,new Vector3(.25f,1.6f,.25f),iron,false);
   // The colonnade carved between hall and galleries: dress each stone pillar with base and capital.
   foreach(int side in new[]{-1,1})foreach(float z in new[]{-9.4f,-5.4f,-1.4f,2.6f,6.6f}){var p=J(side*10,z);KeepPillar(root,p,KeepTall,false);}
   foreach(int side in new[]{-1,1})foreach(float z in new[]{-7.5f,.5f}){KeepBrazier(root,J(side*13.5f,z));}
   foreach(int side in new[]{-1,1})KeepBrazier(root,J(side*4.5f,-12));
   foreach(int side in new[]{-1,1})KeepBrazier(root,J(side*4.5f,11));
  }
  void KeepUndercroft(Transform root)
  {
   foreach(var p in new[]{J(-4.5f,-2),J(4.5f,-2),J(-4.5f,3),J(4.5f,3)})KeepPillar(root,p,3.2f,false);
   foreach(var p in new[]{J(-7.5f,-5),J(7.5f,4.5f)})KeepPiece(root,"coffin",p,new Vector3(2f,.56f,.64f),90,true);
   foreach(var p in new[]{J(-2.2f,-5.8f),J(2.4f,-5.6f),J(-7.5f,1.5f),J(7.6f,-1)})KeepPiece(root,"candles",p,new Vector3(.6f,.42f,.52f),KR(0,90),false);
   Lamp(root,"Lantern light",J(-2.2f,-5.8f)+Vector3.up*.8f);Lamp(root,"Lantern light",J(2.4f,-5.6f)+Vector3.up*.8f);
  }
  // Bones and rubble on floor cells along the stone, clear of the doors and the middle line.
  void KeepScatter(Transform root,string style)
  {
   var spots=new List<Vector3>();
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    if(!keepWalk[i,k])continue;var c=KeepCellCentre(i,k);if(Mathf.Abs(c.x)<3.5f)continue;
    if(!KeepWalkCell(i-1,k)||!KeepWalkCell(i+1,k)||!KeepWalkCell(i,k-1)||!KeepWalkCell(i,k+1))spots.Add(c);
   }
   int count=style=="throne"||style=="undercroft"?3:8;
   for(int n=0;n<count&&spots.Count>0;n++)
   {
    var p=spots[keepRandom.Next(spots.Count)];spots.Remove(p);
    KeepPiece(root,keepRandom.NextDouble()<.5?"bones":"rubble",p,keepRandom.NextDouble()<.5?new Vector3(1.04f,.2f,.82f):new Vector3(1.1f,.5f,.9f),KR(0,180),false);
   }
  }
  // Soft cold light from the dark above every part of the shape, so the floor and the fight read while the
  // stone stays black.
  void KeepFill(Transform root,string style)
  {
   var tone=style=="cells"?new Color(.5f,.75f,.68f):style=="hall"||style=="undercroft"?new Color(.75f,.72f,.8f):new Color(.55f,.64f,.95f);
   for(int i=2;i<keepW;i+=6)for(int k=2;k<keepH;k+=6)
   {
    var c=KeepCellCentre(i,k);if(!keepWalk[i,k])continue;
    var light=new GameObject("Keep cold fill").AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=c+Vector3.up*4.2f;
    light.type=LightType.Point;light.color=tone;light.intensity=4f;light.range=9;light.shadows=LightShadows.None;
   }
  }

  // ---- Pieces.
  // A kit piece placed only if it stands on the floor.
  GameObject KeepPiece(Transform root,string id,Vector3 at,Vector3 size,float yaw,bool solid)=>KeepWalkable(at)?Piece(root,id,at,size,yaw,solid):null;
  // A stone column: free-standing (a blocker of its own) or dressing a carved pillar of stone.
  void KeepPillar(Transform root,Vector3 at,float height,bool solid)
  {
   var stone=KMat("ashlar",new Color(.6f,.6f,.66f),new Vector2(.6f,2));var dark=KMat("slate",new Color(.28f,.28f,.32f),Vector2.one);
   KBox(root,"Keep pillar",at+Vector3.up*height*.5f,new Vector3(.95f,height,.95f),stone,false);
   KBox(root,"Keep pillar base",at+Vector3.up*.2f,new Vector3(1.3f,.4f,1.3f),dark,false);
   KBox(root,"Keep pillar capital",at+Vector3.up*(height-.15f),new Vector3(1.25f,.3f,1.25f),dark,false);
   if(solid)blockers.Add(new Bounds(at+Vector3.up,new Vector3(1.2f,2,1.2f)));
  }
  void KeepBrazier(Transform root,Vector3 at){if(KeepPiece(root,"brazier",at,new Vector3(.6f,1.2f,.6f),0,true))Lamp(root,"Brazier light",at+Vector3.up*1.3f);}
  // An iron ring hung from the dark with candles round it.
  void KeepChandelier(Transform root,Vector3 at)
  {
   var iron=KMat("iron",new Color(.28f,.28f,.3f),Vector2.one);
   for(int i=0;i<8;i++){var a=i*45f;var p=at+Quaternion.Euler(0,a,0)*Vector3.forward*.9f;KBox(root,"Keep chandelier ring",p,new Vector3(.75f,.07f,.07f),iron,false).transform.rotation=Quaternion.Euler(0,a,0);}
   KBox(root,"Keep chandelier chain",at+Vector3.up*1.5f,new Vector3(.05f,3,.05f),iron,false);
   Lamp(root,"Lantern light",at+Vector3.up*.2f);
  }

  // ---- Helpers.
  static Vector3 Size(bool alongZ,float length,float height,float depth)=>alongZ?new Vector3(depth,height,length):new Vector3(length,height,depth);
  GameObject KBox(Transform root,string name,Vector3 at,Vector3 size,Material material,bool solid)
  {
   var go=GameObject.CreatePrimitive(PrimitiveType.Cube);go.name=name;Destroy(go.GetComponent<Collider>());go.transform.SetParent(root,false);go.transform.position=at;go.transform.localScale=size;
   go.GetComponent<Renderer>().sharedMaterial=material;if(solid)blockers.Add(new Bounds(new Vector3(at.x,1,at.z),new Vector3(size.x,2,size.z)));return go;
  }
  // Lit material over one of the room textures (albedo + normal), tinted and tiled; cached by its settings.
  static Material KMat(string texture,Color tint,Vector2 tiling)
  {
   string key=texture+tint+tiling;if(keepMaterials.TryGetValue(key,out var m)&&m)return m;
   m=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Keep "+texture};
   var albedo=Resources.Load<Texture2D>("textures/rooms/"+texture+"_albedo");var normal=Resources.Load<Texture2D>("textures/rooms/"+texture+"_normal");
   if(albedo){m.SetTexture("_BaseMap",albedo);m.SetTextureScale("_BaseMap",tiling);}
   if(normal){m.SetTexture("_BumpMap",normal);m.SetTextureScale("_BumpMap",tiling);m.EnableKeyword("_NORMALMAP");}
   m.SetColor("_BaseColor",tint);m.SetFloat("_Smoothness",texture=="iron"?.35f:.18f);m.SetFloat("_Metallic",texture=="iron"?.3f:0);
   keepMaterials[key]=m;return m;
  }
  // Additive pale-blue glow fading upward: window panes and the moon shafts on the floor.
  static Material ShaftMaterial()
  {
   if(shaftMaterial)return shaftMaterial;
   shaftTexture=new Texture2D(4,64,TextureFormat.RGBA32,false){wrapMode=TextureWrapMode.Clamp,name="Keep shaft gradient"};
   for(int y=0;y<64;y++){float t=y/63f,v=Mathf.Pow(1-t,1.6f)*Mathf.SmoothStep(0,1,t*6);for(int x=0;x<4;x++)shaftTexture.SetPixel(x,y,new Color(v,v,v,1));}
   shaftTexture.Apply();
   shaftMaterial=new Material(Resources.Load<Shader>("Vfx/vfx_tex_add")){name="Keep moonlight"};shaftMaterial.SetTexture("_MainTex",shaftTexture);
   shaftMaterial.SetColor("_Tone",new Color(.5f,.62f,1f,1));shaftMaterial.SetFloat("_Progress",.5f);shaftMaterial.SetFloat("_Opacity",.55f);
   return shaftMaterial;
  }
 }
 // The keep's iron portcullis: it rises into the wall once the room is cleared.
 public sealed class KeepPortcullis:MonoBehaviour
 {
  public BloodwakeGame Game;float lift;Vector3 rest;bool placed;
  void LateUpdate()
  {
   if(!placed){rest=transform.position;placed=true;}
   float target=Game&&Game.ExitOpen?3.6f:0;lift=Mathf.MoveTowards(lift,target,(Game?Game.VfxDelta:Time.deltaTime)*2.2f);transform.position=rest+Vector3.up*lift;
  }
 }
}
