extends SceneTree
# Plays the Revenant through the real world loop (physics, input, skills, enemies)
# and saves each frame. Run with a fixed frame rate so the capture is deterministic:
#   godot --path godot --fixed-fps 30 --resolution 1280x720 --script tools/revenant_game_capture.gd -- [close|game] OUTDIR
var w
var mode="close"
var script_time=0.0

func _initialize():call_deferred("capture")

func free_space(point: Vector3,radius: float) -> bool:
	for block in w.arena.blockers:
		if point.distance_to(block.pos)<block.radius+radius:return false
	return true

func aim_at(direction: Vector3):
	# Screen-space stick that maps back to this world direction.
	var best=Vector2.RIGHT;var score=-2.0
	for i in 72:
		var stick=Vector2.RIGHT.rotated(TAU*i/72.0)
		var d=w.screen_direction(stick).normalized().dot(direction.normalized())
		if d>score:score=d;best=stick
	w.touch_aim=best

func move_toward_dir(direction: Vector3):
	var best=Vector2.RIGHT;var score=-2.0
	for i in 72:
		var stick=Vector2.RIGHT.rotated(TAU*i/72.0)
		var d=w.screen_direction(stick).normalized().dot(direction.normalized())
		if d>score:score=d;best=stick
	w.move_input=best

func foe(pos: Vector3):
	var e=w.spawn_enemy("grunt",w.arena.push_out(pos,0.5));e.hp=100000.0;e.maxHp=100000.0;e.cooldown=999;e.speed=0.0
	return e

func capture():
	var args=OS.get_cmdline_user_args()
	if args.size()>0:mode=args[0]
	var out=ProjectSettings.globalize_path("res://../art/revenant-astra-ready/deliverables/previews/game_capture_"+mode) if args.size()<2 else args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.start_run("revenant");await process_frame
	w=scene.world;w.running=true;w.auto_fire=false;w.rest_time=999
	for e in w.enemies:e.node.queue_free()
	w.enemies.clear()
	w.run.stats.dodgeChance=0;w.run.stats.criticalChance=0;w.run.stats.regenPerSecond=0
	var start=Vector3.ZERO
	for x in range(-12,10,2):
		for z in range(-12,12,2):
			var p=Vector3(x,0,z)
			if free_space(p,2.0) and free_space(p+Vector3(8,0,0),3.0) and free_space(p+Vector3(4,0,0),3.0):start=p
	w.player.position=start
	var label=Label.new();label.position=Vector2(24,660);label.add_theme_font_size_override("font_size",26);root.add_child(label)
	var fps=30.0
	var frames=int(16.5*fps)
	var dir=Vector3.RIGHT
	var target_foe=null
	for f in frames:
		var t=f/fps
		w.move_input=Vector2.ZERO;Input.action_release("fire")
		if t<1.5:label.text="REV_Idle"
		elif t<3.5:
			label.text="REV_AgileRun_InPlace (6 m/s, feet planted)";move_toward_dir(dir)
		elif t<5.6:
			label.text="Claw combo: right - left - right finisher"
			if target_foe==null:target_foe=foe(w.player.position+dir*1.4)
			aim_at(dir);Input.action_press("fire")
		elif t<7.4:
			label.text="Claw while moving: run legs + claw upper body"
			move_toward_dir(-dir if t<6.3 else Vector3.FORWARD);aim_at(dir);Input.action_press("fire")
		elif t<9.0:
			label.text="Light hits while running (upper-body additive)"
			move_toward_dir(Vector3.BACK if t<8.2 else -dir)
			if f%12==0:w._hurt_player(3)
		elif t<10.6:
			label.text="Q · REV_TeleportAttack"
			if is_equal_approx(t,9.0) or (t>=9.0 and t<9.0+1.0/fps):
				for e in w.enemies:e.node.queue_free()
				w.enemies.clear();foe(w.player.position+dir*6.6)
				aim_at(dir);w.aim=dir;w.skill(0)
		elif t<13.4:
			label.text="ULTIMATE · REV_BloodBurst"
			if t>=10.6 and t<10.6+1.0/fps:
				for i in 6:foe(w.player.position+Vector3.RIGHT.rotated(Vector3.UP,TAU*i/6.0)*2.4)
				w.run.ability_cd=0;w.ability()
		else:
			label.text="REV_Death"
			if t>=13.4 and t<13.4+1.0/fps:
				for e in w.enemies:e.node.hide()
				w.run.stats.hp=0.0
		await process_frame
		if mode=="close":
			var focus=w.player.position
			w.camera.size=4.6;w.camera.position=focus+Vector3(12,14,16)*0.5;w.camera.look_at(focus+Vector3.UP*0.75)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out+"/%04d.jpg" % f,0.9)
	print("REVENANT_GAME_CAPTURE_DONE ",out)
	Input.action_release("fire")
	quit()
