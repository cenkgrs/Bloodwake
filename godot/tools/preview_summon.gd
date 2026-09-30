extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;Engine.max_fps=60
	w.player.position=w.arena.push_out(Vector3(-10,0,4),0.42)
	w.camera.position=Vector3(-10,16,14);w.camera.look_at(Vector3(-10,0,2))
	var boss=w.spawn_enemy("boss",w.arena.push_out(Vector3(-10,0,-5),0.9))
	BWBoss.begin(w,boss,"summon");w._enemy_tick(boss,1.51)
	for e in w.enemies:
		e.visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for frame in 190:
		await process_frame
		for e in w.enemies:
			if e.id!="boss":w._enemy_tick(e,1.0/60.0);e.visual.animation.advance(1.0/60.0)
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../art/enemies/preview/boss_summon_flanks.png")
	scene.queue_free();await process_frame;quit()
