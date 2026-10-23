using System.Collections.Generic;
using UnityEngine;
namespace Bloodwake
{
 // The Hollow Keep (second map): castle interiors built from the room kit, the room textures and primitives.
 // Where the town is open streets under the moon, the keep is closed stone: tall ashlar walls behind the fight
 // with buttresses and pointed windows letting in cold shafts of moonlight, low walls on the camera's side so the
 // floor stays in view, banners, braziers and candles, and each room its own furniture (keep: <style> in the
 // region data). The camera looks in from -x/+z, so the north (-z) and east (+x) walls are the tall ones.
 public sealed partial class BloodwakeGame
 {
  const float KeepTall=4.4f,KeepLow=1.1f,KeepWallDepth=.8f;
  static readonly Dictionary<string,Material> keepMaterials=new();
  static Texture2D shaftTexture;static Material shaftMaterial;
  System.Random keepRandom;
  float KR(float a,float b)=>a+(float)keepRandom.NextDouble()*(b-a);

  void BuildKeep()
  {
   // EnterRoom's grey boundary and layout boxes stay as blockers but are not drawn.
   foreach(var r in roomRoot.GetComponentsInChildren<Renderer>())r.enabled=false;
   string style=room.S("keep","hall");keepRandom=new System.Random(room.S("id").GetHashCode());
   var root=new GameObject("Keep "+style).transform;root.SetParent(roomRoot,false);
   float hx=half.x,hz=half.y;
   // Floor: flagstones, with a darker margin where the walls meet it.
   KBox(root,"Keep floor",new Vector3(0,-.05f,0),new Vector3(hx*2+2,.1f,hz*2+2),KMat("flagstone",new Color(.9f,.9f,.95f),new Vector2(hx,hz)*.45f),false);
   // Shell: tall north and east walls (with the exit gap on the north), low south and west walls.
   KeepTallWall(root,new Vector3(0,0,-hz-KeepWallDepth*.5f),hx*2+KeepWallDepth*2,false,true);
   KeepTallWall(root,new Vector3(hx+KeepWallDepth*.5f,0,0),hz*2,true,false);
   KeepLowWall(root,new Vector3(-hx-KeepWallDepth*.5f,0,0),hz*2,true,false);
   KeepLowWall(root,new Vector3(0,0,hz+KeepWallDepth*.5f),hx*2+KeepWallDepth*2,false,true);
   KeepExitGate(root,new Vector3(0,0,-hz),style=="gatehouse"||style=="cells");
   switch(style)
   {
    case "gatehouse":KeepGatehouse(root,hx,hz);break;
    case "armory":KeepArmory(root,hx,hz);break;
    case "chapel":KeepChapel(root,hx,hz);break;
    case "hall":KeepHall(root,hx,hz);break;
    case "cells":KeepCells(root,hx,hz);break;
    case "throne":KeepThrone(root,hx,hz);break;
    case "undercroft":KeepUndercroft(root,hx,hz);break;
   }
   KeepScatter(root,hx,hz,style);
   KeepFill(root,hx,hz,style);
  }
  // Soft cold light from the dark above, so the floor and the fight read while the corners stay black.
  void KeepFill(Transform root,float hx,float hz,string style)
  {
   var tone=style=="cells"?new Color(.5f,.75f,.68f):style=="hall"||style=="undercroft"?new Color(.75f,.72f,.8f):new Color(.55f,.64f,.95f);
   for(float x=-hx*.5f;x<=hx*.5f+.01f;x+=hx*.5f)for(float z=-hz*.5f;z<=hz*.5f+.01f;z+=hz*.5f)
   {
    var light=new GameObject("Keep cold fill").AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=new Vector3(x,4.2f,z);
    light.type=LightType.Point;light.color=tone;light.intensity=3.2f;light.range=Mathf.Max(hx,hz)*.75f;light.shadows=LightShadows.None;
   }
  }

