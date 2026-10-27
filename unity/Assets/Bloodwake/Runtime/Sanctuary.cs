using UnityEngine;
namespace Bloodwake
{
 public sealed partial class BloodwakeGame
 {
  // One hall built from kit pieces, so every wall you see is a wall you collide
  // with. The camera looks in from -x/+z: the north (-z) and east (+x) walls
  // stand tall behind the action, while the south and west walls and every
  // interior partition stay low enough to see over. The merchant, war table and
  // mentor share alcoves along the north wall; the training yard is in front.
  const float SanctuaryHalf=11.5f,TallWall=3.2f,LowWall=.9f,PartitionWall=1.1f,WallDepth=.5f;
  static Material warMapMaterial;
  void BuildSanctuary()
  {
   // EnterRoom's generic grey boundary boxes stay as blockers but are not drawn.
   foreach(var r in roomRoot.GetComponentsInChildren<Renderer>())r.enabled=false;
   var root=new GameObject("Sanctuary").transform;root.SetParent(roomRoot,false);float h=SanctuaryHalf;
   // RoomPresentation turns the one large flat plane into wet stone.
   Slab(root,"Sanctuary floor",new Vector3(0,-.01f,0),new Vector3(h*2,.02f,h*2),new Color(.3f,.27f,.25f));
   foreach(var rug in new[]{new Vector4(7.6f,-9.4f,6.2f,3.4f),new Vector4(0,-9.4f,6.2f,3.4f),new Vector4(-7.6f,-9.4f,6.2f,3.4f)})
    Slab(root,"Sanctuary rug",new Vector3(rug.x,.006f,rug.y),new Vector3(rug.z,.012f,rug.w),new Color(.24f,.035f,.045f));
   // Outer shell: tall behind, low in front with the south entrance open.
   SanctuaryWall(root,new Vector3(0,0,-h),h*2+WallDepth,TallWall,false);
   SanctuaryWall(root,new Vector3(h,0,0),h*2,TallWall,true);
   SanctuaryWall(root,new Vector3(-h,0,0),h*2,LowWall,true);
   foreach(int side in new[]{-1,1})SanctuaryWall(root,new Vector3(side*(h+2)*.5f,0,h),h-2,LowWall,false);
   // Alcove partitions are waist-high with a tall pillar at each mouth.
   foreach(int side in new[]{-1,1})
   {
    SanctuaryWall(root,new Vector3(side*3.8f,0,(-h-7.4f)*.5f),h-7.4f,PartitionWall,true);
    Piece(root,"wall",new Vector3(side*3.8f,0,-7.4f),new Vector3(.8f,3.6f,.8f),0,true);
    // Training yard divider, open in the middle.
    SanctuaryWall(root,new Vector3(side*(h+3)*.5f,0,4),h-3,LowWall,false);
   }
   // Merchant (east alcove): stall counter, stock and a lantern.
   Piece(root,"cloth",new Vector3(7.6f,0,-8.35f),new Vector3(3f,.95f,.9f),0,true);
   Piece(root,"lantern",new Vector3(6.6f,.95f,-8.35f),new Vector3(.32f,.5f,.32f),0,false);Lamp(root,"Lantern light",new Vector3(6.6f,1.35f,-8.35f));
   foreach(var c in new[]{new Vector3(10.4f,0,-10.4f),new Vector3(10.5f,0,-9.1f),new Vector3(9.2f,0,-10.6f)})Piece(root,"crate",c,new Vector3(.9f,.9f,.9f),c.x*37,true);
   foreach(var b in new[]{new Vector3(4.9f,0,-10.6f),new Vector3(5.9f,0,-10.7f)})Piece(root,"barrel",b,new Vector3(.75f,1f,.75f),0,true);
   // War table (centre alcove) carries the hunt map.
   Piece(root,"cloth",new Vector3(0,0,-8.6f),new Vector3(2.6f,.95f,1.6f),0,true);WarMap(root,new Vector3(0,.97f,-8.6f),new Vector2(2.1f,1.2f));
   Piece(root,"lantern",new Vector3(1.05f,.95f,-9.2f),new Vector3(.3f,.46f,.3f),0,false);Lamp(root,"Lantern light",new Vector3(1.05f,1.35f,-9.2f));
   foreach(int side in new[]{-1,1}){Piece(root,"brazier",new Vector3(side*2.6f,0,-10.5f),new Vector3(.6f,1.2f,.6f),0,true);Lamp(root,"Brazier light",new Vector3(side*2.6f,1.3f,-10.5f));}
   // Mentor (west alcove): desk, lantern, braziers.
   Piece(root,"cloth",new Vector3(-7.6f,0,-8.35f),new Vector3(2.4f,.85f,1f),0,true);
   Piece(root,"lantern",new Vector3(-8.5f,.85f,-8.35f),new Vector3(.32f,.5f,.32f),0,false);Lamp(root,"Lantern light",new Vector3(-8.5f,1.25f,-8.35f));
   foreach(var b in new[]{new Vector3(-10.4f,0,-10.4f),new Vector3(-4.9f,0,-10.4f)}){Piece(root,"brazier",b,new Vector3(.6f,1.2f,.6f),0,true);Lamp(root,"Brazier light",b+Vector3.up*1.3f);}
   // Hall fires and wall lanterns on the tall east wall.
   foreach(var f in new[]{new Vector3(-5.6f,0,1.5f),new Vector3(5.6f,0,1.5f),new Vector3(-5.6f,0,-4.5f),new Vector3(5.6f,0,-4.5f)}){Piece(root,"brazier",f,new Vector3(.6f,1.2f,.6f),0,true);Lamp(root,"Brazier light",f+Vector3.up*1.3f);}
   foreach(float z in new[]{-3f,6.5f}){Piece(root,"lantern",new Vector3(h-.45f,2.1f,z),new Vector3(.32f,.5f,.32f),90,false);Lamp(root,"Lantern light",new Vector3(h-.6f,2.5f,z));}
  }
  // Kit model scaled to an exact footprint (model axes before yaw) and sat on the floor.
  GameObject Piece(Transform root,string id,Vector3 at,Vector3 size,float yaw,bool solid)
  {
   var pivot=new GameObject("Sanctuary "+id).transform;pivot.SetParent(root,false);
   var prefab=Resources.Load<GameObject>("Environment/Kit01/"+id+"/"+id);GameObject model;
   if(prefab){model=Instantiate(prefab,pivot);model.transform.localPosition=Vector3.zero;model.transform.localRotation=Quaternion.identity;}
   else{model=GameObject.CreatePrimitive(PrimitiveType.Cube);Destroy(model.GetComponent<Collider>());model.transform.SetParent(pivot,false);model.GetComponent<Renderer>().sharedMaterial=Effects.Mat(new Color(.22f,.2f,.19f));}
   var b=EnvironmentDressing.BoundsOf(model.GetComponentsInChildren<Renderer>());model.transform.localScale=Vector3.Scale(model.transform.localScale,new Vector3(size.x/b.size.x,size.y/b.size.y,size.z/b.size.z));
   b=EnvironmentDressing.BoundsOf(model.GetComponentsInChildren<Renderer>());model.transform.localPosition-=new Vector3(b.center.x,b.min.y,b.center.z);
   pivot.SetPositionAndRotation(at,Quaternion.Euler(0,yaw,0));
   if(solid){var world=EnvironmentDressing.BoundsOf(model.GetComponentsInChildren<Renderer>());world.min=new Vector3(world.min.x,0,world.min.z);if(id=="wall")blockers.Add(world);else PropBlocker(world);}
   return model;
  }
  // Long runs are split into ~2.8 m kit segments so the stone texture is not smeared; one blocker covers the run.
  void SanctuaryWall(Transform root,Vector3 centre,float length,float height,bool alongZ)
  {
   int count=Mathf.Max(1,Mathf.RoundToInt(length/2.8f));float step=length/count;
   for(int i=0;i<count;i++){float offset=-length*.5f+(i+.5f)*step;Piece(root,"wall",centre+(alongZ?Vector3.forward:Vector3.right)*offset,new Vector3(step,height,WallDepth),alongZ?90:0,false);}
   blockers.Add(new Bounds(centre+Vector3.up*Mathf.Max(1,height*.5f),alongZ?new Vector3(WallDepth,Mathf.Max(2,height),length):new Vector3(length,Mathf.Max(2,height),WallDepth)));
  }
  void Slab(Transform root,string name,Vector3 at,Vector3 size,Color color)
  {
   var go=GameObject.CreatePrimitive(PrimitiveType.Cube);go.name=name;Destroy(go.GetComponent<Collider>());go.transform.SetParent(root,false);go.transform.position=at;go.transform.localScale=size;go.GetComponent<Renderer>().sharedMaterial=Effects.Mat(color);
  }
  // RoomPresentation gives every light a flame and the warm palette, keyed on its name.
  void Lamp(Transform root,string name,Vector3 at){var light=new GameObject(name).AddComponent<Light>();light.transform.SetParent(root,false);light.transform.position=at;light.type=LightType.Point;light.shadows=LightShadows.None;}
  void WarMap(Transform root,Vector3 at,Vector2 size)
  {
   if(!warMapMaterial){warMapMaterial=new Material(Shader.Find("Universal Render Pipeline/Lit")){name="War table map"};warMapMaterial.SetTexture("_BaseMap",Resources.Load<Texture2D>("ui/maps/"+GameData.Maps["maps"][0].S("id")));warMapMaterial.SetFloat("_Smoothness",.15f);}
   var quad=GameObject.CreatePrimitive(PrimitiveType.Quad);quad.name="War table map";Destroy(quad.GetComponent<Collider>());quad.transform.SetParent(root,false);
   quad.transform.SetPositionAndRotation(at,Quaternion.Euler(90,0,0));quad.transform.localScale=new Vector3(size.x,size.y,1);quad.GetComponent<Renderer>().sharedMaterial=warMapMaterial;
  }
 }
}
