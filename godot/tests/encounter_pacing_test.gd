extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("mage");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false;w.arena.blockers.clear()
	for wave in [1,2,3,4,9,11,25]:
		for e in w.enemies:e.node.queue_free()
		w.enemies.clear();w.run.wave=wave;w.spawned=0;w.spawn_timer=0
		for i in 20:w._spawn_tick(1.0)
		var ids=[]
		for e in w.enemies:ids.append(e.id)
		check(ids==BWData.wave_roster(wave),"Exact authored five-enemy roster: "+str(wave))
		check(w.enemies.size()==5,"Five-enemy cap")
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	var boss=w.spawn_enemy("boss",Vector3(0,0,-5))
	for i in 3:BWBoss.begin(w,boss,"summon");w._enemy_tick(boss,1.51)
	check(w.enemies.size()==5,"Repeated boss summons respect cap including boss")
	w.visual.animation.play(w.visual.clips.attack);w.visual.animation.seek(w.visual.clip_length("attack")*0.55,true)
	check(w.visual.hand_magic.get_node_or_null("ArcaneOrb/Motes")!=null,"Held orb uses projectile shell and core")
	check(w.visual.hand_magic.get_node("ArcaneOrb").get_child(0).material_override.albedo_texture!=null,"Held orb halo has its soft alpha texture")
	check(w.visual.hand_skeleton.get_bone_name(w.visual.hand_bone).ends_with("LeftHand"),"Player orb follows casting hand")
	var grunt=w.enemies.filter(func(e):return e.id=="grunt")[0]
	check(is_equal_approx(grunt.visual.clip_length("run")/grunt.visual.clip_speed("run"),1.0),"Enemy warrior gait is slowed independently")
	check(grunt.speed==90.0,"Gait change preserves movement speed")
	for pair in [["grunt",42.0],["archer",26.0],["tank",120.0],["assassin",30.0],["mage",32.0],["healer",34.0],["commander",72.0],["boss",2700.0]]:
		check(is_equal_approx(BWData.entry("enemies",pair[0]).maxHp,pair[1]*1.2),"Twenty percent health increase: "+pair[0])
	var palm=w.visual.magic_palm_position()
	w._resolve_weapon("magic_orb",Vector3.FORWARD)
	check(w.bullets.back().node.position.distance_to(palm)<0.001,"Mage projectile starts at current casting palm")
	check(w.bullets.back().remaining==10.0 and w.bullets.back().speed==9.0,"Mage has ten-metre reach and faster projectile")
	check(w.run.weapons.magic_orb.data.attacksPerSecond==1.8,"Mage casts twice as often")
	scene.queue_free();await process_frame
	print("ENCOUNTER_PACING_TEST failures=",failures);quit(0 if failures==0 else 1)
