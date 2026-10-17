using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Bloodwake
{
 // Text-only menu entries: the hovered or focused one brightens and shows its sigil and blood glow.
 // Plaque buttons use it only for Entered, which plays the hover sound.
 public sealed class MenuHover:MonoBehaviour,IPointerEnterHandler,IPointerExitHandler,ISelectHandler,IDeselectHandler
 {
  public Text Label;public GameObject Marker;public Color Normal,Hot;public Action Entered;
  void OnEnable()=>Set(false);
  public void OnPointerEnter(PointerEventData eventData){Set(true);Entered?.Invoke();}
  public void OnPointerExit(PointerEventData eventData)=>Set(false);
  // Gamepad and keyboard focus light the entry the same way.
  public void OnSelect(BaseEventData eventData){Set(true);Entered?.Invoke();}
  public void OnDeselect(BaseEventData eventData)=>Set(false);
  void Set(bool hot){if(Label)Label.color=hot?Hot:Normal;if(Marker)Marker.SetActive(hot);}
 }
}
