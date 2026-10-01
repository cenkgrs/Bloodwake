extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func impacts(fx: Node) -> int:
	var count=0
	for child in fx.get_children():
		if child.name.to_lower().begins_with("groundimpact"):count+=1
	return count
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=true
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear();w.spawn_enemy("tank",Vector3(0.8,0,0))
	w.combo_step=2;w.combo_timer=1.0;w.swing_gate=0;w.run.weapons.sword.cooldown=0;w.visual.lock_time=0
	w._weapons(0.01)
	check(impacts(w.fx)==0,"Finisher ground effect waits for contact")
	check(w.pending_attacks.size()==1,"Finisher queues one contact")
	if not w.pending_attacks.is_empty():w._pending_attacks(w.pending_attacks[0].time+0.001)
	check(impacts(w.fx)==1,"Finisher contact emits ground impact")
	await create_timer(1.25).timeout
	check(impacts(w.fx)==1,"Scar persists beyond one second")
	await create_timer(0.8).timeout
	check(impacts(w.fx)==0,"Impact cleans up by two seconds")
	scene.queue_free();await process_frame
	print("WARRIOR_GROUND_TEST failures=",failures);quit(0 if failures==0 else 1)
