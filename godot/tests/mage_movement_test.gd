extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false;w.arena.blockers.clear()
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear();w.player.position=Vector3.ZERO
	var mage=w.spawn_enemy("mage",Vector3(0,0,-6));mage.cooldown=999
	var start: Vector3=mage.node.position
	for i in 60:
		w.player.position.x=sin(i*0.1)*2.0
		w._enemy_tick(mage,0.05)
	check(mage.node.position.distance_to(start)<0.05,"Mage holds position as player moves at medium range")
	w.player.position=mage.node.position+Vector3(0,0,2)
	var travelled=0.0;var stationary=0
	for i in 80:
		var previous: Vector3=mage.node.position
		w._enemy_tick(mage,0.05)
		var step=previous.distance_to(mage.node.position);travelled+=step
		if step<0.001:stationary+=1
	check(travelled>0.2 and travelled<1.7,"Close-range relocation is a short step: "+str(travelled))
	check(stationary>=58,"Mage remains catchable after stepping: stationary frames="+str(stationary))
	mage.cooldown=0;w._enemy_tick(mage,0.01);start=mage.node.position
	for i in 8:w._enemy_tick(mage,0.05)
	check(mage.node.position.distance_to(start)<0.01,"Mage plants its feet throughout casting")
	# Having cast, it moves to a new angle round the player instead of staying put.
	for i in 12:w._enemy_tick(mage,0.05)
	check(mage.state=="chase","the cast resolves")
	mage.cooldown=999;var cast_spot: Vector3=mage.node.position
	for i in 50:w._enemy_tick(mage,0.05)
	check(mage.node.position.distance_to(cast_spot)>1.0,"Mage relocates after casting: "+str(mage.node.position.distance_to(cast_spot)))
	var settled: Vector3=mage.node.position
	for i in 20:w._enemy_tick(mage,0.05)
	check(mage.node.position.distance_to(settled)<0.05,"Then it plants again")
	# A rune's recharge does not idle the mage: the next bolt follows at the normal cadence.
	for h in w.hazards:h.node.queue_free()
	w.hazards.clear()
	mage.state="chase";mage.pattern_index=1;mage.cooldown=0;mage.rune_cd=0
	w.player.position=mage.node.position+Vector3(0,0,6)
	w._enemy_tick(mage,0.01)
	check(mage.cast_kind=="rune","the second cast is a rune")
	check(is_equal_approx(mage.cooldown,mage.data.attackCooldown),"after a rune the next cast waits only the attack cooldown: "+str(mage.cooldown))
	check(mage.rune_cd>mage.data.attackCooldown,"the rune recharges on its own clock")
	scene.queue_free();await process_frame
	print("MAGE_MOVEMENT_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
