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
	for clip in ["idle","run","attack1","attack2","dash","hit","death"]:
		check(w.visual.clips.has(clip),"Vampire clip exists: "+clip)
	check(not w.visual.clips.has("attack4"),"Warrior finisher does not leak into vampire kit")
	check(w.run.apply_upgrade("greatsword"),"Revenant receives sword upgrades")
	w.player.position=Vector3.ZERO;w.last_move=Vector3.RIGHT
	w.skills.ability();var hp=w.run.stats.hp;w._hurt_player(100)
	check(w.run.stats.hp==hp,"Dash evades damage")
	check(w.run.ability_cd>0,"Dash spends cooldown")
	check(w.visual.state=="dash","Dash plays its skeletal evade")
	w.arena.blockers.append({"pos":Vector3(1.2,0,0),"radius":0.5})
	for i in 12:w._physics_process(1.0/60)
	check(w.player.position.x<0.3,"Dash cannot cross a solid obstacle")
	check(w.dash_time==0,"Dash expires")
	w.run.stats.dodgeChance=0;w._hurt_player(10)
	check(w.run.stats.hp<hp,"Damage returns after dash")
	w.arena.blockers.clear();w.move_input=Vector2.ZERO
	w.pending_attacks.clear();w.swing_gate=0;w.visual.lock_time=0;w.combo_timer=0
	for step in 3:
		w.run.weapons.sword.cooldown=0;w.swing_gate=0;w.visual.lock_time=0
		Input.action_press("fire");w._weapons(0);Input.action_release("fire")
		check(w.visual.state==("attack1" if step%2==0 else "attack2"),"Two-hit claw chain loops correctly")
		check(w.pending_attacks.size()==1 and not w.pending_attacks[0].finisher,"Claw hit is queued without Warrior ultimate")
		w.pending_attacks.clear()
	scene.run.pending_levels=1;scene._intermission();check(scene.page=="upgrades","Reward cards render")
	scene.run.pending_levels=0;scene._next_pick();check(scene.page=="shop","Merchant renders")
	scene.queue_free();await process_frame
	print("REVENANT_TEST failures=",failures);quit(1 if failures else 0)
