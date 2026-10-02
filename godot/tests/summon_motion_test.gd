extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.arena.blockers.clear();w.run.stats.hp=10000;w.run.stats.maxHp=10000
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	w.player.position=Vector3(0,0,10);w.player_velocity=Vector3.ZERO
	var boss=w.spawn_enemy("boss",Vector3.ZERO)
	BWBoss.begin(w,boss,"summon");w._enemy_tick(boss,1.51)
	var flanking=0
	for e in w.enemies:
		if e.has("summon_route"):flanking+=1
	check(flanking==3,"three of four summoned adds have dedicated flanking routes")
	var bilateral_frames=0;var reached_front=false
	for frame in 540:
		for e in w.enemies:
			if e.id!="boss":w._enemy_tick(e,1.0/60.0)
		if frame>=120 and frame<360:
			var left=0;var right=0
			for e in w.enemies:
				if e.id=="boss":continue
				var offset=e.node.position-w.player.position
				if offset.x>2.0:left+=1
				if offset.x< -2.0:right+=1
				if offset.z>1.0:reached_front=true
			if left>=1 and right>=1:bilateral_frames+=1
	var completed=0
	for e in w.enemies:
		if e.get("summon_route",0)==2:completed+=1
	print("SUMMON_MOTION bilateral_frames=",bilateral_frames," completed_routes=",completed," reached_front=",reached_front)
	check(bilateral_frames>=120,"summoned group maintains at least one enemy on each flank for two seconds")
	check(reached_front,"summoned flankers reach ahead of player instead of all trailing boss")
	check(completed>=3,"flankers finish their routes and commit to melee")
	var normal=w.spawn_enemy("grunt",Vector3(8,0,8))
	check(not normal.has("summon_route"),"ordinary wave enemy has no summon routing")
	scene.queue_free();await process_frame;quit(failures)
