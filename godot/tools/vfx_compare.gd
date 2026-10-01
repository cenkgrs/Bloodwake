extends SceneTree
# Capture the same effects before/after edits with a real renderer.
func _initialize():call_deferred("capture")
func capture():
	var output=OS.get_environment("VFX_SHOT_DIR")
	if output=="":output="user://vfx_compare"
	DirAccess.make_dir_recursive_absolute(output)
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("mage");await process_frame
	var w=scene.world;w.running=false;w.auto_fire=false;w.camera.size=8
	w.fx.rng.seed=42
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	for kind in ["slash","nova","orb","enemy_orb","enemy_blast","telegraph"]:
		if kind=="slash":w.fx.slash(Vector3.ZERO,Vector3.RIGHT,2.5,Color("ffc27a"))
		elif kind=="nova":w.skills._resolve_ability(BWData.entry("abilities","frost_nova"))
		elif kind in ["orb","enemy_orb"]:
			w._bullet(Vector3(2.2,0,0),Vector3.RIGHT,8,1,8,kind=="orb",0,"magic_orb" if kind=="orb" else "enemy_magic_orb",0,0,false)
			w.fx.impact(Vector3(-2,0.8,0),"magic_orb" if kind=="orb" else "enemy_magic_orb",kind=="orb")
		elif kind=="enemy_blast":w.fx.arcane_blast(Vector3.ZERO,2.7,Color("df45bc"),Color("de2851"))
		else:w.fx.telegraph(Vector3.ZERO,2.7,Color("b07dff"),0.9)
		for i in 3:
			await create_timer(0.045).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(kind+"_"+str(i)+".png"))
		await create_timer(1.1).timeout
		for b in w.bullets:b.node.queue_free()
		w.bullets.clear()
	scene.queue_free();await process_frame;quit()
