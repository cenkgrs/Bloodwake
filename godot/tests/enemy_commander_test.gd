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
	var commander=w.spawn_enemy("commander",Vector3(0,0,-5))
	var ally=w.spawn_enemy("grunt",Vector3(1,0,-5))
	var distant=w.spawn_enemy("grunt",Vector3(20,0,20))
	check(commander.visual.enemy_asset and not commander.visual.procedural,"Dedicated commander loads")
	for clip in ["idle","run","attack","hit","death"]:check(commander.visual.clips.has(clip),"Commander clip: "+clip)
	check(commander.visual.model.find_child("Equipment_LeftHand",true,false)!=null,"Staff attached to hand")
	commander.cooldown=0;var start=commander.node.position
	w._enemy_tick(commander,0.01)
	check(commander.state=="rally" and commander.visual.state=="attack","Commander performs rally animation")
	check(ally.aura==0,"Aura waits for cast")
	w._enemy_tick(commander,BWWorld.COMMANDER_RELEASE+0.001)
	check(ally.aura==commander.data.auraDuration,"Nearby ally gains configured aura")
	check(distant.aura==0 and commander.aura==0,"Aura excludes distant allies and self")
	check(commander.node.position.distance_to(start)<0.01,"Commander plants feet while casting")
	ally.aura=0;w._enemy_tick(commander,0.1)
	check(ally.aura==0,"Aura does not fire again during recovery")
	commander.visual.action("death");check(commander.visual.dead,"Commander death plays")
	scene.queue_free();await process_frame
	print("ENEMY_COMMANDER_TEST failures=",failures);quit(0 if failures==0 else 1)
