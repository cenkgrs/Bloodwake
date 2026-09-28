class_name BWArena
extends Node3D

# The map the run is fought across. It is a single continuous place divided into
# named districts, because the old arena was one tiled square with its only props
# parked at the rim - far outside the camera, which is why it read as endless flat
# ground no matter how much was in it.
#
# Everything here is data. A prop's mesh is either a primitive built in code or a
# res:// path, so a generated model drops in by filling MESH on one row.

const HALF = 36.0            # the map is HALF*2 square
const EDGE = HALF - 1.5      # bodies are kept this far inside the wall

# A district: where it is, how big, and how it is lit. Ambient and fog are blended
# towards whichever zone the player stands in, which is what makes one end of the
# map feel unlike the other without a second scene.
const ZONES = [
	{"id": "courtyard", "name": "THE COURTYARD", "at": Vector2(0, 0), "radius": 15.0,
		"ground": Color("4a4f58"), "ambient": Color("8fa2bb"), "fog": Color("1b232f"),
		"energy": 0.55, "props": {"pillar": 7, "brazier": 4, "rubble": 10, "urn": 6}},
	{"id": "ossuary", "name": "THE OSSUARY", "at": Vector2(-22, -18), "radius": 13.0,
		"ground": Color("5a5548"), "ambient": Color("93ad9a"), "fog": Color("1d261f"),
		"energy": 0.42, "props": {"bones": 14, "wall": 5, "brazier": 2, "urn": 7}},
	{"id": "ruins", "name": "THE RUINS", "at": Vector2(23, -17), "radius": 14.0,
		"ground": Color("4f4a44"), "ambient": Color("a9a08d"), "fog": Color("241f1a"),
		"energy": 0.48, "props": {"wall": 8, "boulder": 6, "rubble": 12, "urn": 5}},
	{"id": "altar", "name": "THE BLOOD ALTAR", "at": Vector2(-20, 21), "radius": 12.0,
		"ground": Color("52393b"), "ambient": Color("c2707a"), "fog": Color("2a1416"),
		"energy": 0.5, "props": {"pillar": 6, "brazier": 5, "bones": 8, "urn": 4}},
	{"id": "grove", "name": "THE DEAD GROVE", "at": Vector2(22, 20), "radius": 14.0,
		"ground": Color("42463f"), "ambient": Color("7d8f86"), "fog": Color("161c19"),
		"energy": 0.34, "props": {"tree": 10, "boulder": 5, "rubble": 8, "urn": 5}},
]

# radius: how far a body is held off it. hp > 0 means it breaks.
# MESH: leave empty for the primitive built below, or point at a res:// scene once
# a real model exists - nothing else has to change.
const PROPS = {
	"pillar": {"radius": 0.62, "height": 3.4, "blocks": true, "hp": 0.0, "mesh": ""},
	"wall": {"radius": 1.15, "height": 1.9, "blocks": true, "hp": 0.0, "mesh": ""},
	"boulder": {"radius": 0.95, "height": 1.3, "blocks": true, "hp": 0.0, "mesh": ""},
	"tree": {"radius": 0.5, "height": 4.2, "blocks": true, "hp": 0.0, "mesh": ""},
	"brazier": {"radius": 0.45, "height": 1.5, "blocks": true, "hp": 0.0, "mesh": "", "light": true},
	"urn": {"radius": 0.42, "height": 0.9, "blocks": false, "hp": 12.0, "mesh": ""},
	"bones": {"radius": 0.7, "height": 0.25, "blocks": false, "hp": 0.0, "mesh": ""},
	"rubble": {"radius": 0.6, "height": 0.28, "blocks": false, "hp": 0.0, "mesh": ""},
}

var quality = "PC"
var rng = RandomNumberGenerator.new()
var blockers: Array = []      # [{pos:Vector3, radius:float}]
var breakables: Array = []    # [{node, pos, radius, hp, kind}]
var stone: StandardMaterial3D
var ground: MeshInstance3D

signal prop_broken(position: Vector3, kind: String)

