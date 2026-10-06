class_name BWRooms
extends RefCounted

# The room pool and the maps that route through it. Both are plain data: a new
# room is a new entry in data/rooms.json or its own file in data/rooms/, and a
# map is a route over room ids. Nothing here caps how many rooms the pool holds,
# and the length of a route - not the size of the pool - is how many rooms a
# night fights before its boss.
#
# Only the records live in memory. A room's scene is loaded when the room is
# entered, never for the whole pool.

const POOL_FILE = "res://data/rooms.json"
const POOL_DIR = "res://data/rooms"
const MAPS_FILE = "res://data/maps.json"
const MAPS_DIR = "res://data/maps"
const TYPES = ["combat", "boss", "merchant", "safehouse"]
# Markers every room of a type has to carry, whether from data or from its scene.
const REQUIRED = {
	"combat": ["EntrySpawn", "EntranceDoor", "ExitDoor", "ExitTrigger", "RewardPoint", "EnemySpawn"],
	"boss": ["EntrySpawn", "EntranceDoor", "ExitDoor", "ExitTrigger", "RewardPoint", "EnemySpawn", "BossSpawn", "BossArenaCenter"],
	"merchant": ["EntrySpawn", "EntranceDoor", "ExitDoor", "ExitTrigger", "RewardPoint"],
	"safehouse": ["EntrySpawn", "EntranceDoor"],
}
# Net opening of a passable door, from the shared layout rules.
const DOOR_WIDTH = 6.0
# How deep into the room the exit's crossing zone reaches from the wall line.
const TRIGGER_DEPTH = 2.4

static var rooms: Dictionary = {}
static var maps: Dictionary = {}
static var map_order: Array = []
static var loaded = false

static func load_all():
	if loaded:return
	loaded = true
	for path in _sources(POOL_FILE, POOL_DIR):
		load_rooms_file(path)
	for path in _sources(MAPS_FILE, MAPS_DIR):
		load_maps_file(path)

static func _sources(file: String, dir: String) -> Array:
	var found = []
	if FileAccess.file_exists(file):found.append(file)
	if DirAccess.dir_exists_absolute(dir):
		var names = Array(DirAccess.get_files_at(dir))
		names.sort()
		for name in names:
			if name.ends_with(".json"):found.append(dir.path_join(name))
	return found

