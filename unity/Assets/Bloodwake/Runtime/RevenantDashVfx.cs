using UnityEngine;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  int dashMistVersion;
  public void CancelDashMist()=>dashMistVersion++;
  // Crimson dash mist uses the painted blood mist sheet once delivered (its own red, so only the tone's alpha carries over);
  // Vesper's ember smoke keeps the procedural cloud.
  VfxLifetime Mist(bool fire,string name,Vector3 at,Vector3 scale,float life,Color tone)=>!fire&&SheetTexture("blood_mist")
   ?Textured(name,at,scale*1.15f,"blood_mist",life,new Color(.85f,.78f,.8f,Mathf.Min(1,tone.a*1.6f)),true,4,true):Sheet(name,at,scale,"dash_mist",life,tone);
  // A puff of blood mist torn out of a drained body (Sanguine Siphon), drifting toward the hunter.
  public void BloodMistPuff(Vector3 at,Vector3 toward)
  {
   if(!SheetTexture("blood_mist"))return;var drift=(toward-at).normalized*.8f+Vector3.up*.25f;
   var puff=Textured("Siphon blood mist",at,Vector3.one*.9f,"blood_mist",.6f,new Color(.9f,.8f,.82f,.85f),true,4,true);
   puff.Tick=(p,dt)=>{puff.transform.position=at+drift*puff.Age;puff.transform.rotation=Game.Cam.transform.rotation;};
  }
  // fire: Vesper's version of the same dash, ember mist and flame sparks instead of blood.
  public void DashCloud(ActorView actor,Vector3 direction,bool fire=false)
  {
   int version=++dashMistVersion;var side=Vector3.Cross(Vector3.up,direction);
   // A moving volume that trails the body, not stamps on the floor. World-space wake is separate. The blood version
   // sits behind the hunter, darker and thinner, so the silhouette still reads through it instead of a red blot.
   for(int i=0;i<(fire?8:6);i++)
   {
    float seed=i*3.71f,size=actor.Height*(fire?(i<4?.94f:.73f):(i<3?.62f:.5f));
    var offset=Vector3.up*actor.Height*(.24f+(i%4)*.17f)+side*((i%2==0?-1:1)*.24f)-direction*(fire?(i<4?.12f:.5f):(i<3?.45f:.95f));
    var anchor=actor.transform.position;float released=-1;
    var fog=Mist(fire,fire?"Dash moving ember cloud":"Dash moving crimson cloud",anchor+offset,Vector3.one*size,.65f,fire?new Color(.95f,.34f,.06f,.42f):new Color(.3f,.008f,.022f,.3f));
    fog.Block.SetFloat("_Seed",seed);fog.Block.SetFloat("_Opacity",.65f);fog.Apply();
    fog.Tick=(p,dt)=>
    {
     if(!actor||actor.IsDead||version!=dashMistVersion){fog.transform.localScale=Vector3.zero;fog.Duration=fog.Age;return;}
     if(released<0){anchor=actor.transform.position;if(!Game.RevenantDashActive)released=fog.Age;}
     float releaseAge=released<0?0:fog.Age-released;
     float opacity=(.65f+.35f*Mathf.Clamp01(fog.Age/.04f))*(1-Mathf.SmoothStep(0,1,releaseAge/.22f));
     fog.Block.SetFloat("_Opacity",opacity);
     fog.transform.position=anchor+offset+side*Mathf.Sin(seed+fog.Age*13)*.12f-direction*releaseAge*.7f+Vector3.up*releaseAge*.2f;
     fog.transform.rotation=Game.Cam.transform.rotation*Quaternion.Euler(0,0,seed*57+fog.Age*22);
     fog.transform.localScale=Vector3.one*size*(1+releaseAge*.9f);
     if(released>=0&&releaseAge>=.22f)fog.Duration=fog.Age;
    };
   }
  }
  public void DashWake(Vector3 position,Vector3 direction,bool fire=false)
  {
   var side=Vector3.Cross(Vector3.up,direction);
   var trace=Sheet(fire?"Dash scorched ground trace":"Dash blood ground trace",position+Vector3.up*.035f,new Vector3(1.3f,.92f,1),"dash_trace",1.12f,Tone(fire?"2b1408":"70061b"),true);
   trace.transform.rotation=Quaternion.LookRotation(Vector3.up,direction);
   trace.Block.SetFloat("_Seed",UnityEngine.Random.Range(0,20));trace.Apply();
   if(!fire)DashBloodThreads(position,direction);
   else VesperTrailBurn(position,direction,1);
   // Blood sheds one thin, dark wisp per step (two stacked ones pooled into a red blot around the legs).
   for(int i=0;i<(fire?2:1);i++)
   {
    float spread=UnityEngine.Random.Range(-.35f,.35f),fogSize=fire?UnityEngine.Random.Range(1.25f,1.7f):UnityEngine.Random.Range(.8f,1.05f);
    var start=position+Vector3.up*(fire?.55f+i*.65f:.85f)+side*spread;
    var fog=Mist(fire,fire?"Dash shedding ember smoke":"Dash shedding crimson mist",start,Vector3.one*fogSize,fire?1.05f:.7f,fire?new Color(.7f,.2f,.04f,.5f):new Color(.26f,.006f,.018f,.22f));
    fog.Block.SetFloat("_Seed",UnityEngine.Random.Range(0,50f));fog.Apply();
    fog.Tick=(p,dt)=>{fog.Block.SetFloat("_Opacity",1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.38f,1,p)));fog.transform.position=start+side*spread*fog.Age*.25f+Vector3.up*fog.Age*.16f;fog.transform.rotation=Game.Cam.transform.rotation;fog.transform.localScale=Vector3.one*fogSize*Mathf.Lerp(.9f,1.3f,p);};
   }
   for(int i=0;i<(fire?7:4);i++)
   {
    float sign=i%2==0?-1:1;
    var start=position+Vector3.up*UnityEngine.Random.Range(.45f,1.4f)+side*sign*.3f;
    var velocity=side*sign*UnityEngine.Random.Range(2.3f,4f)-direction*UnityEngine.Random.Range(1,2.5f)+Vector3.up*UnityEngine.Random.Range(.4f,1.7f);
    float size=UnityEngine.Random.Range(.065f,.105f)*(fire?.6f:1);
    // Flame sparks are unlit and HDR so bloom makes them glow; blood droplets stay lit and glossy.
    var drop=fire?Particle(start,Vector3.one*size,i%2==0?new Color(4.2f,1.5f,.32f):new Color(3.2f,.7f,.12f),.65f,false,false):Particle(start,Vector3.one*size,Tone(i%2==0?"9d1229":"620817"),.65f,false,true);
    drop.name=fire?"Dash flame spark":"Dash blood droplet";
    drop.Block.SetFloat("_Smoothness",.85f);drop.Apply();bool landed=false;bool stain=i==0&&!fire;
    drop.Tick=(p,dt)=>
    {
     if(landed)return;float age=drop.Age;var at=start+velocity*age-Vector3.up*4.9f*age*age;
     if(at.y<=.035f){landed=true;drop.transform.localScale=Vector3.zero;if(stain)Stain(at,.3f,.75f,.3f);return;}
     var tangent=velocity-Vector3.up*9.8f*age;drop.transform.position=at;drop.transform.rotation=Quaternion.FromToRotation(Vector3.up,tangent.normalized);
     drop.transform.localScale=new Vector3(size,size*Mathf.Lerp(3.8f,1.2f,p),size)*(1-p*.5f);
    };
   }
  }
  public void DashLanding(Vector3 position)
  {
   Stain(position,1.65f,2.5f,.6f);
   for(int i=0;i<8;i++)
   {
    var direction=Quaternion.Euler(0,i*45,0)*Vector3.forward;
    var fx=Particle(position+Vector3.up*.15f,Vector3.one*.09f,Tone("a21029"),.4f,false,true);
    fx.name="Dash talent blood impact";
    fx.Tick=(p,dt)=>{float age=fx.Age;fx.transform.position=position+direction*(age*2.8f)+Vector3.up*Mathf.Max(.03f,.15f+age*2-age*age*4.9f);fx.transform.localScale=new Vector3(.065f,.16f,.065f)*(1-p);};
   }
   Flash(position,Tone("a9172f"),.5f,1.8f,.12f);
  }
  void DashBloodThreads(Vector3 position,Vector3 direction)
  {
   const int strands=3,steps=18,sides=6;
   var vertices=new Vector3[strands*(steps+1)*sides];var triangles=new System.Collections.Generic.List<int>();
   for(int strand=0;strand<strands;strand++)for(int step=0;step<steps;step++)for(int ring=0;ring<sides;ring++)
   {
    int a=(strand*(steps+1)+step)*sides+ring,b=(strand*(steps+1)+step)*sides+(ring+1)%sides;
    triangles.AddRange(new[]{a,a+sides,b,b,a+sides,b+sides});
   }
   var mesh=new Mesh{name="Dash flowing blood strands"};mesh.MarkDynamic();mesh.vertices=vertices;mesh.SetTriangles(triangles,0);
   var go=new GameObject("Dash suspended blood threads");go.transform.SetParent(transform,false);go.transform.position=position;
   go.AddComponent<MeshFilter>().sharedMesh=mesh;go.AddComponent<OwnedVfxMesh>().Mesh=mesh;
   var renderer=go.AddComponent<MeshRenderer>();renderer.sharedMaterial=WetBloodMaterial();renderer.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
   var side=Vector3.Cross(Vector3.up,direction);float seed=UnityEngine.Random.Range(0,6.28f);
   void Shape(float p)
   {
    float fade=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.38f,1,p));
    for(int strand=0;strand<strands;strand++)for(int step=0;step<=steps;step++)
    {
     float t=(float)step/steps,phase=seed+strand*2.1f+t*4.2f+p*3;
     var center=-direction*(t*.85f)+side*(Mathf.Sin(phase)*(.25f+t*.18f))+Vector3.up*(.38f+strand*.38f+Mathf.Sin(t*3+seed)*.12f-p*p*.18f);
     float width=(.006f+.021f*Mathf.Sin(t*Mathf.PI))*fade;
     for(int ring=0;ring<sides;ring++)
     {float angle=ring*Mathf.PI*2/sides;vertices[(strand*(steps+1)+step)*sides+ring]=center+side*Mathf.Cos(angle)*width+Vector3.up*Mathf.Sin(angle)*width*.42f;}
    }
    mesh.vertices=vertices;mesh.RecalculateNormals();mesh.RecalculateBounds();
   }
   Shape(0);Life(go,.9f).Tick=(p,dt)=>Shape(p);
  }
  public void ThrustStrike(Vector3 hand,Vector3 direction,float reach)
  {
   var side=Vector3.Cross(Vector3.up,direction);
   var axis=Vector3.ProjectOnPlane(direction,Game.Cam.transform.forward).normalized;
   if(axis.sqrMagnitude<.01f)axis=Game.Cam.transform.up;
   // The painted blood slash laid along the thrust: its chord (about 43° in the cell) turned onto the screen-space
   // line of the strike, a second thinner one mirrored across it, so the lunge reads as two claws tearing forward...
   if(SheetTexture("blood_slash"))
   {
    var cam=Game.Cam.transform;float angle=Mathf.Atan2(Vector3.Dot(direction,cam.up),Vector3.Dot(direction,cam.right))*Mathf.Rad2Deg;
    for(int i=0;i<2;i++)
    {
     float s=reach*(i==0?1.05f:.8f);var at=hand+direction*reach*(i==0?.5f:.62f)+side*(i==0?-.12f:.14f);
     var slash=Textured("Thrust blood slash",at,new Vector3(s,i==0?s:-s,1),"blood_slash",i==0?.3f:.26f,new Color(1,.86f,.9f,1.2f),false,4,true);
     slash.transform.rotation=cam.rotation*Quaternion.Euler(0,0,angle+(i==0?-43:43));
    }
   }
   // ...with the old straight rakes as a fallback until the sheet is present.
   else for(int i=0;i<4;i++)
   {
    float offset=(i-1.5f)*.16f;var start=hand+side*offset;
    var fx=Sheet("Straight claw thrust trail",start,new Vector3(.24f,reach*.8f,1),"claw_cut",.24f,Tone(i==1||i==2?"e0203f":"a5122e"));
    fx.transform.rotation=Quaternion.LookRotation(Game.Cam.transform.forward,axis);
    fx.Tick=(p,dt)=>{fx.transform.position=start+direction*(reach*(.2f+.35f*p));};
   }
   // ...around a hot blood-red core that shoots the full reach and thins out.
   var core=Sheet("Thrust core",hand,new Vector3(.32f,reach*1.1f,1),"claw_cut",.18f,Tone("ff5a6e"));
   core.transform.rotation=Quaternion.LookRotation(Game.Cam.transform.forward,axis);
   core.Tick=(p,dt)=>{core.transform.position=hand+direction*(reach*(.35f+.3f*p));core.transform.localScale=new Vector3(.32f*(1-p*.8f),reach*1.1f,1);};
   Flash(hand+direction*reach*.6f,Tone("ff2a45"),1.4f,2.4f,.12f);
  }
  public void ThrustClawImpact(ActorView target)
  {
   // A painted gash bursting on the body itself...
   if(SheetTexture("blood_slash"))
   {
    float s=target.Height*.95f;var gash=Textured("Thrust blood gash",target.transform.position+Vector3.up*target.Height*.57f,new Vector3(s,s,1),"blood_slash",.32f,new Color(1,.86f,.9f,1.25f),false,4,true);
    float tilt=UnityEngine.Random.Range(-25f,25f);gash.Tick=(p,dt)=>{if(!target){gash.transform.localScale=Vector3.zero;return;}var cam=Game.Cam.transform;gash.transform.position=target.transform.position+Vector3.up*target.Height*.57f-cam.forward*.5f;gash.transform.rotation=cam.rotation*Quaternion.Euler(0,0,tilt);};
   }
   // ...over four straight parallel cuts across the victim, following its recoil.
   for(int i=0;i<4;i++)
   {
    float offset=(i-1.5f)*.15f,length=target.Height*(i==0||i==3?.40f:.52f);
    var cut=Sheet("Thrust straight claw impact",target.transform.position,Vector3.one,"claw_cut",.26f,Tone("ba1936"));
    cut.Block.SetFloat("_Seed",i*2.71f);cut.Apply();
    cut.Tick=(p,dt)=>
    {
     if(!target){cut.transform.localScale=Vector3.zero;return;}
     var cam=Game.Cam.transform;var axis=(cam.up+cam.right*.22f).normalized;
     cut.transform.position=target.transform.position+Vector3.up*target.Height*.57f-cam.forward*.4f+cam.right*offset;
     cut.transform.rotation=Quaternion.LookRotation(cam.forward,axis);
     cut.transform.localScale=new Vector3(.19f,length,1);
    };
    cut.Tick(0,0);
   }
  }
 }
}
