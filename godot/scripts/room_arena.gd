class_name BWRoomArena
extends BWArena

# One room of a map, built from its record in data/rooms.json. If the room's
# exported scene exists it is instanced and its markers, collision proxies and
# door leaves are read from it; until then the room is grey-boxed from the same
# record, so the flow can be played before a single model is delivered.
#
# Conventions read from an exported scene (see docs/rooms.md):
#   markers   EntrySpawn, EntranceDoor, ExitDoor, ExitTrigger, RewardPoint,
#             EnemySpawn_01.., BossSpawn, BossArenaCenter (empties)
#   collision anything under a node called Collision, or named COL_*, or a
#             CollisionShape3D the importer made from a -colonly mesh
#   doors     EntranceLeaf_L/_R and ExitLeaf_L/_R, pivots on the hinges
#   camera    anything under CameraSide, or named CamWall_*, is hideable

const WALL_HEIGHT = 3.2
const LOW_WALL = 1.0
const WALL_THICK = 1.0
const LEAF_SWING = deg_to_rad(100.0)
const DOOR_OPEN_TIME = 0.6

var room: Dictionary = {}
var markers: Dictionary = {}
var problems: Array = []
var from_scene = false
var zone: Dictionary = {}
var doors: Dictionary = {}          # name -> {leaves:[{pivot, sign}], open:bool, glow}
var camera_side: Array = []
var reward_node: Node3D
var reward_light: OmniLight3D
var reward_gem: MeshInstance3D
var reward_state = "none"
static var materials: Dictionary = {}
const KIT_FILE = "res://data/room_kit.json"
static var kit: Dictionary = {}

func build_room(room_row: Dictionary, profile: String, seed_value: int = 0):
	room = room_row
	quality = profile
	rng.seed = seed_value if seed_value != 0 else hash(room_row.id)
	half_x = room_row.half.x
	half_z = room_row.half.y
	margin = 0.6
	stone = _mat("stone")
	var light = room_row.get("light", {})
	# Each room's light leans its own way, but only leans: fully saturated it drowned
	# the stone in one colour and every room read as a tinted box.
	zone = {"id": room_row.id, "name": room_row.name, "ambient": Color(light.get("ambient", "8fa2bb")).lerp(Color("c4ad94"), 0.62),
		"fog": Color(light.get("fog", "1b232f")).lerp(Color("17171a"), 0.4), "energy": 0.62,
		"ground": Color(light.get("ground", "4f545c")), "garrison": {}}
	markers = room_row.markers.duplicate(true)
	if ResourceLoader.exists(String(room_row.get("scene", ""))):
		from_scene = _instance_scene(room_row.scene)
	if not from_scene:
		_grey_box()
	_reward_pedestal()
	build_nav()
	problems = check()

func zone_at(_spot: Vector3) -> Dictionary:
	return zone

func zone_by_id(_id: String) -> Dictionary:
	return zone

