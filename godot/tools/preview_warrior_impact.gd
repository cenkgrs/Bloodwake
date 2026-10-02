extends SceneTree
func _initialize():call_deferred("capture")
func shot(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../art/vfx/preview/"+name+".png")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear();w.camera.size=13
	w.camera.position=Vector3(0,16,12);w.camera.look_at(Vector3.ZERO)
	for row in [["grunt",Vector3(3,0,-2)],["mage",Vector3(-4,0,-3)],["healer",Vector3(2,0,4)]]:
		w.spawn_enemy(row[0],row[1])
	for i in 8:await process_frame
	await shot("camera_current")
	w.camera.position=Vector3(12,14,16);w.camera.look_at(Vector3.ZERO)
	for i in 8:await process_frame
	await shot("camera_diagonal")
	w.camera.size=9
	w.fx.ground_impact(Vector3.ZERO,2.8)
	await create_timer(0.18).timeout;await shot("warrior_impact")
	await create_timer(0.7).timeout;await shot("warrior_settling")
	await create_timer(0.62).timeout;await shot("warrior_ground_scar")
	scene.queue_free();await process_frame;quit()
