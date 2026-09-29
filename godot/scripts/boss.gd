class_name BWBoss
extends RefCounted

# Every health level uses the same vocabulary. Recovery is a punish window;
# direction and origin are committed when the floor warning appears.
const PATTERN = ["attack", "sweep", "cast", "charge", "slam", "summon"]
const WARNING_SHADER = preload("res://shaders/boss_warning.gdshader")
const ATTACKS = {
	"attack": {"windup":0.38,"recovery":0.42,"contact":0.40,"radius":2.8,"arc":70.0,"damage":1.0,"color":Color("ffb55c")},
	"slam": {"windup":1.25,"recovery":0.9,"contact":0.62,"radius":4.2,"arc":360.0,"damage":2.0,"color":Color("ff5547")},
	"sweep": {"windup":0.8,"recovery":0.65,"contact":0.62,"radius":3.8,"arc":270.0,"damage":1.2,"color":Color("ff8755")},
	"charge": {"windup":0.9,"recovery":0.6,"contact":0.38,"radius":8.0,"width":2.0,"damage":1.35,"color":Color("ffcc66")},
	"cast": {"windup":1.0,"recovery":0.65,"contact":0.5,"radius":14.0,"damage":0.7,"color":Color("dc83ff")},
	"summon": {"windup":1.5,"recovery":0.8,"contact":0.45,"radius":3.0,"arc":360.0,"damage":0.0,"color":Color("8dee9e")}
}
const CHARGE_TIME = 0.6

static func tick(world, e: Dictionary, dt: float, speed: float) -> bool:
	if e.hp<=0:return false
	if e.state=="chase":
		var delta: Vector3=world.player.position-e.node.position;delta.y=0
		var direction=delta.normalized()
		var index: int=e.get("pattern_index",0)
		var next: String=PATTERN[index%PATTERN.size()]
		var distance=delta.length()
		var melee=next in ["attack","slam","sweep"]
		var reach: float=ATTACKS[next].radius-0.3 if melee else 12.0
		e.chase_time=e.get("chase_time",0.0)+dt
		# Kiting does not leave the boss trapped waiting for a melee opportunity.
		# This extra lunge closes the gap without consuming the queued pattern step.
		if melee and distance>reach and e.chase_time>2.5 and e.cooldown<=0:
			begin(world,e,"charge");return false
		if distance<=reach and e.cooldown<=0:
			e.pattern_index=index+1;begin(world,e,next);return false
		if distance>0.01:e.visual.rotation.y=lerp_angle(e.visual.rotation.y,atan2(direction.x,direction.z),minf(1.0,dt*8.0))
		if distance>reach:
			direction=world.arena.steer(e.node.position,direction,e.radius)
			e.node.position=world.arena.push_out(e.node.position+direction*speed*dt,e.radius*0.8)
			return true
		return false
	e.timer-=dt
	if e.state=="boss_windup":
		if is_instance_valid(e.get("warning")):
			var mat=e.warning.material_override
			mat.set_shader_parameter("progress",clampf(1.0-e.timer/ATTACKS[e.boss_attack].windup,0,1))
		if e.timer<=0:_strike(world,e)
	elif e.state=="boss_charge":
		var previous: Vector3=e.node.position
		var step=minf(dt,maxf(0.0,e.timer+dt))
		var intended: Vector3=previous+e.attack_direction*(ATTACKS.charge.radius/CHARGE_TIME)*step
		e.node.position=world.arena.push_out(intended,e.radius*0.8)
		# Obstacle contact stops the lunge instead of bending its warning lane.
		if e.node.position.distance_to(intended)>0.15:
			e.node.position=previous;e.timer=0.0
		if not e.charge_hit:
			var closest=Geometry3D.get_closest_point_to_segment(world.player.position,previous,e.node.position)
			if closest.distance_to(world.player.position)<=ATTACKS.charge.width*0.5+0.36:
				e.charge_hit=true;world._hurt_player(e.damage*ATTACKS.charge.damage)
		if e.timer<=0:
			clear_warning(e);e.state="boss_recovery";e.timer=ATTACKS.charge.recovery
	elif e.state=="boss_recovery" and e.timer<=0:
		e.state="chase";e.cooldown=0.45;e.chase_time=0.0
	return false

static func begin(world, e: Dictionary, attack: String):
	clear_warning(e)
	var spec: Dictionary=ATTACKS[attack]
	e.boss_attack=attack;e.state="boss_windup";e.timer=spec.windup;e.chase_time=0.0
	e.attack_origin=e.node.position
	var direction: Vector3=world.player.position-e.node.position;direction.y=0
	e.attack_direction=direction.normalized() if direction.length()>0.01 else Vector3.FORWARD
	e.visual.rotation.y=atan2(e.attack_direction.x,e.attack_direction.z)
	e.visual.action(attack,spec.windup/spec.contact)
	e.warning=_warning(e.attack_origin,e.attack_direction,spec,attack)
	world.add_child(e.warning)
	if attack=="summon":
		e.summon_points=[]
		for index in 10:
			var point=world.arena.push_out(e.attack_origin+e.attack_direction.rotated(Vector3.UP,TAU*index/10.0)*(4.6 if index%2==0 else 6.0),0.5)
			e.summon_points.append(point)
			var portal=_warning(point,Vector3.FORWARD,{"radius":0.7,"arc":360.0,"color":spec.color},"portal")
			e.warning.add_child(portal);portal.top_level=true;portal.position=point+Vector3.UP*0.06
		world.sound("ulti_war_cry")
	elif attack=="cast":
		var glow=world.fx.glow_sprite(spec.color,1.2,1.8)
		e.warning.add_child(glow);glow.position=Vector3(0,1.6,0)

