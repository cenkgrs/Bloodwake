extends SceneTree
# Every class's basic attack, held on one enemy, keeps it off its feet: once the
# first blow lands, the body does not get a swing in between the player's hits.
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	for id in ["warrior","revenant","gunslinger","mage"]:
		var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
		scene.start_run(id);await process_frame
		var w=scene.world;w.rest_time=999;w.auto_fire=true;w.arena.blockers.clear()
		w.run.stats.dodgeChance=0;w.run.stats.regenPerSecond=0;w.run.stats.lifesteal=0
		w.run.stats.maxHp=1e6;w.run.stats.hp=1e6
		for e in w.enemies:e.node.queue_free()
		w.enemies.clear();w.player.position=Vector3.ZERO
		var grunt=w.spawn_enemy("grunt",Vector3(1.2,0,0))
		grunt.hp=1e7;grunt.maxHp=1e7;grunt.cooldown=0.0;grunt.erase("rising")
		var landed=-1.0;var answered=0;var time=0.0;var hp=w.run.stats.hp
		for f in 360:
			w._physics_process(1.0/60);time+=1.0/60
			if landed<0 and grunt.hp<grunt.maxHp:landed=time
			if w.run.stats.hp<hp:
				if landed>=0:answered+=1
				hp=w.run.stats.hp
			w.enemies=w.enemies.filter(func(e):return e==grunt)
		check(landed>=0,id+": the basic attack connects")
		check(answered==0,id+": the enemy struck back "+str(answered)+" times through the attack chain (cadence "+str(w.hit_cadence)+")")
		print(id," first hit at %.2f s, struck back %d times, cadence %s"%[landed,answered,w.hit_cadence])
		scene.queue_free();await process_frame
	print("STAGGER_HOLD_TEST failures=",failures);quit(1 if failures else 0)
