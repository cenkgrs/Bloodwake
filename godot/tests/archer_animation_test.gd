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
	var world=scene.world;world.running=false;world.auto_fire=false;world.arena.blockers.clear()
	for e in world.enemies:e.node.queue_free()
	world.enemies.clear()
	world.player.position=Vector3.ZERO
	var archer=world.spawn_enemy("archer",Vector3(0,0,-7))
	archer.cooldown=0
	check(archer.visual.enemy_asset,"Archer uses its own rig")
	check(archer.visual.model.find_child("Equipment_LeftHand",true,false)!=null,"Bow attached to left hand")
	for clip in ["idle","run","draw","attack","hit","death"]:
		check(archer.visual.clips.has(clip),"Archer clip: "+clip)
	world._enemy_tick(archer,0.01)
	check(archer.state=="draw" and archer.visual.state=="draw","Windup plays the aiming clip")
	check(world.bullets.is_empty(),"No arrow before windup")
	var shot: Vector3=archer.shot_direction
	world.player.position=Vector3(3,0,0)
	for i in 7:world._enemy_tick(archer,0.05)
	check(world.bullets.is_empty(),"Arrow waits the full warning time")
	check(archer.shot_direction.is_equal_approx(shot),"Dodging does not bend the announced aim")
	world._enemy_tick(archer,0.06)
	check(world.bullets.size()==1,"Windup releases exactly one arrow")
	check(archer.visual.state=="attack","Release plays recoil clip")
	if not world.bullets.is_empty():
		check(world.bullets[0].direction.is_equal_approx(shot),"Arrow follows the warning direction")
	var facing=Vector3(sin(archer.visual.rotation.y),0,cos(archer.visual.rotation.y))
	check(facing.dot(shot)>0.98,"Archer faces the shot while strafing")
	for i in 8:world._enemy_tick(archer,0.05)
	check(world.bullets.size()==1,"Recovery does not emit duplicate arrows")
	check(archer.visual.state!="attack","Movement resumes after recoil")
	scene.queue_free();await process_frame
	print("ARCHER_ANIMATION_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
