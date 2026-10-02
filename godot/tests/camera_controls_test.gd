extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false;w.arena.blockers.clear()
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear();w.player.position=Vector3.ZERO
	check(w.camera.size==13,"Approved camera framing")
	var origin=w.camera.unproject_position(Vector3.ZERO)
	var up=w.camera.unproject_position(w.screen_direction(Vector2.UP))-origin
	var right=w.camera.unproject_position(w.screen_direction(Vector2.RIGHT))-origin
	check(up.y<0 and absf(up.x)<0.01,"W moves screen-up")
	check(right.x>0 and absf(right.y)<0.01,"D moves screen-right")
	check(absf(w.screen_direction(Vector2(0.3,0.4)).length()-0.5)<0.001,"Analog magnitude preserved")
	check(absf(w.screen_direction(Vector2.ONE.normalized()).length()-1)<0.001,"Diagonal speed preserved")
	w.rest_time=999;w.running=true;w.touch_aim=Vector2.LEFT
	w._physics_process(0.01)
	check(w.aim.distance_to(w.screen_direction(Vector2.LEFT))<0.001,"Touch aim follows camera")
	check((w.ground_target(3)-w.player.position).normalized().distance_to(w.aim)<0.001,"Ground skill follows touch aim")
	var target=Vector3(2,0,-3);var pixel=w.camera.unproject_position(target)
	var hit=Plane(Vector3.UP,0).intersects_ray(w.camera.project_ray_origin(pixel),w.camera.project_ray_normal(pixel))
	check(hit!=null and hit.distance_to(target)<0.001,"Mouse ray picks world target")
	w.player.position=Vector3(2,0,2);w.shake=0
	for i in 90:w._physics_process(0.016)
	check((w.camera.position-w.player.position).distance_to(BWWorld.CAMERA_OFFSET)<0.01,"Camera follow retains approved offset")
	w.running=false
	scene.queue_free();await process_frame
	print("CAMERA_CONTROLS_TEST failures=",failures)
	quit(0 if failures==0 else 1)
