class_name BWTouch
extends Control
signal ability_pressed
signal auto_fire_toggled
var movement=Vector2.ZERO
var firing=false
var fire_finger=-1
var auto_fire_on=false
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
	var skill=_skill_spot()
	var trigger=_fire_spot()
	var toggle=_toggle_spot()
	if event is InputEventScreenTouch:
		if event.pressed and event.position.distance_to(toggle)<38:
			auto_fire_on=not auto_fire_on;auto_fire_toggled.emit();get_viewport().set_input_as_handled()
		elif event.pressed and event.position.distance_to(trigger)<62:
			firing=true;fire_finger=event.index;get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==fire_finger:
			firing=false;fire_finger=-1;get_viewport().set_input_as_handled()
		elif event.pressed and event.position.distance_to(skill)<65:
			ability_pressed.emit();get_viewport().set_input_as_handled()
		elif event.pressed and event.position.x<size.x*0.45 and event.position.y>size.y*0.45 and finger==-1:
			finger=event.index;center=event.position;knob=center;get_viewport().set_input_as_handled()
		elif not event.pressed and event.index==finger:
			finger=-1;movement=Vector2.ZERO;get_viewport().set_input_as_handled()
	if event is InputEventScreenDrag and event.index==finger:
		movement=((event.position-center)/60).limit_length();knob=center+movement*60;get_viewport().set_input_as_handled()
	queue_redraw()

func _skill_spot() -> Vector2:return Vector2(size.x-100,size.y-110)
func _fire_spot() -> Vector2:return Vector2(size.x-235,size.y-95)
func _toggle_spot() -> Vector2:return Vector2(size.x-100,size.y-250)

func _draw():
	if not enabled:return
	var origin=Vector2(100,size.y-110) if finger==-1 else center
	draw_circle(origin,65,Color(0.06,0.045,0.035,0.6))
	draw_arc(origin,65,0,TAU,48,Color("8a6a35",0.65),2)
	draw_circle(origin if finger==-1 else knob,25,Color(0.82,0.76,0.62,0.72))
	var skill=_skill_spot()
	draw_circle(skill,52,Color(0.06,0.045,0.035,0.88));draw_arc(skill,52,0,TAU,48,Color("d7ae64"),3)
	draw_line(skill+Vector2(-12,12),skill+Vector2(12,-12),Color("d7ae64"),5)
	draw_line(skill+Vector2(-8,-5),skill+Vector2(5,8),Color("d7ae64"),4)
	var trigger=_fire_spot()
	draw_circle(trigger,58,Color(0.1,0.03,0.03,0.9) if firing else Color(0.06,0.045,0.035,0.88))
	draw_arc(trigger,58,0,TAU,48,Color("c64349"),3)
	draw_circle(trigger,13,Color("c64349"))
	draw_arc(trigger,26,0,TAU,32,Color("c64349"),2)
	var toggle=_toggle_spot()
	draw_circle(toggle,34,Color(0.09,0.07,0.04,0.88))
	draw_arc(toggle,34,0,TAU,32,Color("d7ae64") if auto_fire_on else Color(0.45,0.4,0.32),2)
	draw_arc(toggle,16,0,TAU if auto_fire_on else PI,24,Color("d7ae64") if auto_fire_on else Color(0.5,0.45,0.36),4)