  // ---- Shell.
  // A tall wall: ashlar courses in ~3 m bays, a buttress between bays, a pointed window in every other bay that
  // throws a shaft of cold light across the floor. gap leaves the middle open for the exit gate.
  void KeepTallWall(Transform root,Vector3 centre,float length,bool alongZ,bool gap)
  {
   // Inward points from the wall into the room.
   var along=alongZ?Vector3.forward:Vector3.right;var inward=alongZ?(centre.x>0?Vector3.left:Vector3.right):(centre.z<0?Vector3.forward:Vector3.back);
   var stone=KMat("ashlar",new Color(.85f,.85f,.9f),new Vector2(1.2f,2));var dark=KMat("slate",new Color(.4f,.41f,.46f),Vector2.one);
   int bays=Mathf.Max(2,Mathf.RoundToInt(length/3.2f));float bay=length/bays;
   for(int i=0;i<bays;i++)
   {
    float offset=-length*.5f+(i+.5f)*bay;var c=centre+along*offset;
    if(gap&&Mathf.Abs(offset)<2.4f)
    {
     // Lintel and jambs over the gate.
     KBox(root,"Keep gate lintel",c+Vector3.up*(KeepTall-.7f),Size(alongZ,bay,1.4f,KeepWallDepth),stone,false);
     continue;
    }
    KBox(root,"Keep wall",c+Vector3.up*KeepTall*.5f,Size(alongZ,bay,KeepTall,KeepWallDepth),stone,false);
    // Plinth course.
    KBox(root,"Keep plinth",c+Vector3.up*.25f+inward*(KeepWallDepth*.5f+.12f),Size(alongZ,bay,.5f,.25f),dark,false);
    if(i%2==1&&!(gap&&Mathf.Abs(offset)<4))KeepWindow(root,c+inward*(KeepWallDepth*.5f+.02f),alongZ,inward);
    if(i<bays-1)
    {
     var b=centre+along*(offset+bay*.5f)+inward*(KeepWallDepth*.5f+.3f);
     KBox(root,"Keep buttress",b+Vector3.up*KeepTall*.45f,Size(alongZ,.7f,KeepTall*.9f,.6f),stone,false);
     KBox(root,"Keep buttress cap",b+Vector3.up*(KeepTall*.9f+.15f),Size(alongZ,.9f,.3f,.8f),dark,false);
    }
   }
   blockers.Add(new Bounds(centre+Vector3.up,Size(alongZ,length,2,KeepWallDepth)));
  }
  void KeepLowWall(Transform root,Vector3 centre,float length,bool alongZ,bool gap)
  {
   var stone=KMat("ashlar",new Color(.55f,.55f,.6f),new Vector2(2,.6f));var cap=KMat("slate",new Color(.3f,.3f,.34f),Vector2.one);
   var along=alongZ?Vector3.forward:Vector3.right;
   foreach(int side in new[]{-1,1})
   {
    float from=gap?2.4f:0,to=length*.5f;if(!gap&&side<0)continue;
    float span=gap?to-from:length;var c=gap?centre+along*side*(from+span*.5f):centre;
    KBox(root,"Keep low wall",c+Vector3.up*KeepLow*.5f,Size(alongZ,span,KeepLow,KeepWallDepth),stone,false);
    KBox(root,"Keep low wall cap",c+Vector3.up*(KeepLow+.08f),Size(alongZ,span,.16f,KeepWallDepth+.15f),cap,false);
    // Low stubs of the old upper wall: broken teeth along the camera side.
    for(float u=-span*.5f+1.2f;u<span*.5f-1;u+=KR(2.6f,4.2f))
     KBox(root,"Keep wall stub",c+along*u+Vector3.up*(KeepLow+KR(.3f,.9f)*.5f),Size(alongZ,KR(.5f,.9f),KR(.3f,.9f),KeepWallDepth*.9f),stone,false);
   }
  }
  // A pointed window: a dark recess with a pale glowing pane, a cold light just inside and a shaft of moonlight
  // laid across the floor below it.
  void KeepWindow(Transform root,Vector3 at,bool alongZ,Vector3 inward)
  {
   var frame=KMat("slate",new Color(.2f,.21f,.25f),Vector2.one);
   float sill=1.8f,height=2.6f,width=1.1f;
   KBox(root,"Keep window frame",at+Vector3.up*(sill+height*.5f),Size(alongZ,width+.4f,height+.3f,.12f),frame,false);
   var pane=GameObject.CreatePrimitive(PrimitiveType.Quad);pane.name="Keep window pane";Destroy(pane.GetComponent<Collider>());pane.transform.SetParent(root,false);
   pane.transform.position=at+inward*.08f+Vector3.up*(sill+height*.5f);pane.transform.rotation=Quaternion.LookRotation(-inward);pane.transform.localScale=new Vector3(width,height,1);
   var paneRenderer=pane.GetComponent<MeshRenderer>();paneRenderer.sharedMaterial=ShaftMaterial();paneRenderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
   // The point of the arch.
   var tip=GameObject.CreatePrimitive(PrimitiveType.Quad);tip.name="Keep window arch";Destroy(tip.GetComponent<Collider>());tip.transform.SetParent(root,false);
   tip.transform.position=at+inward*.08f+Vector3.up*(sill+height+.25f);tip.transform.rotation=Quaternion.LookRotation(-inward)*Quaternion.Euler(0,0,45);tip.transform.localScale=Vector3.one*width*.7f;
   var tipRenderer=tip.GetComponent<MeshRenderer>();tipRenderer.sharedMaterial=ShaftMaterial();tipRenderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
   // The shaft: a long pale quad lying on the floor in front of the window.
   var shaft=GameObject.CreatePrimitive(PrimitiveType.Quad);shaft.name="Keep moon shaft";Destroy(shaft.GetComponent<Collider>());shaft.transform.SetParent(root,false);
   shaft.transform.position=new Vector3(at.x,.03f,at.z)+inward*2.6f;shaft.transform.rotation=Quaternion.LookRotation(Vector3.down,inward);shaft.transform.localScale=new Vector3(width*1.4f,4.6f,1);
   var shaftRenderer=shaft.GetComponent<MeshRenderer>();shaftRenderer.sharedMaterial=ShaftMaterial();shaftRenderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
   var light=new GameObject("Keep cold window light").AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=at+inward*1.2f+Vector3.up*2.2f;
   light.type=LightType.Point;light.color=new Color(.55f,.66f,1);light.intensity=2.2f;light.range=7;light.shadows=LightShadows.None;
  }
  // The exit: the kit's double gate (it swings open with the room cleared), or an iron portcullis that rises.
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
   // The articulated gate (separate leaves) the town uses, sized to the gap and facing into the room.
   var source=Resources.Load<GameObject>("Environment/Kit01/gate/gate_articulated");if(!source)return;
   var gate=Instantiate(source,root);gate.name="Keep exit gate";gate.transform.SetPositionAndRotation(at,Quaternion.LookRotation(Vector3.forward));
   var b=EnvironmentDressing.BoundsOf(gate.GetComponentsInChildren<Renderer>());gate.transform.localScale=new Vector3(4.4f/b.size.x,4.2f/b.size.y,1.25f);
   var animated=gate.AddComponent<CourtyardGate>();animated.Game=this;animated.Exit=true;animated.Left=gate.transform.Find("Left leaf");animated.Right=gate.transform.Find("Right leaf");
   if(!animated.Left||!animated.Right)Destroy(animated);
  }

