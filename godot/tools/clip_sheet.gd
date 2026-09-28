extends Node

# Renders every clip of a player rig as a strip of frames, so an animation can be
# looked at instead of guessed at. Writes one PNG per clip to user://clip_sheets.
#
#   godot --path godot tools/clip_sheet.tscn
#
# Needs a real display; the headless renderer draws nothing.

const SHOTS = 8
const SIZE = Vector2i(300, 380)
const CLIPS = ["Idle", "Attack", "Attack1", "Attack2", "Attack3", "Attack4", "SpinAttack", "SunderLeap"]

var out := ""

func _ready():
	out = ProjectSettings.globalize_path("user://clip_sheets")
	DirAccess.make_dir_recursive_absolute(out)
	var view = SubViewport.new()
	view.own_world_3d = true
	view.size = SIZE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10161d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fb0c6")
	environment.ambient_light_energy = 1.0
	env.environment = environment
	view.add_child(env)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -40, 0)
	key.light_energy = 1.6
	view.add_child(key)

	# A floor grid at y=0 is the whole point: it shows a clip sinking through it.
	var floor_plane = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_plane.mesh = plane
	var checker = StandardMaterial3D.new()
	checker.albedo_color = Color("2b3440")
	floor_plane.material_override = checker
	view.add_child(floor_plane)
	for i in range(-6, 7):
		for axis in 2:
			var bar = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(12, 0.012, 0.02) if axis == 0 else Vector3(0.02, 0.012, 12)
			bar.mesh = box
			var line = StandardMaterial3D.new()
			line.albedo_color = Color("d9434a") if i == 0 else Color("47566a")
			line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bar.material_override = line
			bar.position = Vector3(0, 0.006, i) if axis == 0 else Vector3(i, 0.006, 0)
			view.add_child(bar)

	var camera = Camera3D.new()
	camera.position = Vector3(3.1, 1.5, 3.1)
	camera.fov = 50.0
	view.add_child(camera)
	camera.look_at(Vector3(0, 0.95, 0))

	var model = load("res://assets/models/warrior_player.glb").instantiate()
	view.add_child(model)
	var player = _find(model, "AnimationPlayer") as AnimationPlayer

	for clip in CLIPS:
		if not player.has_animation(clip):
			continue
		var anim = player.get_animation(clip)
		for shot in SHOTS:
			player.play(clip)
			player.seek(anim.length * (float(shot) / float(SHOTS - 1)) * 0.999, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png("%s/%s_%02d.png" % [out, clip, shot])
		# Numbers alongside the frames: how far the body drifts from the origin, and
		# whether any bone ends up under the floor.
		var skel=_find(model,"Skeleton3D") as Skeleton3D
		var low=INF
		var drift=0.0
		for shot in 24:
			player.seek(anim.length*float(shot)/23.0,true)
			await get_tree().process_frame
			for b in skel.get_bone_count():
				var o=(skel.global_transform*skel.get_bone_global_pose(b)).origin
				low=minf(low,o.y)
			var hip=(skel.global_transform*skel.get_bone_global_pose(0)).origin
			drift=maxf(drift,Vector2(hip.x,hip.z).length())
		print("CLIP_SHEET %-11s len=%.2f  en_dusuk_Y=%+.3f  yatay_kayma=%.2f" % [clip,anim.length,low,drift])
	print("CLIP_SHEET_DONE ", out)
	get_tree().quit()

func _find(node, type_name):
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var found = _find(child, type_name)
		if found:
			return found
	return null
