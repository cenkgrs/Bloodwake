extends SceneTree
# Real BWWorld, runtime asset, input movement, skill dispatch and damage paths.
# --fixed-fps 60 --resolution 960x720 --script tools/bloodhound_game_preview.gd
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://bloodhound_preview_progression.json"
	scene.start_run("gunslinger");await process_frame
	var w=scene.world;var run=scene.run
	w.set_physics_process(false);w.running=true;w.rest_time=999;w.auto_fire=false
	run.stats.dodgeChance=0;run.stats.armor=0;run.stats.regenPerSecond=0
	w.player.position=Vector3.ZERO;w.last_move=Vector3.BACK;w.aim=Vector3.BACK
	var victim=w.spawn_enemy("tank",Vector3(0,0,4));victim.speed=0;victim.cooldown=999;victim.hp=1e5;victim.maxHp=1e5
	var label=Label.new();scene.root.add_child(label);label.position=Vector2(24,110);label.add_theme_font_size_override("font_size",26)
	var out=ProjectSettings.globalize_path("res://../art/bloodhound_v2/qa/gameplay")
	DirAccess.make_dir_recursive_absolute(out)
	var log=[]
	w.bloodhound_event.connect(func(event):log.append({"event":event,"time":w.elapsed}))
	for frame in 660:
		match frame:
			0:label.text="NEW MODEL / IDLE"
			60:label.text="WALK / actual input";Input.action_press("move_up",0.4)
			150:
				Input.action_release("move_up");w.visual.lock_time=0
				victim.node.position=w.player.position+Vector3(0,0,4)
				w.auto_fire=true;run.weapons.rapid_rifle.cooldown=0;w._weapons(0);w.auto_fire=false
				label.text="FIVE SHOT / 5 triggers, 6 barrels"
			225:label.text="GET HIT";w._hurt_player(5)
			270:
				label.text="BOMB THROW / release frame 20"
				w.visual.lock_time=0;w.skill(1)
			360:
				label.text="BLOODWAKE / 360-degree salvos"
				w.visual.lock_time=0;w.ability()
			480:
				label.text="MOVING SHOT / actual input";Input.action_press("move_right",0.3)
				w.visual.lock_time=0;w.auto_fire=true;run.weapons.rapid_rifle.cooldown=0;w._weapons(0);w.auto_fire=false
			540:Input.action_release("move_right")
			570:label.text="DEATH";w._hurt_player(1e5)
		w._physics_process(1.0/60.0)
		# Keep the actual arena camera direction but move closer for QA readability.
		w.camera.position=w.player.position+Vector3(5,7,7)
		w.camera.look_at(w.player.position+Vector3.UP*0.8);w.camera.size=8
		await process_frame
		if frame%2==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/%04d.png"%(frame/2))
	var file=FileAccess.open(out+"/events.json",FileAccess.WRITE);file.store_string(JSON.stringify(log,"\t"));file.close()
	scene.queue_free();await process_frame;print("BLOODHOUND_GAME_CAPTURE ",out);quit()