  // ---- Rooms.
  void KeepGatehouse(Transform root,float hx,float hz)
  {
   foreach(var p in new[]{new Vector3(-5,0,-3),new Vector3(5,0,-3),new Vector3(-5,0,4.5f),new Vector3(5,0,4.5f)})KeepPillar(root,p,4.5f);
   foreach(var p in new[]{new Vector3(-5,0,.8f),new Vector3(5,0,.8f)})KeepBrazier(root,p);
   // Racks of the garrison's spears along the east wall, rubble where the gate was rammed.
   for(float z=-hz+3;z<hz-3;z+=4.2f)Piece(root,"weapon_rack",new Vector3(hx-.9f,0,z),new Vector3(1.55f,1.36f,.6f),-90,true);
   foreach(var p in new[]{new Vector3(-3,0,-hz+2.2f),new Vector3(3.4f,0,-hz+2.5f),new Vector3(-hx+2,0,2)})Piece(root,"rubble",p,new Vector3(1.4f,.6f,1.1f),KR(0,180),true);
   KeepBanner(root,new Vector3(-3.2f,0,-hz),Vector3.forward,new Color(.38f,.07f,.08f));KeepBanner(root,new Vector3(3.2f,0,-hz),Vector3.forward,new Color(.38f,.07f,.08f));
  }
  void KeepArmory(Transform root,float hx,float hz)
  {
   for(float x=-3;x<=3.01f;x+=1.6f)Piece(root,"weapon_rack",new Vector3(x,0,-5),new Vector3(1.55f,1.36f,.6f),0,true);
   for(float z=-hz+3;z<hz-3;z+=3.6f)Piece(root,"weapon_rack",new Vector3(hx-.9f,0,z),new Vector3(1.55f,1.36f,.6f),-90,true);
   var iron=KMat("iron",new Color(.3f,.3f,.33f),Vector2.one);
   foreach(int side in new[]{-1,1})
   {
    var a=new Vector3(side*7,0,3);KBox(root,"Keep anvil",a+Vector3.up*.45f,new Vector3(1.2f,.9f,.6f),iron,false);KeepBrazier(root,a+new Vector3(side*1.6f,0,-1.2f));
    Piece(root,"crate",a+new Vector3(0,0,2.2f),new Vector3(.95f,.95f,.95f),KR(0,60),true);Piece(root,"barrel",a+new Vector3(-side*1.2f,0,2.4f),new Vector3(.7f,.95f,.7f),0,true);
   }
   KeepBanner(root,new Vector3(-5,0,-hz),Vector3.forward,new Color(.12f,.13f,.2f));KeepBanner(root,new Vector3(5,0,-hz),Vector3.forward,new Color(.12f,.13f,.2f));
  }
  void KeepChapel(Transform root,float hx,float hz)
  {
   var wood=KMat("wood",new Color(.42f,.32f,.25f),new Vector2(2,.5f));
   foreach(int side in new[]{-1,1})for(float z=-1.8f;z<=4.8f;z+=1.45f)
   {
    KBox(root,"Keep pew seat",new Vector3(side*5.2f,.45f,z),new Vector3(5.6f,.12f,.55f),wood,false);
    KBox(root,"Keep pew back",new Vector3(side*5.2f,.75f,z+.3f),new Vector3(5.6f,.7f,.1f),wood,false);
   }
   var stone=KMat("ashlar",new Color(.62f,.62f,.68f),Vector2.one);
   KBox(root,"Keep altar",new Vector3(0,.55f,-hz+4),new Vector3(4,1.1f,1.6f),stone,false);
   KBox(root,"Keep altar cloth",new Vector3(0,1.12f,-hz+4),new Vector3(4.2f,.04f,1.2f),KMat("cloth",new Color(.6f,.58f,.5f),Vector2.one),false);
   Piece(root,"shrine_statue",new Vector3(0,0,-hz+1.9f),new Vector3(1.1f,3.1f,1.15f),0,true);
   foreach(int side in new[]{-1,1}){Piece(root,"candles",new Vector3(side*1.4f,1.12f,-hz+4),new Vector3(.6f,.42f,.52f),0,false);Lamp(root,"Lantern light",new Vector3(side*1.4f,1.6f,-hz+4));}
   foreach(var p in new[]{new Vector3(-hx+2,0,-hz+2),new Vector3(hx-2,0,-hz+2)})Piece(root,"candles",p,new Vector3(.6f,.42f,.52f),KR(0,90),false);
   // Stained glass: the windows of the north wall throw coloured shafts instead of plain moonlight.
   var hues=new[]{new Color(.45f,.55f,1),new Color(.75f,.3f,.85f),new Color(.9f,.35f,.3f)};int h=0;
   foreach(var light in root.GetComponentsInChildren<Light>())if(light.name=="Keep cold window light"&&light.transform.position.z<-hz+2){light.color=hues[h%hues.Length];light.intensity=2.8f;h++;}
  }
  void KeepHall(Transform root,float hx,float hz)
  {
   var wood=KMat("wood",new Color(.45f,.33f,.24f),new Vector2(1,4));var cloth=KMat("cloth",new Color(.42f,.06f,.07f),new Vector2(1,6));
   KBox(root,"Keep carpet",new Vector3(0,.012f,0),new Vector3(3.2f,.02f,hz*2-2),cloth,false);
   foreach(int side in new[]{-1,1})
   {
    var t=new Vector3(side*6.5f,0,0);
    KBox(root,"Keep table",t+Vector3.up*.8f,new Vector3(2,.12f,11),wood,false);
    foreach(int end in new[]{-1,1})foreach(int s2 in new[]{-1,1})KBox(root,"Keep table leg",t+new Vector3(s2*.8f,.4f,end*5),new Vector3(.18f,.8f,.18f),wood,false);
    foreach(int bench in new[]{-1,1})KBox(root,"Keep bench",t+new Vector3(bench*1.5f,.42f,0),new Vector3(.45f,.1f,10.5f),wood,false);
    for(float z=-4;z<=4.01f;z+=4){Piece(root,"candles",t+new Vector3(0,.86f,z),new Vector3(.5f,.36f,.44f),KR(0,90),false);}
    Lamp(root,"Lantern light",t+new Vector3(0,1.4f,-2));Lamp(root,"Lantern light",t+new Vector3(0,1.4f,2.5f));
   }
   // Hearth in the east wall.
   var stone=KMat("ashlar",new Color(.5f,.48f,.48f),Vector2.one);var hearth=new Vector3(hx-.6f,0,2);
   KBox(root,"Keep hearth",hearth+Vector3.up*1.4f,new Vector3(.9f,2.8f,3.6f),stone,false);
   KBox(root,"Keep hearth mouth",hearth+new Vector3(-.46f,.8f,0),new Vector3(.05f,1.4f,2.2f),KMat("slate",new Color(.05f,.04f,.04f),Vector2.one),false);
   Piece(root,"firewood",hearth+new Vector3(-.8f,0,0),new Vector3(1.23f,.56f,1.02f),90,false);Lamp(root,"Brazier light",hearth+new Vector3(-1.1f,.9f,0));
   for(float z=-6;z<=6.01f;z+=6)KeepChandelier(root,new Vector3(0,3.6f,z));
   KeepBanner(root,new Vector3(-6,0,-hz),Vector3.forward,new Color(.4f,.06f,.07f));KeepBanner(root,new Vector3(0,0,-hz),Vector3.forward,new Color(.12f,.12f,.16f));KeepBanner(root,new Vector3(6,0,-hz),Vector3.forward,new Color(.4f,.06f,.07f));
  }
  void KeepCells(Transform root,float hx,float hz)
  {
   var iron=KMat("iron",new Color(.3f,.31f,.33f),Vector2.one);var stone=KMat("ashlar",new Color(.45f,.47f,.47f),Vector2.one);
   foreach(int side in new[]{-1,1})
   {
    float x=side*10;
    // A block of three cells against the wall: stone dividers, a barred front facing the middle.
    for(int c=0;c<3;c++)
    {
     float z=-8+c*4.8f;
     KBox(root,"Keep cell divider",new Vector3(x,1.3f,z-2.4f),new Vector3(5.8f,2.6f,.3f),stone,false);
     for(float b=-2.1f;b<=2.11f;b+=.35f)KBox(root,"Keep cell bar",new Vector3(x-side*2.9f,1.3f,z+b),new Vector3(.07f,2.6f,.07f),iron,false);
     KBox(root,"Keep cell rail",new Vector3(x-side*2.9f,2.55f,z),new Vector3(.12f,.12f,4.8f),iron,false);
     var inside=new Vector3(x+side*.8f,0,z);
     if(c==1)Piece(root,"bones",inside,new Vector3(1.04f,.2f,.82f),KR(0,180),false);else Piece(root,"coffin",inside,new Vector3(2f,.56f,.64f),side*90+KR(-15,15),false);
    }
    KBox(root,"Keep cell divider",new Vector3(x,1.3f,-8+3*4.8f-2.4f),new Vector3(5.8f,2.6f,.3f),stone,false);
   }
   foreach(var p in new[]{new Vector3(-3,0,-hz+2.5f),new Vector3(3,0,5),new Vector3(-2.5f,0,6.5f)})Piece(root,"cage",p,new Vector3(.83f,1.85f,1f),KR(0,90),true);
   // Chains hanging from the dark above.
   for(int i=0;i<6;i++){var p=new Vector3(KR(-5,5),0,KR(-hz+3,hz-4));float len=KR(1.2f,2.6f);KBox(root,"Keep chain",p+Vector3.up*(KeepTall-len*.5f),new Vector3(.05f,len,.05f),iron,false);}
   foreach(var p in new[]{new Vector3(0,0,-hz+2),new Vector3(-4,0,1),new Vector3(4,0,-3)})KeepBrazier(root,p);
   foreach(var light in root.GetComponentsInChildren<Light>())if(light.name=="Keep cold window light"){light.color=new Color(.5f,.85f,.75f);light.intensity=1.8f;}
  }
  void KeepThrone(Transform root,float hx,float hz)
  {
   var stone=KMat("ashlar",new Color(.58f,.58f,.64f),Vector2.one);var cloth=KMat("cloth",new Color(.38f,.05f,.06f),new Vector2(1,8));var iron=KMat("iron",new Color(.33f,.33f,.36f),Vector2.one);
   KBox(root,"Keep carpet",new Vector3(0,.012f,.5f),new Vector3(3.6f,.02f,hz*2-6),cloth,false);
   // The dais and the throne at its head.
   KBox(root,"Keep dais",new Vector3(0,.3f,-hz+3.5f),new Vector3(10,.6f,4),stone,false);
   KBox(root,"Keep dais step",new Vector3(0,.15f,-hz+5.9f),new Vector3(6,.3f,.8f),stone,false);
   KBox(root,"Keep throne seat",new Vector3(0,1.05f,-hz+3),new Vector3(1.8f,.9f,1.4f),stone,false);
   KBox(root,"Keep throne back",new Vector3(0,2.5f,-hz+2.4f),new Vector3(2,3.4f,.4f),iron,false);
   foreach(int side in new[]{-1,1})KBox(root,"Keep throne spire",new Vector3(side*1.1f,3.6f,-hz+2.4f),new Vector3(.25f,1.6f,.25f),iron,false);
   // Two rows of columns down the hall and a brazier at every other one.
   foreach(int side in new[]{-1,1})for(int i=0;i<4;i++){var p=new Vector3(side*8.5f,0,-hz+8+i*6.5f);KeepPillar(root,p,KeepTall);if(i%2==0)KeepBrazier(root,p+new Vector3(-side*1.4f,0,0));}
   foreach(int side in new[]{-1,1})KeepBanner(root,new Vector3(side*4.2f,0,-hz),Vector3.forward,new Color(.36f,.05f,.06f),4.2f);
  }
  void KeepUndercroft(Transform root,float hx,float hz)
  {
   foreach(var p in new[]{new Vector3(-4.5f,0,-2),new Vector3(4.5f,0,-2),new Vector3(-4.5f,0,3),new Vector3(4.5f,0,3)})KeepPillar(root,p,3.2f);
   foreach(var p in new[]{new Vector3(-7,0,-4.6f),new Vector3(7,0,4.4f)})Piece(root,"coffin",p,new Vector3(2f,.56f,.64f),90,true);
   foreach(var p in new[]{new Vector3(-2.2f,0,-5.6f),new Vector3(2.4f,0,-5.4f),new Vector3(-7.2f,0,1.5f),new Vector3(7.4f,0,-1)})Piece(root,"candles",p,new Vector3(.6f,.42f,.52f),KR(0,90),false);
   Lamp(root,"Lantern light",new Vector3(-2.2f,.8f,-5.6f));Lamp(root,"Lantern light",new Vector3(2.4f,.8f,-5.4f));
  }
  // Floor dressing for every room: bones and rubble along the walls, kept clear of the doors and the middle.
  void KeepScatter(Transform root,float hx,float hz,string style)
  {
   int count=style=="throne"||style=="undercroft"?3:7;
   for(int i=0;i<count;i++)
   {
    bool alongX=keepRandom.NextDouble()<.5;var p=alongX?new Vector3(KR(-hx+1.5f,hx-1.5f),0,KR(0,1)<.5f?-hz+1.3f:hz-1.3f):new Vector3(KR(0,1)<.5f?-hx+1.3f:hx-1.3f,0,KR(-hz+1.5f,hz-1.5f));
    if(Mathf.Abs(p.x)<3.5f)continue;
    Piece(root,keepRandom.NextDouble()<.5?"bones":"rubble",p,keepRandom.NextDouble()<.5?new Vector3(1.04f,.2f,.82f):new Vector3(1.1f,.5f,.9f),KR(0,180),false);
   }
  }

