extends SceneTree
func _initialize():call_deferred("capture")
func capture():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("warrior");await process_frame
	var w=scene.world;w.running=false;w.arena.visible=false
	var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(30,30);floor.mesh=plane
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("202936");mat.roughness=1.0;floor.material_override=mat
	w.add_child(floor);floor.position=Vector3(-8,-0.01,0)
	w.player.position=Vector3(-8,0,0)
	w.camera.position=Vector3(-8,12,11);w.camera.look_at(Vector3(-8,0,0));w.camera.size=12
	var normal=w.spawn_enemy("grunt",Vector3(-5.3,0,0))
	var elite=w.spawn_enemy("grunt",Vector3(-10.7,0,0),true)
	for level in [1,11]:
		w.run.level=level;w.visual.set_level_scale(BWData.actor_growth(level))
		for e in [normal,elite]:e.visual.set_level_scale(BWData.actor_growth(level))
		for frame in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../art/enemies/preview/actor_sizes_level_"+str(level)+".png")
	scene.queue_free();await process_frame;quit()
