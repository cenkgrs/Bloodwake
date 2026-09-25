extends SceneTree

# Headed VFX capture harness. Starts a run, stages a scenario, and writes PNG frames
# so a combat effect can be judged from the actual renderer instead of by eye-balling
# constants. Needs a real display - the headless renderer draws nothing.
#
#   godot --path godot --resolution 1280x720 --script res://tools/vfx_lab.gd
#
# Shots land in VFX_SHOT_DIR when that is set, otherwise user://vfx_shots (the
# resolved path is printed on start). Add a scenario by appending to SCENARIOS:
#   class_id, camera size, enemies to place, frames to settle, shot name.

const SCENARIOS = [
	{"class_id":"gunslinger","zoom":9.0,"name":"tracer_bearings","frames":30,
		"enemies":[Vector3(4.5,0,0),Vector3(-4.0,0,1.5),Vector3(0,0,-4.2),Vector3(3.0,0,3.0)],"enemy":"grunt"},
	{"class_id":"warrior","zoom":7.0,"name":"melee_slash","frames":24,
		"enemies":[Vector3(1.4,0,0),Vector3(-1.2,0,0.6)],"enemy":"tank"},
	{"class_id":"mage","zoom":9.0,"name":"orb_through_crowd","frames":34,
		"enemies":[Vector3(3.0,0,0),Vector3(5.0,0,0.3),Vector3(6.8,0,-0.2)],"enemy":"grunt"},
]

var out_dir = ""
var scene

func _initialize():call_deferred("run_lab")

func _resolve_dir() -> String:
	var dir=OS.get_environment("VFX_SHOT_DIR")
	if dir=="":dir="user://vfx_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	return dir

func shot(name: String):
	await RenderingServer.frame_post_draw
	var path=out_dir.path_join(name+".png")
	var error=root.get_texture().get_image().save_png(path)
	if error!=OK:push_error("could not write %s (error %d)" % [path,error])
	else:print("SHOT ",ProjectSettings.globalize_path(path))

func run_lab():
	out_dir=_resolve_dir()
	print("VFX_LAB output: ",ProjectSettings.globalize_path(out_dir))
	scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://vfx_lab_progression.json"
	for row in SCENARIOS:
		scene.start_run(row.class_id);await process_frame
		var world=scene.world
		world.auto_fire=true;world.camera.size=row.zoom
		for spot in row.enemies:world.spawn_enemy(row.enemy,spot)
		for i in row.frames:await process_frame
		await shot(row.name)
	quit()
