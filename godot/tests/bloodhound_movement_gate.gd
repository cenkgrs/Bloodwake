extends SceneTree
var failures=0
func _initialize():call_deferred("suite")
func check(ok: bool,label: String):
	if not ok:failures+=1;push_error(label)
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://bloodhound_movement_gate.json"
	scene.start_run("gunslinger");await process_frame
	var w=scene.world;var run=scene.run;w.set_physics_process(false)
	w.rest_time=999;w.auto_fire=false;w.running=true
	var origin=w.player.position;var traces=[];var events=[]
	w.bloodhound_event.connect(func(event):events.append(event))
	for firing in [false,true]:
		w.player.position=origin;w.visual.lock_time=0;w.pending_attacks.clear();w.impact_pause=0
		Input.action_press("move_right");w.aim=Vector3.BACK
		if firing:Input.action_press("fire")
		else:Input.action_release("fire")
		var positions=[]
		for frame in 180:
			w._physics_process(1.0/60);positions.append(w.player.position)
			await process_frame
		traces.append(positions)
	Input.action_release("fire");Input.action_release("move_right")
	var travelled=0.0;var mismatch=0.0
	for i in 179:
		travelled+=traces[0][i].distance_to(traces[0][i+1])
		mismatch=maxf(mismatch,traces[0][i].distance_to(traces[1][i]))
	check(travelled>3,"Baseline movement traverses arena")
	check(events.size()>=15,"Sustained input produces multiple real bursts")
	check(mismatch<0.005,"Firing and non-firing movement paths match within 5mm")
	print("BH_MOVEMENT_GATE travelled=",travelled," max_path_error=",mismatch," events=",events.size()," failures=",failures)
	scene.queue_free();await process_frame;quit(1 if failures else 0)
