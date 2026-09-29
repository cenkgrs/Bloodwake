extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	await process_frame
	scene.start_run("warrior");await process_frame
	var world=scene.world;world.running=false;world.auto_fire=false
	world.player.position=Vector3(2.5,0,3.5)
	world.camera.position=Vector3(0,15,12);world.camera.look_at(Vector3(0,0,1))
	var boss=world.spawn_enemy("boss",Vector3(0,0,-1))
	if "--play" in OS.get_cmdline_user_args():
		scene.run.wave=10;world.spawned=BWData.wave_rules(10).quota
		world.running=true;world.wave_music()
		return
	boss.visual.animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for attack in ["slam","charge","cast","summon"]:
		boss.visual.lock_time=0;BWBoss.begin(world,boss,attack)
		var time: float=BWBoss.ATTACKS[attack].windup*0.72
		boss.visual.animation.advance(time);world._enemy_tick(boss,time)
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../art/enemies/preview/boss_"+attack+".png")
		BWBoss.clear_warning(boss)
	scene.queue_free();await process_frame;quit()
