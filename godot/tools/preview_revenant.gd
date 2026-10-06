extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.class_pick="revenant";scene.show_classes()
	await create_timer(0.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../art/revenant/preview/class.png")
	scene.start_run("revenant");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false;w.set_physics_process(false)
	w.camera.size=7.0;w.visual.rotation.y=0.45
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../art/revenant/preview/game.png")
	w.visual.animation.play("Attack1",0.0)
	w.visual.animation.seek(w.visual.clip_length("attack1")*0.38,true);w.visual.animation.pause()
	var direction=Vector3.FORWARD.rotated(Vector3.UP,0.45)*-1
	w.fx.revenant_claws(w.player.position,direction,BWData.entry("weapons","sword").range*BWData.UNIT)
	await create_timer(0.09).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../art/revenant/preview/attack.png")
	scene.queue_free();await process_frame;quit()
