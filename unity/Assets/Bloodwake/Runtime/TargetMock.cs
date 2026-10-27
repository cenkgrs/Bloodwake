using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
namespace Bloodwake
{
 // Target renders (--targetcapture): the four rooms of the 27 Oct target sketches (art/concepts/hedef), dressed
 // the way the sketches say and lit and graded the way the finished game should be, captured from the same
 // camera as the sketch so the two lie on top of each other. Everything here is a mock-up built for the capture
 // (primitive shapes where the real models are still to come); it never runs in play.
 // Writes /tmp/bloodwake-target-<room>.png. Silent.
 public sealed partial class BloodwakeGame
 {
  public IEnumerator TargetCapture()
  {
   AudioListener.volume=0;smokeRunning=true;
   yield return new WaitForSeconds(.5f);
   StartRun("mage");invulnerable=99999;
   var rooms=new[]{("town_boss_blackbell_01",1),("town_well_03",1),("keep_throne_01",2),("keep_hall_04",2)};
   foreach(var (id,night) in rooms)
   {
    Run.Night=night;PlanNight();EnterRoom(id);spawnTimer=999;
    yield return new WaitForSeconds(1.2f);
    // The sketch camera: the room's middle at the default zoom.
    Cam.orthographicSize=DefaultZoom;Cam.transform.position=cameraOffset;Cam.transform.rotation=Quaternion.LookRotation(-cameraOffset,Vector3.up);
    var root=new GameObject("Target mock").transform;root.SetParent(roomRoot,false);
    bool keep=night==2;
    switch(id)
    {
     case "town_boss_blackbell_01":TargetBell(root);break;
     case "town_well_03":TargetWell(root);break;
     case "keep_throne_01":TargetThrone(root);break;
     case "keep_hall_04":TargetHall(root);break;
    }
    TargetAtmosphere(root,keep);
    for(int f=0;f<40;f++)yield return null;   // let particles and fades settle
    Cam.transform.position=cameraOffset;Cam.transform.rotation=Quaternion.LookRotation(-cameraOffset,Vector3.up);
    SaveView("/tmp/bloodwake-target-"+id+".png");
    Debug.Log("BLOODWAKE_TARGET "+id);
   }
   Debug.Log("BLOODWAKE_TARGET_DONE");
#if UNITY_EDITOR
   UnityEditor.EditorApplication.isPlaying=false;
#else
   Application.Quit(0);
#endif
  }

  // A pixel of the 1600x900 sketch to the floor point under it (or at a height above the floor).
  Vector3 Spot(float px,float py,float height=0)
  {
   var ray=Cam.ViewportPointToRay(new Vector3(px/1600f,1-py/900f,0));
   float t=(height-ray.origin.y)/ray.direction.y;return ray.origin+ray.direction*t;
  }
  Vector3 Ground(float px,float py){var p=Spot(px,py);p.y=0;return p;}

