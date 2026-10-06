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
	zone = {"id": room_row.id, "name": room_row.name, "ambient": Color(light.get("ambient", "8fa2bb")).lerp(Color("a7a39c"), 0.45),
		"fog": Color(light.get("fog", "1b232f")).lerp(Color("17171a"), 0.4), "energy": float(light.get("energy", 0.55)) + 0.1,
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

func _floor():
	var outer = MeshInstance3D.new();var plane = PlaneMesh.new()
	plane.size = Vector2(half_x * 2.0 + 160.0, half_z * 2.0 + 160.0)
	outer.mesh = plane;outer.material_override = _mat("street");outer.position.y = -0.03
	add_child(outer)
	ground = MeshInstance3D.new();var slab = PlaneMesh.new()
	slab.size = Vector2(half_x * 2.0 + WALL_THICK * 2.0, half_z * 2.0 + WALL_THICK * 2.0)
	slab.subdivide_width = 8;slab.subdivide_depth = 8
	ground.mesh = slab
	var cobble = _mat("cobble").duplicate()
	# The room's ground colour shifts the stone, it does not replace it.
	# Kept a step darker than the walls so telegraphs and bodies read on top of it.
	if cobble.albedo_texture != null:cobble.albedo_color = Color(0.74, 0.71, 0.67).lerp(zone.ground.lightened(0.4), 0.3);cobble.normal_scale = 0.7
	else:cobble.albedo_color = zone.ground
	ground.material_override = cobble
	add_child(ground)

# Walls run just outside the floor. The far sides (north, west) stand at full
# height with the town behind them; the camera-side ones are kept low so they
# never cover a fight. Each wall is cut where a door sits in it.
func _perimeter():
	var room_doors = room.get("doors", {})
	var openings = {"north": [], "south": [], "west": [], "east": []}
	for key in room_doors:
		var spot = BWRooms.vec(room_doors[key].at)
		openings[BWRooms.wall_side(spot, Vector2(half_x, half_z))].append(spot)
	for side in openings:
		var tall = side in ["north", "west"]
		var along_x = side in ["north", "south"]
		var reach = half_x if along_x else half_z
		var cuts = []
		for spot in openings[side]:
			var centre = spot.x if along_x else spot.z
			cuts.append([centre - BWRooms.DOOR_WIDTH * 0.5 - 0.8, centre + BWRooms.DOOR_WIDTH * 0.5 + 0.8])
		cuts.sort_custom(func(a, b): return a[0] < b[0])
		var start = -reach - WALL_THICK
		for cut in cuts + [[reach + WALL_THICK, reach + WALL_THICK]]:
			if cut[0] - start > 0.05:_wall_run(side, start, cut[0], tall)
			start = cut[1]
		if tall:_facades(side, openings[side])
	for key in room_doors:_door(key, room_doors[key])

func _wall_run(side: String, from: float, to: float, tall: bool):
	var height = WALL_HEIGHT if tall else LOW_WALL
	var length = to - from
	var middle = (from + to) * 0.5
	var size: Vector3
	var at: Vector3
	match side:
		"north":size = Vector3(length, height, WALL_THICK);at = Vector3(middle, height * 0.5, -half_z - WALL_THICK * 0.5)
		"south":size = Vector3(length, height, WALL_THICK);at = Vector3(middle, height * 0.5, half_z + WALL_THICK * 0.5)
		"west":size = Vector3(WALL_THICK, height, length);at = Vector3(-half_x - WALL_THICK * 0.5, height * 0.5, middle)
		_:size = Vector3(WALL_THICK, height, length);at = Vector3(half_x + WALL_THICK * 0.5, height * 0.5, middle)
	var kind = "wall_tall" if tall else "wall_low"
	if not kit_files(kind).is_empty():
		# Modular 4 m pieces, stretched a little so a run closes exactly.
		var pieces = maxi(1, ceili(length / 4.0))
		var turn = {"north": 0.0, "south": PI, "west": PI * 0.5, "east": -PI * 0.5}[side]
		var holder = Node3D.new();holder.name = ("Wall_" if tall else "CamWall_") + side;add_child(holder)
		for i in pieces:
			var t = from + (i + 0.5) * length / pieces
			var spot = Vector3(t, 0, at.z) if side in ["north", "south"] else Vector3(at.x, 0, t)
			_kit_piece(kind, spot, Vector3(length / pieces, height, WALL_THICK), turn, holder)
		if not tall:camera_side.append(holder)
		return
	var wall = _box(size, "stone", at)
	wall.name = ("Wall_" if tall else "CamWall_") + side
	add_child(wall)
	# A coping course along the top, so a wall reads as built rather than extruded.
	var cap = Vector3(size.x + (0.2 if size.x > size.z else 0.25), 0.18, size.z + (0.25 if size.x > size.z else 0.2))
	wall.add_child(_box(cap, "stone_dark", Vector3(0, height * 0.5 + 0.09, 0)))
	if not tall:camera_side.append(wall)

# The town behind the far walls: timber houses and their lit windows. All of it
# stands outside the floor, so none of it needs collision.
func _facades(side: String, door_spots: Array):
	var along_x = side == "north"
	var reach = half_x if along_x else half_z
	var cursor = -reach - 3.0
	while cursor < reach + 3.0:
		var width = rng.randf_range(4.5, 7.0)
		var centre = cursor + width * 0.5
		cursor += width + rng.randf_range(0.3, 1.2)
		var blocked = false
		for spot in door_spots:
			if absf(centre - (spot.x if along_x else spot.z)) < width * 0.5 + 3.8:blocked = true
		if blocked:continue
		var depth = rng.randf_range(3.5, 5.0)
		var height = rng.randf_range(4.8, 7.2)
		var house = Node3D.new();house.name = "House"
		var back = depth * 0.5 + WALL_THICK + 0.2
		house.position = Vector3(centre, 0, -half_z - back) if along_x else Vector3(-half_x - back, 0, centre)
		if not along_x:house.rotation.y = PI * 0.5
		add_child(house)
		if _kit_piece("house", Vector3.ZERO, Vector3(width, height, depth), 0.0, house) != null:continue
		# Stone ground storey, half-timbered above, slate on top: the town on the boards.
		var plinth = minf(2.2, height * 0.38)
		house.add_child(_box(Vector3(width, plinth, depth), "stone", Vector3(0, plinth * 0.5, 0)))
		var upper = _box(Vector3(width + 0.3, height - plinth, depth + 0.3), "timber", Vector3(0, plinth + (height - plinth) * 0.5, 0))
		house.add_child(upper)
		house.add_child(_box(Vector3(width + 0.45, 0.22, depth + 0.45), "wood_dark", Vector3(0, plinth, 0)))
		var roof = MeshInstance3D.new();var prism = PrismMesh.new()
		prism.size = Vector3(width + 0.9, rng.randf_range(1.8, 2.8), depth + 0.9)
		roof.mesh = prism;roof.material_override = _mat("roof");roof.position.y = height + prism.size.y * 0.5
		house.add_child(roof)
		if rng.randf() < 0.6:
			var stack_x = rng.randf_range(-width * 0.3, width * 0.3)
			house.add_child(_box(Vector3(0.7, 1.6, 0.7), "stone_dark", Vector3(stack_x, height + prism.size.y * 0.6, -depth * 0.15)))
		var front = depth * 0.5 + 0.17
		house.add_child(_box(Vector3(1.1, 1.9, 0.08), "wood_dark", Vector3(rng.randf_range(-width * 0.3, width * 0.3), 0.95, depth * 0.5 + 0.03)))
		for column in maxi(1, int(width / 2.0)):
			var x = -width * 0.5 + 1.0 + column * 2.0
			if x > width * 0.5 - 0.6:break
			for level in [plinth + (height - plinth) * 0.45]:
				var lit = rng.randf() < 0.55
				house.add_child(_box(Vector3(0.9, 1.1, 0.06), "wood_dark", Vector3(x, level, front)))
				house.add_child(_box(Vector3(0.62, 0.82, 0.07), "window" if lit else "iron", Vector3(x, level, front + 0.01)))
		if rng.randf() < 0.45:
			house.add_child(_box(Vector3(1.0, 2.4, 0.06), "cloth", Vector3(rng.randf_range(-width * 0.3, width * 0.3), plinth + 1.6, front + 0.05)))

func _door(key: String, spec: Dictionary):
	var spot = BWRooms.vec(spec.at)
	var side = BWRooms.wall_side(spot, Vector2(half_x, half_z))
	var tall = side in ["north", "west"]
	var grand = spec.get("grand", false)
	var frame = Node3D.new();frame.name = key.capitalize() + "Door"
	frame.position = Vector3(spot.x, 0, spot.z)
	# Facing the room: north doors look south, and so on.
	var inward = BWRooms.inward(side)
	frame.rotation.y = atan2(inward.x, inward.z)
	add_child(frame)
	var post_height = (5.2 if grand else 4.2) if tall else 2.0
	var half_gap = BWRooms.DOOR_WIDTH * 0.5
	var frame_kind = "gate_frame_grand" if grand and not kit_files("gate_frame_grand").is_empty() else "gate_frame"
	var kit_frame = _kit_piece(frame_kind, Vector3.ZERO, Vector3(BWRooms.DOOR_WIDTH + 1.8, post_height, 1.2), 0.0, frame) if tall else null
	for hand in ([] if kit_frame != null else [-1.0, 1.0]):
		var post = _box(Vector3(0.9, post_height, 1.2), "stone_dark", Vector3(hand * (half_gap + 0.45), post_height * 0.5, 0))
		frame.add_child(post)
		frame.add_child(_box(Vector3(1.1, 0.3, 1.4), "stone", Vector3(hand * (half_gap + 0.45), post_height + 0.15, 0)))
	if tall and kit_frame == null:
		frame.add_child(_box(Vector3(BWRooms.DOOR_WIDTH + 1.8, 0.7, 1.2), "stone_dark", Vector3(0, post_height - 0.35, 0)))
		if grand:frame.add_child(_box(Vector3(BWRooms.DOOR_WIDTH, 1.2, 0.08), "cloth", Vector3(0, post_height - 1.4, 0.62)))
	var leaves = []
	var leaf_height = minf(post_height - 0.8, 3.0) if tall else 1.8
	for hand in [-1.0, 1.0]:
		var pivot = Node3D.new();pivot.name = "%sLeaf_%s" % [key.capitalize(), "L" if hand < 0 else "R"]
		pivot.position = Vector3(hand * half_gap, 0, 0)
		frame.add_child(pivot)
		# One delivered leaf serves both sides: the right one is its mirror.
		if _kit_piece("gate_leaf", Vector3(-hand * half_gap * 0.5, 0.05, 0), Vector3(half_gap, leaf_height, 0.15), 0.0, pivot, hand > 0) == null:
			var leaf = _box(Vector3(half_gap, leaf_height, 0.12), "iron", Vector3(-hand * half_gap * 0.5, leaf_height * 0.5 + 0.05, 0))
			pivot.add_child(leaf)
			for bar in 4:
				leaf.add_child(_box(Vector3(0.08, leaf_height * 0.9, 0.2), "iron", Vector3(-half_gap * 0.5 + 0.35 + bar * (half_gap - 0.7) / 3.0, 0, 0)))
		# Swing away from the room so an opening door never sweeps the floor.
		leaves.append({"pivot": pivot, "rest": 0.0, "sign": -hand})
	var glow = _exit_glow() if key == "exit" else null
	doors[key] = {"leaves": leaves, "open": false, "glow": glow}
	set_door(key, false, false)
	for hand in [-1.0, 1.0]:
		var lamp_at = frame.position + frame.basis * Vector3(hand * (half_gap + 0.45), post_height + 0.55, 0.3)
		_lamp(lamp_at, 0.9)

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
			add_child(_box(Vector3(size.x, 0.6, size.y), "stone_dark", at + Vector3(0, 0.3, 0)))
			add_child(_box(Vector3(size.x * 0.5, 0.45, size.y * 0.4), "stone", at + Vector3(0.15, 0.82, 0.1)))
			var shard = _box(Vector3(0.3, 0.3, 0.5), "stone", at + Vector3(-0.6, 0.75, -0.3))
			shard.rotation = Vector3(0.4, 0.6, 0.2);add_child(shard)
			rects.append(footprint)
		"hearth":
			add_child(_box(Vector3(size.x, height, size.y), "stone_dark", at + Vector3(0, height * 0.5, 0)))
			add_child(_box(Vector3(size.x * 0.6, height * 0.5, 0.2), "ember", at + Vector3(0, height * 0.3, size.y * 0.5 + 0.02)))
			_lamp(at + Vector3(0, height * 0.5, size.y * 0.5 + 0.8), 1.8, Color("ff8a45"), 8.0)
			rects.append(footprint)
		"well":_well(at, float(row.get("radius", 2.0)), height)
		"ring":_ring(at, float(row.get("radius", 10.0)), 0.7)
		"seal":
			var radius = float(row.get("radius", 14.0))
			_ring(at, radius, 0.6);_ring(at, radius * 0.62, 0.35);_ring(at, 1.6, 0.4)
			for turn in 4:
				var spoke = _box(Vector3(0.22, 0.012, radius * 2.0 - 1.0), "seal", at + Vector3(0, 0.014, 0))
				spoke.rotation.y = turn * PI * 0.25;spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(spoke)

# Crates, barrels and a cart packed into the footprint: low enough to see over,
# solid enough to fight around.
func _cargo(at: Vector3, size: Vector2, height: float):
	var holder = Node3D.new();holder.name = "Cargo";holder.position = at;add_child(holder)
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
	match row.kind:
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

# Warm lamps on the far walls. Only the PC profile lights them; the flame quads
# still read on mobile.
func _lanterns():
	for side in ["north", "west"]:
		var along_x = side == "north"
		var reach = half_x if along_x else half_z
		var count = maxi(2, int(reach * 2.0 / 11.0))
		for i in count:
			var t = -reach + (i + 0.5) * reach * 2.0 / count
			var spot = Vector3(t, WALL_HEIGHT + 0.45, -half_z - 0.1) if along_x else Vector3(-half_x - 0.1, WALL_HEIGHT + 0.45, t)
			_lamp(spot, 0.75)

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
	"seal": ["ashlar", 2.0, Color(1.55, 1.5, 1.42)],
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