static func _strike(world, e: Dictionary):
	var attack: String=e.boss_attack
	var spec: Dictionary=ATTACKS[attack]
	if attack!="charge":clear_warning(e)
	# Wind-up and recovery use separate speeds, so a long warning does not turn
	# the whole performance into slow motion. The pose at contact stays continuous.
	var recovery: float=spec.recovery+(CHARGE_TIME if attack=="charge" else 0.0)
	if e.visual.animation and e.visual.clips.has(attack):
		var full: float=spec.windup/spec.contact
		e.visual.animation.speed_scale=(full-spec.windup)/recovery
		e.visual.lock_time=recovery
	e.state="boss_recovery";e.timer=spec.recovery
	match attack:
		"attack","slam","sweep":
			if in_sector(world.player.position,e.attack_origin,e.attack_direction,spec.radius,spec.arc):
				world._hurt_player(e.damage*spec.damage)
			if attack=="slam":
				_impact(world,e.attack_origin,spec.radius,spec.color)
				world.fx.radial_streaks(e.attack_origin,spec.radius,spec.color,18)
				world.shake=0.24;world.sound("boss_phase",-3.0)
			else:
				world.fx.slash(e.attack_origin,e.attack_direction,spec.radius,spec.color)
				world.sound("sword_swing")
		"charge":
			e.state="boss_charge";e.timer=CHARGE_TIME;e.charge_hit=false
		"cast":
			world.fx.flash_light(e.attack_origin,spec.color,3.0,5.0,0.3)
			for i in 3:
				var direction: Vector3=e.attack_direction.rotated(Vector3.UP,(i-1)*0.22)
				var bullet=world._bullet(e.attack_origin+direction*0.8,direction,6.5,e.damage*spec.damage,spec.radius,false,0,"boss_cast",0,0,false)
				if bullet!=null:
					bullet.node.add_child(world.fx.glow_sprite(spec.color,0.75,1.6))
			world.sound("orb_cast")
		"summon":
			_impact(world,e.attack_origin,3.5,spec.color)
			for point in e.summon_points:
				world.fx.spark(point+Vector3.UP*0.5,spec.color,20)
				world.spawn_enemy("grunt",point)

static func in_sector(point: Vector3, origin: Vector3, direction: Vector3, radius: float, arc: float) -> bool:
	var offset=point-origin;offset.y=0
	if offset.length()>radius+0.36:return false
	return arc>=360 or offset.length()<0.36 or direction.dot(offset.normalized())>=cos(deg_to_rad(arc*0.5))

static func clear_warning(e: Dictionary):
	if is_instance_valid(e.get("warning")):
		e.warning.queue_free()
	e.warning=null

# Ember outlines use the same sector/lane dimensions as collision. Warnings
# stay fixed in world space and disappear on impact or death, including portals.
static func _warning(origin: Vector3, direction: Vector3, spec: Dictionary, attack: String) -> MeshInstance3D:
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if attack=="charge":
		var side=direction.cross(Vector3.UP)*spec.width*0.5
		var end=direction*spec.radius
		for v in [-side,side,end+side,-side,end+side,end-side]:mesh.surface_add_vertex(v)
	elif attack=="cast":
		for angle in [-0.22,0.0,0.22]:
			var ray=direction.rotated(Vector3.UP,angle)
			var side=ray.cross(Vector3.UP)*0.12;var end=ray*spec.radius
			for v in [-side,side,end+side,-side,end+side,end-side]:mesh.surface_add_vertex(v)
	else:
		var arc=deg_to_rad(spec.arc)
		for i in 48:
			mesh.surface_add_vertex(Vector3.ZERO)
			mesh.surface_add_vertex(direction.rotated(Vector3.UP,-arc*0.5+arc*i/48.0)*spec.radius)
			mesh.surface_add_vertex(direction.rotated(Vector3.UP,-arc*0.5+arc*(i+1)/48.0)*spec.radius)
	mesh.surface_end()
	var node=MeshInstance3D.new();node.mesh=mesh;node.position=origin+Vector3.UP*0.06
	var mat=ShaderMaterial.new();mat.shader=WARNING_SHADER
	mat.set_shader_parameter("tone",spec.color)
	mat.set_shader_parameter("forward_axis",Vector2(direction.x,direction.z))
	mat.set_shader_parameter("radius",float(spec.radius))
	mat.set_shader_parameter("half_arc",deg_to_rad(spec.get("arc",360.0)*0.5))
	mat.set_shader_parameter("lane_width",spec.get("width",2.0))
	mat.set_shader_parameter("shape",1 if attack=="charge" else 2 if attack=="cast" else 0)
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func _impact(world, origin: Vector3, radius: float, color: Color):
	var wave=_warning(origin,Vector3.FORWARD,{"radius":radius,"arc":360.0,"color":color},"impact")
	world.add_child(wave);wave.scale=Vector3.ONE*0.2
	wave.material_override.set_shader_parameter("progress",1.0)
	var tween=wave.create_tween();tween.set_parallel(true)
	tween.tween_property(wave,"scale",Vector3.ONE,0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value):wave.material_override.set_shader_parameter("tone",Color(color*value,1.0)),1.0,0.0,0.55)
	tween.chain().tween_callback(wave.queue_free)
	world.fx.spark(origin+Vector3.UP*0.15,color,24)
	world.fx.flash_light(origin,color,2.0,radius*1.4,0.3)