func build(profile: String, seed_value: int):
	quality = profile
	rng.seed = seed_value
	stone = StandardMaterial3D.new()
	stone.albedo_color = Color("3a4049")
	stone.roughness = 0.92
	_ground()
	_walls()
	for zone in ZONES:
		_populate(zone)

func _ground():
	ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	ground.mesh = plane
	var dirt = StandardMaterial3D.new()
	dirt.albedo_texture = load("res://assets/art/arena.png")
	dirt.uv1_scale = Vector3(16, 16, 16)
	dirt.roughness = 0.95
	dirt.albedo_color = Color("545a63")
	ground.material_override = dirt
	add_child(ground)
	# A tinted disc per district. The ground is the cheapest way to tell the player
	# which part of the map they are standing in, and it costs one quad each.
	for zone in ZONES:
		var patch = MeshInstance3D.new()
		var disc = CylinderMesh.new()
		disc.top_radius = zone.radius
		disc.bottom_radius = zone.radius
		disc.height = 0.02
		disc.radial_segments = 32
		patch.mesh = disc
		var tint = StandardMaterial3D.new()
		tint.albedo_texture = load("res://assets/art/arena.png")
		tint.uv1_scale = Vector3(6, 6, 6)
		tint.albedo_color = zone.ground
		tint.roughness = 0.95
		patch.material_override = tint
		patch.position = Vector3(zone.at.x, 0.012, zone.at.y)
		add_child(patch)

func _walls():
	for edge in 4:
		var wall = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(HALF * 2.0 + 1.0, 2.2, 0.6)
		wall.mesh = box
		wall.material_override = stone
		wall.position = Vector3(0, 1.1, -HALF) if edge == 0 else Vector3(0, 1.1, HALF) \
			if edge == 1 else Vector3(-HALF, 1.1, 0) if edge == 2 else Vector3(HALF, 1.1, 0)
		if edge > 1:
			wall.rotation.y = PI / 2
		add_child(wall)

func _populate(zone: Dictionary):
	for kind in zone.props:
		for i in int(zone.props[kind]):
			# Props are pushed off the centre so the middle of a district stays
			# fightable; a ring of cover reads better than a field of obstacles.
			var angle = rng.randf() * TAU
			var reach = zone.radius * sqrt(rng.randf_range(0.18, 1.0))
			var spot = Vector3(zone.at.x + cos(angle) * reach, 0.0, zone.at.y + sin(angle) * reach)
			spot.x = clampf(spot.x, -EDGE, EDGE)
			spot.z = clampf(spot.z, -EDGE, EDGE)
			if _crowded(spot, PROPS[kind].radius):
				continue
			_place(kind, spot, zone)

func _crowded(spot: Vector3, radius: float) -> bool:
	for other in blockers:
		if other.pos.distance_to(spot) < other.radius + radius + 0.7:
			return true
	for other in breakables:
		if other.pos.distance_to(spot) < other.radius + radius + 0.5:
			return true
	return false

func _place(kind: String, spot: Vector3, zone: Dictionary):
	var spec = PROPS[kind]
	var node = _model(kind, spec, zone)
	node.position = spot
	node.rotation.y = rng.randf() * TAU
	add_child(node)
	if spec.blocks:
		blockers.append({"pos": spot, "radius": spec.radius})
	if spec.hp > 0.0:
		breakables.append({"node": node, "pos": spot, "radius": spec.radius, "hp": spec.hp, "kind": kind})

