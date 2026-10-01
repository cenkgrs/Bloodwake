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
	var w=scene.world;w.running=false;w.auto_fire=false;w.arena.blockers.clear()
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear();w.player.position=Vector3.ZERO
	var mage=w.spawn_enemy("mage",Vector3(0,0,-7))
	check(mage.visual.enemy_asset and not mage.visual.procedural,"Dedicated enemy mage replaces placeholder")
	for clip in ["idle","run","attack","cast","hit","death"]:check(mage.visual.clips.has(clip),"Mage clip: "+clip)
	mage.cooldown=0;w._enemy_tick(mage,0.01)
	check(mage.cast_kind=="bolt" and mage.visual.state=="attack","Bolt uses one-hand attack")
	check(w.bullets.is_empty(),"Bolt waits for casting pose")
	w._enemy_tick(mage,BWWorld.CAST_TIME+0.01)
	check(w.bullets.size()==1,"Bolt releases at contact")
	mage.cooldown=0;w._enemy_tick(mage,0.01)
	check(mage.cast_kind=="rune" and mage.visual.state=="cast","Rune uses distinct two-hand cast")
	check(w.hazards.is_empty(),"Rune waits for contact")
	w._enemy_tick(mage,BWWorld.CAST_TIME+0.01)
	check(w.hazards.size()==1,"Ground rune appears at contact")
	mage.visual.action("death")
	check(mage.visual.dead,"Mage death animation is available")
	scene.queue_free();await process_frame
	print("ENEMY_MAGE_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
