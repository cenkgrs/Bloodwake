extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	var capture="--capture-intro" in OS.get_cmdline_user_args()
	var classes=["warrior"] if capture else BWData.CLASSES.keys()
	for id in classes:
		scene.begin_run(id)
		check(scene.page=="loading","Selection immediately enters transition")
		var serial=scene.transition_serial
		scene.begin_run(id)
		check(scene.transition_serial==serial,"Repeated selection does not start another run")
		var deadline=Time.get_ticks_msec()+60000
		var saw_arrival=false
		var entry=Vector3.ZERO
		var captured=false
		var arrival_started=0
		while scene.page in ["loading","arrival"] and Time.get_ticks_msec()<deadline:
			if scene.page=="arrival":
				if not saw_arrival:
					entry=scene.world.player.position;arrival_started=Time.get_ticks_msec()
					saw_arrival=true
				check(scene.world.enemies.is_empty() and scene.world.spawned==0,"No enemies during arrival")
				check(not scene.world.running and scene.world.elapsed==0,"Combat clock stays stopped")
				check(not scene.hud.visible,"HUD stays hidden for cinematic")
				if capture and not captured and Time.get_ticks_msec()-arrival_started>900:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/bw-intro-arrival.png");captured=true
			await process_frame
		check(saw_arrival and scene.page=="playing","Arrival finishes and hands over control for "+id)
		if scene.page!="playing":break
		check(scene.world.run.class_id==id and scene.world.visual.actor_kind==id,"Only selected hero enters")
		check(entry.distance_to(scene.world.player.position)>2.5,"Hero moves into the courtyard")
		check(scene.world.camera.size==BWWorld.CAMERA_SIZE,"Camera returns to gameplay framing")
		check(scene.hud.visible and scene.world.running,"HUD and simulation resume together")
		check(scene.world.enemies.is_empty(),"First enemy waits until after cinematic")
		await create_timer(1.0).timeout
		check(not scene.world.enemies.is_empty(),"First wave starts after control returns")
		scene.show_menu();await process_frame
	# Class confirmation owns its own short cinematic and only reveals the
	# safehouse after the selected model has finished loading.
	scene.show_classes();await process_frame
	scene.select_class("revenant")
	check(scene.page=="loading" and is_instance_valid(scene.run_intro),"Class confirmation opens its loading cinematic")
	var safehouse_deadline=Time.get_ticks_msec()+20000
	while scene.page=="loading" and Time.get_ticks_msec()<safehouse_deadline:await process_frame
	check(scene.page=="playing" and scene.in_safehouse(),"Class cinematic hands control to the safehouse")
	check(scene.run.class_id=="revenant" and scene.world.visual.actor_kind=="revenant","Class cinematic preserves the selected hero")
	scene.show_menu();await process_frame
	# Leaving either asynchronous phase must never revive a cancelled run.
	scene.begin_run("warrior");scene.show_menu()
	await create_timer(0.5).timeout
	check(scene.page=="menu" and scene.world==null,"Menu cancels loading safely")
	if not capture:
		scene.begin_run("mage")
		var deadline=Time.get_ticks_msec()+60000
		while scene.page=="loading" and Time.get_ticks_msec()<deadline:await process_frame
		check(scene.page=="arrival","Cancellation test reaches arrival")
		scene.show_menu();await create_timer(0.2).timeout
		check(scene.page=="menu" and scene.world==null,"Menu cancels arrival safely")
	scene.queue_free();await process_frame
	print("RUN_INTRO_TEST failures=",failures);quit(0 if failures==0 else 1)
