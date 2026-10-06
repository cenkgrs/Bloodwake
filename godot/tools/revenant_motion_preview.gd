extends SceneTree
# Deterministic Godot footage of the actual imported clips and runtime VFX.
# Run with --fixed-fps 30 --resolution 960x720 --script tools/revenant_motion_preview.gd
func _initialize():call_deferred("capture")
func capture():
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();var e=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color("0a0d12")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("a6b5d2");e.ambient_light_energy=0.75
	env.environment=e;stage.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-38,-35,0);key.light_energy=1.5;key.shadow_enabled=true;stage.add_child(key)
	var floor_node=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(20,20);floor_node.mesh=plane
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("25232a");mat.roughness=0.95;floor_node.material_override=mat;stage.add_child(floor_node)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.6
	camera.position=Vector3(3.2,2.4,4.4);stage.add_child(camera);camera.look_at(Vector3(0,.8,.25))
	var actor=BWVisual.new();stage.add_child(actor);actor.configure("revenant")
	var fx=BWFx.new();stage.add_child(fx);fx.configure("PC")
	var reach=BWData.entry("weapons","sword").range*BWData.UNIT
	var out=ProjectSettings.globalize_path("res://../art/revenant/preview/motion")
	DirAccess.make_dir_recursive_absolute(out)
	for frame in 150:
		var clip="Idle"
		var time=frame/30.0
		if frame>=30 and frame<48:clip="Attack1";time=(frame-30)/30.0/.58
		if frame>=60 and frame<79:clip="Attack2";time=(frame-60)/30.0/.58
		if frame>=96 and frame<126:clip="Attack1";time=(frame-96)/30.0
		actor.animation.play(clip,0.0);actor.animation.seek(time,true);actor.animation.pause()
		if frame==37:fx.revenant_claws(Vector3.ZERO,Vector3.FORWARD*-1,reach)
		if frame==39:fx.revenant_impact(Vector3(.1,.9,1.2))
		if frame==67:fx.revenant_claws(Vector3.ZERO,Vector3.FORWARD*-1,reach,true)
		if frame==70:fx.revenant_impact(Vector3(-.1,.9,1.2))
		if frame==107:fx.revenant_claws(Vector3.ZERO,Vector3.FORWARD*-1,reach)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/%03d.png"%frame)
	print("REVENANT_MOTION_PREVIEW ",out)
	stage.queue_free();await process_frame;quit()
