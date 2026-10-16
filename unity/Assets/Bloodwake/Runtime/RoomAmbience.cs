using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;
using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // Town rooms read as an empty moonlit plate next to the art-direction frames.
  // This pass rings the walkable edge with fires and stacked cargo and scatters
  // ground decals, keeping clear of doors, spawns, the reward point, existing
  // lights, blockers and the central fighting space. Placement is seeded by the
  // room id so a room always dresses the same way.
  static Texture2D bloodDecal,puddleDecal,grateDecal;static Material bloodMaterial,puddleMaterial,grateMaterial;
  void DressRoom(string id)
  {
   var random=new System.Random(id.Aggregate(17,(h,c)=>h*31+c));float R(float a,float b)=>a+(float)random.NextDouble()*(b-a);
   var root=new GameObject("Room ambience").transform;root.SetParent(roomRoot,false);
   var keep=new List<(Vector3 at,float radius)>();
   foreach(var door in (room["doors"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())keep.Add((Point(door.Value["at"]),4.2f));
   foreach(var marker in (room["markers"] as JObject)?.Properties()??Enumerable.Empty<JProperty>())
    if(marker.Value is JArray list&&list.Count>0&&list[0] is JArray)foreach(var p in list)keep.Add((Point(p),2.4f));else keep.Add((Point(marker.Value),2.6f));
   foreach(var light in roomRoot.GetComponentsInChildren<Light>())keep.Add((light.transform.position,3.2f));
   bool Free(Vector3 p,float radius)=>keep.All(k=>Vector3.Distance(new Vector3(p.x,0,p.z),new Vector3(k.at.x,0,k.at.z))>k.radius+radius)&&
    blockers.All(b=>{var e=b;e.Expand(new Vector3(radius*2+.6f,0,radius*2+.6f));return !e.Contains(new Vector3(p.x,b.center.y,p.z));});
   // Perimeter ring, inset from the walkable edge; the middle stays open for combat.
   float inset=1.3f;var ring=new List<Vector3>();
   for(float x=-half.x+inset;x<=half.x-inset;x+=4.6f){ring.Add(new Vector3(x,0,-half.y+inset));ring.Add(new Vector3(x,0,half.y-inset));}
   for(float z=-half.y+inset+4.6f;z<=half.y-inset-4.6f;z+=4.6f){ring.Add(new Vector3(-half.x+inset,0,z));ring.Add(new Vector3(half.x-inset,0,z));}
   int fires=0,stacks=0;
   foreach(var spot in ring.OrderBy(_=>random.Next()))
   {
    var p=spot+new Vector3(R(-.6f,.6f),0,R(-.6f,.6f));
    if(fires<6&&Free(p,.5f)){Piece(root,"brazier",p,new Vector3(.6f,1.2f,.6f),0,true);Lamp(root,"Brazier light",p+Vector3.up*1.3f);keep.Add((p,4.4f));fires++;continue;}
    if(stacks<6&&Free(p,1f))
    {
     // A crate stack with a barrel beside it, turned so it doesn't sit on the grid.
     float yaw=R(0,90);Piece(root,"crate",p,new Vector3(.95f,.95f,.95f),yaw,true);
     if(random.NextDouble()<.6)Piece(root,"crate",p+Vector3.up*.95f,new Vector3(.8f,.8f,.8f),yaw+R(10,35),false);
     Piece(root,"barrel",p+Quaternion.Euler(0,yaw,0)*new Vector3(1.05f,0,.15f),new Vector3(.7f,.95f,.7f),0,true);keep.Add((p,1.6f));stacks++;
    }
   }
   // Decals: blood where the fighting happens, puddles near fires to catch their light, a couple of drain grates.
   EnsureDecalMaterials();float floorX=half.x-.8f,floorZ=half.y-.8f;
   for(int i=0,tries=0;i<9&&tries<80;tries++){var p=new Vector3(R(-floorX,floorX),0,R(-floorZ,floorZ));if(!Free(p,0))continue;var stain=Decal(root,"Blood stain",p,R(1.1f,2.6f),R(0,360),bloodMaterial,.012f);stain.transform.localScale=Vector3.Scale(stain.transform.localScale,new Vector3(1,R(.4f,1),1));i++;}
   var fireSpots=roomRoot.GetComponentsInChildren<Light>().Select(l=>l.transform.position).ToArray();
   for(int i=0,tries=0;i<6&&tries<80&&fireSpots.Length>0;tries++){var f=fireSpots[random.Next(fireSpots.Length)];var p=new Vector3(f.x,0,f.z)+Quaternion.Euler(0,R(0,360),0)*Vector3.forward*R(1.4f,3.2f);
    if(Mathf.Abs(p.x)>floorX||Mathf.Abs(p.z)>floorZ||!Free(p,0))continue;Decal(root,"Puddle",p,R(1.4f,2.8f),R(0,360),puddleMaterial,.008f);i++;}
   for(int i=0,tries=0;i<2&&tries<40;tries++){var p=new Vector3(R(-floorX*.7f,floorX*.7f),0,R(-floorZ*.7f,floorZ*.7f));if(!Free(p,.4f))continue;Decal(root,"Drain grate",p,.9f,Mathf.Round(R(0,4))*90,grateMaterial,.016f);i++;}
  }
  static GameObject Decal(Transform root,string name,Vector3 at,float size,float yaw,Material material,float lift)
  {
   var quad=GameObject.CreatePrimitive(PrimitiveType.Quad);quad.name=name;Object.Destroy(quad.GetComponent<Collider>());quad.transform.SetParent(root,false);
   quad.transform.SetPositionAndRotation(at+Vector3.up*lift,Quaternion.Euler(90,yaw,0));quad.transform.localScale=new Vector3(size,size,1);
   var r=quad.GetComponent<MeshRenderer>();r.sharedMaterial=material;r.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;return quad;
  }
  static void EnsureDecalMaterials()
  {
   if(bloodMaterial)return;
   bloodDecal=Splat(256,1,true);puddleDecal=Splat(256,2,false);grateDecal=Grate(128);
   bloodMaterial=DecalMaterial("Blood decal",bloodDecal,new Color(.32f,.015f,.025f),.82f);
   puddleMaterial=DecalMaterial("Puddle decal",puddleDecal,new Color(.03f,.035f,.045f,.7f),.97f);
   grateMaterial=DecalMaterial("Grate decal",grateDecal,new Color(.42f,.39f,.36f),.6f);grateMaterial.SetFloat("_Metallic",.7f);
  }
  // URP Lit set up as alpha-blended so wet decals still take fire light and reflections.
  static Material DecalMaterial(string name,Texture2D texture,Color tint,float smoothness)
  {
   var m=new Material(Shader.Find("Universal Render Pipeline/Lit")){name=name};m.SetTexture("_BaseMap",texture);m.SetColor("_BaseColor",tint);m.SetFloat("_Smoothness",smoothness);
   m.SetFloat("_Surface",1);m.SetFloat("_Blend",0);m.SetFloat("_SrcBlend",(float)UnityEngine.Rendering.BlendMode.SrcAlpha);m.SetFloat("_DstBlend",(float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
   m.SetFloat("_ZWrite",0);m.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");m.SetOverrideTag("RenderType","Transparent");m.renderQueue=(int)UnityEngine.Rendering.RenderQueue.Transparent-50;m.SetShaderPassEnabled("ShadowCaster",false);return m;
  }
  // Irregular blob from layered noise; blood adds flung droplets around the edge.
  static Texture2D Splat(int size,int seed,bool droplets)
  {
   var t=new Texture2D(size,size,TextureFormat.RGBA32,true){wrapMode=TextureWrapMode.Clamp,name=droplets?"Blood splat":"Puddle"};var px=new Color32[size*size];float o=seed*17.3f;
   var drops=new List<Vector3>();var rnd=new System.Random(seed);if(droplets)for(int i=0;i<14;i++){float a=(float)rnd.NextDouble()*6.283f,d=.3f+(float)rnd.NextDouble()*.17f;drops.Add(new Vector3(.5f+Mathf.Cos(a)*d,.5f+Mathf.Sin(a)*d,.012f+(float)rnd.NextDouble()*.03f));}
   for(int y=0;y<size;y++)for(int x=0;x<size;x++)
   {
    float u=x/(float)size,v=y/(float)size,dx=u-.5f,dy=v-.5f,r=Mathf.Sqrt(dx*dx+dy*dy),ang=Mathf.Atan2(dy,dx);
    float edge=.26f+.07f*Mathf.PerlinNoise(Mathf.Cos(ang)*1.8f+o,Mathf.Sin(ang)*1.8f+o)+.05f*Mathf.PerlinNoise(Mathf.Cos(ang)*5+o,Mathf.Sin(ang)*5+o);
    float a=Mathf.Clamp01((edge-r)/.03f);foreach(var d in drops){float dd=Vector2.Distance(new Vector2(u,v),new Vector2(d.x,d.y));a=Mathf.Max(a,Mathf.Clamp01((d.z-dd)/.006f));}
    float body=.75f+.25f*Mathf.PerlinNoise(u*9+o,v*9+o);px[y*size+x]=new Color(body,body,body,a*(droplets?.95f:.85f));
   }
   t.SetPixels32(px);t.Apply(true);return t;
  }
  static Texture2D Grate(int size)
  {
   var t=new Texture2D(size,size,TextureFormat.RGBA32,true){wrapMode=TextureWrapMode.Clamp,name="Drain grate"};var px=new Color32[size*size];
   for(int y=0;y<size;y++)for(int x=0;x<size;x++)
   {
    float u=x/(float)size,v=y/(float)size;bool frame=u<.08f||u>.92f||v<.08f||v>.92f;bool bar=(int)(u*9)%2==0;
    float slotShade=frame?.75f:bar?.6f:.03f;px[y*size+x]=new Color(slotShade,slotShade,slotShade,1);
   }
   t.SetPixels32(px);t.Apply(true);return t;
  }
 }
}