  // ---- 1. Kara Çan: the fallen bell, the candle ring, the tower's rubble, the cut rope, the graves.
  void TargetBell(Transform root)
  {
   var bronze=TargetMat("Bell bronze",new Color(.16f,.13f,.09f),.22f,.25f);bronze.SetFloat("_Cull",0);
   var bell=new GameObject("Target fallen bell",typeof(MeshFilter),typeof(MeshRenderer));bell.transform.SetParent(root,false);
   bell.GetComponent<MeshFilter>().sharedMesh=BellMesh();bell.GetComponent<MeshRenderer>().sharedMaterial=bronze;
   // Lying on its side, mouth to the sigil, crown end resting on the stones.
   var at=Ground(1180,360);var away=(at-Ground(840,460)).normalized;
   bell.transform.SetPositionAndRotation(at+Vector3.up*1.05f,Quaternion.LookRotation(away,Vector3.up)*Quaternion.Euler(90+8,0,0));bell.transform.localScale=Vector3.one*.85f;
   // Cracked stone where it landed.
   EnsureGroundMaterials();Decal(root,"Target impact cracks",at,5.5f,20,crackMaterial,.01f);Decal(root,"Target impact dust",at,4.5f,70,mudMaterial,.009f);
   // Candles in a ring round the sigil; every third one lit.
   var c=Ground(840,460);int n=0;
   for(int a=0;a<360;a+=20)
   {
    var p=Ground(840+360*Mathf.Cos(a*Mathf.Deg2Rad),460+185*Mathf.Sin(a*Mathf.Deg2Rad));
    Piece(root,"candles",p,new Vector3(.55f,.4f,.48f),a,false);if(n++%3==0)TargetLamp(root,p+Vector3.up*.55f);
   }
   // The tower's fall: rubble heaped with broken beams.
   var r=Ground(300,250);var timber=KMat("timber",new Color(.32f,.25f,.19f),Vector2.one);
   for(int i=0;i<6;i++)Piece(root,"rubble",r+new Vector3(KRT(-2,2),0,KRT(-1.5f,1.5f)),new Vector3(KRT(1.4f,2.2f),KRT(.6f,1.1f),KRT(1.1f,1.8f)),KRT(0,360),true);
   for(int i=0;i<4;i++)KBoxR(root,"Target beam",r+new Vector3(KRT(-1.5f,1.5f),KRT(.5f,1.2f),KRT(-1,1)),Quaternion.Euler(KRT(-30,30),KRT(0,180),KRT(10,40)),new Vector3(4,.32f,.32f),timber);
   for(int i=0;i<8;i++)KBoxR(root,"Target block",r+new Vector3(KRT(-2.5f,2.5f),.3f,KRT(-2,2)),Quaternion.Euler(KRT(-20,20),KRT(0,360),KRT(-20,20)),new Vector3(KRT(.5f,.9f),KRT(.4f,.6f),KRT(.4f,.7f)),KMat("ashlar",new Color(.55f,.5f,.48f),Vector2.one));
   // The cut bell rope hanging out of the dark above.
   var rope=Ground(1012,330);KBoxR(root,"Target bell rope",rope+Vector3.up*7,Quaternion.Euler(3,0,2),new Vector3(.07f,9,.07f),KMat("timber",new Color(.4f,.32f,.22f),Vector2.one));
   // Leaning graves in the corner.
   var stone=KMat("ashlar",new Color(.5f,.48f,.47f),Vector2.one);
   foreach(var (x,y) in new[]{(1120f,700f),(1220f,730f),(1320f,700f),(1420f,730f)})
   {var g=Ground(x+18,y);var lean=Quaternion.Euler(KRT(-12,12),KRT(-25,25),KRT(-10,10));KBoxR(root,"Target grave",g+Vector3.up*.55f,lean,new Vector3(.75f,1.1f,.18f),stone);
    Decal(root,"Target grave moss",g,1.3f,KRT(0,360),mossMaterial,.006f);}
   // The warden waits on the sigil; the hunter comes in from below.
   TargetActors(Ground(840,430),Ground(620,700),"boss");
  }
  // ---- 1. Kuyu Meydanı: paving rings, chain and bucket, offerings, the old stall, a string of lanterns.
  void TargetWell(Transform root)
  {
   var w=Ground(800,470);var slab=KMat("flagstone",new Color(.72f,.7f,.68f),new Vector2(.5f,.5f));var kerb=KMat("ashlar",new Color(.6f,.58f,.56f),Vector2.one);
   for(int a=0;a<360;a+=10)
   {
    var q=Quaternion.Euler(0,a,0);
    KBoxR(root,"Target paving",w+q*Vector3.forward*3.35f+Vector3.up*.014f,q,new Vector3(.62f,.03f,.9f),slab);
    if(a%30==0)KBoxR(root,"Target paving joint",w+q*Vector3.forward*3.35f+Vector3.up*.03f,q,new Vector3(.05f,.03f,.95f),KMat("slate",new Color(.15f,.15f,.16f),Vector2.one));
   }
   for(int a=0;a<360;a+=6){var q=Quaternion.Euler(0,a,0);KBoxR(root,"Target ring kerb",w+q*Vector3.forward*3.85f+Vector3.up*.05f,q,new Vector3(.42f,.1f,.14f),kerb);KBoxR(root,"Target ring kerb",w+q*Vector3.forward*2.85f+Vector3.up*.05f,q,new Vector3(.32f,.1f,.14f),kerb);}
   var iron=KMat("iron",new Color(.3f,.3f,.32f),Vector2.one);
   KBoxR(root,"Target well chain",w+new Vector3(.2f,1.5f,0),Quaternion.identity,new Vector3(.04f,1.4f,.04f),iron);
   var bucket=GameObject.CreatePrimitive(PrimitiveType.Cylinder);bucket.name="Target bucket";Destroy(bucket.GetComponent<Collider>());bucket.transform.SetParent(root,false);bucket.transform.position=w+new Vector3(.2f,.75f,0);bucket.transform.localScale=new Vector3(.36f,.2f,.36f);bucket.GetComponent<Renderer>().sharedMaterial=KMat("wood",new Color(.4f,.3f,.2f),Vector2.one);
   foreach(var (x,y) in new[]{(600f,560f),(650f,590f),(980f,570f),(1030f,540f),(700f,600f)}){var p=Ground(x,y);Piece(root,"candles",p,new Vector3(.5f,.36f,.44f),KRT(0,90),false);TargetLamp(root,p+Vector3.up*.5f);}
   // The stall: four posts and a torn awning, baskets under it.
   var s=Ground(310,300);var timber=KMat("timber",new Color(.38f,.3f,.22f),Vector2.one);var awning=KMat("cloth",new Color(.62f,.18f,.12f),new Vector2(2,1));
   foreach(var o in new[]{new Vector3(-1.4f,0,-.8f),new Vector3(1.4f,0,-.8f),new Vector3(-1.4f,0,.8f),new Vector3(1.4f,0,.8f)})KBoxR(root,"Target stall post",s+o+Vector3.up*(o.z<0?1.2f:1.5f),Quaternion.identity,new Vector3(.14f,o.z<0?2.4f:3,.14f),timber);
   KBoxR(root,"Target awning",s+Vector3.up*2.75f,Quaternion.Euler(-14,0,3),new Vector3(3.2f,.04f,2),awning);
   KBoxR(root,"Target awning tear",s+new Vector3(.9f,2.3f,-1),Quaternion.Euler(70,10,0),new Vector3(.9f,.03f,1),awning);
   Piece(root,"sacks",s+new Vector3(-.5f,0,.2f),new Vector3(1,.6f,.8f),20,true);Piece(root,"crate",s+new Vector3(.7f,0,.3f),new Vector3(.8f,.7f,.8f),35,true);
   // A string of lanterns across the square, high on the far side.
   var a0=Spot(0,120,4.6f);var a1=Spot(1600,120,4.6f);var rope=KMat("timber",new Color(.25f,.2f,.15f),Vector2.one);
   for(int i=0;i<=20;i++)
   {
    float u=i/20f;var p=Vector3.Lerp(a0,a1,u)+Vector3.down*Mathf.Sin(u*Mathf.PI)*.8f;var q=Vector3.Lerp(a0,a1,u+.05f)+Vector3.down*Mathf.Sin((u+.05f)*Mathf.PI)*.8f;
    if(i<20)KBoxR(root,"Target lantern rope",(p+q)*.5f,Quaternion.LookRotation(q-p),new Vector3(.03f,.03f,Vector3.Distance(p,q)),rope);
    if(i%2==1){Piece(root,"lantern",p+Vector3.down*.45f,new Vector3(.3f,.45f,.3f),0,false);TargetLamp(root,p+Vector3.down*.25f);}
   }
   TargetActors(Ground(1000,380),Ground(640,700),"grunt","grunt");
  }
  // ---- 2. Taht Salonu: banners between the columns, the chandelier, the fallen crown, kneeling stone knights.
  void TargetThrone(Transform root)
  {
   var cloth=KMat("cloth",new Color(.5f,.07f,.07f),new Vector2(1,3));var iron=KMat("iron",new Color(.3f,.3f,.32f),Vector2.one);
   foreach(int side in new[]{-1,1})foreach(float z in new[]{-7.4f,-3.4f,.6f,4.6f})
   {
    var p=J(side*9.4f,z);var length=KRT(2.6f,3.2f);
    KBox(root,"Target banner",p+Vector3.up*(KeepTall-.3f-length*.5f),new Vector3(.06f,length,1),cloth,false);
    KBox(root,"Target banner rod",p+Vector3.up*(KeepTall-.25f),new Vector3(.08f,.08f,1.2f),iron,false);
    var tail=KBoxR(root,"Target banner tail",p+Vector3.up*(KeepTall-.3f-length),Quaternion.Euler(45,0,0),new Vector3(.06f,.7f,.7f),cloth);
   }
   TargetChandelier(root,Ground(820,604)+Vector3.up*4.2f,1.9f);
   // The broken crown, fallen before the dais.
   var gold=TargetMat("Crown gold",new Color(.75f,.55f,.22f),.7f,1);var c=Ground(1080,160);
   for(int i=0;i<10;i++){var q=Quaternion.Euler(0,i*36,0);if(i==7)continue;KBoxR(root,"Target crown",c+q*Vector3.forward*.28f+Vector3.up*.1f,q*Quaternion.Euler(0,0,i==3?40:0),new Vector3(.18f,.18f,.05f),gold);if(i%2==0)KBoxR(root,"Target crown point",c+q*Vector3.forward*.28f+Vector3.up*.25f,q*Quaternion.Euler(0,0,45),new Vector3(.1f,.1f,.04f),gold);}
   TargetLamp(root,c+Vector3.up*.6f);
   foreach(var (x,y) in new[]{(330f,320f),(520f,210f)})
   {var p=Ground(x,y);KBox(root,"Target plinth",p+Vector3.up*.3f,new Vector3(1.2f,.6f,1.2f),KMat("ashlar",new Color(.55f,.55f,.6f),Vector2.one),true);Piece(root,"shrine_statue",p+Vector3.up*.6f,new Vector3(.9f,2.4f,.95f),Yaw(Ground(820,450)-p),false);}
   // Moonlight through the tall west windows, laid across the hall.
   foreach(float z in new[]{-6f,0f,6f})TargetBeam(root,J(-16.5f,z)+Vector3.up*5,J(-4,z-3),new Color(.55f,.66f,1),2.2f);
   TargetActors(Ground(1050,300),Ground(420,760),"boss","keep_wraith","keep_knight");
  }
  // ---- 2. Büyük Salon: cornice and plinth, pointed windows, trophies, a laid feast, a second chandelier.
  void TargetHall(Transform root)
  {
   var stone=KMat("ashlar",new Color(.8f,.8f,.86f),new Vector2(.5f,.5f));var dark=KMat("slate",new Color(.28f,.28f,.32f),Vector2.one);
   var windows=new List<Transform>();foreach(Transform t in roomRoot.GetComponentsInChildren<Transform>())if(t.name=="Keep window frame")windows.Add(t);
   for(int i=0;i<keepW;i++)for(int k=0;k<keepH;k++)
   {
    if(keepWalk[i,k])continue;var c=KeepCellCentre(i,k);if(StoneHeight(c)<KeepTall-.01f)continue;
    foreach(var n in new[]{Vector3.forward,Vector3.left})
    {
     if(!KeepWalkable(c+n*KeepCell))continue;bool alongZ=Mathf.Abs(n.x)>.5f;var face=c+n*KeepCell*.5f;
     KBox(root,"Target cornice",face+n*.18f+Vector3.up*(KeepTall-.25f),Size(alongZ,KeepCell+.02f,.34f,.36f),stone,false);
     KBox(root,"Target cornice lip",face+n*.28f+Vector3.up*(KeepTall-.5f),Size(alongZ,KeepCell+.02f,.12f,.2f),dark,false);
     KBox(root,"Target plinth",face+n*.16f+Vector3.up*.45f,Size(alongZ,KeepCell+.02f,.9f,.32f),stone,false);
     KBox(root,"Target plinth cap",face+n*.3f+Vector3.up*.92f,Size(alongZ,KeepCell+.02f,.1f,.14f),dark,false);
    }
   }
   foreach(var w in windows)
   {
    var n=w.position.x>0?Vector3.left:Vector3.forward;var probe=new Vector3(w.position.x,0,w.position.z);
    bool f=KeepWalkable(probe+Vector3.forward*.6f),l=KeepWalkable(probe+Vector3.left*.6f);if(f==l)continue;n=f?Vector3.forward:Vector3.left;var along=Vector3.Cross(Vector3.up,n);var basePos=probe+n*.12f;
    // Deep reveal, pointed head, a mullion.
    foreach(int s in new[]{-1,1})
    {
     KBoxR(root,"Target jamb",basePos+along*s*.55f+Vector3.up*2.65f,Quaternion.LookRotation(n),new Vector3(.22f,2.3f,.34f),stone);
     KBoxR(root,"Target arch",basePos+along*s*.27f+Vector3.up*4.05f,Quaternion.LookRotation(n)*Quaternion.Euler(0,0,s*-32),new Vector3(.2f,.75f,.34f),stone);
    }
    KBoxR(root,"Target mullion",basePos+Vector3.up*2.75f,Quaternion.LookRotation(n),new Vector3(.08f,2.2f,.2f),stone);
    KBoxR(root,"Target sill",basePos+Vector3.up*1.5f,Quaternion.LookRotation(n),new Vector3(1.4f,.14f,.42f),stone);
    // Trophy beside the window: a shield with antlers.
    var t=basePos+along*1.5f+Vector3.up*2.9f;
    if(KeepWalkable(probe+along*1.5f+n*.6f))
    {
     var shield=GameObject.CreatePrimitive(PrimitiveType.Cylinder);shield.name="Target trophy";Destroy(shield.GetComponent<Collider>());shield.transform.SetParent(root,false);
     shield.transform.SetPositionAndRotation(t,Quaternion.LookRotation(Vector3.up,n));shield.transform.localScale=new Vector3(.55f,.03f,.65f);shield.GetComponent<Renderer>().sharedMaterial=KMat("wood",new Color(.35f,.25f,.17f),Vector2.one);
     var bone=TargetMat("Antler",new Color(.75f,.7f,.6f),.2f,0);
     foreach(int s in new[]{-1,1}){KBoxR(root,"Target antler",t+n*.1f+along*s*.3f+Vector3.up*.3f,Quaternion.LookRotation(n)*Quaternion.Euler(0,0,s*-35),new Vector3(.06f,.7f,.06f),bone);KBoxR(root,"Target antler tine",t+n*.1f+along*s*.5f+Vector3.up*.55f,Quaternion.LookRotation(n)*Quaternion.Euler(0,0,s*10),new Vector3(.05f,.35f,.05f),bone);}
    }
    TargetBeam(root,basePos+Vector3.up*2.8f,probe+n*4.5f,new Color(.55f,.66f,1),1.1f);
   }
   // The feast: plates, goblets, a knocked-over jug along the long table.
   var table=roomRoot.Find("Keep hall")?.Find("Keep table")??FindNamed("Keep table");
   if(table)
   {
    var top=table.position+Vector3.up*.07f;var pewter=TargetMat("Pewter",new Color(.6f,.6f,.62f),.6f,.8f);
    for(float z=-4.4f;z<=4.4f;z+=.75f)foreach(int s in new[]{-1,1})
    {
     var p=top+new Vector3(s*.45f,0,z+KRT(-.1f,.1f));
     var plate=GameObject.CreatePrimitive(PrimitiveType.Cylinder);plate.name="Target plate";Destroy(plate.GetComponent<Collider>());plate.transform.SetParent(root,false);plate.transform.position=p+Vector3.up*.01f;plate.transform.localScale=new Vector3(.32f,.008f,.32f);plate.GetComponent<Renderer>().sharedMaterial=pewter;
     if(KRT(0,1)<.6f){var cup=GameObject.CreatePrimitive(PrimitiveType.Cylinder);cup.name="Target goblet";Destroy(cup.GetComponent<Collider>());cup.transform.SetParent(root,false);cup.transform.position=p+new Vector3(-s*.2f,.1f,.15f);cup.transform.localScale=new Vector3(.08f,.1f,.08f);cup.GetComponent<Renderer>().sharedMaterial=pewter;}
    }
    var jug=GameObject.CreatePrimitive(PrimitiveType.Cylinder);jug.name="Target jug";Destroy(jug.GetComponent<Collider>());jug.transform.SetParent(root,false);jug.transform.SetPositionAndRotation(top+new Vector3(0,.12f,1.2f),Quaternion.Euler(0,30,90));jug.transform.localScale=new Vector3(.2f,.18f,.2f);jug.GetComponent<Renderer>().sharedMaterial=TargetMat("Clay",new Color(.45f,.25f,.15f),.2f,0);
    EnsureDecalMaterials();Decal(root,"Target wine",top+new Vector3(.1f,-.06f,1.6f),1.1f,40,bloodMaterial,.07f);
    TargetChandelier(root,table.position+Vector3.up*3.8f,1.6f);
   }
   TargetActors(J(-6,9),J(1.2f,-9),"keep_wraith","keep_halberd","keep_chaplain");
  }
  static Material targetFlame;
  void TargetLamp(Transform root,Vector3 at)
  {
   var light=new GameObject("Target lamp").AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=at;
   light.type=LightType.Point;light.color=new Color(1,.5f,.2f);light.intensity=3.4f;light.range=6;light.shadows=LightShadows.None;
   if(!targetFlame)targetFlame=new Material(Resources.Load<Shader>("Presentation/Flame")){name="Target flame"};
   var flame=GameObject.CreatePrimitive(PrimitiveType.Quad);flame.name="Target flame";Destroy(flame.GetComponent<Collider>());flame.transform.SetParent(root,false);
   flame.transform.position=at;flame.transform.localScale=new Vector3(.16f,.32f,1);var r=flame.GetComponent<MeshRenderer>();r.sharedMaterial=targetFlame;r.shadowCastingMode=ShadowCastingMode.Off;flame.AddComponent<FlameFacing>();
  }
  Transform FindNamed(string name){foreach(var t in roomRoot.GetComponentsInChildren<Transform>())if(t.name==name)return t;return null;}

