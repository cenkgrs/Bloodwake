extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false
	var last_hp=0.0;var last_damage=0.0
	for wave in [1,5,10,20,30]:
		w.run.wave=wave
		var grunt=w.spawn_enemy("grunt",Vector3.ZERO)
		check(grunt.maxHp>last_hp and grunt.damage>last_damage,"spawned enemy grows at wave "+str(wave))
		print("ENEMY_SCALE wave=",wave," grunt_hp=",grunt.maxHp," damage=",grunt.damage)
		last_hp=grunt.maxHp;last_damage=grunt.damage
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	w.run.wave=10
	var boss=w.spawn_enemy("boss",Vector3.ZERO)
	check(boss.maxHp==3240 and boss.damage==65,"first boss retains its authored balance")
	BWBoss.begin(w,boss,"summon");w._enemy_tick(boss,1.51)
	for e in w.enemies:
		if e.id=="boss":continue
		check(e.maxHp>3*60,"boss adds use wave scaling and survive a basic 60-damage hit")
	w.run.wave=20
	var next_boss=w.spawn_enemy("boss",Vector3.ZERO)
	check(next_boss.maxHp>boss.maxHp and next_boss.damage>boss.damage,"later bosses also grow")
	scene.queue_free();await process_frame
	print("ENEMY_SCALING_TEST failures=",failures);quit(failures)
