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
var cinematic: TextureRect
var cinematic_material: ShaderMaterial
var cinematic_started = 0.0
const WALK_SECONDS = 1.8
const INTRO_SECONDS = 3.8
const CINEMATIC_SECONDS = 4.1
const CINEMATICS={
	"revenant":[preload("res://assets/ui/loading_cinematics/revenant_triptych.png"),preload("res://assets/ui/loading_cinematics/revenant_triptych_2.png")],
	"warrior":[preload("res://assets/ui/loading_cinematics/warrior_triptych.png"),preload("res://assets/ui/loading_cinematics/warrior_triptych_2.png")],
	"gunslinger":[preload("res://assets/ui/loading_cinematics/gunslinger_triptych.png"),preload("res://assets/ui/loading_cinematics/gunslinger_triptych_2.png")],
	"mage":[preload("res://assets/ui/loading_cinematics/mage_triptych.png"),preload("res://assets/ui/loading_cinematics/mage_triptych_2.png")],
	"assassin":[preload("res://assets/ui/loading_cinematics/assassin_triptych.png"),preload("res://assets/ui/loading_cinematics/assassin_triptych_2.png")]}
const CINEMATIC_LINES={
	"revenant":"BECOMING THE MIST",
	"warrior":"STEEL ANSWERS STEEL",
	"gunslinger":"THE HUNT IS LOADED",
	"mage":"THE VOID TAKES SHAPE",
	"assassin":"THE SHADOW MOVES"}

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	curtain=ColorRect.new();curtain.color=Color("080b12")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(curtain)
	curtain.modulate.a=0.0
	cinematic=TextureRect.new();cinematic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;cinematic.stretch_mode=TextureRect.STRETCH_SCALE
	cinematic.mouse_filter=Control.MOUSE_FILTER_IGNORE;cinematic.modulate.a=0.0;add_child(cinematic)
	var cinematic_shader=Shader.new();cinematic_shader.code="""
shader_type canvas_item;
uniform float sequence = 0.0;
uniform float pulse = 0.0;
uniform float viewport_aspect = 1.6;
uniform sampler2D source_texture_a : source_color;
uniform sampler2D source_texture_b : source_color;

vec4 frame_sample(float index, vec2 frame_uv) {
	float atlas_index = mod(index, 3.0);
	vec2 atlas_uv = vec2((frame_uv.x + atlas_index) / 3.0, frame_uv.y);
	if (index < 3.0) return texture(source_texture_a, atlas_uv);
	return texture(source_texture_b, atlas_uv);
}

vec4 panel(float index, vec2 uv) {
	float frame_aspect = 0.5;
	float content_height = 0.82;
	float content_width = min(1.0, content_height * frame_aspect / viewport_aspect);
	vec2 backdrop_uv = vec2(uv.x, (uv.y - 0.5) * frame_aspect / viewport_aspect + 0.5);
	vec4 backdrop = frame_sample(index, backdrop_uv);
	backdrop.rgb *= vec3(0.12, 0.075, 0.08);
	vec2 local_uv = vec2((uv.x - 0.5) / content_width + 0.5, (uv.y - 0.5) / content_height + 0.5);
	if (local_uv.x < 0.0 || local_uv.x > 1.0 || local_uv.y < 0.0 || local_uv.y > 1.0) return backdrop;
	float zoom = 1.0 + 0.018 * pulse;
	local_uv = (local_uv - 0.5) / zoom + 0.5;
	vec4 color = frame_sample(index, local_uv);
	float vignette = smoothstep(0.78, 0.22, distance(local_uv, vec2(0.5)));
	color.rgb *= 0.58 + 0.42 * vignette;
	float edge = smoothstep(0.0, 0.045, local_uv.x) * smoothstep(0.0, 0.045, 1.0 - local_uv.x);
	edge *= smoothstep(0.0, 0.035, local_uv.y) * smoothstep(0.0, 0.035, 1.0 - local_uv.y);
	return mix(backdrop, color, edge);
}

void fragment() {
	float at = mod(sequence, 6.0);
	float first = floor(at);
	float second = mod(first + 1.0, 6.0);
	float blend = smoothstep(0.18, 0.82, fract(at));
	COLOR = mix(panel(first, UV), panel(second, UV), blend);
}
"""
	cinematic_material=ShaderMaterial.new();cinematic_material.shader=cinematic_shader
	cinematic.material=cinematic_material
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
	if cinematic.visible and cinematic_material:
		var elapsed=maxf(0.0,clock-cinematic_started)
		cinematic_material.set_shader_parameter("sequence",fmod(elapsed/0.72,6.0))
		cinematic_material.set_shader_parameter("pulse",0.5+0.5*sin(elapsed*1.7))
		cinematic_material.set_shader_parameter("viewport_aspect",get_viewport_rect().size.aspect())
	if is_instance_valid(detail) and progress.visible:detail.modulate.a=0.65+0.25*sin(clock*2.5)

