extends SceneTree
# Review the draft GLB directly without changing the shipped player model.
func _initialize():call_deferred("capture")
func find_type(node: Node,type_name: String):
	if node.is_class(type_name):return node
	for child in node.get_children():
		var result=find_type(child,type_name)
		if result!=null:return result
	return null
func capture():
	var out=ProjectSettings.globalize_path("res://../art/bloodhound_v2/qa/godot")
	DirAccess.make_dir_recursive_absolute(out)
	var document=GLTFDocument.new();var state=GLTFState.new()
	var error=document.append_from_file(ProjectSettings.globalize_path("res://../art/bloodhound_v2/work/Bloodhound_Rig_WIP.glb"),state)
	if error!=OK:push_error("Cannot load draft model");quit(1);return
	var stage=Node3D.new();root.add_child(stage)
	var actor=document.generate_scene(state);stage.add_child(actor)
	var player=find_type(actor,"AnimationPlayer") as AnimationPlayer
	var skeleton=find_type(actor,"Skeleton3D") as Skeleton3D
	if player==null or skeleton==null:push_error("No animated skeleton");quit(1);return
	var environment=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("22252b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8
	environment.environment=env;stage.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_energy=1.5;stage.add_child(light)
	var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(12,12);ground.mesh=plane
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("36383e");ground.material_override=mat;stage.add_child(ground)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.5;stage.add_child(camera)
	var report={"status":"IN_REVIEW","bone_count":skeleton.get_bone_count(),"clips":{}}
	var positions=[Vector3(0,1.3,5),Vector3(5,1.3,0),Vector3(3,2,5)]
	for clip in player.get_animation_list():
		if not String(clip).begins_with("BH_"):continue
		var animation=player.get_animation(clip);animation.loop_mode=Animation.LOOP_NONE
		var sheet=Image.create(8*256,3*256,false,Image.FORMAT_RGB8)
		var change=0.0;var baseline=[]
		for angle in 3:
			camera.position=positions[angle];camera.look_at(Vector3(0,.85,0))
			for shot in 8:
				player.play(clip,0);player.seek(animation.length*shot/7.0,true);player.pause()
				await process_frame
				if angle==0:
					for b in skeleton.get_bone_count():
						var pose=skeleton.get_bone_global_pose(b)
						if shot==0:baseline.append(pose)
						else:change=maxf(change,pose.origin.distance_to(baseline[b].origin))
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					var image=root.get_texture().get_image();image.resize(256,256);image.convert(Image.FORMAT_RGB8)
					sheet.blit_rect(image,Rect2i(0,0,256,256),Vector2i(shot*256,angle*256))
		if DisplayServer.get_name()!="headless":sheet.save_png(out+"/"+String(clip)+".png")
		report.clips[String(clip)]={"duration":animation.length,"max_joint_displacement":change}
		print("BH_REVIEW ",clip," duration=",animation.length," joint_change=",change)
	var file=FileAccess.open(out+"/runtime_review.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	stage.queue_free();await process_frame;quit()
