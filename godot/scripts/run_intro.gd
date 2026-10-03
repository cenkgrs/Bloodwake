extends Control

# Own the curtain and strong resource references until the world is ready.
# Loading polls yield every frame; scene-tree construction stays on the main thread.
var cancelled = false
var resources: Array[Resource] = []
var curtain: ColorRect
var caption: Label
var detail: Label
var progress: ProgressBar
var top_bar: ColorRect
var bottom_bar: ColorRect
var clock = 0.0
const WALK_SECONDS = 1.8
const INTRO_SECONDS = 3.8

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	curtain=ColorRect.new();curtain.color=Color("080b12")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(curtain)
	curtain.modulate.a=0.0
	for bottom in [false,true]:
		var bar=ColorRect.new();bar.color=Color("080b12");bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		if bottom:bar.anchor_top=0.88
		else:bar.anchor_bottom=0.12
		bar.modulate.a=0;add_child(bar)
		if bottom:bottom_bar=bar
		else:top_bar=bar
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caption.offset_left=-420;caption.offset_right=420;caption.offset_top=-50;caption.offset_bottom=12
	caption.add_theme_font_override("font",BWKit.title_font());caption.add_theme_font_size_override("font_size",38)
	caption.add_theme_color_override("font_color",BWKit.GOLD);caption.modulate.a=0;add_child(caption)
	detail=Label.new();detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	detail.offset_left=-420;detail.offset_right=420;detail.offset_top=26;detail.offset_bottom=52
	detail.text="THE NIGHT AWAITS";detail.add_theme_font_size_override("font_size",14)
	detail.modulate.a=0;add_child(detail)
	progress=ProgressBar.new();progress.show_percentage=false
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	progress.offset_left=-140;progress.offset_right=140;progress.offset_top=74;progress.offset_bottom=77
	progress.modulate.a=0;add_child(progress)

func _process(dt: float):
	clock+=dt
	if is_instance_valid(detail) and progress.visible:detail.modulate.a=0.65+0.25*sin(clock*2.5)

func close_screen(id: String) -> bool:
	caption.text=BWData.CLASSES[id].name.to_upper()
	var elapsed=0.0
	while elapsed<0.35:
		await get_tree().process_frame
		if cancelled:return false
		elapsed+=get_process_delta_time()
		curtain.modulate.a=minf(1,elapsed/0.35)
		caption.modulate.a=curtain.modulate.a;progress.modulate.a=curtain.modulate.a
	return true

func prepare(id: String) -> bool:
	var paths: Array[String]=["res://assets/art/arena.png"]
	var player_file=BWVisual.player_model(id)
	var models=BWVisual.ENEMY_MODELS.duplicate();models.append(player_file)
	for file in models:paths.append("res://assets/models/%s.glb" % file)
	for spec in BWArena.PROPS.values():
		if not String(spec.mesh).is_empty() and not paths.has(spec.mesh):paths.append(spec.mesh)
	for index in paths.size():
		if cancelled:return false
		var path=paths[index]
		if ResourceLoader.load_threaded_request(path)!=OK:return false
		while true:
			var status=ResourceLoader.load_threaded_get_status(path)
			if status==ResourceLoader.THREAD_LOAD_LOADED:break
			if status!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:return false
			await get_tree().process_frame
			if cancelled:return false
		var resource=ResourceLoader.load_threaded_get(path)
		if resource==null:return false
		resources.append(resource)
		if path.begins_with("res://assets/models/") and path.get_file().get_basename() in models:
			BWVisual.model_scenes[path.get_file().get_basename()]=resource
		progress.value=80.0*float(index+1)/paths.size()
		await get_tree().process_frame
	return not cancelled

func arrival(w: BWWorld) -> bool:
	progress.hide();detail.hide()
	caption.text="THE COURTYARD"
	caption.anchor_top=0.88;caption.anchor_bottom=0.88
	caption.offset_top=10;caption.offset_bottom=62
	caption.add_theme_font_size_override("font_size",26)
	# The courtyard's central clearing holds the whole entrance path.
	var heading=w.screen_direction(Vector2.UP).normalized()
	var entry=-heading*3.2
	w.player.position=entry;w.last_move=heading;w.aim=heading
	w.visual.rotation.y=atan2(heading.x,heading.z)
	w.set_physics_process(false)
	var elapsed=0.0
	while elapsed<INTRO_SECONDS:
		if cancelled or not is_instance_valid(w):return false
		var dt=get_process_delta_time()
		elapsed+=dt
		var walking=elapsed<WALK_SECONDS
		w.player.position=w.arena.push_out(entry.lerp(Vector3.ZERO,clampf(elapsed/WALK_SECONDS,0,1)),0.42)
		w.visual.tick(dt,walking,0.55)
		var pullback=smoothstep(1.7,INTRO_SECONDS,elapsed)
		w.camera.size=lerpf(7.2,BWWorld.CAMERA_SIZE,pullback)
		w.camera.position=w.player.position+BWWorld.CAMERA_OFFSET+Vector3.UP*(1.0-pullback)
		w.camera.look_at(w.player.position+Vector3.UP*(0.85*(1.0-pullback)))
		curtain.modulate.a=1.0-smoothstep(0.0,0.65,elapsed)
		var bars=1.0-smoothstep(2.8,INTRO_SECONDS,elapsed)
		top_bar.modulate.a=bars;bottom_bar.modulate.a=bars;caption.modulate.a=bars
		await get_tree().process_frame
	if cancelled or not is_instance_valid(w):return false
	w.camera.position=w.player.position+BWWorld.CAMERA_OFFSET
	w.camera.look_at(w.player.position);w.camera.size=BWWorld.CAMERA_SIZE
	w.visual.tick(0,false);w.player_velocity=Vector3.ZERO
	w.move_input=Vector2.ZERO;w.fire_input=false
	w.spawn_timer=0.8
	w.set_physics_process(true)
	return true
