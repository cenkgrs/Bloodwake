using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Bloodwake
{
 // Text-only menu entries: the hovered one brightens and shows its sigil and blood glow.
 public sealed class MenuHover:MonoBehaviour,IPointerEnterHandler,IPointerExitHandler
 {
  public Text Label;public GameObject Marker;public Color Normal,Hot;
  void OnEnable()=>Set(false);
  public void OnPointerEnter(PointerEventData eventData)=>Set(true);
  public void OnPointerExit(PointerEventData eventData)=>Set(false);
  void Set(bool hot){if(Label)Label.color=hot?Hot:Normal;if(Marker)Marker.SetActive(hot);}
 }
}
