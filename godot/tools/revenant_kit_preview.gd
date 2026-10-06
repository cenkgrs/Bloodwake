extends SceneTree
# Actual imported animations + actual Q/ultimate dispatch, 30 fps review capture.
func _initialize():call_deferred("capture")
func free_space(w,point: Vector3,radius: float) -> bool:
	for block in w.arena.blockers:
		if point.distance_to(block.pos)<block.radius+radius:return false
	return true
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("revenant");await process_frame
	var w=scene.world;w.set_physics_process(false);w.running=true;w.auto_fire=false;w.rest_time=0
	for foe in w.enemies:foe.node.queue_free()
	w.enemies.clear()
	w.player.position=w.arena.push_out(Vector3.ZERO,0.42);w.run.stats.dodgeChance=0;w.run.stats.criticalChance=0
	var chosen=false
	for x in range(-15,12,3):
		for z in range(-15,16,3):
			var point=Vector3(x,0,z)
			if not chosen and free_space(w,point,1.5) and free_space(w,point+Vector3.RIGHT*6,3.7):
				w.player.position=point;chosen=true
	var launch=w.player.position
	w.camera.size=5.0;w.camera.position=launch+Vector3(3.2,3.3,4.4);w.camera.look_at(launch+Vector3(0,.8,0))
	w.visual.rotation.y=.25
	var title=Label.new();title.position=Vector2(24,850);title.add_theme_font_size_override("font_size",24);root.add_child(title)
	var out=ProjectSettings.globalize_path("res://../art/revenant/preview/kit_review")
	DirAccess.make_dir_recursive_absolute(out)
	for f in 480:
		if f<75:
			title.text="IDLE · sakin duruş";w.visual.animation.play("Idle",0.0);w.visual.animation.seek(f/30.0,true);w.visual.animation.pause()
		elif f<165:
			title.text="WALK · tempolu ilerleyiş"
			w.visual.animation.play("Run",0.0);w.visual.animation.seek(fmod((f-75)/30.0/.72,1.0),true);w.visual.animation.pause()
		elif f<210:
			title.text="GET HIT · kan tepkisi"
			if f==165:w.visual.lock_time=0;w._hurt_player(5)
			w.visual.tick(1.0/30,false)
		elif f<300:
			title.text="Q · Blood Step"
			if f==210:
				w.camera.size=11.5;w.camera.position=launch+Vector3(4.8,8,7);w.camera.look_at(launch+Vector3(3,0,0))
				w.touch_aim=Vector2.RIGHT;w.aim=Vector3.RIGHT
				var target=w.skills.blood_step_destination(w.ground_target(6),6)
				var foe=w.spawn_enemy("grunt",w.arena.push_out(target+Vector3(1.7,0,0),0.5));foe.hp=10000;foe.cooldown=999
				w.skill(0)
			w.visual.tick(1.0/30,false)
		elif f<390:
			title.text="ULTIMATE · Blood Burst"
			if f==300:
				w.camera.size=10;w.camera.position=w.player.position+Vector3(3.2,6,6);w.camera.look_at(w.player.position+Vector3.UP*.5)
				w.run.ability_cd=0;w.ability()
			w.visual.tick(1.0/30,false)
		else:
			title.text="DEATH · kana dağılma"
			if f==390:
				w.camera.size=5;w.camera.position=w.player.position+Vector3(3.2,3.3,4.4);w.camera.look_at(w.player.position+Vector3.UP*.6)
				for foe in w.enemies:foe.node.hide()
				w.visual.action("death");w.fx.revenant_death(w.player.position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out+"/%03d.jpg"%f,0.9)
	print("REVENANT_KIT_PREVIEW_DONE ",out)
	scene.queue_free();title.queue_free();await process_frame;quit()
