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
	check(w.player.position.length()>0.0,"Movement can leave an empty attack recovery")
	w.swing_gate=0;w._physics_process(0.1)
	check(w.player.position.length()>0.2 and w.visual.state=="run","Movement cancels recovery into locomotion")
	check(is_equal_approx(w.player.position.length(),0.84),"Warrior moves at 4.2 m/s across two steps")
	check(is_equal_approx(w.visual.clip_length("run")/w.visual.clip_speed("run"),0.72),"Locomotion cycle matches grounded stride")
	# A real button-triggered swing advances along its committed aim, even at rest.
	w.move_input=Vector2.ZERO;w.player.position=Vector3.ZERO;w.aim=Vector3.RIGHT
	w.visual.lock_time=0;w.swing_gate=0
	for id in w.run.weapons:w.run.weapons[id].cooldown=0
	Input.action_press("fire");w._weapons(0);Input.action_release("fire")
	check(w.pending_attacks.size()==1,"Button starts one committed swing")
	w._physics_process(0.05)
	check(w.player.position.x>0.0 and w.player.position.x<0.5,"Swing begins with a short forward step")
	w.aim=Vector3.LEFT
	for frame in 20:w._physics_process(0.05)
	check(w.player.position.is_equal_approx(Vector3.RIGHT*0.5),"Step finishes at half a metre without following changed aim")
	w.player.position=Vector3.ZERO;w.swing_gate=0;w.visual.lock_time=0;w.aim=Vector3.RIGHT
	w.arena.blockers.append({"pos":Vector3(0.9,0,0),"radius":0.4})
	for id in w.run.weapons:w.run.weapons[id].cooldown=0
	Input.action_press("fire");w._weapons(0);Input.action_release("fire")
	for frame in 20:w._physics_process(0.05)
	check(w.player.position.x<=0.081,"Swing step respects solid obstacles")
	# Fourth link uses the exact ultimate clip and contacts the ground at 450 ms.
	w.arena.blockers.clear();w.player.position=Vector3.ZERO;w.move_input=Vector2.RIGHT
	w.pending_attacks.clear();w.visual.lock_time=0;w.swing_gate=0
	w.combo_step=2;w.combo_timer=2
	for id in w.run.weapons:w.run.weapons[id].cooldown=0
	Input.action_press("fire");w._weapons(0);Input.action_release("fire")
	check(w.visual.clips.attack4==w.visual.clips.ultimate,"Fourth swing uses ultimate ground slam")
	check(w.visual.state=="attack4" and is_equal_approx(w.pending_attacks[0].time,0.45),"Finisher contacts at ultimate contact time")
	check(not w.pending_attacks[0].has("step_time"),"Ground slam does not slide forward")
	w._physics_process(0.1)
	check(w.player.position.length()<0.001,"Slam stays planted despite movement input")
	w.running=false;scene.queue_free();await process_frame
	print("WARRIOR_MOVEMENT_TEST failures=",failures);quit(0 if failures==0 else 1)
