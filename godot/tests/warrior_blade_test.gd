extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func arcs(w) -> Array:
	return w.fx.get_children().filter(func(n):return n.has_meta("degrees"))
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=true
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	for step in 4:
		var enemy=w.spawn_enemy("tank",w.player.position+Vector3(0,0,-0.8));enemy.hp=100000
		w.combo_step=step-1;w.combo_timer=1;w.swing_gate=0;w.run.weapons.sword.cooldown=0;w.visual.lock_time=0
		w._weapons(0.001)
		check(w.pending_attacks.size()==1,"One queued contact per combo clip")
		check(arcs(w).is_empty(),"No arc during wind-up")
		var hp=enemy.hp
		if not w.pending_attacks.is_empty():
			var delay=w.pending_attacks[0].time
			w._pending_attacks(delay-0.001)
			check(arcs(w).is_empty() and enemy.hp==hp,"No damage or VFX before contact")
			w._pending_attacks(0.002)
			check(enemy.hp<hp and arcs(w).size()==1,"Damage and VFX share contact")
			if not arcs(w).is_empty():check(arcs(w)[0].get_meta("degrees")==BWWorld.WARRIOR_BLADE_ARC,"Arc matches damage angle")
		await create_timer(0.3).timeout
		check(arcs(w).is_empty(),"Blade trail cleans up")
		w.enemies.erase(enemy);enemy.node.queue_free()
	# The cut reaches where the greatsword tip does (~2 m), across its wide front sweep.
	for a in arcs(w):a.queue_free()
	var reach=w.run.weapons.sword.data.range*w.run.stats.attackRange*BWData.UNIT
	var tip=w.spawn_enemy("tank",w.player.position+Vector3.FORWARD*reach*1.6);tip.hp=100000
	var side=w.spawn_enemy("tank",w.player.position+Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(70))*reach*1.3);side.hp=100000
	var past=w.spawn_enemy("tank",w.player.position+Vector3.FORWARD*reach*2.6);past.hp=100000
	w._resolve_weapon("sword",Vector3.FORWARD)
	check(tip.hp<100000,"The blade tip cuts at its full reach")
	check(side.hp<100000,"The cut covers the blade's wide sweep")
	check(past.hp==100000,"Nothing beyond the blade is cut")
	for e in [tip,side,past]:w.enemies.erase(e);e.node.queue_free()
	await create_timer(0.3).timeout
	w._resolve_spin("sword",Vector3.FORWARD)
	check(arcs(w).size()==1 and arcs(w)[0].get_meta("degrees")==360.0,"Spin shows full damage circle")
	scene.queue_free();await process_frame
	print("WARRIOR_BLADE_TEST failures=",failures);quit(0 if failures==0 else 1)
