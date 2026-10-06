extends SceneTree
# Stage-1 inspection only: direct GLB, no gameplay asset replacement.
func _initialize():call_deferred("capture")
func find_type(node,type_name):
	if node.is_class(type_name):return node
	for child in node.get_children():
		var found=find_type(child,type_name)
		if found!=null:return found
	return null
func silhouette(node,material):
	if node is MeshInstance3D:node.material_override=material
	for child in node.get_children():silhouette(child,material)
func capture():
	var args=OS.get_cmdline_user_args();var pass_name=args[0] if args.size()>0 else "spline"
	var base=ProjectSettings.globalize_path("res://../art/bloodhound_v3/stage1/"+pass_name)
	var document=GLTFDocument.new();var state=GLTFState.new()
	if document.append_from_file(base+"/Bloodhound_Stage1.glb",state)!=OK:quit(1);return
	var stage=Node3D.new();root.add_child(stage)
	var actor=document.generate_scene(state);stage.add_child(actor)
	var player=find_type(actor,"AnimationPlayer")
	var environment=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("24282c")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7
	environment.environment=env;stage.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.5;light.shadow_enabled=true;stage.add_child(light)
	var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(100,100);ground.mesh=plane
	var shader=Shader.new();shader.code="shader_type spatial; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 q=abs(fract(p.xz)-0.5); float line=smoothstep(0.48,0.495,max(q.x,q.y)); ALBEDO=mix(vec3(0.14,0.15,0.17),vec3(0.33),line); ROUGHNESS=1.0;}"
	var floor_material=ShaderMaterial.new();floor_material.shader=shader;ground.material_override=floor_material;stage.add_child(ground)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var label=Label.new();root.add_child(label);label.position=Vector2(14,14);label.add_theme_font_size_override("font_size",20)
	var modes=["normal","game","silhouette","idle"]
	if args.size()>1:modes=[args[1]]
	for mode in modes:
		var folder=base+"/preview_"+mode;DirAccess.make_dir_recursive_absolute(folder)
		var clip="BH_Idle" if mode=="idle" else "BH_AgileMove"
		var cycle=71 if mode=="idle" else 38
		var duration=player.get_animation(clip).length
		var scale_value=2.05/1.8 if mode=="game" else 1.0
		actor.scale=Vector3.ONE*scale_value;camera.size=3.3 if mode=="game" else 2.6
		if mode=="silhouette":
			var ink=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color.BLACK
			silhouette(actor,ink);env.background_color=Color("eeeeee");ground.visible=false
			label.add_theme_color_override("font_color",Color.BLACK)
		elif mode=="idle":
			silhouette(actor,null);env.background_color=Color("24282c");ground.visible=true
			label.add_theme_color_override("font_color",Color.WHITE)
		for frame in (cycle*3 if mode!="idle" else cycle):
			if args.size()>2 and frame!=int(args[2]):continue
			var local_time=float(frame%cycle)/60.0
			actor.position=Vector3.ZERO if mode in ["idle","silhouette"] else Vector3(0,0,float(frame)/60*5.0/(2.05/1.8)*scale_value)
			camera.position=actor.position+(Vector3(5,7,7) if mode=="game" else Vector3(3,2.6,5))
			camera.look_at(actor.position+Vector3.UP*(.9*scale_value))
			player.play(clip,0);player.seek(minf(duration,local_time),true);player.pause()
			label.text="%s / %s / frame %02d"%[pass_name.to_upper(),mode.to_upper(),frame%cycle+1]
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/%04d.png"%frame)
		print("STAGE1_PREVIEW ",mode)
	stage.queue_free();label.queue_free();await process_frame;quit()