  // ---- Pieces.
  void KeepPillar(Transform root,Vector3 at,float height)
  {
   var stone=KMat("ashlar",new Color(.6f,.6f,.66f),new Vector2(.6f,2));var dark=KMat("slate",new Color(.28f,.28f,.32f),Vector2.one);
   KBox(root,"Keep pillar",at+Vector3.up*height*.5f,new Vector3(.9f,height,.9f),stone,false);
   KBox(root,"Keep pillar base",at+Vector3.up*.2f,new Vector3(1.25f,.4f,1.25f),dark,false);
   KBox(root,"Keep pillar capital",at+Vector3.up*(height-.15f),new Vector3(1.2f,.3f,1.2f),dark,false);
   blockers.Add(new Bounds(at+Vector3.up,new Vector3(1.1f,2,1.1f)));
  }
  void KeepBrazier(Transform root,Vector3 at){Piece(root,"brazier",at,new Vector3(.6f,1.2f,.6f),0,true);Lamp(root,"Brazier light",at+Vector3.up*1.3f);}
  // A long cloth banner on a tall wall, hanging from an iron rod.
  void KeepBanner(Transform root,Vector3 wallAt,Vector3 inward,Color color,float length=3.2f)
  {
   // wallAt is on the wall's inner face; the banner hangs just off it.
   var cloth=KMat("cloth",color,new Vector2(1,2));var p=wallAt+inward*.06f;
   KBox(root,"Keep banner",p+Vector3.up*(KeepTall-.6f-length*.5f),new Vector3(1.3f,length,.05f),cloth,false);
   KBox(root,"Keep banner rod",p+Vector3.up*(KeepTall-.55f),new Vector3(1.6f,.07f,.07f),KMat("iron",new Color(.3f,.3f,.32f),Vector2.one),false);
   // A pointed tail.
   var tail=GameObject.CreatePrimitive(PrimitiveType.Cube);tail.name="Keep banner tail";Destroy(tail.GetComponent<Collider>());tail.transform.SetParent(root,false);
   tail.transform.position=p+Vector3.up*(KeepTall-.6f-length-.02f);tail.transform.rotation=Quaternion.Euler(0,0,45);tail.transform.localScale=new Vector3(.92f,.92f,.05f);tail.GetComponent<Renderer>().sharedMaterial=cloth;
  }
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
   go.GetComponent<Renderer>().sharedMaterial=material;if(solid)blockers.Add(new Bounds(at,size));return go;
  }
  // Lit material over one of the room textures (albedo + normal), tinted and tiled; cached by its settings.
  static Material KMat(string texture,Color tint,Vector2 tiling)
  {
   string key=texture+tint+tiling;if(keepMaterials.TryGetValue(key,out var m)&&m)return m;
   m=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Keep "+texture};
   var albedo=Resources.Load<Texture2D>("textures/rooms/"+texture+"_albedo");var normal=Resources.Load<Texture2D>("textures/rooms/"+texture+"_normal");
   if(albedo){m.SetTexture("_BaseMap",albedo);m.SetTextureScale("_BaseMap",tiling);}
   if(normal){m.SetTexture("_BumpMap",normal);m.SetTextureScale("_BumpMap",tiling);m.EnableKeyword("_NORMALMAP");}
   m.SetColor("_BaseColor",tint);m.SetFloat("_Smoothness",texture=="iron"?.45f:.18f);m.SetFloat("_Metallic",texture=="iron"?.6f:0);
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
