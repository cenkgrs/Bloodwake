extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("revenant");await process_frame
	var w=scene.world;w.auto_fire=false;w.running=true;w.rest_time=999;w.arena.blockers.clear()
	check(w.visual.model.scene_file_path.ends_with("revenant_player.glb"),"Revenant loads its own vampire mesh")
	for clip in ["idle","run","attack1","attack2","teleport","ultimate","hit","death"]:
		check(w.visual.clips.has(clip),"Vampire clip exists: "+clip)
	check(not w.visual.clips.has("attack4"),"Warrior finisher does not leak into vampire kit")
	check(w.run.apply_upgrade("greatsword"),"Revenant receives sword upgrades")
	check(BWData.skills("revenant")[0]=="blood_step","Q is Blood Step")
	check(BWData.CLASSES.revenant.ability=="blood_burst","Ultimate is Blood Burst")
	w.arena.blockers.clear();w.move_input=Vector2.ZERO
	w.pending_attacks.clear();w.swing_gate=0;w.visual.lock_time=0;w.combo_timer=0
	for step in 4:
		w.run.weapons.sword.cooldown=0;w.swing_gate=0;w.visual.lock_time=0
		Input.action_press("fire");w._weapons(0);Input.action_release("fire")
		check(w.visual.state==["attack1","attack2","attack3"][step%3],"Right-left-right claw chain loops correctly")
		check(w.visual.lock_time>=0.45,"Base lunge is not crushed into a 300 ms clip")
		check(w.pending_attacks.size()==1 and not w.pending_attacks[0].finisher,"Claw hit is queued without Warrior ultimate")
		if w.pending_attacks.size()==1:
			var clip=["attack1","attack2","attack3"][step%3]
			var contact=BWVisual.revenant_time(clip,"damage")/w.visual.clip_length(clip)
			check(is_equal_approx(w.pending_attacks[0].time,w.visual.lock_time*contact),"Damage follows the authored lunge contact")
		w.pending_attacks.clear()
	scene.run.pending_levels=1;scene._intermission();check(scene.page=="upgrades","Reward cards render")
	scene.run.pending_levels=0;scene._next_pick();check(scene.page=="shop","Merchant renders")
	scene.queue_free();await process_frame
	print("REVENANT_TEST failures=",failures);quit(1 if failures else 0)
