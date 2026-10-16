using UnityEngine;
namespace Bloodwake
{
 public sealed partial class RevenantVfx
 {
  int dashMistVersion;
  public void CancelDashMist()=>dashMistVersion++;
  public void DashCloud(ActorView actor,Vector3 direction)
  {
   int version=++dashMistVersion;var side=Vector3.Cross(Vector3.up,direction);
   // A body-sized moving volume, not stamps on the floor. World-space wake is separate.
   for(int i=0;i<8;i++)
   {
    float seed=i*3.71f,size=actor.Height*(i<4?.94f:.73f);
    var offset=Vector3.up*actor.Height*(.24f+(i%4)*.17f)+side*((i%2==0?-1:1)*.24f)-direction*(i<4?.12f:.5f);
    var anchor=actor.transform.position;float released=-1;
    var fog=Sheet("Dash moving crimson cloud",anchor+offset,Vector3.one*size,"dash_mist",.65f,new Color(.46f,.012f,.032f,.49f));
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
  public void DashWake(Vector3 position,Vector3 direction)
  {
   var side=Vector3.Cross(Vector3.up,direction);
   var trace=Sheet("Dash blood ground trace",position+Vector3.up*.035f,new Vector3(1.3f,.92f,1),"dash_trace",1.12f,Tone("70061b"),true);
   trace.transform.rotation=Quaternion.LookRotation(Vector3.up,direction);
   trace.Block.SetFloat("_Seed",UnityEngine.Random.Range(0,20));trace.Apply();
   DashBloodThreads(position,direction);
   for(int i=0;i<2;i++)
   {
    float spread=UnityEngine.Random.Range(-.35f,.35f),fogSize=UnityEngine.Random.Range(1.25f,1.7f);
    var start=position+Vector3.up*(.55f+i*.65f)+side*spread;
    var fog=Sheet("Dash shedding crimson mist",start,Vector3.one*fogSize,"dash_mist",1.05f,new Color(.4f,.008f,.023f,.55f));
    fog.Block.SetFloat("_Seed",UnityEngine.Random.Range(0,50f));fog.Apply();
    fog.Tick=(p,dt)=>{fog.Block.SetFloat("_Opacity",1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(.38f,1,p)));fog.transform.position=start+side*spread*fog.Age*.25f+Vector3.up*fog.Age*.16f;fog.transform.rotation=Game.Cam.transform.rotation;fog.transform.localScale=Vector3.one*fogSize*Mathf.Lerp(.9f,1.3f,p);};
   }
   for(int i=0;i<4;i++)
   {
    float sign=i%2==0?-1:1;
    var start=position+Vector3.up*UnityEngine.Random.Range(.45f,1.4f)+side*sign*.3f;
    var velocity=side*sign*UnityEngine.Random.Range(2.3f,4f)-direction*UnityEngine.Random.Range(1,2.5f)+Vector3.up*UnityEngine.Random.Range(.4f,1.7f);
    float size=UnityEngine.Random.Range(.065f,.105f);var drop=Particle(start,Vector3.one*size,Tone(i%2==0?"9d1229":"620817"),.65f,false,true);
    drop.name="Dash blood droplet";
    drop.Block.SetFloat("_Smoothness",.85f);drop.Apply();bool landed=false;bool stain=i==0;
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
   for(int i=0;i<4;i++)
   {
    float offset=(i-1.5f)*.12f;var start=hand+side*offset;
    var fx=Sheet("Straight claw thrust trail",start,new Vector3(.14f,reach*.65f,1),"claw_cut",.16f,Tone("95112b"));
    var axis=Vector3.ProjectOnPlane(direction,Game.Cam.transform.forward).normalized;
    if(axis.sqrMagnitude<.01f)axis=Game.Cam.transform.up;
    fx.transform.rotation=Quaternion.LookRotation(Game.Cam.transform.forward,axis);
    fx.Tick=(p,dt)=>{fx.transform.position=start+direction*(reach*(.25f+.25f*p));};
   }
  }
  public void ThrustClawImpact(ActorView target)
  {
   // Four straight parallel cuts across the victim, following its recoil.
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