static func _parse(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Unreadable room data: " + path)
		return {}
	return parsed

static func load_rooms_file(path: String) -> int:
	var parsed = _parse(path)
	var rows = parsed.get("rooms", [parsed] if parsed.has("id") else [])
	var count = 0
	for row in rows:
		if row is Dictionary and register(row):count += 1
	return count

static func load_maps_file(path: String) -> int:
	var parsed = _parse(path)
	var rows = parsed.get("maps", [parsed] if parsed.has("id") else [])
	var count = 0
	for row in rows:
		if row is Dictionary and register_map(row):count += 1
	return count

# A record is normalised once, here, so every consumer reads the same derived
# markers: door centres, the exit's crossing zone and Vector3 positions.
static func register(row: Dictionary) -> bool:
	var problems = validate(row)
	if not problems.is_empty():
		push_error("Room %s rejected: %s" % [row.get("id", "?"), "; ".join(problems)])
		return false
	rooms[row.id] = normalised(row)
	return true

static func register_map(row: Dictionary) -> bool:
	if String(row.get("id", "")).is_empty():return false
	if not row.has("route") and not row.has("draw"):return false
	maps[row.id] = row.duplicate(true)
	if not map_order.has(row.id):map_order.append(row.id)
	return true

static func room(id: String) -> Dictionary:
	load_all()
	return rooms.get(id, {})

static func map(id: String) -> Dictionary:
	load_all()
	return maps.get(id, {})

static func map_list() -> Array:
	load_all()
	var list = []
	for id in map_order:list.append(maps[id])
	return list

static func rooms_of(region: String, type: String) -> Array:
	load_all()
	var list = []
	for id in rooms:
		if rooms[id].region == region and rooms[id].type == type:list.append(id)
	list.sort()
	return list

static func safehouse() -> Dictionary:
	load_all()
	for id in rooms:
		if rooms[id].type == "safehouse":return rooms[id]
	return {}

# One night of a map, in the order it is played: the ordinary rooms, then the
# boss, then the merchant. An explicit route is used as written; a draw takes
# count rooms of the region, so a pool of twenty never forces twenty fights.
static func night_plan(map_row: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	var plan = []
	if map_row.has("route"):
		for id in map_row.route:plan.append(String(id))
	elif map_row.has("draw"):
		var pool = rooms_of(map_row.draw.get("region", map_row.get("region", "")), "combat")
		if rng != null:
			for i in range(pool.size() - 1, 0, -1):
				var j = rng.randi_range(0, i)
				var swap = pool[i];pool[i] = pool[j];pool[j] = swap
		plan.append_array(pool.slice(0, int(map_row.draw.get("count", pool.size()))))
	if map_row.has("boss"):plan.append(String(map_row.boss))
	if map_row.has("interlude"):plan.append(String(map_row.interlude))
	return plan

static func validate(row: Dictionary) -> Array:
	var problems = []
	for key in ["id", "type", "size"]:
		if not row.has(key):problems.append("missing " + key)
	if not problems.is_empty():return problems
	if not TYPES.has(row.type):problems.append("unknown type " + str(row.type))
	var size = row.size
	if not size is Array or size.size() != 2 or float(size[0]) < 8.0 or float(size[1]) < 8.0:
		problems.append("size must be [width, depth] of at least 8 m")
		return problems
	var doors = row.get("doors", {})
	if not doors.has("entrance"):problems.append("no entrance door")
	if row.type != "safehouse" and not doors.has("exit"):problems.append("no exit door")
	var markers = row.get("markers", {})
	if not markers.has("EntrySpawn"):problems.append("no EntrySpawn")
	if row.type in ["combat", "boss"] and markers.get("EnemySpawn", []).is_empty():problems.append("no EnemySpawn")
	if row.type == "boss" and not markers.has("BossSpawn"):problems.append("no BossSpawn")
	if row.type in ["combat", "boss"] and waves(row, 1).is_empty():problems.append("no encounter roster")
	return problems

static func vec(value) -> Vector3:
	if value is Vector3:return value
	if value is Array and value.size() >= 2:return Vector3(float(value[0]), 0.0, float(value[1]))
	return Vector3.ZERO

static func normalised(row: Dictionary) -> Dictionary:
	var room_row = row.duplicate(true)
	room_row.name = row.get("name", String(row.id).to_upper())
	room_row.region = row.get("region", "")
	room_row.half = Vector2(float(row.size[0]) * 0.5, float(row.size[1]) * 0.5)
	room_row.markers = derived_markers(row, room_row.half)
	return room_row

# Grey-box markers in the same shape the scene importer produces: Vector3 points,
# EnemySpawn as a list, ExitTrigger as an axis-aligned Rect2 on the ground plane.
static func derived_markers(row: Dictionary, half: Vector2) -> Dictionary:
	var out = {}
	var raw = row.get("markers", {})
	for key in raw:
		if key == "EnemySpawn":
			out.EnemySpawn = []
			for point in raw.EnemySpawn:out.EnemySpawn.append(vec(point))
		else:out[key] = vec(raw[key])
	var doors = row.get("doors", {})
	if doors.has("entrance"):out.EntranceDoor = vec(doors.entrance.at)
	if doors.has("exit"):
		out.ExitDoor = vec(doors.exit.at)
		out.ExitTrigger = exit_zone(out.ExitDoor, half)
	return out

# The crossing zone of a door: the full net opening wide, reaching TRIGGER_DEPTH
# into the room from whichever wall the door sits in.
static func exit_zone(door: Vector3, half: Vector2) -> Rect2:
	var side = wall_side(door, half)
	match side:
		"north":return Rect2(door.x - DOOR_WIDTH * 0.5, -half.y, DOOR_WIDTH, TRIGGER_DEPTH)
		"south":return Rect2(door.x - DOOR_WIDTH * 0.5, half.y - TRIGGER_DEPTH, DOOR_WIDTH, TRIGGER_DEPTH)
		"west":return Rect2(-half.x, door.z - DOOR_WIDTH * 0.5, TRIGGER_DEPTH, DOOR_WIDTH)
		_:return Rect2(half.x - TRIGGER_DEPTH, door.z - DOOR_WIDTH * 0.5, TRIGGER_DEPTH, DOOR_WIDTH)

static func wall_side(door: Vector3, half: Vector2) -> String:
	var gaps = {"north": absf(door.z + half.y), "south": absf(door.z - half.y), "west": absf(door.x + half.x), "east": absf(door.x - half.x)}
	var best = "north"
	for side in gaps:
		if gaps[side] < gaps[best]:best = side
	return best

# The direction a body faces when it steps through a door into the room.
static func inward(side: String) -> Vector3:
	match side:
		"north":return Vector3(0, 0, 1)
		"south":return Vector3(0, 0, -1)
		"west":return Vector3(1, 0, 0)
		_:return Vector3(-1, 0, 0)

# One room's fight for a given night, wave by wave. A room lists `waves` (or a
# single `roster`); every night after the first adds one more body from perNight
# to each wave.
static func waves(room_row: Dictionary, night: int) -> Array:
	var encounter = room_row.get("encounter", {})
	var authored = encounter.get("waves", [])
	if authored.is_empty() and not encounter.get("roster", []).is_empty():authored = [encounter.roster]
	var extra = encounter.get("perNight", [])
	var out = []
	for wave in authored:
		var list = []
		for id in wave:list.append(String(id))
		for i in mini(maxi(night - 1, 0), extra.size()):list.append(String(extra[i]))
		if not list.is_empty():out.append(list)
	return out

# Every body the room fields on that night, all waves together.
static func roster(room_row: Dictionary, night: int) -> Array:
	var list = []
	for wave in waves(room_row, night):list.append_array(wave)
	return list
