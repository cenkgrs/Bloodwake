using UnityEngine;
using UnityEngine.UI;
namespace Bloodwake
{
 [RequireComponent(typeof(CanvasRenderer))]
 public sealed class PortraitMask:MaskableGraphic
 {
  protected override void OnPopulateMesh(VertexHelper vh)
  {
   vh.Clear();var rect=rectTransform.rect;var center=rect.center;var vertex=UIVertex.simpleVert;vertex.color=Color.white;vertex.position=center;vertex.uv0=new Vector2(.5f,.5f);vh.AddVert(vertex);
   for(int i=0;i<=48;i++){float angle=i*Mathf.PI*2/48;var uv=new Vector2(Mathf.Cos(angle),Mathf.Sin(angle))*.5f+Vector2.one*.5f;vertex.position=new Vector3(rect.xMin+uv.x*rect.width,rect.yMin+uv.y*rect.height);vertex.uv0=uv;vh.AddVert(vertex);if(i>0)vh.AddTriangle(0,i,i+1);}
  }
 }
}