# Primitive stand-ins. Every one of these is a single mesh with a known footprint,
# so swapping in a generated model means loading a scene here instead.
func _model(kind: String, spec: Dictionary, zone: Dictionary) -> Node3D:
	if not String(spec.mesh).is_empty():
		var packed = load(spec.mesh)
		if packed is PackedScene:
			return packed.instantiate()
	var holder = Node3D.new()
	var body = MeshInstance3D.new()
	var skin = stone.duplicate()
	match kind:
		"pillar":
			var column = CylinderMesh.new()
			column.top_radius = spec.radius * 0.8
			column.bottom_radius = spec.radius
			column.height = spec.height
			column.radial_segments = 10
			body.mesh = column
			body.position.y = spec.height * 0.5
		"wall":
			var slab = BoxMesh.new()
			slab.size = Vector3(spec.radius * 2.2, spec.height, spec.radius * 0.7)
			body.mesh = slab
			body.position.y = spec.height * 0.5
			body.rotation.z = rng.randf_range(-0.05, 0.05)
		"boulder":
			var rock = SphereMesh.new()
			rock.radius = spec.radius
			rock.height = spec.height
			rock.radial_segments = 8
			rock.rings = 5
			body.mesh = rock
			body.position.y = spec.height * 0.32
			skin.albedo_color = Color("474b52")
		"tree":
			var trunk = CylinderMesh.new()
			trunk.top_radius = spec.radius * 0.35
			trunk.bottom_radius = spec.radius
			trunk.height = spec.height
			trunk.radial_segments = 7
			body.mesh = trunk
			body.position.y = spec.height * 0.5
			skin.albedo_color = Color("2f2a25")
			for i in 3:
				var limb = MeshInstance3D.new()
				var branch = CylinderMesh.new()
				branch.top_radius = 0.04
				branch.bottom_radius = 0.12
				branch.height = 1.6
				branch.radial_segments = 5
				limb.mesh = branch
				limb.material_override = skin
				limb.position = Vector3(0, spec.height * rng.randf_range(0.6, 0.9), 0)
				limb.rotation = Vector3(rng.randf_range(0.5, 1.1), rng.randf() * TAU, 0)
				holder.add_child(limb)
		"brazier":
			var bowl = CylinderMesh.new()
			bowl.top_radius = spec.radius
			bowl.bottom_radius = spec.radius * 0.35
			bowl.height = spec.height
			bowl.radial_segments = 8
			body.mesh = bowl
			body.position.y = spec.height * 0.5
			var fire = MeshInstance3D.new()
			var flame = SphereMesh.new()
			flame.radius = spec.radius * 0.6
			flame.height = spec.radius * 1.5
			fire.mesh = flame
			var lit = StandardMaterial3D.new()
			lit.albedo_color = Color("ff9b48")
			lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fire.material_override = lit
			fire.position.y = spec.height + 0.2
			holder.add_child(fire)
			# Unlike the old rim torches, these stand inside the play space, so their
			# light is actually seen.
			if quality == "PC":
				var lamp = OmniLight3D.new()
				lamp.light_color = Color("ff9854")
				lamp.light_energy = 2.2
				lamp.omni_range = 7.0
				lamp.position.y = spec.height + 0.4
				holder.add_child(lamp)
		"urn":
			var pot = CylinderMesh.new()
			pot.top_radius = spec.radius * 0.6
			pot.bottom_radius = spec.radius
			pot.height = spec.height
			pot.radial_segments = 8
			body.mesh = pot
			body.position.y = spec.height * 0.5
			skin.albedo_color = Color("6b5a49")
		"bones":
			var pile = SphereMesh.new()
			pile.radius = spec.radius
			pile.height = spec.height * 2.0
			pile.radial_segments = 7
			pile.rings = 3
			body.mesh = pile
			body.position.y = spec.height * 0.25
			skin.albedo_color = Color("9a9382")
		_:
			var heap = BoxMesh.new()
			heap.size = Vector3(spec.radius * 1.8, spec.height, spec.radius * 1.5)
			body.mesh = heap
			body.position.y = spec.height * 0.5
			skin.albedo_color = zone.ground.darkened(0.15)
	if body.mesh != null:
		body.material_override = skin
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality == "PC" \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(body)
	return holder

# ------------------------------------------------------------------ queries

func zone_at(spot: Vector3) -> Dictionary:
	var best = ZONES[0]
	var nearest = INF
	for zone in ZONES:
		var gap = Vector2(spot.x, spot.z).distance_to(zone.at)
		if gap < nearest:
			nearest = gap
			best = zone
	return best

