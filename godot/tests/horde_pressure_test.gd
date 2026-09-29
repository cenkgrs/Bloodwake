extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var world=scene.world;world.running=false;world.auto_fire=false;world.arena.blockers.clear()
	world.player.position=Vector3.ZERO
	world.player_velocity=Vector3.RIGHT*3.0
	var crossing=world.spawn_enemy("grunt",Vector3(0,0,6));crossing.hunt_role=1;crossing.hunt_side=1.0
	var intercept=world._pursuit_direction(crossing,6.0)
	check(intercept.x>0.35 and intercept.z<0,"enemy approaching from below cuts ahead of a runner moving right")
	world.player_velocity=Vector3.LEFT*3.0
	check(world._pursuit_direction(crossing,6.0).x< -0.35,"interception adapts when the runner reverses direction")
	world.player_velocity=Vector3.BACK*3.0;crossing.node.position=Vector3(0,0,-7)
	crossing.hunt_side=-1.0;var left=world._pursuit_direction(crossing,7.0)
	crossing.hunt_side=1.0;var right=world._pursuit_direction(crossing,7.0)
	check(left.x*right.x<0 and absf(left.x)>0.12,"rear pursuers split onto both flanks instead of sharing one line")
	crossing.node.position=Vector3(0,0,1.0)
	check(world._pursuit_direction(crossing,1.0).is_equal_approx(Vector3.FORWARD),"nearby flankers commit to contact instead of circling forever")
	world.enemies.erase(crossing);crossing.node.queue_free()
	for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]:
		world.player_velocity=direction*3;world.spawn_slot=0;world.spawn_bearing=0;world.rng.seed=421
		var ahead=0
		for i in 24:
			var point=world._spawn_point();var offset=point-world.player.position
			if offset.normalized().dot(direction)>0.4:ahead+=1
			check(offset.length()>=7.5,"reactive spawns keep a safe arrival distance")
		check(ahead>=15,"most arrivals contest current escape direction: "+str(direction))
	for corner in [Vector3(34,0,34),Vector3(-34,0,-34),Vector3(-34,0,34),Vector3(34,0,-34)]:
		world.player.position=corner;world.player_velocity=corner.normalized()*3
		for i in 12:
			var point=world._spawn_point()
			check(point.distance_to(corner)>=7.5,"corner spawn does not collapse onto player")
			check(absf(point.x)<=BWArena.EDGE and absf(point.z)<=BWArena.EDGE,"arrival stays inside arena")
	# Actual movement drives the prediction and it decays after releasing input.
	world.player.position=Vector3.ZERO;world.player_velocity=Vector3.ZERO
	world.rest_time=999;world.running=true;world.move_input=Vector2.RIGHT
	for i in 10:world._physics_process(0.05)
	check(world.player_velocity.x>1,"prediction observes actual player movement")
	world.move_input=Vector2.ZERO
	for i in 20:world._physics_process(0.05)
	check(world.player_velocity.length()<0.1,"stopping does not leave a stale pursuit velocity")
	world.running=false
	scene.queue_free();await process_frame
	print("HORDE_PRESSURE_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
