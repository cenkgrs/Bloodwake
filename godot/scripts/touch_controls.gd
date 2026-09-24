class_name BWTouch
extends Control
signal ability_pressed
var movement=Vector2.ZERO
var finger=-1
var center=Vector2.ZERO
var knob=Vector2.ZERO
var enabled=false

func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event):
 if not visible or not enabled:return
 var origin=Vector2(100,size.y-110)
 var skill=Vector2(size.x-100,size.y-110)
 if event is InputEventScreenTouch:
  if event.pressed and event.position.distance_to(skill)<65:
   ability_pressed.emit();get_viewport().set_input_as_handled()
  elif event.pressed and event.position.x<size.x*0.45 and event.position.y>size.y*0.45 and finger==-1:
   finger=event.index;center=event.position;knob=center;get_viewport().set_input_as_handled()
  elif not event.pressed and event.index==finger:
   finger=-1;movement=Vector2.ZERO;get_viewport().set_input_as_handled()
 if event is InputEventScreenDrag and event.index==finger:
  movement=((event.position-center)/60).limit_length();knob=center+movement*60;get_viewport().set_input_as_handled()
 queue_redraw()

func _draw():
 if not enabled:return
 var origin=Vector2(100,size.y-110) if finger==-1 else center
 draw_circle(origin,65,Color(0.15,0.18,0.23,0.6))
 draw_arc(origin,65,0,TAU,48,Color(0.8,0.68,0.4,0.6),2)
 draw_circle(origin if finger==-1 else knob,25,Color(0.8,0.76,0.66,0.7))
 var skill=Vector2(size.x-100,size.y-110)
 draw_circle(skill,52,Color(0.14,0.18,0.23,0.85));draw_arc(skill,52,0,TAU,48,Color("d7ae64"),3)
 draw_line(skill+Vector2(-12,12),skill+Vector2(12,-12),Color("d7ae64"),5)
 draw_line(skill+Vector2(-8,-5),skill+Vector2(5,8),Color("d7ae64"),4)