  // ---- Shared pieces.
  void TargetChandelier(Transform root,Vector3 at,float radius)
  {
   var iron=KMat("iron",new Color(.22f,.22f,.24f),Vector2.one);var wax=TargetMat("Wax",new Color(.9f,.85f,.72f),.3f,0);
   for(int i=0;i<16;i++){float a=i*22.5f;var q=Quaternion.Euler(0,a,0);KBoxR(root,"Target chandelier ring",at+q*Vector3.forward*radius,q,new Vector3(radius*.42f,.08f,.08f),iron);}
   for(int i=0;i<4;i++){var q=Quaternion.Euler(0,i*90+45,0);var tip=at+q*Vector3.forward*radius;KBoxR(root,"Target chandelier chain",(tip+at+Vector3.up*2)*.5f,Quaternion.LookRotation(at+Vector3.up*2-tip)*Quaternion.Euler(90,0,0),new Vector3(.03f,Vector3.Distance(tip,at+Vector3.up*2),.03f),iron);}
   KBoxR(root,"Target chandelier chain",at+Vector3.up*6,Quaternion.identity,new Vector3(.05f,8,.05f),iron);
   for(int i=0;i<12;i++){var q=Quaternion.Euler(0,i*30,0);var p=at+q*Vector3.forward*radius;KBoxR(root,"Target candle",p+Vector3.up*.15f,Quaternion.identity,new Vector3(.07f,.26f,.07f),wax);if(i%3==0)TargetLamp(root,p+Vector3.up*.35f);}
  }
  // Crossed light planes from a window or the sky down to the floor.
  void TargetBeam(Transform root,Vector3 from,Vector3 to,Color color,float width)
  {
   var m=new Material(ShaftMaterial()){name="Target beam"};m.SetColor("_Tone",color);m.SetFloat("_Opacity",.6f);
   var mid=(from+to)*.5f;var dir=(from-to);float length=dir.magnitude;
   foreach(float spin in new[]{0f,90f})
   {
    var q=GameObject.CreatePrimitive(PrimitiveType.Quad);q.name="Target beam";Destroy(q.GetComponent<Collider>());q.transform.SetParent(root,false);
    q.transform.SetPositionAndRotation(mid,Quaternion.LookRotation(Vector3.Cross(dir,Vector3.up).normalized,dir)*Quaternion.Euler(0,spin,0));
    q.transform.rotation=Quaternion.FromToRotation(Vector3.up,dir.normalized)*Quaternion.Euler(0,spin+45,0);
    q.transform.localScale=new Vector3(width,length,1);var r=q.GetComponent<MeshRenderer>();r.sharedMaterial=m;r.shadowCastingMode=ShadowCastingMode.Off;
   }
  }
  void TargetActors(Vector3 foe,Vector3 hunter,params string[] kinds)
  {
   Player.transform.position=hunter;Player.transform.rotation=Quaternion.LookRotation(new Vector3(foe.x-hunter.x,0,foe.z-hunter.z));
   // Moved for the still, not walked there: no blade trail streaking from where she was.
   foreach(var trail in Player.GetComponentsInChildren<TrailRenderer>())trail.Clear();
   foreach(var ps in Player.GetComponentsInChildren<ParticleSystem>())ps.Clear();
   for(int i=0;i<kinds.Length;i++)
   {
    var side=Vector3.Cross(Vector3.up,(foe-hunter).normalized);var at=foe+side*(i-(kinds.Length-1)*.5f)*2.2f+(i==0?Vector3.zero:(foe-hunter).normalized*1.2f);
    SpawnEnemy(kinds[i],at);var e=Enemies[Enemies.Count-1];e.View.TickEmergence(10);if(e.Agent)e.Agent.enabled=false;
    e.View.transform.position=at;e.View.transform.rotation=Quaternion.LookRotation(new Vector3(hunter.x-at.x,0,hunter.z-at.z));e.Cooldown=float.PositiveInfinity;
   }
  }
  // The finished look: ground mist that catches the fires, ash and embers, a stronger bloom, a warm (town) or
  // cold (keep) grade and a heavier vignette.
  void TargetAtmosphere(Transform root,bool keep)
  {
   // The room's own exit and entrance glows belong to play, not to the still.
   foreach(var r in roomRoot.GetComponentsInChildren<MeshRenderer>())if(r.name.Contains("Glow")&&!r.name.StartsWith("Target"))r.enabled=false;
   var mist=MistMaterial(keep);
   for(int i=0;i<14;i++)
   {
    var q=GameObject.CreatePrimitive(PrimitiveType.Quad);q.name="Target mist";Destroy(q.GetComponent<Collider>());q.transform.SetParent(root,false);
    q.transform.SetPositionAndRotation(new Vector3(KRT(-half.x,half.x),KRT(.25f,1.1f),KRT(-half.y,half.y)),Quaternion.Euler(90,KRT(0,360),0));q.transform.localScale=Vector3.one*KRT(6,11);
    var r=q.GetComponent<MeshRenderer>();r.sharedMaterial=mist;r.shadowCastingMode=ShadowCastingMode.Off;
   }
   AmbientParticles(root);
   var volume=root.gameObject.AddComponent<Volume>();volume.isGlobal=true;volume.priority=50;var profile=ScriptableObject.CreateInstance<VolumeProfile>();volume.sharedProfile=profile;
   var bloom=profile.Add<Bloom>();bloom.intensity.Override(1.1f);bloom.threshold.Override(.8f);bloom.scatter.Override(.72f);bloom.tint.Override(keep?new Color(.8f,.88f,1):new Color(1,.85f,.7f));
   var grade=profile.Add<ColorAdjustments>();grade.contrast.Override(14);grade.saturation.Override(keep?-8:6);grade.postExposure.Override(keep?.45f:.3f);grade.colorFilter.Override(keep?new Color(.86f,.92f,1.06f):new Color(1.04f,.98f,.92f));
   var split=profile.Add<SplitToning>();split.shadows.Override(keep?new Color(.25f,.35f,.6f):new Color(.32f,.28f,.28f));split.highlights.Override(keep?new Color(1,.75f,.5f):new Color(.8f,.68f,.55f));split.balance.Override(keep?-20:0);
   var vignette=profile.Add<Vignette>();vignette.intensity.Override(.44f);vignette.smoothness.Override(.55f);vignette.color.Override(new Color(.01f,0,.01f));
  }
  static Material MistMaterial(bool keep)
  {
   const int n=256;var t=new Texture2D(n,n,TextureFormat.RGBA32,true){wrapMode=TextureWrapMode.Clamp,name="Target mist"};var px=new Color32[n*n];
   for(int y=0;y<n;y++)for(int x=0;x<n;x++)
   {
    float u=x/(float)n,v=y/(float)n,r=Vector2.Distance(new Vector2(u,v),new Vector2(.5f,.5f))*2;
    float cloud=Mathf.PerlinNoise(u*4+3,v*4+7)*.6f+Mathf.PerlinNoise(u*9+1,v*9+5)*.4f;
    float a=Mathf.Clamp01((1-r)*1.5f)*Mathf.Clamp01(cloud*1.6f-.35f);px[y*n+x]=new Color(a,a,a,1);   // the additive shader reads colour, not alpha
   }
   t.SetPixels32(px);t.Apply(true);
   var m=new Material(Resources.Load<Shader>("Vfx/vfx_tex_add")){name="Target mist"};m.SetTexture("_MainTex",t);
   m.SetColor("_Tone",keep?new Color(.32f,.38f,.5f,1):new Color(.42f,.34f,.3f,1));m.SetFloat("_Progress",.5f);m.SetFloat("_Opacity",.35f);return m;
  }
  static Material TargetMat(string name,Color color,float smooth,float metal)
  {
   var m=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="Target "+name};m.SetColor("_BaseColor",color);m.SetFloat("_Smoothness",smooth);m.SetFloat("_Metallic",metal);return m;
  }
  // A bell, lathed from its profile (radius, height), open at the mouth, seen from both sides.
  static Mesh BellMesh()
  {
   var profile=new[]{new Vector2(.12f,2.5f),new Vector2(.55f,2.48f),new Vector2(.85f,2.3f),new Vector2(.95f,1.95f),new Vector2(1f,1.4f),new Vector2(1.12f,.8f),new Vector2(1.35f,.3f),new Vector2(1.6f,.05f),new Vector2(1.62f,0)};
   const int seg=40;var v=new List<Vector3>();var tri=new List<int>();
   for(int i=0;i<profile.Length;i++)for(int s=0;s<=seg;s++){float a=s*Mathf.PI*2/seg;v.Add(new Vector3(Mathf.Cos(a)*profile[i].x,profile[i].y,Mathf.Sin(a)*profile[i].x));}
   int row=seg+1;
   for(int i=0;i<profile.Length-1;i++)for(int s=0;s<seg;s++)
   {int a=i*row+s,b=a+1,c=a+row,d=c+1;tri.AddRange(new[]{a,c,b,b,c,d});}
   var mesh=new Mesh{name="Target bell"};mesh.SetVertices(v);mesh.SetTriangles(tri,0);mesh.RecalculateNormals();mesh.RecalculateBounds();return mesh;
  }
  static readonly System.Random targetRandom=new(27);
  static float KRT(float a,float b)=>a+(float)targetRandom.NextDouble()*(b-a);
 }
}