func marker(name: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var value = markers.get(name, fallback)
	return value if value is Vector3 else fallback

func enemy_spawns() -> Array:
	return markers.get("EnemySpawn", [])

func exit_zone() -> Rect2:
	return markers.get("ExitTrigger", Rect2())

func in_exit(spot: Vector3) -> bool:
	return markers.has("ExitTrigger") and exit_zone().grow(0.25).has_point(Vector2(spot.x, spot.z))

func side_of(door_name: String) -> String:
	return BWRooms.wall_side(marker(door_name), Vector2(half_x, half_z))

# ------------------------------------------------------------------ validation

# What a delivered room has to satisfy before the flow trusts it. Problems are
# reported, not fatal: a room with a missing marker still loads on its data.
func check() -> Array:
	var found = []
	for name in BWRooms.REQUIRED.get(room.type, []):
		if not markers.has(name) or (name == "EnemySpawn" and enemy_spawns().is_empty()):
			found.append("missing marker " + name)
	var floor_rect = Rect2(-half_x, -half_z, half_x * 2.0, half_z * 2.0)
	var points = {}
	for name in ["EntrySpawn", "RewardPoint", "BossSpawn", "BossArenaCenter"]:
		if markers.has(name):points[name] = marker(name)
	for i in enemy_spawns().size():points["EnemySpawn_%02d" % (i + 1)] = enemy_spawns()[i]
	for name in points:
		var p: Vector3 = points[name]
		if not floor_rect.has_point(Vector2(p.x, p.z)):found.append(name + " is outside the floor")
		elif in_rect(p, 0.3):found.append(name + " is inside an obstacle")
	if markers.has("EntrySpawn"):
		var start = marker("EntrySpawn")
		var targets = points.duplicate()
		if markers.has("ExitTrigger"):
			var crossing = exit_zone().get_center()
			targets["ExitTrigger"] = Vector3(crossing.x, 0, crossing.y)
		if markers.has("EntranceDoor"):targets["EntranceDoor"] = clamp_inside(marker("EntranceDoor"))
		var cost = nav_fill(start)
		for name in targets:
			if not _reached(cost, targets[name]):found.append(name + " cannot be reached from EntrySpawn")
	if markers.has("EntranceDoor") and markers.has("EntrySpawn"):
		var depth = marker("EntrySpawn").distance_to(clamp_inside(marker("EntranceDoor")))
		if depth > 6.0:found.append("EntrySpawn is %.1f m from the entrance" % depth)
	return found

# A point counts as reached when its own cell, or one within arm's length of it,
# can be walked to: the pedestal and the hosts stand on their own markers.
func _reached(cost: PackedInt32Array, spot: Vector3) -> bool:
	var centre = nav_cell_of(spot)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cell = centre + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= nav_size.x or cell.y >= nav_size.y:continue
			if cost[cell.y * nav_size.x + cell.x] >= 0:return true
	return false

# ------------------------------------------------------------------ doors

func set_door(name: String, open: bool, animate: bool = true):
	if not doors.has(name):return
	var door = doors[name]
	door.open = open
	for leaf in door.leaves:
		var target = leaf.rest + (leaf.sign * LEAF_SWING if open else 0.0)
		if animate and is_inside_tree():
			create_tween().tween_property(leaf.pivot, "rotation:y", target, DOOR_OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			leaf.pivot.rotation.y = target
	if door.glow != null:door.glow.visible = open

func door_open(name: String) -> bool:
	return doors.has(name) and doors[name].open

# Camera-side walls can be faded out by whoever owns the camera; grey-box ones
# are already built low enough not to need it.
func set_camera_side_visible(show: bool):
	for node in camera_side:
		if is_instance_valid(node):node.visible = show

# ------------------------------------------------------------------ reward pedestal

# none: dark stone. ready: lit, something to take. taken: dark again.
func set_reward(state: String):
	reward_state = state
	if reward_gem == null:return
	reward_gem.visible = state == "ready"
	if reward_light != null:reward_light.visible = state == "ready"

func _reward_pedestal():
	if not markers.has("RewardPoint") or room.type in ["merchant", "safehouse"]:return
	reward_node = Node3D.new();reward_node.name = "RewardPedestal"
	reward_node.position = marker("RewardPoint")
	add_child(reward_node)
	if _kit_piece("reward_pedestal", Vector3.ZERO, Vector3(1.2, 0.85, 1.2), 0.0, reward_node) == null:
		reward_node.add_child(_box(Vector3(1.1, 0.7, 1.1), "stone_dark", Vector3(0, 0.35, 0)))
		reward_node.add_child(_box(Vector3(0.8, 0.12, 0.8), "stone", Vector3(0, 0.76, 0)))
	reward_gem = MeshInstance3D.new()
	var gem = PrismMesh.new();gem.size = Vector3(0.42, 0.6, 0.42)
	reward_gem.mesh = gem;reward_gem.material_override = _mat("reward")
	reward_gem.position.y = 1.25;reward_gem.rotation.z = PI
	var crown = MeshInstance3D.new();var top = PrismMesh.new();top.size = Vector3(0.42, 0.4, 0.42)
	crown.mesh = top;crown.material_override = _mat("reward");crown.position.y = -0.5;crown.rotation.z = PI
	reward_gem.add_child(crown)
	reward_node.add_child(reward_gem)
	var spin = reward_gem.create_tween().set_loops()
	spin.tween_property(reward_gem, "rotation:y", TAU, 4.0).from(0.0)
	reward_light = OmniLight3D.new();reward_light.light_color = Color("b77cff");reward_light.light_energy = 1.4
	reward_light.omni_range = 4.0;reward_light.position.y = 1.4
	reward_node.add_child(reward_light)
	blockers.append({"pos": reward_node.position, "radius": 0.6})
	set_reward("none")

# ------------------------------------------------------------------ exported scene

func _instance_scene(path: String) -> bool:
	var packed = load(path)
	if not packed is PackedScene:return false
	var scene = packed.instantiate()
	scene.name = "RoomScene"
	add_child(scene)
	var spawns = []
	for node in _walk(scene):
		var name = String(node.name)
		if node is Node3D:
			var spot: Vector3 = node.global_position if node.is_inside_tree() else node.position
			spot.y = 0.0
			if name.begins_with("EnemySpawn"):spawns.append([name, spot])
			elif name == "ExitTrigger":
				markers.ExitTrigger = _footprint(node, spot)
			elif name in ["EntrySpawn", "EntranceDoor", "ExitDoor", "RewardPoint", "BossSpawn", "BossArenaCenter"]:
				markers[name] = spot
		if _is_collision(node):
			var box = _footprint(node, Vector3.INF)
			if box.size.x > 0.05 and box.size.y > 0.05:rects.append(box)
			if node is VisualInstance3D:node.visible = false
		if name.begins_with("CamWall") or _under(node, "CameraSide"):camera_side.append(node)
		for door in ["Entrance", "Exit"]:
			for hand in ["L", "R"]:
				if name == "%sLeaf_%s" % [door, hand]:
					var key = door.to_lower()
					if not doors.has(key):doors[key] = {"leaves": [], "open": false, "glow": null}
					doors[key].leaves.append({"pivot": node, "rest": node.rotation.y, "sign": 1.0 if hand == "L" else -1.0})
	if not spawns.is_empty():
		spawns.sort_custom(func(a, b): return a[0] < b[0])
		markers.EnemySpawn = spawns.map(func(row): return row[1])
	if markers.has("ExitDoor") and not markers.get("ExitTrigger", Rect2()).has_area():
		markers.ExitTrigger = BWRooms.exit_zone(marker("ExitDoor"), Vector2(half_x, half_z))
	for key in doors:doors[key].glow = _exit_glow() if key == "exit" else null
	set_door("entrance", false, false);set_door("exit", false, false)
	return true

func _walk(node: Node) -> Array:
	var list = [node]
	for child in node.get_children():list.append_array(_walk(child))
	return list

func _under(node: Node, ancestor: String) -> bool:
	var parent = node.get_parent()
	while parent != null and parent != self:
		if String(parent.name) == ancestor:return true
		parent = parent.get_parent()
	return false

func _is_collision(node: Node) -> bool:
	if node is CollisionShape3D:return true
	if not node is MeshInstance3D:return false
	return String(node.name).begins_with("COL_") or _under(node, "Collision")

# A node's footprint on the ground plane, as the rect its world-space box covers.
# Floor slabs (under 30 cm tall) are not obstacles and come back empty.
func _footprint(node: Node3D, fallback: Vector3) -> Rect2:
	var box = AABB()
	if node is MeshInstance3D and node.mesh != null:box = node.global_transform * node.get_aabb()
	elif node is CollisionShape3D and node.shape != null:box = node.global_transform * node.shape.get_debug_mesh().get_aabb()
	elif fallback != Vector3.INF:
		var reach = node.global_transform.basis.get_scale()
		box = AABB(fallback - Vector3(reach.x, 0, reach.z), Vector3(reach.x * 2.0, 1.0, reach.z * 2.0))
	if box.size.y < 0.3 and fallback == Vector3.INF:return Rect2()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

# ------------------------------------------------------------------ grey box

func _grey_box():
	_floor()
	_perimeter()
	for row in room.get("layout", []):_layout(row)
	for row in room.get("hosts", []):
		if row.get("kind", "") == "war_table":_war_table(BWRooms.vec(row.at))
		else:blockers.append({"pos": BWRooms.vec(row.at), "radius": 0.6})
	for row in room.get("landmarks", []):_landmark(row)
	_lanterns()

# Past the walls the street falls away into the dark: the camera is held inside
# the room, and whatever corner of the outside still shows is night, not void.
const OUTSIDE_SHADER = """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec2 half_size;
uniform float fade = 8.0;
uniform vec3 night : source_color = vec3(0.02);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 beyond = max(abs(world.xz) - half_size, vec2(0.0));
	float lit = 1.0 - smoothstep(0.0, fade, length(beyond));
	ALBEDO = mix(night, texture(albedo_tex, world.xz / 2.6).rgb * 0.32, lit);
	ROUGHNESS = 0.95;
}
"""

func _floor():
	var outer = MeshInstance3D.new();var plane = PlaneMesh.new()
	plane.size = Vector2(half_x * 2.0 + 160.0, half_z * 2.0 + 160.0)
	outer.mesh = plane;outer.position.y = -0.03;outer.name = "Outside"
	var street = ShaderMaterial.new();street.shader = Shader.new();street.shader.code = OUTSIDE_SHADER
	var paving = _mat("cobble").albedo_texture
	if paving != null:street.set_shader_parameter("albedo_tex", paving)
	street.set_shader_parameter("half_size", Vector2(half_x + 9.0, half_z + 9.0))
	street.set_shader_parameter("night", zone.fog.darkened(0.6))
	outer.material_override = street
	add_child(outer)
	ground = MeshInstance3D.new();var slab = PlaneMesh.new()
	slab.size = Vector2(half_x * 2.0 + WALL_THICK * 2.0, half_z * 2.0 + WALL_THICK * 2.0)
	slab.subdivide_width = 8;slab.subdivide_depth = 8
	ground.mesh = slab
	var paved = _mat("flagstone").duplicate()
	# The room's ground colour shifts the stone, it does not replace it.
	if paved.albedo_texture != null:paved.albedo_color = Color(0.74, 0.69, 0.62).lerp(zone.ground.lightened(0.3), 0.2);paved.normal_scale = 0.8
	else:paved.albedo_color = zone.ground
	ground.material_override = paved
	add_child(ground)

# The edge of a room, built the way the environment boards draw it. The north,
# west and east sides are the town itself - stone wall bays with buttresses,
# lean-to sheds and timber houses whose fronts stand on the wall line - with more
# roofs behind them. The south side faces the camera, so it stays a low parapet of
# capped pillars and iron railings. Every side is cut where a door sits in it.
const BUILT_HEIGHT = 3.4
const FRONT_DEPTH = 4.0

func _perimeter():
	var room_doors = room.get("doors", {})
	var openings = {"north": [], "south": [], "west": [], "east": []}
	for key in room_doors:
		var spot = BWRooms.vec(room_doors[key].at)
		openings[BWRooms.wall_side(spot, Vector2(half_x, half_z))].append(spot)
	for side in openings:
		var along_x = side in ["north", "south"]
		var reach = half_x if along_x else half_z
		var cuts = []
		for spot in openings[side]:
			var centre = spot.x if along_x else spot.z
			cuts.append([centre - BWRooms.DOOR_WIDTH * 0.5 - 1.5, centre + BWRooms.DOOR_WIDTH * 0.5 + 1.5])
		for row in room.get("landmarks", []):
			if row.get("flush", "") == side:
				var middle = BWRooms.vec(row.at).x if along_x else BWRooms.vec(row.at).z
				cuts.append([middle - float(row.span) * 0.5, middle + float(row.span) * 0.5])
		cuts.sort_custom(func(a, b): return a[0] < b[0])
		var start = -reach
		for cut in cuts + [[reach, reach]]:
			if cut[0] - start > 0.3:
				if side == "south":_parapet(side, start, cut[0])
				else:_frontage(side, start, cut[0])
			start = maxf(start, cut[1])
		if side != "south":_backdrop(side)
		else:_street_layer()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var low = corner.y > 0
		var tower = _box(Vector3(1.6, 1.8 if low else BUILT_HEIGHT + 1.2, 1.6), "stone_dark", Vector3(corner.x * (half_x + 0.8), (1.8 if low else BUILT_HEIGHT + 1.2) * 0.5, corner.y * (half_z + 0.8)))
		add_child(tower)
		tower.add_child(_box(Vector3(1.9, 0.3, 1.9), "stone", Vector3(0, tower.mesh.size.y * 0.5 + 0.15, 0)))
	for key in room_doors:_door(key, room_doors[key])

# A point on a side's wall line, `t` along it and `out` metres beyond it, and the
# turn that makes a piece's local +Z face into the room from that side.
func _side_point(side: String, t: float, out: float = 0.0) -> Vector3:
	match side:
		"north":return Vector3(t, 0, -half_z - out)
		"south":return Vector3(t, 0, half_z + out)
		"west":return Vector3(-half_x - out, 0, t)
		_:return Vector3(half_x + out, 0, t)

func _side_turn(side: String) -> float:
	return {"north": 0.0, "south": PI, "west": PI * 0.5, "east": -PI * 0.5}[side]

func _piece(side: String, t: float, name: String) -> Node3D:
	var node = Node3D.new();node.name = name
	node.position = _side_point(side, t);node.rotation.y = _side_turn(side)
	add_child(node, true)
	return node

func _frontage(side: String, from: float, to: float):
	var cursor = from
	while to - cursor > 0.3:
		var left = to - cursor
		var roll = rng.randf()
		var kind = "wall" if left < 3.6 or roll < 0.38 else ("shed" if roll < 0.7 else "house")
		var width = left if kind == "wall" and left < 3.6 else clampf({"wall": rng.randf_range(3.5, 6.0), "shed": rng.randf_range(3.8, 5.2), "house": rng.randf_range(4.8, 6.4)}[kind], 1.0, left)
		if left - width < 2.0:width = left
		var node = _piece(side, cursor + width * 0.5, kind.capitalize())
		if _kit_piece("house" if kind != "wall" else "wall_tall", Vector3.ZERO, Vector3(width, BUILT_HEIGHT if kind == "wall" else 6.5, FRONT_DEPTH if kind != "wall" else WALL_THICK), 0.0, node) == null:
			match kind:
				"wall":_wall_bay(node, width)
				"shed":_shed(node, width)
				_:_town_house(node, width)
		cursor += width

func _wall_bay(node: Node3D, width: float):
	node.add_child(_box(Vector3(width, BUILT_HEIGHT, WALL_THICK), "stone", Vector3(0, BUILT_HEIGHT * 0.5, -WALL_THICK * 0.5)))
	node.add_child(_box(Vector3(width + 0.1, 0.2, WALL_THICK + 0.25), "stone_dark", Vector3(0, BUILT_HEIGHT + 0.1, -WALL_THICK * 0.5)))
	for hand in [-1.0, 1.0]:
		var pier = _box(Vector3(0.8, BUILT_HEIGHT + 0.6, 1.2), "stone_dark", Vector3(hand * (width * 0.5 - 0.4), (BUILT_HEIGHT + 0.6) * 0.5, -0.6))
		node.add_child(pier)
		pier.add_child(_box(Vector3(1.0, 0.25, 1.4), "stone", Vector3(0, (BUILT_HEIGHT + 0.6) * 0.5 + 0.12, 0)))
	if rng.randf() < 0.55:_banner(node, Vector3(rng.randf_range(-width * 0.25, width * 0.25), BUILT_HEIGHT - 0.3, 0.04), 2.2)
	if rng.randf() < 0.5:
		var lamp_x = rng.randf_range(-width * 0.3, width * 0.3)
		node.add_child(_box(Vector3(0.08, 0.5, 0.35), "iron", Vector3(lamp_x, 2.4, 0.15)))
		_lamp(node.position + node.basis * Vector3(lamp_x, 2.2, 0.35), 0.7, Color("ffb36b"), 4.5)

# A timber lean-to against the town wall: plank walls, a roof running down
# towards the courtyard, a lit window and a door. Low, so it never hides a fight.
func _shed(node: Node3D, width: float):
	var height = rng.randf_range(3.0, 3.8)
	node.add_child(_box(Vector3(width, height, FRONT_DEPTH), "wood_dark", Vector3(0, height * 0.5, -FRONT_DEPTH * 0.5)))
	node.add_child(_box(Vector3(width, 0.5, FRONT_DEPTH), "stone_dark", Vector3(0, 0.25, -FRONT_DEPTH * 0.5)))
	var roof = _box(Vector3(width + 0.5, 0.18, FRONT_DEPTH + 0.9), "wood", Vector3(0, height + 0.55, -FRONT_DEPTH * 0.5 + 0.2))
	roof.rotation.x = 0.3;node.add_child(roof)
	for hand in [-1.0, 1.0]:
		node.add_child(_box(Vector3(0.22, height + 0.3, 0.22), "wood", Vector3(hand * (width * 0.5 - 0.15), (height + 0.3) * 0.5, 0.12)))
	node.add_child(_box(Vector3(1.0, 2.0, 0.08), "wood", Vector3(-width * 0.2, 1.0, 0.03)))
	var lit = rng.randf() < 0.65
	node.add_child(_box(Vector3(0.9, 0.7, 0.08), "wood_dark", Vector3(width * 0.22, height * 0.62, 0.03)))
	node.add_child(_box(Vector3(0.7, 0.5, 0.09), "window" if lit else "iron", Vector3(width * 0.22, height * 0.62, 0.04)))
	if rng.randf() < 0.5:
		for step in 4:
			node.add_child(_box(Vector3(0.9, 0.22, 0.4), "wood", Vector3(width * 0.5 - 0.5, 0.11 + step * 0.42, -FRONT_DEPTH + 0.4 + step * 0.45)))
	if rng.randf() < 0.45:_banner(node, Vector3(width * 0.05, height - 0.2, 0.05), 1.8)

# Stone ground storey, half-timbered above, a slate gable facing the court.
func _town_house(node: Node3D, width: float):
	var height = rng.randf_range(5.6, 7.0)
	var plinth = minf(2.4, height * 0.4)
	node.add_child(_box(Vector3(width, plinth, FRONT_DEPTH), "stone", Vector3(0, plinth * 0.5, -FRONT_DEPTH * 0.5)))
	node.add_child(_box(Vector3(width + 0.3, height - plinth, FRONT_DEPTH + 0.3), "timber", Vector3(0, plinth + (height - plinth) * 0.5, -FRONT_DEPTH * 0.5)))
	node.add_child(_box(Vector3(width + 0.45, 0.22, FRONT_DEPTH + 0.45), "wood_dark", Vector3(0, plinth, -FRONT_DEPTH * 0.5)))
	var roof = MeshInstance3D.new();var prism = PrismMesh.new()
	prism.size = Vector3(width + 0.8, rng.randf_range(2.2, 3.0), FRONT_DEPTH + 0.8)
	roof.mesh = prism;roof.material_override = _mat("roof");roof.position = Vector3(0, height + prism.size.y * 0.5, -FRONT_DEPTH * 0.5)
	node.add_child(roof)
	if rng.randf() < 0.6:node.add_child(_box(Vector3(0.6, 1.6, 0.6), "stone_dark", Vector3(width * 0.25, height + prism.size.y * 0.6, -FRONT_DEPTH * 0.7)))
	node.add_child(_box(Vector3(1.1, 2.0, 0.1), "wood_dark", Vector3(rng.randf_range(-width * 0.25, width * 0.25), 1.0, 0.03)))
	for column in maxi(1, int(width / 2.0)):
		var x = -width * 0.5 + 1.0 + column * 2.0
		if x > width * 0.5 - 0.6:break
		var level = plinth + (height - plinth) * 0.45
		node.add_child(_box(Vector3(0.9, 1.1, 0.08), "wood_dark", Vector3(x, level, 0.17)))
		node.add_child(_box(Vector3(0.62, 0.82, 0.09), "window" if rng.randf() < 0.6 else "iron", Vector3(x, level, 0.18)))
	if rng.randf() < 0.4:_banner(node, Vector3(rng.randf_range(-width * 0.25, width * 0.25), plinth + 1.9, 0.2), 2.2)

# The town around the room: rows of houses beyond the frontage on the north,
# west and east, so that the edge of the view always lands on rooftops. Nothing
# out here can be reached; the floor stops at the walls.
func _backdrop(side: String):
	var along_x = side in ["north", "south"]
	var rows = 3 if side == "north" else 2
	for row in rows:
		var reach = (half_x if along_x else half_z) + 6.0 + row * 4.0
		var cursor = -reach
		var out = FRONT_DEPTH + 0.6 + row * 6.0
		while cursor < reach:
			var width = rng.randf_range(4.5, 7.5)
			var node = Node3D.new();node.name = "Backdrop"
			node.position = _side_point(side, cursor + width * 0.5, out + rng.randf_range(0.0, 1.2));node.rotation.y = _side_turn(side)
			add_child(node, true)
			var height = rng.randf_range(6.5, 9.0) + row * 1.2
			node.add_child(_box(Vector3(width, height, 5.0), "timber" if rng.randf() < 0.6 else "stone_dark", Vector3(0, height * 0.5, -2.5)))
			var roof = MeshInstance3D.new();var prism = PrismMesh.new();prism.size = Vector3(width + 0.6, rng.randf_range(2.4, 3.6), 5.6)
			roof.mesh = prism;roof.material_override = _mat("roof");roof.position = Vector3(0, height + prism.size.y * 0.5, -2.5)
			node.add_child(roof)
			if rng.randf() < 0.55:node.add_child(_box(Vector3(0.6, 1.6, 0.6), "stone_dark", Vector3(rng.randf_range(-width * 0.3, width * 0.3), height + prism.size.y * 0.7, -3.0)))
			for column in maxi(1, int(width / 2.2)):
				if rng.randf() < 0.45:continue
				node.add_child(_box(Vector3(0.6, 0.8, 0.08), "window", Vector3(-width * 0.5 + 1.1 + column * 2.2, height * rng.randf_range(0.45, 0.75), 0.03)))
			cursor += width + rng.randf_range(0.0, 0.5)

# South of the parapet, between the room and the camera, the town is a lit
# street: lamps, carts, crates and a market stall, nothing tall enough to stand
# in front of the fight. Past it the street fades into the dark.
func _street_layer():
	var reach = half_x + 7.0
	var cursor = -reach
	var ways = []
	for key in room.get("doors", {}):
		var door = BWRooms.vec(room.doors[key].at)
		if BWRooms.wall_side(door, Vector2(half_x, half_z)) == "south":ways.append(door.x)
	while cursor < reach:
		cursor += rng.randf_range(2.5, 4.5)
		# The way in stays an open street, steps clear of carts and stalls.
		if ways.any(func(x): return absf(x - cursor) < BWRooms.DOOR_WIDTH * 0.5 + 2.6):continue
		var spot = _side_point("south", cursor, rng.randf_range(1.6, 3.0))
		var roll = rng.randf()
		var node = Node3D.new();node.name = "Street";node.position = spot;node.rotation.y = rng.randf_range(-0.3, 0.3);add_child(node, true)
		if roll < 0.3:
			for piece in rng.randi_range(2, 4):
				var crate = _box(Vector3(0.6, rng.randf_range(0.5, 0.9), 0.6), "crate", Vector3(piece * 0.65 - 0.9, 0, rng.randf_range(-0.2, 0.2)))
				crate.position.y = crate.mesh.size.y * 0.5;node.add_child(crate)
		elif roll < 0.5:
			node.add_child(_box(Vector3(2.2, 0.45, 1.2), "wood", Vector3(0, 0.75, 0)))
			for wheel_x in [-0.7, 0.7]:
				var wheel = _disc(0.42, 0.1, "wood_dark", 0.0);wheel.rotation.z = PI * 0.5;wheel.position = Vector3(wheel_x, 0.42, 0.65);node.add_child(wheel)
		elif roll < 0.65:
			_stall(spot, Vector2(2.4, 1.6), 1.0)
		elif roll < 0.85:
			for barrel in rng.randi_range(2, 3):
				var cask = _disc(0.3, 0.85, "wood", 0.43);cask.position.x = barrel * 0.7 - 0.7;node.add_child(cask)
		else:
			_lamp_post(spot, false)

# The camera side: a parapet of capped stone pillars with low wall or iron
# railing between them.
func _parapet(side: String, from: float, to: float):
	if not kit_files("wall_low").is_empty():
		_wall_run(side, from, to, false)
		return
	var holder = Node3D.new();holder.name = "CamWall_" + side;add_child(holder, true)
	camera_side.append(holder)
	var bays = maxi(1, int(round((to - from) / 3.4)))
	var step = (to - from) / bays
	for i in bays + 1:
		var spot = _side_point(side, from + i * step, 0.45)
		holder.add_child(_box(Vector3(0.75, 1.2, 0.75), "stone_dark", spot + Vector3(0, 0.6, 0)))
		holder.add_child(_box(Vector3(0.95, 0.16, 0.95), "stone", spot + Vector3(0, 1.28, 0)))
		var finial = _disc(0.2, 0.32, "stone", 0.0);finial.position = spot + Vector3(0, 1.52, 0);holder.add_child(finial)
	for i in bays:
		var centre = _side_point(side, from + (i + 0.5) * step, 0.45)
		var along = Vector3(1, 0, 0) if side in ["north", "south"] else Vector3(0, 0, 1)
		var length = step - 0.75
		if rng.randf() < 0.35:
			for bar in int(length / 0.22):
				var offset = -length * 0.5 + 0.11 + bar * 0.22
				holder.add_child(_box(Vector3(0.05, 0.95, 0.05), "iron", centre + along * offset + Vector3(0, 0.48, 0)))
			var rail = _box(Vector3(length, 0.06, 0.06) if along.x > 0 else Vector3(0.06, 0.06, length), "iron", centre + Vector3(0, 0.88, 0))
			holder.add_child(rail)
		else:
			holder.add_child(_box(Vector3(length, 0.75, 0.6) if along.x > 0 else Vector3(0.6, 0.75, length), "stone", centre + Vector3(0, 0.38, 0)))

func _wall_run(side: String, from: float, to: float, tall: bool):
	var height = WALL_HEIGHT if tall else LOW_WALL
	var length = to - from
	var kind = "wall_tall" if tall else "wall_low"
	var pieces = maxi(1, ceili(length / 4.0))
	var holder = Node3D.new();holder.name = ("Wall_" if tall else "CamWall_") + side;add_child(holder, true)
	for i in pieces:
		var spot = _side_point(side, from + (i + 0.5) * length / pieces, WALL_THICK * 0.5)
		_kit_piece(kind, spot, Vector3(length / pieces, height, WALL_THICK), _side_turn(side), holder)
	if not tall:camera_side.append(holder)

# A cross on bordo cloth, the town's colours on every second pillar.
func _banner(node: Node3D, at: Vector3, length: float):
	var cloth = _box(Vector3(0.95, length, 0.05), "cloth", at - Vector3(0, length * 0.5, 0))
	node.add_child(cloth)
	cloth.add_child(_box(Vector3(0.1, length * 0.42, 0.02), "bone", Vector3(0, length * 0.12, 0.035)))
	cloth.add_child(_box(Vector3(0.42, 0.1, 0.02), "bone", Vector3(0, length * 0.2, 0.035)))
	node.add_child(_box(Vector3(1.15, 0.07, 0.07), "iron", at + Vector3(0, 0.03, 0)))

# A gate as on the boards: two tall stone pillars carrying statues, banners on
# their faces, and a pair of spear-topped iron leaves. On the camera side the
# pillars are low and the way in is a short flight of steps up into the room.
func _door(key: String, spec: Dictionary):
	var spot = BWRooms.vec(spec.at)
	var side = BWRooms.wall_side(spot, Vector2(half_x, half_z))
	var low = side == "south"
	var grand = spec.get("grand", false)
	var frame = Node3D.new();frame.name = key.capitalize() + "Door"
	frame.position = Vector3(spot.x, 0, spot.z)
	var inward = BWRooms.inward(side)
	frame.rotation.y = atan2(inward.x, inward.z)
	add_child(frame)
	var post_height = 1.7 if low else (5.6 if grand else 4.6)
	var half_gap = BWRooms.DOOR_WIDTH * 0.5
	var frame_kind = "gate_frame_grand" if grand and not kit_files("gate_frame_grand").is_empty() else "gate_frame"
	var kit_frame = _kit_piece(frame_kind, Vector3.ZERO, Vector3(BWRooms.DOOR_WIDTH + 3.0, post_height, 1.5), 0.0, frame) if not low else null
	if kit_frame == null:
		for hand in [-1.0, 1.0]:
			var x = hand * (half_gap + 0.75)
			var pillar = _box(Vector3(1.5, post_height, 1.5), "stone_dark", Vector3(x, post_height * 0.5, -0.4))
			frame.add_child(pillar)
			frame.add_child(_box(Vector3(1.8, 0.35, 1.8), "stone", Vector3(x, 0.18, -0.4)))
			frame.add_child(_box(Vector3(1.75, 0.3, 1.75), "stone", Vector3(x, post_height + 0.15, -0.4)))
			if low:
				var finial = _disc(0.3, 0.5, "stone", post_height + 0.55);finial.position.x = x;finial.position.z = -0.4;frame.add_child(finial)
			else:
				_statue(frame, Vector3(x, post_height + 0.3, -0.4), 1.0 if not grand else 1.2)
				_banner(frame, Vector3(x, post_height - 0.5, 0.36), 2.4)
		if grand and not low:
			frame.add_child(_box(Vector3(BWRooms.DOOR_WIDTH + 3.0, 0.9, 1.4), "stone_dark", Vector3(0, post_height - 0.45, -0.4)))
			frame.add_child(_box(Vector3(BWRooms.DOOR_WIDTH, 1.1, 0.08), "cloth", Vector3(0, post_height - 1.5, 0.32)))
	if low:
		for step in 3:
			frame.add_child(_box(Vector3(BWRooms.DOOR_WIDTH + 0.4, 0.2, 0.7), "stone", Vector3(0, -0.1 - step * 0.2, -0.6 - step * 0.7)))
		for hand in [-1.0, 1.0]:_lamp_post(frame.position + frame.basis * Vector3(hand * (half_gap + 1.9), 0, 0.2), false)
	var leaves = []
	var leaf_height = 1.3 if low else minf(post_height - 0.6, 3.6)
	for hand in [-1.0, 1.0]:
		var pivot = Node3D.new();pivot.name = "%sLeaf_%s" % [key.capitalize(), "L" if hand < 0 else "R"]
		pivot.position = Vector3(hand * half_gap, 0, 0)
		frame.add_child(pivot)
		if _kit_piece("gate_leaf", Vector3(-hand * half_gap * 0.5, 0.05, 0), Vector3(half_gap, leaf_height, 0.15), 0.0, pivot, hand > 0) == null:
			var leaf = Node3D.new();pivot.add_child(leaf)
			for rail in [0.35, leaf_height - 0.35]:
				leaf.add_child(_box(Vector3(half_gap, 0.08, 0.08), "iron", Vector3(-hand * half_gap * 0.5, rail, 0)))
			var bars = int(half_gap / 0.24)
			for bar in bars:
				var bx = -hand * (0.12 + bar * 0.24)
				leaf.add_child(_box(Vector3(0.05, leaf_height, 0.05), "iron", Vector3(bx, leaf_height * 0.5, 0)))
				var tip = MeshInstance3D.new();var spike = PrismMesh.new();spike.size = Vector3(0.12, 0.22, 0.05)
				tip.mesh = spike;tip.material_override = _mat("iron");tip.position = Vector3(bx, leaf_height + 0.11, 0);leaf.add_child(tip)
		leaves.append({"pivot": pivot, "rest": 0.0, "sign": -hand})
	var glow = _exit_glow() if key == "exit" else null
	doors[key] = {"leaves": leaves, "open": false, "glow": glow}
	set_door(key, false, false)
	if not low:
		for hand in [-1.0, 1.0]:_lamp(frame.position + frame.basis * Vector3(hand * (half_gap + 0.75), 2.6, 0.5), 0.9)

# A cowled stone figure on a pedestal: the gate guardians and the kneeling dead
# on the Black Bell's plinths.
func _statue(parent: Node3D, at: Vector3, scale: float, kneeling: bool = false):
	var figure = Node3D.new();figure.position = at;figure.scale = Vector3.ONE * scale;parent.add_child(figure)
	figure.add_child(_box(Vector3(0.9, 0.35, 0.9), "stone", Vector3(0, 0.18, 0)))
	var body = 0.75 if kneeling else 1.45
	figure.add_child(_box(Vector3(0.62, body, 0.42), "stone_light", Vector3(0, 0.35 + body * 0.5, 0)))
	figure.add_child(_box(Vector3(0.82, 0.3, 0.46), "stone_light", Vector3(0, 0.35 + body - 0.1, 0)))
	figure.add_child(_box(Vector3(0.34, 0.4, 0.36), "stone_light", Vector3(0, 0.35 + body + 0.25, 0.02)))
	figure.add_child(_box(Vector3(0.16, 0.7 if not kneeling else 0.4, 0.16), "stone_light", Vector3(0.25, 0.35 + body * 0.55, 0.26)))

func _exit_glow() -> MeshInstance3D:
	if not markers.has("ExitTrigger"):return null
	var area: Rect2 = markers.ExitTrigger
	var glow = MeshInstance3D.new();glow.name = "ExitGlow"
	var plane = PlaneMesh.new();plane.size = area.size
	glow.mesh = plane;glow.material_override = _mat("exit_glow")
	glow.position = Vector3(area.get_center().x, 0.02, area.get_center().y)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visible = false
	add_child(glow)
	return glow

func _layout(row: Dictionary):
	var at = BWRooms.vec(row.at)
	var size = Vector2(float(row.get("size", [2, 2])[0]), float(row.get("size", [2, 2])[1]))
	var height = float(row.get("height", 1.2))
	var footprint = Rect2(at.x - size.x * 0.5, at.z - size.y * 0.5, size.x, size.y)
	var kit_kind = {"cargo": "cargo", "stall": "stall", "trough": "trough", "divider": "divider", "plinth": "plinth", "hearth": "hearth"}.get(row.kind, "")
	if not kit_kind.is_empty() and _kit_piece(kit_kind, at, Vector3(size.x, height, size.y), float(row.get("turn", 0.0))) != null:
		rects.append(footprint.grow_individual(0.7, 0, 0.7, 0) if row.kind == "divider" else footprint)
		if row.kind == "hearth":_lamp(at + Vector3(0, height * 0.5, size.y * 0.5 + 0.8), 1.8, Color("ff8a45"), 8.0)
		return
	match row.kind:
		"cargo":_cargo(at, size, height);rects.append(footprint)
		"stall":_stall(at, size, height);rects.append(footprint)
		"trough":
			add_child(_box(Vector3(size.x, height, size.y), "wood", at + Vector3(0, height * 0.5, 0)))
			add_child(_box(Vector3(size.x - 0.3, 0.05, size.y - 0.3), "water", at + Vector3(0, height - 0.05, 0)))
			rects.append(footprint)
		"divider":
			add_child(_box(Vector3(size.x, height, size.y), "stone", at + Vector3(0, height * 0.5, 0)))
			add_child(_box(Vector3(size.x + 0.3, 0.2, size.y + 0.3), "stone_dark", at + Vector3(0, height + 0.1, 0)))
			for hand in [-1.0, 1.0]:
				var trough_at = at + Vector3(hand * (size.x * 0.5 + 0.35), 0.35, 0)
				add_child(_box(Vector3(0.7, 0.7, size.y * 0.6), "wood", trough_at))
			rects.append(footprint.grow_individual(0.7, 0, 0.7, 0))
		"plinth":
			var base = _box(Vector3(size.x, 0.45, size.y), "stone_dark", at + Vector3(0, 0.22, 0))
			base.rotation.y = PI * 0.25;add_child(base)
			_statue(self, at + Vector3(0, 0.45, 0), 0.6, true)
			rects.append(footprint)
		"hearth":
			add_child(_box(Vector3(size.x, height, size.y), "stone_dark", at + Vector3(0, height * 0.5, 0)))
			add_child(_box(Vector3(size.x * 0.6, height * 0.5, 0.2), "ember", at + Vector3(0, height * 0.3, size.y * 0.5 + 0.02)))
			_lamp(at + Vector3(0, height * 0.5, size.y * 0.5 + 0.8), 1.8, Color("ff8a45"), 8.0)
			rects.append(footprint)
		"well":_well(at, float(row.get("radius", 2.0)), height)
		"ring":_ring(at, float(row.get("radius", 10.0)), float(row.get("band", 0.3)))
		"seal":
			var radius = float(row.get("radius", 14.0))
			_ring(at, radius, 0.35);_ring(at, radius * 0.66, 0.2);_ring(at, 1.2, 0.25)
			# The compass rose of the boards: four long points, four short ones.
			for turn in 8:
				var length = radius * (0.95 if turn % 2 == 0 else 0.5)
				var point = Node3D.new();point.position = at + Vector3(0, 0.012, 0);point.rotation.y = turn * PI * 0.25;add_child(point)
				# A square turned 45 degrees inside a stretched holder is a diamond: one ray.
				var squash = Node3D.new();squash.position = Vector3(0, 0, -length * 0.5);squash.scale = Vector3(0.16, 1.0, 1.0)
				point.add_child(squash)
				var blade = _box(Vector3(length * 0.707, 0.01, length * 0.707), "seal", Vector3.ZERO)
				blade.rotation.y = PI * 0.25;blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				squash.add_child(blade)

# Crates, barrels and a cart packed into the footprint: low enough to see over,
# solid enough to fight around.
func _cargo(at: Vector3, size: Vector2, height: float):
	var holder = Node3D.new();holder.name = "Cargo";holder.position = at;add_child(holder)
	# The boards set every cargo island on a kerbed stone apron.
	holder.add_child(_box(Vector3(size.x + 0.5, 0.06, size.y + 0.5), "stone_dark", Vector3(0, 0.03, 0)))
	holder.add_child(_box(Vector3(size.x, 0.12, size.y), "wood_dark", Vector3(0, 0.06, 0)))
	var cart = size.x >= 4.0 and rng.randf() < 0.7
	var used_x = -size.x * 0.5 + 0.2
	if cart:
		var length = minf(2.8, size.x * 0.45)
		holder.add_child(_box(Vector3(length, 0.5, minf(1.5, size.y * 0.6)), "wood", Vector3(used_x + length * 0.5, 0.75, 0)))
		for wheel_x in [used_x + 0.5, used_x + length - 0.5]:
			for hand in [-1.0, 1.0]:
				var wheel = MeshInstance3D.new();var disc = CylinderMesh.new()
				disc.top_radius = 0.45;disc.bottom_radius = 0.45;disc.height = 0.12;disc.radial_segments = 12
				wheel.mesh = disc;wheel.material_override = _mat("wood_dark")
				wheel.position = Vector3(wheel_x, 0.45, hand * minf(0.8, size.y * 0.32));wheel.rotation.x = PI * 0.5
				holder.add_child(wheel)
		used_x += length + 0.3
	var x = used_x
	while x < size.x * 0.5 - 0.6:
		var z = -size.y * 0.5 + 0.2
		var column = rng.randf_range(0.9, 1.3)
		while z < size.y * 0.5 - 0.6:
			var piece = rng.randf_range(0.8, 1.2)
			var stack = height * rng.randf_range(0.55, 1.0)
			if rng.randf() < 0.3:
				var barrel = MeshInstance3D.new();var body = CylinderMesh.new()
				body.top_radius = piece * 0.38;body.bottom_radius = piece * 0.38;body.height = minf(stack, 1.0);body.radial_segments = 10
				barrel.mesh = body;barrel.material_override = _mat("wood")
				barrel.position = Vector3(x + column * 0.5, body.height * 0.5 + 0.12, z + piece * 0.5)
				holder.add_child(barrel)
			else:
				var crate = _box(Vector3(column * 0.92, stack, piece * 0.92), "crate", Vector3(x + column * 0.5, stack * 0.5 + 0.12, z + piece * 0.5))
				crate.rotation.y = rng.randf_range(-0.12, 0.12)
				holder.add_child(crate)
			z += piece
		x += column

func _stall(at: Vector3, size: Vector2, height: float):
	var holder = Node3D.new();holder.name = "Stall";holder.position = at;add_child(holder)
	holder.add_child(_box(Vector3(size.x, height, size.y), "wood", Vector3(0, height * 0.5, 0)))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		holder.add_child(_box(Vector3(0.14, 2.5, 0.14), "wood_dark", Vector3(corner.x * (size.x * 0.5 - 0.1), 1.25, corner.y * (size.y * 0.5 - 0.1))))
	var canopy = _box(Vector3(size.x + 0.4, 0.08, size.y + 0.4), "cloth", Vector3(0, 2.5, 0))
	canopy.rotation.x = 0.08;holder.add_child(canopy)

func _well(at: Vector3, radius: float, height: float):
	if _kit_piece("well", at, Vector3(radius * 2.0 + 1.6, height, radius * 2.0 + 1.6)) != null:
		blockers.append({"pos": at, "radius": radius + 0.35})
		return
	var holder = Node3D.new();holder.name = "Well";holder.position = at;add_child(holder)
	holder.add_child(_disc(radius + 0.8, 0.25, "stone_dark", 0.125))
	holder.add_child(_disc(radius, height, "stone", height * 0.5))
	holder.add_child(_disc(radius - 0.35, 0.05, "water", height - 0.1))
	for hand in [-1.0, 1.0]:
		holder.add_child(_box(Vector3(0.2, 2.2, 0.2), "wood_dark", Vector3(hand * (radius - 0.2), 1.1 + height * 0.5, 0)))
	holder.add_child(_box(Vector3(radius * 2.0, 0.2, 0.2), "wood_dark", Vector3(0, 2.2 + height * 0.5, 0)))
	blockers.append({"pos": at, "radius": radius + 0.35})

# Ground-level paving rings: a lighter band of stone, never a step.
func _ring(at: Vector3, radius: float, band: float):
	var ring = MeshInstance3D.new();var torus = TorusMesh.new()
	torus.inner_radius = radius - band;torus.outer_radius = radius;torus.rings = 72;torus.ring_segments = 6
	ring.mesh = torus;ring.material_override = _mat("seal")
	ring.scale = Vector3(1, 0.04, 1);ring.position = at + Vector3(0, 0.01, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _war_table(at: Vector3):
	if _kit_piece("war_table", at, Vector3(2.6, 0.95, 1.5)) != null:
		_lamp(at + Vector3(0, 2.6, 0), 0.4, Color("ffb06a"), 4.0)
		rects.append(Rect2(at.x - 1.3, at.z - 0.75, 2.6, 1.5))
		return
	var holder = Node3D.new();holder.name = "WarTable";holder.position = at;add_child(holder)
	holder.add_child(_box(Vector3(2.6, 0.9, 1.5), "wood_dark", Vector3(0, 0.45, 0)))
	holder.add_child(_box(Vector3(2.3, 0.03, 1.25), "map", Vector3(0, 0.915, 0)))
	for hand in [-1.0, 1.0]:holder.add_child(_box(Vector3(0.08, 0.25, 0.08), "ember", Vector3(hand * 1.05, 1.05, -0.5)))
	_lamp(at + Vector3(0, 2.6, 0), 0.4, Color("ffb06a"), 4.0)
	rects.append(Rect2(at.x - 1.3, at.z - 0.75, 2.6, 1.5))

# Set pieces beyond the walls that tell one room from the next.
func _landmark(row: Dictionary):
	var at = BWRooms.vec(row.at)
	var landmark_sizes = {"bell_tower": Vector3(11, 24, 7), "station_facade": Vector3(22, 11, 4), "wagon": Vector3(3.2, 3, 9), "crane": Vector3(3, 8, 7)}
	if landmark_sizes.has(row.kind) and _kit_piece(row.kind, at, landmark_sizes[row.kind], float(row.get("turn", 0.0))) != null:return
	var holder = Node3D.new();holder.name = String(row.kind).capitalize();holder.position = at;add_child(holder)
	holder.rotation.y = float(row.get("turn", 0.0))
	match row.kind:
		"dead_tree":
			holder.add_child(_disc(0.9, 0.3, "stone_dark", 0.15))
			var trunk = _disc(0.28, 3.4, "wood_dark", 1.7);holder.add_child(trunk)
			for i in 6:
				var limb = _box(Vector3(0.12, 1.8 - i * 0.15, 0.12), "wood_dark", Vector3(0, 2.4 + i * 0.25, 0))
				limb.rotation = Vector3(rng.randf_range(0.5, 1.1), i * 1.05, 0);limb.position += limb.basis.y * 0.8;holder.add_child(limb)
			blockers.append({"pos": at, "radius": 0.7})
		"sign":
			holder.add_child(_box(Vector3(2.0, 2.4, 0.1), "wood_dark", Vector3(0, 2.6, 0.06)))
			var text = Label3D.new();text.text = String(row.get("text", ""));text.font_size = 64;text.pixel_size = 0.0055
			text.modulate = Color("d9cfb8");text.outline_size = 0;text.position = Vector3(0, 2.6, 0.13);holder.add_child(text)
		"bell_tower":
			holder.add_child(_box(Vector3(11, 9, 7), "stone", Vector3(0, 4.5, 0)))
			holder.add_child(_box(Vector3(7, 9, 5), "stone_dark", Vector3(0, 13.5, 0)))
			holder.add_child(_box(Vector3(8, 0.6, 6), "stone", Vector3(0, 18.3, 0)))
			var spire = MeshInstance3D.new();var prism = PrismMesh.new();prism.size = Vector3(7.5, 6, 5.5)
			spire.mesh = prism;spire.material_override = _mat("roof");spire.position.y = 21.6;holder.add_child(spire)
			var bell = MeshInstance3D.new();var shape = CylinderMesh.new()
			shape.top_radius = 1.0;shape.bottom_radius = 1.8;shape.height = 2.6;shape.radial_segments = 20
			bell.mesh = shape;bell.material_override = _mat("iron");bell.position = Vector3(0, 13.2, 2.6)
			holder.add_child(bell)
			for hand in [-1.0, 1.0]:
				holder.add_child(_box(Vector3(1.4, 6.0, 0.08), "cloth", Vector3(hand * 4.6, 12.0, 2.55)))
			_lamp(at + Vector3(0, 11.5, 4.5), 1.6, Color("ffa260"), 9.0)
		"station_facade":
			holder.add_child(_box(Vector3(22, 8, 4), "stone", Vector3(0, 4, 0)))
			var roof = MeshInstance3D.new();var prism = PrismMesh.new();prism.size = Vector3(23, 3.5, 5)
			roof.mesh = prism;roof.material_override = _mat("roof");roof.position.y = 9.75;holder.add_child(roof)
			holder.add_child(_box(Vector3(7, 1.0, 0.2), "wood_dark", Vector3(0, 6.6, 2.1)))
			var sign = Label3D.new();sign.text = "BRACKWELL STATION";sign.font_size = 72;sign.pixel_size = 0.008
			sign.modulate = Color("d7ae64");sign.position = Vector3(0, 6.6, 2.25);holder.add_child(sign)
			for column in 6:
				holder.add_child(_box(Vector3(1.0, 1.6, 0.06), "window", Vector3(-8.5 + column * 3.4, 3.2, 2.03)))
		"wagon":
			holder.add_child(_box(Vector3(3.2, 2.2, 9), "wood_dark", Vector3(0, 1.6, 0)))
			holder.add_child(_box(Vector3(3.4, 0.25, 9.4), "roof", Vector3(0, 2.8, 0)))
		"crane":
			holder.add_child(_box(Vector3(0.6, 7.5, 0.6), "wood_dark", Vector3(0, 3.75, 0)))
			var arm = _box(Vector3(0.4, 0.4, 6.0), "wood_dark", Vector3(0, 7.2, 2.2));arm.rotation.x = -0.25;holder.add_child(arm)
			holder.add_child(_box(Vector3(2.4, 0.5, 2.4), "stone_dark", Vector3(0, 0.25, 0)))

# Iron lamp posts a step in from the walls, every seven metres or so, each with
# its pool of amber light - most of the warmth on the boards comes from these.
func _lanterns():
	var keep_clear = []
	for name in ["EntrySpawn", "RewardPoint", "BossSpawn", "EntranceDoor", "ExitDoor"]:
		if markers.has(name):keep_clear.append(marker(name))
	keep_clear.append_array(enemy_spawns())
	for side in ["north", "west", "east", "south"]:
		var along_x = side in ["north", "south"]
		var reach = (half_x if along_x else half_z) - 1.5
		var count = maxi(2, int(reach * 2.0 / 7.5) + 1)
		for i in count:
			var t = -reach + i * reach * 2.0 / maxf(count - 1, 1)
			var spot = _side_point(side, t, -0.9)
			if _near(spot, keep_clear, 2.6) or in_rect(spot, 0.6):continue
			_lamp_post(spot, true)
		if side == "south":continue
		# Crates and barrels stacked against the wall bases.
		var t2 = -reach
		while t2 < reach:
			t2 += rng.randf_range(3.0, 6.0)
			if rng.randf() < 0.5 or t2 > reach:continue
			var spot = _side_point(side, t2, -0.55)
			if _near(spot, keep_clear, 3.0) or in_rect(spot, 0.8):continue
			var width = rng.randf_range(1.0, 1.6)
			var holder = Node3D.new();holder.name = "Clutter";holder.position = spot;holder.rotation.y = _side_turn(side);add_child(holder, true)
			for piece in int(width / 0.55):
				var x = -width * 0.5 + 0.3 + piece * 0.55
				if rng.randf() < 0.45:
					var barrel = _disc(0.26, 0.8, "wood", 0.4);barrel.position.x = x;holder.add_child(barrel)
				else:
					var crate = _box(Vector3(0.52, rng.randf_range(0.5, 1.0), 0.6), "crate", Vector3(x, 0.0, 0.0))
					crate.position.y = crate.mesh.size.y * 0.5;crate.rotation.y = rng.randf_range(-0.2, 0.2);holder.add_child(crate)
			var size = Vector2(width, 0.7) if along_x else Vector2(0.7, width)
			rects.append(Rect2(spot.x - size.x * 0.5, spot.z - size.y * 0.5, size.x, size.y))

func _near(spot: Vector3, points: Array, gap: float) -> bool:
	for point in points:
		if Vector2(spot.x - point.x, spot.z - point.z).length() < gap:return true
	return false

func _lamp_post(spot: Vector3, solid: bool):
	var post = Node3D.new();post.name = "LampPost";post.position = spot;add_child(post, true)
	post.add_child(_disc(0.22, 0.3, "stone_dark", 0.15))
	var pole = _disc(0.07, 3.0, "iron", 1.6);post.add_child(pole)
	post.add_child(_box(Vector3(0.55, 0.06, 0.06), "iron", Vector3(0.22, 3.05, 0)))
	post.add_child(_box(Vector3(0.26, 0.38, 0.26), "iron", Vector3(0.42, 2.82, 0)))
	var flame = _box(Vector3(0.18, 0.26, 0.18), "flame", Vector3(0.42, 2.82, 0));flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.add_child(flame)
	if quality == "PC":
		var lamp = OmniLight3D.new();lamp.light_color = Color("ffa654");lamp.light_energy = 2.2;lamp.omni_range = 7.5
		lamp.omni_attenuation = 1.6;lamp.position = Vector3(0.42, 2.7, 0);post.add_child(lamp)
	if solid:blockers.append({"pos": spot, "radius": 0.3})

func _lamp(spot: Vector3, energy: float, color: Color = Color("ffb36b"), reach: float = 6.5):
	var flame = _box(Vector3(0.18, 0.28, 0.18), "flame", spot)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	if quality != "PC":return
	var lamp = OmniLight3D.new();lamp.light_color = color;lamp.light_energy = energy;lamp.omni_range = reach
	lamp.position = spot + Vector3(0, 0.2, 0)
	add_child(lamp)

# ------------------------------------------------------------------ kit

static func kit_rows() -> Dictionary:
	if kit.is_empty() and FileAccess.file_exists(KIT_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(KIT_FILE))
		kit = parsed.get("pieces", {}) if parsed is Dictionary else {}
	return kit

static func kit_files(kind: String) -> Array:
	return kit_rows().get(kind, {}).get("files", []).filter(func(path): return ResourceLoader.exists(path))

# A delivered model for this kind of piece, fitted into `size` (the piece's own
# width, height, depth) and set down at `at`. Null while none has been delivered,
# and the caller builds its textured grey box instead.
func _kit_piece(kind: String, at: Vector3, size: Vector3, turn: float = 0.0, parent: Node = null, mirror: bool = false) -> Node3D:
	var files = kit_files(kind)
	if files.is_empty():return null
	var packed = load(files[rng.randi() % files.size()])
	if not packed is PackedScene:return null
	var holder = Node3D.new();holder.name = "Kit_" + kind
	var model: Node3D = packed.instantiate()
	holder.add_child(model)
	var bounds = _prop_bounds(model)
	if bounds.size.x > 0.001 and bounds.size.y > 0.001 and bounds.size.z > 0.001:
		var factor = Vector3.ONE
		if kit_rows()[kind].get("fit", "footprint") == "stretch":
			factor = Vector3(size.x / bounds.size.x, size.y / bounds.size.y, size.z / bounds.size.z)
		else:
			factor = Vector3.ONE * minf(size.x / bounds.size.x, size.z / bounds.size.z)
		if mirror:factor.x = -factor.x
		model.scale = model.scale * factor
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	holder.position = at
	holder.rotation.y = turn
	(parent if parent != null else self).add_child(holder, true)
	return holder

# ------------------------------------------------------------------ primitives

func _box(size: Vector3, material: String, at: Vector3) -> MeshInstance3D:
	var node = MeshInstance3D.new();var mesh = BoxMesh.new();mesh.size = size
	node.mesh = mesh;node.material_override = _mat(material);node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality == "PC" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _disc(radius: float, height: float, material: String, y: float) -> MeshInstance3D:
	var node = MeshInstance3D.new();var mesh = CylinderMesh.new()
	mesh.top_radius = radius;mesh.bottom_radius = radius;mesh.height = height;mesh.radial_segments = 40
	node.mesh = mesh;node.material_override = _mat(material);node.position.y = y
	return node

# One material per surface, shared by every room, so repeated pieces batch.
# Surfaces from tools/gen_room_textures.py, mapped in world space so a texel is
# the same size on a 1 m crate and a 30 m wall: [texture, metres per tile, tint].
const SURFACES = {
	"cobble": ["cobble", 2.6, Color(1, 1, 1)], "street": ["cobble", 2.6, Color(0.34, 0.33, 0.33)],
	"stone": ["ashlar", 3.0, Color(1, 1, 1)], "stone_dark": ["ashlar", 3.0, Color(0.68, 0.68, 0.7)],
	"stone_light": ["ashlar", 1.5, Color(1.35, 1.32, 1.27)], "flagstone": ["flagstone", 2.4, Color(1, 1, 1)],
	"seal": ["ashlar", 2.0, Color(1.12, 1.08, 1.02)],
	"wood": ["wood", 2.0, Color(1, 1, 1)], "wood_dark": ["wood", 2.0, Color(0.55, 0.5, 0.48)],
	"crate": ["crate", 1.2, Color(1, 1, 1)], "timber": ["timber", 3.2, Color(0.82, 0.8, 0.78)],
	"roof": ["slate", 2.2, Color(1, 1, 1)], "iron": ["iron", 1.5, Color(1.8, 1.75, 1.7)],
	"cloth": ["cloth", 1.0, Color(1, 1, 1)],
}
const TEXTURE_DIR = "res://assets/textures/rooms/%s_%s.png"

static func _mat(id: String) -> StandardMaterial3D:
	if materials.has(id):return materials[id]
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.9
	if SURFACES.has(id):
		var spec = SURFACES[id]
		var albedo = load(TEXTURE_DIR % [spec[0], "albedo"])
		if albedo is Texture2D:
			mat.albedo_texture = albedo;mat.albedo_color = spec[2]
			var bumps = load(TEXTURE_DIR % [spec[0], "normal"])
			if bumps is Texture2D:mat.normal_enabled = true;mat.normal_texture = bumps;mat.normal_scale = 0.9
			mat.uv1_triplanar = true;mat.uv1_world_triplanar = true
			mat.uv1_scale = Vector3.ONE / float(spec[1])
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			# Little metalness: with no reflections to pick up, a metallic surface goes black.
			if id == "iron":mat.metallic = 0.2;mat.roughness = 0.7
			materials[id] = mat
			return mat
	match id:
		"stone":mat.albedo_color = Color("4a4e55")
		"stone_dark":mat.albedo_color = Color("34373d")
		"cobble":mat.albedo_color = Color("545a63")
		"street":mat.albedo_color = Color("1c1f24")
		"wood", "timber":mat.albedo_color = Color("5a4434")
		"wood_dark":mat.albedo_color = Color("2e241d")
		"crate":mat.albedo_color = Color("6a5038")
		"roof":mat.albedo_color = Color("26282d")
		"iron":mat.albedo_color = Color("1d1e22");mat.metallic = 0.6;mat.roughness = 0.5
		"cloth":mat.albedo_color = Color("5e1a20")
		"seal":mat.albedo_color = Color("6a6762")
		"water":mat.albedo_color = Color("16222b");mat.roughness = 0.15;mat.metallic = 0.3
		"map":mat.albedo_color = Color("6f5d40")
		"bone":mat.albedo_color = Color("c9bfa8")
		"window", "flame", "ember":
			mat.albedo_color = Color("ffb35c") if id != "ember" else Color("e0582a")
			mat.emission_enabled = true;mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 1.1 if id == "window" else 1.6
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"reward":
			mat.albedo_color = Color("a978ff");mat.emission_enabled = true;mat.emission = Color("9a5cff")
			mat.emission_energy_multiplier = 1.4
		"exit_glow":
			mat.albedo_color = Color(1.0, 0.72, 0.38, 0.28);mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials[id] = mat
	return mat
