extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=true;w.auto_fire=false;w.rest_time=999;w.arena.blockers.clear()
	w.move_input=Vector2.RIGHT;w.player.position=Vector3.ZERO
	w.visual.action("attack1",0.8);w.swing_gate=0.4
	w._physics_process(0.1)
	check(w.player.position.length()<0.001,"Full-body attack plants feet through strike")
	w.swing_gate=0;w._physics_process(0.1)
	check(w.player.position.length()>0.2 and w.visual.state=="run","Movement cancels recovery into locomotion")
	check(is_equal_approx(w.player.position.length(),0.34),"Warrior moves at reduced 3.4 m/s")
	check(is_equal_approx(w.visual.clip_length("run")/w.visual.clip_speed("run"),0.82),"Slower locomotion cycle")
	w.running=false;scene.queue_free();await process_frame
	print("WARRIOR_MOVEMENT_TEST failures=",failures);quit(0 if failures==0 else 1)
