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
	var tank=w.spawn_enemy("tank",Vector3(0,0,-1));tank.cooldown=0
	check(tank.visual.enemy_asset and not tank.visual.procedural,"Dedicated tank model loads")
	for clip in ["idle","run","attack","hit","death"]:check(tank.visual.clips.has(clip),"Tank clip: "+clip)
	var hp=w.run.stats.hp
	w._enemy_tick(tank,0.01)
	check(tank.state=="tank_swing" and w.run.stats.hp==hp,"Tank winds up without instant damage")
	w._enemy_tick(tank,BWWorld.TANK_CONTACT-0.01)
	check(w.run.stats.hp==hp,"Damage waits until contact")
	w._enemy_tick(tank,0.02)
	check(w.run.stats.hp<hp,"Axe contact damages player in reach")
	tank.visual.lock_time=0;tank.cooldown=0;w._enemy_tick(tank,0.01)
	hp=w.run.stats.hp;w.player.position=Vector3(8,0,8)
	w._enemy_tick(tank,BWWorld.TANK_CONTACT+0.01)
	check(w.run.stats.hp==hp,"Leaving reach dodges committed attack")
	tank.visual.action("death");check(tank.visual.dead,"Tank can play death")
	scene.queue_free();await process_frame
	print("ENEMY_TANK_TEST failures=",failures);quit(0 if failures==0 else 1)