func close_screen(id: String) -> bool:
	var frames: Array=CINEMATICS.get(id,[])
	cinematic.texture=frames[0] if frames.size()==2 else null
	cinematic.visible=cinematic.texture!=null
	if cinematic.visible:
		cinematic_material.set_shader_parameter("source_texture_a",frames[0])
		cinematic_material.set_shader_parameter("source_texture_b",frames[1])
	cinematic_started=clock
	caption.text=BWData.CLASSES[id].name.to_upper()
	detail.text=CINEMATIC_LINES.get(id,"THE NIGHT AWAITS")
	caption.anchor_top=0.88;caption.anchor_bottom=0.88
	caption.offset_top=-4;caption.offset_bottom=48
	detail.anchor_top=0.88;detail.anchor_bottom=0.88
	detail.offset_top=48;detail.offset_bottom=76
	progress.anchor_top=0.88;progress.anchor_bottom=0.88
	progress.offset_top=82;progress.offset_bottom=85
	var elapsed=0.0
	while elapsed<0.35:
		await get_tree().process_frame
		if cancelled:return false
		elapsed+=get_process_delta_time()
		curtain.modulate.a=minf(1,elapsed/0.35)
		cinematic.modulate.a=curtain.modulate.a
		top_bar.modulate.a=curtain.modulate.a;bottom_bar.modulate.a=curtain.modulate.a
		caption.modulate.a=curtain.modulate.a;detail.modulate.a=curtain.modulate.a;progress.modulate.a=curtain.modulate.a
	return true

func wait_for_cinematic() -> bool:
	while clock-cinematic_started<CINEMATIC_SECONDS:
		await get_tree().process_frame
		if cancelled:return false
	return true

func dismiss() -> bool:
	var elapsed=0.0
	while elapsed<0.45:
		await get_tree().process_frame
		if cancelled:return false
		elapsed+=get_process_delta_time()
		modulate.a=1.0-smoothstep(0.0,0.45,elapsed)
	return true

func prepare_safehouse(id: String) -> bool:
	var hall=BWRooms.safehouse()
	if hall.is_empty():return false
	var paths: Array[String]=[
		"res://assets/models/%s.glb" % BWVisual.player_model(id)]
	var hall_scene=String(hall.get("scene",""))
	if ResourceLoader.exists(hall_scene):paths.append(hall_scene)
	return await _prepare_paths(paths,[BWVisual.player_model(id)],100.0)

