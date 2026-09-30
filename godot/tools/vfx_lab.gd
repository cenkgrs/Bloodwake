extends SceneTree

# Headed VFX capture harness. Starts a run, stages a scenario, and writes PNG frames
# so a combat effect can be judged from the actual renderer instead of by eye-balling
# constants. Needs a real display - the headless renderer draws nothing.
#
#   godot --path godot --resolution 1280x720 --script res://tools/vfx_lab.gd
#
# Shots land in VFX_SHOT_DIR when that is set, otherwise user://vfx_shots (the
# resolved path is printed on start). Add a scenario by appending to SCENARIOS;
# "cast" fires the class ability once instead of leaving auto-fire on, which is how
# the ability effects are staged.

# a handful of bodies around the caster, so an area effect has something to land on
const RING = [Vector3(1.8,0,0.4),Vector3(-1.6,0,1.2),Vector3(0.3,0,-2.0),Vector3(2.6,0,-1.4)]

const SCENARIOS = [
	{"class_id":"gunslinger","zoom":9.0,"name":"tracer_bearings","frames":30,
		"enemies":[Vector3(4.5,0,0),Vector3(-4.0,0,1.5),Vector3(0,0,-4.2),Vector3(3.0,0,3.0)],"enemy":"grunt"},
	{"class_id":"warrior","zoom":7.0,"name":"melee_slash","frames":24,
		"enemies":[Vector3(1.4,0,0),Vector3(-1.2,0,0.6)],"enemy":"tank"},
	{"class_id":"mage","zoom":9.0,"name":"orb_through_crowd","frames":34,
		"enemies":[Vector3(3.0,0,0),Vector3(5.0,0,0.3),Vector3(6.8,0,-0.2)],"enemy":"grunt"},
	{"class_id":"mage","zoom":8.0,"name":"ability_frost_nova","frames":24,"cast":true,"strip":true,
		"enemies":RING,"enemy":"grunt"},
	{"class_id":"warrior","zoom":8.0,"name":"ability_war_cry","frames":20,"cast":true,"strip":true,
		"enemies":RING,"enemy":"grunt"},
	{"class_id":"assassin","zoom":8.0,"name":"ability_shadow_strike","frames":20,"cast":true,"strip":true,
		"enemies":RING,"enemy":"grunt"},
	{"class_id":"gunslinger","zoom":8.0,"name":"ability_fan_shot","frames":16,"cast":true,"strip":true,
		"enemies":RING,"enemy":"grunt"},
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
		var cast=row.get("cast",false)
		world.auto_fire=not cast;world.camera.size=row.zoom
		for spot in row.enemies:world.spawn_enemy(row.enemy,spot)
		if cast:
			world.aim=Vector3(1,0,0)
			for i in 4:await process_frame
			# The ability lives in the kit since world.gd was split; the lab calls the
			# same entry point the game does rather than a copy of it.
			world.skills._resolve_ability(BWData.entry("abilities",BWData.CLASSES[row.class_id].ability))
		# strip writes every frame, numbered. A single still says whether an effect
		# exists; only the strip says whether it reads as anticipation, impact and
		# settle rather than one quad scaling up and fading out.
		for i in row.frames:
			await process_frame
			if row.get("strip",false):await shot("%s_%02d" % [row.name,i])
		await shot(row.name)
	quit()