func zone_by_id(id: String) -> Dictionary:
	for zone in ZONES:
		if zone.id == id:
			return zone
	return ZONES[0]

func centre_of(zone: Dictionary) -> Vector3:
	return Vector3(zone.at.x, 0.0, zone.at.y)

# Circle push-out. There is no physics in this project and adding it would mean
# rewriting how every body moves, so blockers are resolved the way everything else
# here is: by hand, against a radius.
func push_out(spot: Vector3, radius: float) -> Vector3:
	var moved = spot
	for block in blockers:
		var away = Vector3(moved.x - block.pos.x, 0.0, moved.z - block.pos.z)
		var gap = away.length()
		var want = block.radius + radius
		if gap < want:
			if gap < 0.001:
				away = Vector3(1, 0, 0)
				gap = 0.001
			moved += away / gap * (want - gap)
	moved.x = clampf(moved.x, -EDGE, EDGE)
	moved.z = clampf(moved.z, -EDGE, EDGE)
	return moved

# Enemies walk straight at the player, so a blocker in the way would have them
# grinding into it. This nudges them around the obstacle instead: not pathfinding,
# just enough steering to clear a pillar.
func steer(from: Vector3, direction: Vector3, radius: float) -> Vector3:
	for block in blockers:
		var offset = Vector3(block.pos.x - from.x, 0.0, block.pos.z - from.z)
		var distance = offset.length()
		var want = block.radius + radius + 0.35
		if distance > 6.0 or distance < 0.001:
			continue
		var ahead = offset.normalized().dot(direction)
		if ahead <= 0.1:
			continue
		var side = offset.normalized().cross(Vector3.UP)
		var lateral = side.dot(direction)
		if absf(offset.normalized().cross(direction).y) * distance > want:
			continue
		var urgency = clampf(1.0 - (distance - want) / 5.0, 0.0, 1.0)
		direction = (direction + side * (1.0 if lateral >= 0.0 else -1.0) * urgency * 1.4).normalized()
	return direction

# Anything breakable inside the radius takes the hit. Returns what broke so the
# caller can pay out drops without this file knowing what a pickup is.
func damage_area(spot: Vector3, radius: float, damage: float) -> Array:
	var broken = []
	for prop in breakables.duplicate():
		if prop.pos.distance_to(Vector3(spot.x, prop.pos.y, spot.z)) > radius + prop.radius:
			continue
		prop.hp -= damage
		if prop.hp > 0.0:
			var shove = create_tween()
			shove.tween_property(prop.node, "rotation:z", rng.randf_range(-0.12, 0.12), 0.08)
			shove.tween_property(prop.node, "rotation:z", 0.0, 0.14)
			continue
		breakables.erase(prop)
		broken.append({"position": prop.pos, "kind": prop.kind})
		prop_broken.emit(prop.pos, prop.kind)
		_shatter(prop)
	return broken

func _shatter(prop: Dictionary):
	var origin = prop.node.position
	prop.node.queue_free()
	if quality != "PC":
		return
	# Cheap debris: a handful of the prop's own colour thrown outwards.
	for i in 7:
		var chunk = MeshInstance3D.new()
		var bit = BoxMesh.new()
		var size = rng.randf_range(0.08, 0.2)
		bit.size = Vector3(size, size, size)
		chunk.mesh = bit
		var shard = StandardMaterial3D.new()
		shard.albedo_color = Color("6b5a49")
		shard.roughness = 0.9
		chunk.material_override = shard
		chunk.position = origin + Vector3(0, 0.4, 0)
		add_child(chunk)
		var angle = TAU * i / 7.0 + rng.randf_range(-0.4, 0.4)
		var land = origin + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.8, 2.0)
		var toss = create_tween()
		toss.set_parallel(true)
		toss.tween_property(chunk, "position", land + Vector3(0, 0.06, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		toss.tween_property(chunk, "rotation", Vector3(rng.randf() * 6, rng.randf() * 6, rng.randf() * 6), 0.5)
		toss.chain().tween_interval(1.4)
		toss.chain().tween_callback(chunk.queue_free)