# Everything the first seconds of the hunt touch. A map only needs its first
# room's scene, when one has been delivered; the open field needs its props.
func prepare(id: String,map_id: String="") -> bool:
	var paths: Array[String]=["res://assets/art/arena.png"]
	var player_file=BWVisual.player_model(id)
	var models=BWVisual.ENEMY_MODELS.duplicate();models.append(player_file)
	for file in models:paths.append("res://assets/models/%s.glb" % file)
	var map_row=BWRooms.map(map_id) if not map_id.is_empty() else {}
	if map_row.is_empty():
		for spec in BWArena.PROPS.values():
			if not String(spec.mesh).is_empty() and not paths.has(spec.mesh):paths.append(spec.mesh)
	else:
		var plan=BWRooms.night_plan(map_row)
		var first=BWRooms.room(plan[0]) if not plan.is_empty() else {}
		if ResourceLoader.exists(String(first.get("scene",""))):paths.append(first.scene)
	return await _prepare_paths(paths,models,80.0)

func _prepare_paths(paths: Array[String],models: Array,max_progress: float) -> bool:
	for index in paths.size():
		if cancelled:return false
		var path=paths[index]
		if path.is_empty():continue
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
		progress.value=max_progress*float(index+1)/paths.size()
		await get_tree().process_frame
	return not cancelled

func arrival(w: BWWorld) -> bool:
	progress.hide();detail.hide()
	var room_mode=not w.room.is_empty()
	caption.text=w.room.name if room_mode else "THE COURTYARD"
	caption.anchor_top=0.88;caption.anchor_bottom=0.88
	caption.offset_top=10;caption.offset_bottom=62
	caption.add_theme_font_size_override("font_size",26)
	# The courtyard's central clearing holds the whole entrance path. A room is
	# entered for real: through its entrance and up to its EntrySpawn.
	var heading=w.screen_direction(Vector2.UP).normalized()
	var entry=-heading*3.2
	var stop=Vector3.ZERO
	if room_mode:
		stop=w.arena.marker("EntrySpawn")
		entry=w.arena.clamp_inside(w.arena.marker("EntranceDoor",stop))
		heading=(stop-entry).normalized() if stop.distance_to(entry)>0.1 else Vector3.FORWARD
	w.player.position=entry;w.last_move=heading;w.aim=heading
	w.visual.rotation.y=atan2(heading.x,heading.z)
	w.set_physics_process(false)
	var elapsed=0.0
	while elapsed<INTRO_SECONDS:
		if cancelled or not is_instance_valid(w):return false
		var dt=get_process_delta_time()
		elapsed+=dt
		var walking=elapsed<WALK_SECONDS
		w.player.position=w.arena.push_out(entry.lerp(stop,clampf(elapsed/WALK_SECONDS,0,1)),0.42)
		w.visual.tick(dt,walking,0.55)
		var pullback=smoothstep(1.7,INTRO_SECONDS,elapsed)
		w.camera.size=lerpf(7.2,minf(BWWorld.CAMERA_SIZE,w.max_camera_size()),pullback)
		var focus=w.player.position.lerp(w.camera_focus(w.player.position),pullback)
		w.camera.position=focus+w.camera_offset+Vector3.UP*(1.0-pullback)
		w.camera.look_at(focus+Vector3.UP*(0.85*(1.0-pullback)))
		curtain.modulate.a=1.0-smoothstep(0.0,0.65,elapsed)
		var bars=1.0-smoothstep(2.8,INTRO_SECONDS,elapsed)
		top_bar.modulate.a=bars;bottom_bar.modulate.a=bars;caption.modulate.a=bars
		await get_tree().process_frame
	if cancelled or not is_instance_valid(w):return false
	w.camera.size=minf(BWWorld.CAMERA_SIZE,w.max_camera_size())
	var rest=w.camera_focus(w.player.position)
	w.camera.position=rest+w.camera_offset
	w.camera.look_at(rest)
	w.visual.tick(0,false);w.player_velocity=Vector3.ZERO
	w.move_input=Vector2.ZERO;w.fire_input=false
	# The walk in was the quiet; the doors shut half a second after control returns.
	if room_mode:w.rest_time=0.5
	else:w.spawn_timer=0.8
	w.set_physics_process(true)
	return true
