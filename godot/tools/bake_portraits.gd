extends Node

# Bakes a portrait plate per class off the in-game rig, so the class screen shows
# the same character the run does. Run it with
#   godot --path godot tools/bake_portraits.tscn
# It writes ungraded plates to art/portraits/raw. tools/grade_portraits.py then
# grades those into godot/assets/ui/portraits, which is what the game loads.

const SIZE = Vector2i(560, 840)
# The ungraded plates live outside the project so re-grading never has to re-bake,
# and so the raw renders are not imported as game assets.
const OUT = "res://../art/portraits/raw"

# Each rig frames differently, so the camera and the turn are per class: yaw is the
# three-quarter turn, lift/dolly frame the bust, tilt aims at the chest.
const SHOTS = {
	"warrior": {"yaw": 24.0, "lift": 1.20, "dolly": 2.16, "tilt": -4.0, "height": 1.85, "shift": 0.02},
	"gunslinger": {"yaw": -22.0, "lift": 1.20, "dolly": 2.20, "tilt": -4.0, "height": 1.85, "shift": 0.0},
	"mage": {"yaw": 18.0, "lift": 1.22, "dolly": 2.18, "tilt": -5.0, "height": 1.85, "shift": -0.13},
	"assassin": {"yaw": -26.0, "lift": 1.20, "dolly": 2.14, "tilt": -4.0, "height": 1.85, "shift": 0.03}
}

func _ready():
	BWData.load_catalogs()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in SHOTS:
		await _bake(id, SHOTS[id])
	print("BLOODWAKE_PORTRAITS_BAKED")
	get_tree().quit()

func _bake(id: String, shot: Dictionary):
	var view = SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.size = SIZE
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2b1d22")
	environment.ambient_light_energy = 0.9
	world.environment = environment
	view.add_child(world)

	# A cold key from the front left, a blood rim from behind right, and a low fill so
	# the greaves do not fall into pure black. Straight out of the mockups' lighting.
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24.0, -34.0, 0.0)
	key.light_color = Color("cfd8e6")
	key.light_energy = 2.1
	view.add_child(key)
	var rim = OmniLight3D.new()
	rim.position = Vector3(1.35, 1.75, -1.25)
	rim.light_color = Color("d9434a")
	rim.light_energy = 7.0
	rim.omni_range = 5.5
	view.add_child(rim)
	var fill = OmniLight3D.new()
	fill.position = Vector3(-1.5, 0.75, 1.6)
	fill.light_color = Color("6d5f7a")
	fill.light_energy = 2.4
	fill.omni_range = 5.0
	view.add_child(fill)

	var camera = Camera3D.new()
	camera.position = Vector3(0.0, shot.lift, shot.dolly)
	camera.rotation_degrees = Vector3(shot.tilt, 0.0, 0.0)
	camera.fov = 42.0
	view.add_child(camera)

	var art = BWVisual.new()
	view.add_child(art)
	art.configure(id, false, Color.WHITE, shot.height)
	art.position = art.frame_offset()
	art.rotation_degrees.y = shot.yaw
	art.position.x += shot.shift
	_recolour_magic(art)
	# The idle clip has to settle before the pose is worth capturing.
	for i in 12:
		art.tick(1.0 / 60.0, false)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image = view.get_texture().get_image()
	var path = ProjectSettings.globalize_path("%s/%s.png" % [OUT, id])
	var err = image.save_png(path)
	print("portrait %s -> %s (%s)" % [id, path, error_string(err)])
	view.queue_free()

# The mage carries a cyan orb in the world. The menus are lit by blood, so the
# portrait plate gets the same prop in the screen's palette.
func _recolour_magic(art: BWVisual):
	if not is_instance_valid(art.hand_magic): return
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff8f86")
	mat.emission_enabled = true
	mat.emission = Color("d9434a")
	mat.emission_energy_multiplier = 2.2
	for child in art.hand_magic.get_children():
		if child is GeometryInstance3D: child.material_override = mat
		if child is OmniLight3D: child.light_color = Color("e05055")
