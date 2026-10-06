extends SceneTree
# Visual QA of the same right-hand anchor at rest, wind-up and release.
func _initialize():call_deferred("capture")
func capture():
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();var e=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color("101722")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_energy=0.8
	env.environment=e;stage.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-35,0);light.light_energy=1.5;stage.add_child(light)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6
	camera.position=Vector3(-2.7,2.0,4);stage.add_child(camera);camera.look_at(Vector3(0,1,0))
	var actor=BWVisual.new();stage.add_child(actor);actor.configure("mage")
	var out=ProjectSettings.globalize_path("res://../art/mage/preview")
	DirAccess.make_dir_recursive_absolute(out)
	for shot in [["Idle",0.0,"right-hand-idle"],["Attack",0.15,"right-hand-windup"],["Attack",0.55,"right-hand-release"]]:
		actor.animation.play(shot[0],0.0);actor.animation.seek(shot[1],true);actor.animation.pause()
		actor._process(0.0)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+shot[2]+".png")
	print("MAGE_HAND_PREVIEW_DONE")
	stage.queue_free();await process_frame;quit()
