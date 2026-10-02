extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var world=scene.world;world.running=false;world.auto_fire=false
	for enemy in world.enemies:enemy.node.queue_free()
	world.enemies.clear()
	world.player.position=Vector3(-2,0,0)
	var enemy=world.spawn_enemy("tank",Vector3(1,0,0))
	enemy.visual.rotation.y=-PI/2
	world.camera.size=6
	for pose in ["idle","attack","death"]:
		enemy.visual.animation.play(enemy.visual.clips[pose])
		enemy.visual.animation.seek(1.15 if pose=="attack" else 1.7 if pose=="death" else 0.1,true)
		enemy.visual.animation.pause()
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../art/enemies/preview/tank_"+pose+"_ingame.png")
	scene.queue_free();await process_frame;quit()
