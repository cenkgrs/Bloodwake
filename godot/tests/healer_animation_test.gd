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
	for e in world.enemies:e.node.queue_free()
	world.enemies.clear();world.player.position=Vector3(0,0,-5)
	var healer=world.spawn_enemy("healer",Vector3.ZERO)
	var ally=world.spawn_enemy("tank",Vector3(1,0,0))
	check(healer.visual.enemy_asset,"Healer uses dedicated Mixamo model")
	check(healer.visual.model.find_child("Equipment_LeftHand",true,false)!=null,"Staff bound to left hand")
	for clip in ["idle","run","attack","hit","death"]:check(healer.visual.clips.has(clip),"Healer clip: "+clip)
	healer.cooldown=0
	world._enemy_tick(healer,0.01)
	check(healer.state!="heal","No empty cast when allies are healthy")
	ally.hp=1;healer.cooldown=0
	world._enemy_tick(healer,0.01)
	check(healer.state=="heal" and healer.visual.state=="attack","Injured ally starts Magic Heal")
	check(ally.hp==1,"Healing waits for casting pose")
	world._enemy_tick(healer,0.2)
	check(ally.hp==1,"No early healing during windup")
	world._enemy_tick(healer,0.21)
	check(ally.hp==minf(ally.maxHp,1+healer.data.healAmount),"One heal lands at contact")
	var healed=ally.hp
	world._enemy_tick(healer,0.2)
	check(ally.hp==healed,"Recovery does not apply a second heal")
	# Leaving range and dying during the cast both invalidate the selected target.
	for removed in [false,true]:
		healer.node.position=Vector3.ZERO;healer.cooldown=0;healer.visual.lock_time=0
		ally.node.position=Vector3(1,0,0);ally.hp=1
		world._enemy_tick(healer,0.01)
		if removed:world.enemies.erase(ally)
		else:ally.node.position=Vector3(100,0,0)
		world._enemy_tick(healer,0.41)
		check(ally.hp==1,"Invalid target is not healed: removed="+str(removed))
		check(not healer.has("heal_target"),"Cast releases target reference")
	ally.node.queue_free()
	scene.queue_free();await process_frame
	print("HEALER_ANIMATION_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
