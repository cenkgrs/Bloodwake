class_name BWWorld
extends Node3D

signal wave_cleared
signal run_ended
signal changed

var run: BWRun
var audio: BWAudio
var player: Node3D
var visual: BWVisual
const CAMERA_OFFSET = Vector3(12,14,16)
const CAMERA_SIZE = 13.0
var camera: Camera3D
var arena: BWArena
var fx: BWFx
var skills: BWSkills
var environment: Environment
var wave_zone = "courtyard"
var enemies: Array = []
var bullets: Array = []
var pickups: Array = []
var hazards: Array = []
var spawn_timer = 0.0
var spawned = 0
var spawn_slot = 0
var spawn_bearing = 0.0
var running = true
var auto_fire = false
var move_input = Vector2.ZERO
var fire_input = false
var touch_aim = Vector2.ZERO
var aim = Vector3.FORWARD
var last_move = Vector3.FORWARD
var player_velocity = Vector3.ZERO
var enemy_serial = 0
var quality = "PC"
var elapsed = 0.0
var rest_time = 0.0
var hit_flash = 0.0
var flash_rect: ColorRect
var combo_step = 0
var mark_chain = 0
var combo_timer = 0.0
var swing_gate = 0.0
var shake = 0.0
var airborne = false
var pending_attacks: Array = []
var bullet_mesh: SphereMesh
var bullet_material: StandardMaterial3D
var rng = RandomNumberGenerator.new()
const ARENA_HALF = BWArena.HALF
# How far out a body appears: outside the view the camera gives, close enough
# that it is on the player within a couple of seconds.
const SPAWN_RING = 9.6
# The ring is divided into this many bearings, and each spawn takes the next one.
const SPAWN_ARC = 8
# Coprime with SPAWN_ARC, so successive spawns land across the ring from each
# other rather than walking round it in order.
const SPAWN_STRIDE = 3
# Inside this the approach boost is gone and a body fights at its catalogued
# speed; it ramps to CLOSE_RUSH over the next CLOSE_FALLOFF metres.
const CLOSE_RANGE = 2.6
const CLOSE_FALLOFF = 6.0
const CLOSE_RUSH = 2.45
# How much room a body leaves the player. The catalogued attack range on a grunt is
# shorter than the two bodies are wide, so a wave used to close until it was
# standing inside the player. Enemies now ring them at arm's length: the press is
# still a press, but every member of it is a separate thing you can see and hit.
const PERSONAL_SPACE = 0.62
# A swing is one blade travelling through one arc, so only what is in front of it
# is cut, and only the nearest few. Landing on everything within reach is what made
# a hit on six bodies feel like a hit on none. The shockwave upgrade is the stated
# exception: that swing is bought to clear a crowd, so it keeps the full circle.
const MELEE_ARC = 105.0
const MELEE_TARGETS = 3
const SHOCKWAVE_TARGETS = 6
# What a landed hit does to the body that took it, beyond the number: it is stopped
# for a beat and shoved back. Armour and elites resist both.
const STAGGER_TIME = 0.15
const KNOCKBACK = 0.24
# Where missile troops stand: off to the player's left or right, far enough out to
# read as the edge of the arena. Posts use the camera’s ground-plane basis so they stay
# screen-horizontal with the diagonal view and expose the attack wind-up.
const FLANK_STANDOFF = 8.6
# How long an archer holds its aim before the arrow leaves, and how long a mage
# commits to a cast. Both exist so a shot from the flank can be read and dodged.
const DRAW_TIME = 0.4
const CAST_TIME = 0.55
# Runes a mage may have standing at once. A wave of mages must not carpet the floor.
const HAZARD_LIMIT = 6
const ARMORED = ["tank","boss"]
const WEAPON_SHOT = {"rapid_rifle":"gun_rifle","basic_pistol":"gun_pistol","shotgun":"gun_shotgun","magic_orb":"orb_cast","lightning":"lightning_cast"}
const HURT_FLASH_COLOR = Color("ff3b30")
# The melee chain, one clip per link. Attack1-3 are cut from a single Mixamo
# performance so the seams share a pose; Attack4 is its own swing and ends the run.
const COMBO = ["attack1","attack2","attack3","attack4"]
# Where in each clip the blade is actually moving fastest, measured off the source
# curves. The damage used to land at a flat 32% of every clip, which read early on
# the wind-up-heavy links and late on the quick ones.
const IMPACT = {"attack1":0.46,"attack2":0.33,"attack3":0.22,"attack4":0.26,"spinattack":0.55,"attack":0.32}
# A link may be cancelled into the next one once this much of it has played. Waiting
# for the whole clip reads as unresponsive; cancelling before the impact would skip
# the hit. Just past the strike is where a chain wants to accept the next input.
const CANCEL = 0.62
# How much faster than authored the chain plays. The Mixamo greatsword performance
# is heavier than this game wants: 2.5 read as fast-forward, 1.0 read as sluggish.
# Static so the debug menu can dial it between runs while it is being tuned.
static var combo_pace = 1.5
static var spin_pace = 1.5
# How much of its cooldown a chainless rig may spend on one swing. Under 1 so the
# blade has finished before the next is allowed, leaving the strike readable.
const SOLO_SWING = 0.9
const SPIN_COOLDOWN = 2.6
const SPIN_RADIUS = 1.9
const SPIN_DAMAGE = 2.2
const ENEMY_COLORS = {"grunt":"8b6256","archer":"9a789e","tank":"65463f","assassin":"667482","healer":"72b78e","commander":"c4a75e","mage":"8f6fc4","boss":"8a3440"}

func start(state: BWRun,profile: String="PC",mixer: BWAudio=null):
	run=state;quality=profile;audio=mixer;rng.randomize()
	BWVisual.warm_enemy_models()
	fx=BWFx.new();add_child(fx);fx.configure(quality)
	skills=BWSkills.new();add_child(skills);skills.bind(self)
	_environment()
	player=Node3D.new();player.name="Player";add_child(player)
	# Enemies read as 1.7-3.5 m (tanks/bosses run bigger on purpose); the player
	# was left at the 1.8 m rig default and looked undersized next to them.
	visual=BWVisual.new();player.add_child(visual);visual.configure(run.class_id,false,Color.WHITE,2.05)
	get_viewport().msaa_3d=Viewport.MSAA_4X if quality=="PC" else Viewport.MSAA_DISABLED
	var fill=OmniLight3D.new();fill.position=Vector3(0,2.5,1);fill.omni_range=4;fill.light_energy=1.0;fill.light_color=Color("d1def0");player.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=CAMERA_SIZE
	camera.position=CAMERA_OFFSET;camera.current=true;add_child(camera);camera.look_at(Vector3.ZERO)
	last_move=screen_direction(Vector2.UP);aim=last_move
	var flash_layer=CanvasLayer.new();flash_layer.layer=2;add_child(flash_layer)
	flash_rect=ColorRect.new();flash_rect.color=Color(HURT_FLASH_COLOR,0.0)
	flash_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	bullet_mesh=SphereMesh.new();bullet_mesh.radius=0.07;bullet_mesh.height=0.14;bullet_mesh.radial_segments=8;bullet_mesh.rings=4
	bullet_material=StandardMaterial3D.new();bullet_material.albedo_color=Color("ffd99a");bullet_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED

func _environment():
	var env_node=WorldEnvironment.new();var env=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("121923")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("a6bad0");env.ambient_light_energy=0.55
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_white=1.8
	env.glow_enabled=true;env.glow_intensity=0.9;env.glow_strength=1.1;env.glow_bloom=0.25
	env.glow_hdr_threshold=0.85;env.glow_hdr_scale=2.0;env.glow_blend_mode=Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in range(1,5):env.set_glow_level(i,1.0)
	env.set_glow_level(5,0.6);env.set_glow_level(6,0.3)
	env.adjustment_enabled=true;env.adjustment_contrast=1.06;env.adjustment_saturation=1.12
	env.fog_enabled=true;env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_density=0.0
	env.fog_depth_begin=18.0;env.fog_depth_end=52.0;env.fog_depth_curve=1.4
	environment=env
	env_node.environment=env;add_child(env_node)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("b4c7e0");sun.light_energy=1.15;sun.shadow_enabled=quality=="PC";sun.directional_shadow_max_distance=45;add_child(sun)
	arena=BWArena.new();add_child(arena);arena.build(quality,rng.randi())
	arena.prop_broken.connect(_prop_broken)
	_apply_zone(arena.zone_at(Vector3.ZERO),1.0)

# The district a wave belongs to is a plain function of the wave number, so it
# needs no state and a run always walks the same tour. Boss waves are always held
# at the altar.
func current_zone() -> Dictionary:
	if arena==null:return {}
	return arena.zone_at(player.position if player!=null else Vector3.ZERO)

func wave_zone_id() -> String:
	var zone=current_zone()
	return zone.id if zone.has("id") else "courtyard"

# The district the player is standing in. It names where the fight is, it does not
# send the player anywhere - the wave comes to them.
func zone_hint() -> String:
	if arena==null or not running:return ""
	var zone=current_zone()
	return zone.name if zone.has("name") else ""

# Ambient and fog are blended toward the district under the player. One end of the
# map lit like the other is what made every part of it feel the same.
func _apply_zone(zone: Dictionary,weight: float):
	if environment==null:return
	environment.ambient_light_color=environment.ambient_light_color.lerp(zone.ambient,weight)
	environment.ambient_light_energy=lerpf(environment.ambient_light_energy,zone.energy,weight)
	environment.fog_light_color=environment.fog_light_color.lerp(zone.fog,weight)
	environment.background_color=environment.background_color.lerp(zone.fog.darkened(0.25),weight)
	environment.fog_density=lerpf(environment.fog_density,0.55,weight)

func _prop_broken(position: Vector3,kind: String):
	sound("sword_hit_armor",0.0,1)
	fx.spark(position+Vector3.UP*0.5,Color("d8c39a"),12)
	if rng.randf()<0.35:_drop(position,"gold",3+rng.randi_range(0,4))

func _physics_process(dt: float):
	if run==null:return
	if not running:
		visual.tick(dt,false)
		return
	elapsed+=dt
	if rest_time>0:
		rest_time=maxf(0,rest_time-dt)
		if rest_time==0:changed.emit()
	run.ability_cd=maxf(0,run.ability_cd-dt)
	run.tick_skills(dt)
	run.stats.hp=minf(run.stats.maxHp,run.stats.hp+run.stats.regenPerSecond*dt)
	# Enemies get visibly bigger/tankier as the run goes on (elite odds and the
	# tank/boss mix both climb with wave); grow the player to match instead of
	# shrinking into an ant by wave 10, capped so a long run doesn't get silly.
	visual.set_level_scale(BWData.actor_growth(run.level))
	var input=Input.get_vector("move_left","move_right","move_up","move_down")+move_input
	input=input.limit_length()
	var movement=screen_direction(input)
	var previous_player_position=player.position
	# A leap owns the body until it lands; steering mid-flight would fight its tween.
	if airborne:movement=Vector3.ZERO
	else:
		player.position+=movement*run.stats.moveSpeed*BWData.UNIT*dt
		player.position=arena.push_out(player.position,0.42)
	var measured_velocity=(player.position-previous_player_position)/maxf(dt,0.001) if not airborne else Vector3.ZERO
	player_velocity=player_velocity.lerp(measured_velocity,1.0-exp(-dt*6.0))
	if movement.length_squared()>0.001:last_move=movement.normalized()
	var aim_stick=Input.get_vector("aim_left","aim_right","aim_up","aim_down")
	if touch_aim.length_squared()>0.04:aim=screen_direction(touch_aim).normalized()
	elif aim_stick.length_squared()>0.04:aim=screen_direction(aim_stick).normalized()
	elif Input.is_action_pressed("fire") and not OS.has_feature("mobile"):
		var mouse=get_viewport().get_mouse_position();var plane=Plane(Vector3.UP,0)
		var hit=plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null and player.position.distance_squared_to(hit)>0.01:aim=(hit-player.position).normalized()
	elif movement.length_squared()>0.001:aim=last_move
	var facing=aim if Input.is_action_pressed("fire") or aim_stick.length_squared()>0.04 or touch_aim.length_squared()>0.04 else last_move
	if facing.length_squared()>0.01:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),minf(1,dt*16))
	visual.tick(dt,movement.length_squared()>0.001,run.stats.moveSpeed/BWData.stats(run.class_id).moveSpeed)
	_apply_zone(arena.zone_at(player.position),1-exp(-dt*1.2))
	var desired=player.position+CAMERA_OFFSET;camera.position=camera.position.lerp(desired,1-exp(-dt*10))
	if shake>0:camera.position+=camera.basis.x*rng.randf_range(-shake,shake)+camera.basis.y*rng.randf_range(-shake,shake);shake=move_toward(shake,0,dt*2)
	if combo_timer>0:combo_timer=maxf(0,combo_timer-dt)
	if swing_gate>0:swing_gate=maxf(0,swing_gate-dt)
	if hit_flash>0 or flash_rect.color.a>0:hit_flash=maxf(0,hit_flash-dt*1.9);flash_rect.color.a=hit_flash
	_pending_attacks(dt)
	if not airborne:_weapons(dt)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy.node):_enemy_tick(enemy,dt)
	_projectiles(dt)
	_hazards(dt)
	if run.stats.hp>0:_pickups(dt)
	if run.stats.hp<=0:
		running=false;pending_attacks.clear();visual.action("death");sound("player_death")
		if audio!=null:audio.music("")
		run_ended.emit()
	elif rest_time<=0:_spawn_tick(dt)

func _spawn_tick(dt: float):
	var rules=BWData.wave_rules(run.wave)
	if spawned>=rules.quota:
		if enemies.is_empty():
			for pickup in pickups:
				if pickup.kind=="xp":run.add_xp(pickup.amount)
				pickup.node.queue_free()
			pickups.clear();pending_attacks.clear();clear_hazards();running=false;wave_cleared.emit()
		return
	# The wave forms around the player, wherever that is. The district under them
	# only decides what turns up, so walking somewhere changes who comes for you
	# rather than whether anything does.
	var zone=current_zone()
	spawn_timer-=dt
	if spawn_timer>0 or enemies.size()>=rules.cap:return
	spawn_timer=rules.interval
	var id="boss" if rules.boss else _draw_from(spawn_pool(run.wave,zone.get("id","courtyard")))
	spawn_enemy(id,_spawn_point(),not rules.boss and rng.randf()<rules.elite)
	spawned+=1

# Where the next body comes in. Taking a uniformly random bearing let a run of
# spawns land on the same side and leave the player an open back to walk into;
# handing each spawn the next slot of a rotating ring puts them all the way round
# instead. The slot is jittered so the ring does not read as a drawn circle.
func _spawn_point() -> Vector3:
	var slot=TAU*float(spawn_slot%SPAWN_ARC)/float(SPAWN_ARC)
	# Step by an amount coprime with the slot count: every bearing is still used
	# once per turn of the ring, but consecutive spawns land across from each other
	# rather than sweeping round in order.
	spawn_slot+=SPAWN_STRIDE
	var angle=spawn_bearing+slot+rng.randf_range(-0.28,0.28)
	# Two arrivals out of three contest the direction of travel. The remaining
	# arrival preserves rear pressure; no new enemies are added outside the quota.
	if player_velocity.length()>0.7 and (spawn_slot/SPAWN_STRIDE)%3!=0:
		angle=atan2(player_velocity.z,player_velocity.x)+(-0.65 if spawn_slot%2==0 else 0.65)+rng.randf_range(-0.18,0.18)
	var distance=SPAWN_RING+rng.randf_range(-0.9,0.9)
	var best=Vector3.ZERO;var best_score=-INF
	# Sample alternate bearings when an edge or pillar blocks the desired arrival.
	# Never clamp a spawn onto the player at the arena boundary.
	for i in 16:
		var bearing=angle+TAU*i/16.0
		var candidate=arena.push_out(player.position+Vector3(cos(bearing),0,sin(bearing))*distance,0.6)
		var gap=candidate.distance_to(player.position)
		if gap<7.5:continue
		var score=cos(bearing-angle)*2.0
		for enemy in enemies:
			var separation=candidate.distance_to(enemy.node.position)
			if separation<3.0:score-=(3.0-separation)*0.35
		if score>best_score:best_score=score;best=candidate
	return best if best_score>-INF else arena.push_out(player.position-Vector3(cos(angle),0,sin(angle))*SPAWN_RING,0.6)

# The goal is a position ahead of the runner, not their trail. Stable left/right
# roles split a pack; the flank width collapses near contact so enemies commit
# their attacks instead of orbiting. Ranged/support actors use this only to close.
func _pursuit_direction(e: Dictionary, distance: float) -> Vector3:
	if e.has("summon_route") and e.summon_route<2:
		return _summon_pursuit(e)
	var direct: Vector3=player.position-e.node.position;direct.y=0
	if distance<1.5:return direct.normalized()
	var role: int=e.hunt_role
	var ahead=player_velocity.limit_length(run.stats.moveSpeed*BWData.UNIT)
	var lead=clampf(distance/6.0,0.35,1.5)*(0.45 if role==0 else 1.0)
	var target: Vector3=player.position+ahead*lead
	var spread=clampf((distance-1.5)/3.0,0.0,1.0)
	if role!=0:
		if ahead.length()>0.7:
			var lateral=ahead.normalized().cross(Vector3.UP)
			target+=lateral*e.hunt_side*(1.8+e.hunt_depth*0.8)*spread
		else:
			var outward=(e.node.position-player.position).normalized()
			target+=outward.rotated(Vector3.UP,e.hunt_side*0.7)*2.0*spread
	return arena.steer(e.node.position,(target-e.node.position).normalized(),e.radius)

# Boss adds first travel around the player's flanks, then close from those sides.
# This route is exclusive to summoned bodies; ordinary wave pursuit is unchanged.
func _summon_pursuit(e: Dictionary) -> Vector3:
	var forward: Vector3=e.summon_forward
	var side=forward.cross(Vector3.UP)*e.summon_side
	var lead=player_velocity.limit_length(run.stats.moveSpeed*BWData.UNIT)*0.65
	var target: Vector3=player.position+lead
	if e.summon_route==0:
		target+=side*e.summon_width
	else:
		target+=side*2.8+forward*2.4
	target=arena.push_out(target,e.radius)
	if e.node.position.distance_to(target)<1.1 or e.summon_age>7.0:
		e.summon_route+=1;e.summon_age=0.0
		if e.summon_route>=2:return (player.position-e.node.position).normalized()
	return arena.steer(e.node.position,(target-e.node.position).normalized(),e.radius)

# What an ordinary wave can field here: every type the run has unlocked, weighted
# by the catalog and then again by whichever district the wave is being held in.
# A district shifts the mix rather than choosing it, so nothing unlocked is ever
# unreachable and the pool cannot come back empty.
func spawn_pool(wave: int,zone_id: String) -> Dictionary:
	var garrison=arena.zone_by_id(zone_id).get("garrison",{}) if arena!=null else {}
	var pool={}
	for row in BWData.rows("enemies"):
		if row.id=="boss" or wave<row.get("unlockWave",1):continue
		pool[row.id]=maxf(0.25,float(row.get("spawnWeight",1))*float(garrison.get(row.id,1.0)))
	return pool

func _draw_from(pool: Dictionary) -> String:
	var total=0.0
	for id in pool:total+=pool[id]
	var roll=rng.randf()*total
	for id in pool:
		roll-=pool[id]
		if roll<=0.0:return id
	return pool.keys()[pool.size()-1]

func spawn_enemy(id: String,pos: Vector3,elite: bool=false,multiplier: float=-1.0):
	var data=BWData.entry("enemies",id)
	var power=BWData.enemy_power(run.wave,id)
	if multiplier>=0:power={"health":multiplier,"damage":multiplier}
	var actor=Node3D.new();add_child(actor);actor.position=pos
	var art=BWVisual.new();actor.add_child(art)
	var color=Color(ENEMY_COLORS[id]);if elite:color=Color("c59857")
	art.configure(id,true,color,BWData.enemy_height(id,elite))
	art.set_level_scale(BWData.actor_growth(run.level))
	var max_hp=data.maxHp*power.health*(2.5 if elite else 1)
	var enemy={"id":id,"data":data,"node":actor,"visual":art,"hp":max_hp,"maxHp":max_hp,"damage":data.damage*power.damage*(1.4 if elite else 1),"speed":data.moveSpeed*(1.15 if elite else 1),"radius":data.radius*BWData.UNIT*(1.35 if elite else 1),"elite":elite,"cooldown":2.5 if id=="boss" else rng.randf()*0.7,"state":"chase","timer":0.0,"pattern_index":0,"aura":0.0,"slow":0.0,"slow_amount":0.0,"burn":0.0,"burn_dps":0.0,"bleed":0.0,"bleed_dps":0.0,"status_tick":0.0,"stagger":0.0,"cast_kind":""}
	enemy.hunt_role=enemy_serial%3
	enemy.hunt_side=-1.0 if enemy_serial%2==0 else 1.0
	enemy.hunt_depth=(enemy_serial%5)/4.0
	enemy_serial+=1
	enemies.append(enemy)
	return enemy

func _enemy_tick(e: Dictionary,dt: float):
	if e.hp<=0:return
	e.visual.set_level_scale(BWData.actor_growth(run.level))
	var node=e.node;var data=e.data
	e.aura=maxf(0,e.aura-dt);e.slow=maxf(0,e.slow-dt)
	for status in ["burn","bleed"]:
		if e[status]>0:
			e[status]=maxf(0,e[status]-dt)
			_damage_enemy(e,e[status+"_dps"]*dt,false,false)
			if e.hp<=0:return
	# A staggered body is off its feet for a moment: it does not advance, attack or
	# tick its cooldown down. This is the whole of what a landed hit buys, and it is
	# why the fight now reads as an exchange with each enemy rather than a crowd.
	if e.stagger>0 and e.id!="boss":
		e.stagger=maxf(0.0,e.stagger-dt)
		e.visual.tick(dt,false)
		return
	var delta=player.position-node.position;delta.y=0
	var distance=delta.length();var direction=delta.normalized()
	# Not pathfinding - just enough steering that a pillar does not become a wall an
	# enemy grinds against for the rest of the wave.
	if distance>0.6:direction=arena.steer(node.position,direction,e.radius)
	var speed=e.speed*BWData.UNIT*(1.22 if e.aura>0 else 1)*(1-e.slow_amount if e.slow>0 else 1)
	# A horde closes. Beyond arm's reach a body hurries to get there, and the boost
	# falls off as it arrives, so the press stays as fast as it was to fight once
	# it lands - this buys the approach, not the melee.
	if distance>CLOSE_RANGE:speed*=lerpf(1.0,CLOSE_RUSH,clampf((distance-CLOSE_RANGE)/CLOSE_FALLOFF,0.0,1.0))
	if e.has("summon_route") and e.summon_route<2:
		e.summon_age+=dt
		if distance>2.5:speed*=1.35
	var move=Vector3.ZERO;e.cooldown-=dt
	var range_value=data.attackRange*BWData.UNIT
	var pursuit=_pursuit_direction(e,distance) if e.id!="boss" else direction
	match e.id:
		"archer":
			e.timer-=dt
			# Kiting along the line the player is on kept archers in the middle of the
			# melee, shooting through bodies. A post to one side takes them out of the
			# press and puts them where the camera can show the draw.
			move=_to_post(e,speed,distance,minf(data.preferredRange*BWData.UNIT,FLANK_STANDOFF))
			if e.state=="draw":
				move=Vector3.ZERO
				if e.timer<=0:
					e.state="chase"
					e.visual.action("attack",0.35)
					var shot: Vector3=e.shot_direction
					_bullet(node.position+shot*0.4,shot,data.projectileSpeed*BWData.UNIT,e.damage*(1.25 if e.aura>0 else 1),range_value,false,0,"",0,0,false)
			elif distance<=range_value and e.cooldown<=0:
				e.state="draw";e.timer=DRAW_TIME;e.cooldown=data.attackCooldown
				move=Vector3.ZERO
				e.shot_direction=delta.normalized()
				e.visual.action("draw",DRAW_TIME)
		"healer","commander":
			var preferred=data.preferredRange*BWData.UNIT
			if distance<preferred*(0.65 if e.id=="commander" else 1):move=-direction*speed
			elif distance>preferred*1.5:move=pursuit*speed*0.4
			if e.id=="healer" and e.state=="heal":
				move=Vector3.ZERO;e.timer-=dt
				if e.timer<=0:
					e.state="chase"
					for ally in enemies:
						if ally.node.get_instance_id()==e.heal_target and ally.hp>0 and ally.node.position.distance_to(node.position)<=data.supportRadius*BWData.UNIT:
							ally.hp=minf(ally.maxHp,ally.hp+data.healAmount*(2.5 if e.elite else 1))
							fx.ring(ally.node.position,ally.radius*2.0,Color("619c82"),0.45)
							break
					e.erase("heal_target")
			elif e.cooldown<=0:
				e.cooldown=data.attackCooldown
				var best={};var missing=0.0
				for ally in enemies:
					if ally==e or ally.node.position.distance_to(node.position)>data.supportRadius*BWData.UNIT:continue
					if e.id=="commander" and ally.id not in ["commander","boss"]:ally.aura=data.auraDuration
					elif e.id=="healer" and ally.maxHp-ally.hp>missing:best=ally;missing=ally.maxHp-ally.hp
				if not best.is_empty():
					e.heal_target=best.node.get_instance_id();e.state="heal";e.timer=0.4;move=Vector3.ZERO
					e.heal_direction=(best.node.position-node.position).normalized()
					e.visual.action("attack",0.9)
				elif e.id=="commander":
					fx.ring(node.position,data.supportRadius*BWData.UNIT,Color("cfab53"),0.45)
		"mage":
			e.timer-=dt
			move=_mage_step(e,dt,distance)
			if e.state=="cast":
				move=Vector3.ZERO
				if e.timer<=0:
					e.state="chase"
					if e.cast_kind=="rune":
						_plant_rune(e)
					else:
						_bullet(node.position+direction*0.4+Vector3.UP*0.3,direction,data.projectileSpeed*BWData.UNIT,e.damage*(1.25 if e.aura>0 else 1),range_value,false,0,"enemy_magic_orb",0,0,false)
						sound_at("orb_cast",node.position,-4.0)
			elif e.cooldown<=0 and distance<=range_value:
				# Every other cast is a rune instead of a bolt, so a mage is a thing to
				# close on rather than a turret to trade with. At the rune limit it
				# spends the cast on a bolt instead of stacking the floor.
				e.pattern_index+=1
				e.cast_kind="rune" if e.pattern_index%2==0 and hazards.size()<HAZARD_LIMIT else "bolt"
				e.state="cast";e.timer=CAST_TIME
				move=Vector3.ZERO
				e.visual.action("cast" if e.cast_kind=="rune" else "attack",0.9)
				e.cooldown=float(data.get("runeCooldown",6.5)) if e.cast_kind=="rune" else data.attackCooldown
				fx.spark(node.position+Vector3.UP*1.2,Color("c07bff"),6)
		"assassin":
			e.timer-=dt
			match e.state:
				"chase":
					if distance<3.2:e.state="vanish";e.timer=0.35;e.visual.visible=false
					else:move=pursuit*speed
				"vanish":
					if e.timer<=0:
						var angle=rng.randf()*TAU;node.position=player.position+Vector3(cos(angle),0,sin(angle))*3.2;e.visual.visible=true;e.state="dash"
				"dash":
					if distance<range_value+0.15:
						_hurt_player(e.damage*(1.25 if e.aura>0 else 1));e.visual.action("attack");e.state="retreat";e.timer=0.7
					else:move=direction*speed*4.5
				"retreat":
					move=-direction*speed*1.3
					if e.timer<=0:e.state="chase"
		"boss":
			var moving=BWBoss.tick(self,e,dt,speed)
			e.visual.tick(dt,moving)
			return
		_:
			# A body stops where its blade can reach and not a step closer, so the
			# player can see which enemy is swinging at them.
			var standoff=maxf(range_value,e.radius+PERSONAL_SPACE)
			if distance>standoff:move=pursuit*speed
			elif e.cooldown<=0:
				_hurt_player(e.damage*(1.25 if e.aura>0 else 1));e.cooldown=data.attackCooldown;e.visual.action("attack")
	if move.length_squared()>0.01:
		var separation=Vector3.ZERO
		for other in enemies:
			if other==e:continue
			var offset=node.position-other.node.position;offset.y=0;var d=offset.length()
			if d>0.01 and d<e.radius*3.5:separation+=offset/d*(1-d/(e.radius*3.5))
		move+=separation*speed*1.4
		node.position+=move.limit_length(speed*(4.5 if e.state=="dash" else 1.3))*dt
	node.position=arena.push_out(node.position,e.radius*0.8)
	# Whatever the steering did, nothing but the assassin's dash ends its frame inside
	# the player. Bodies ring them; they do not occupy them.
	if e.state!="dash":
		var gap=e.radius+PERSONAL_SPACE*0.8
		var out=node.position-player.position;out.y=0
		if out.length()<gap and out.length()>0.001:node.position=player.position+out.normalized()*gap
	var facing=move.normalized() if move.length_squared()>0.01 else direction
	# The bow follows its committed shot, not the archer's strafing velocity.
	if e.id=="archer" and (e.state=="draw" or (e.visual.state=="attack" and e.visual.lock_time>0)):
		facing=e.get("shot_direction",direction)
	if e.id=="healer" and e.visual.state=="attack" and e.visual.lock_time>0:
		facing=e.get("heal_direction",direction)
	if e.id=="mage" and e.visual.state in ["attack","cast"] and e.visual.lock_time>0:
		facing=delta.normalized()
	if distance>0.01:e.visual.rotation.y=lerp_angle(e.visual.rotation.y,atan2(facing.x,facing.z),minf(1,dt*10))
	e.visual.tick(dt,move.length_squared()>0.01)

func nearest(origin: Vector3,range_value: float,excluded: Array=[]):
	var best=null;var best_distance=range_value*range_value
	for e in enemies:
		if e.hp<=0 or excluded.has(e):continue
		var distance=origin.distance_squared_to(e.node.position)
		if distance<=best_distance:best=e;best_distance=distance
	return best

func _weapons(dt: float):
	for id in run.weapons:
		var slot=run.weapons[id];slot.cooldown-=dt
		if slot.cooldown>0:continue
		var data=slot.data;var range_value=data.range*run.stats.attackRange*slot.range*BWData.UNIT
		var target=nearest(player.position,range_value)
		var manual=Input.is_action_pressed("fire")
		# Holding the touch trigger aims at the nearest enemy the way auto-fire does;
		# a thumb on a button cannot also point at a target.
		var assisted=auto_fire or fire_input
		if not manual and (not assisted or target==null):continue
		var primary=id==BWData.CLASSES[run.class_id].weapon
		# The chain is gated by its cancel window; everything else waits out its clip.
		if primary and visual.fitted_timing and (swing_gate>0 if data.get("behavior","")=="melee" else visual.lock_time>0):continue
		var direction=aim if manual else (target.node.position-player.position).normalized()
		var cooldown=1.0/(data.attacksPerSecond*run.stats.attackSpeed*slot.speed)
		var melee=data.get("behavior","")=="melee"
		# Holding the heavy modifier spends the swing on the spin instead of the chain.
		if primary and melee and has_heavy() and Input.is_action_pressed("heavy") and Input.is_action_pressed("fire"):
			combo_step=0;combo_timer=0.0
			var spin=visual.clip_length("spinattack")/(spin_pace*clampf(run.stats.attackSpeed,0.8,1.5))
			_swing(id,2)
			visual.action("spinattack",spin)
			swing_gate=spin*0.85
			pending_attacks.append({"time":spin*IMPACT.spinattack,"id":id,"direction":direction,"spin":true})
			visual.rotation.y=atan2(direction.x,direction.z)
			slot.cooldown=cooldown*SPIN_COOLDOWN
			continue
		var next_step=0 if combo_timer<=0 or combo_step>=COMBO.size()-1 else combo_step+1
		# The swing is heard while the blade is still moving; impacts land later from
		# _damage_enemy, so a connecting hit reads as whoosh-then-bite rather than one blip.
		if melee:_swing(id,next_step)
		if primary and visual.fitted_timing:
			var duration=minf(0.45,cooldown*0.85)
			var clip="attack"
			if melee:
				combo_step=next_step
				clip=COMBO[combo_step] if visual.clips.has(COMBO[combo_step]) else "attack"
				# Play the swing at the pace it was authored at, nudged by attack speed
				# rather than crushed into the weapon cooldown. Forcing a 1.1 s greatsword
				# swing into 0.45 s is what made the chain read as fast-forward.
				var authored=visual.clip_length(clip)
				if authored>0.0:duration=authored/(combo_pace*clampf(run.stats.attackSpeed,0.8,1.5))
				# That pace exists to keep the seams of a chain readable. A rig with no
				# chain has no seams to protect, and one long clip then sets the whole
				# tempo: the assassin's single 2.1 s swing gated a 2.4/s weapon down to
				# 1.1. Without a chain, fit the swing to the cadence the weapon asks for.
				if not has_chain():duration=minf(duration,cooldown*SOLO_SWING)
				swing_gate=duration*CANCEL
				combo_timer=duration+0.5
				# The last link is the finisher: it runs longer and carries the class's
				# ability effect, which is what makes finishing the chain worth doing.
				visual.action(clip,duration)
			else:visual.action(clip,duration)
			pending_attacks.append({"time":duration*IMPACT.get(clip,0.32),"id":id,"direction":direction,"finisher":melee and combo_step==COMBO.size()-1})
		else:
			_resolve_weapon(id,direction)
			# Rapid fire outpaces the 0.96s clip ~5x, so playing it full length left the
			# shot animation stuck while bullets kept leaving the barrel. Fitting the clip
			# to the firing cadence keeps it cycling per shot without dropping to idle.
			if not visual.fitted_timing:visual.action("attack",clampf(cooldown,0.18,0.34))
		# Snap to face the attack immediately, even mid-movement - the per-frame
		# facing lerp in _physics_process picks the movement direction back up
		# on its own once the attack's done and the player keeps moving.
		visual.rotation.y=atan2(direction.x,direction.z)
		slot.cooldown=cooldown

func _pending_attacks(dt: float):
	for attack in pending_attacks.duplicate():
		attack.time-=dt
		if attack.time<=0:
			pending_attacks.erase(attack)
			if run.stats.hp<=0:continue
			if attack.id=="ultimate":skills._resolve_ability(attack.data)
			elif attack.get("spin",false):_resolve_spin(attack.id,attack.direction)
			else:
				_resolve_weapon(attack.id,attack.direction)
				if attack.get("finisher",false):
					var finisher=BWData.entry("abilities",BWData.CLASSES[run.class_id].ability)
					skills._ability_effect(finisher.id,player.position,finisher.range*run.stats.attackRange*BWData.UNIT*0.5)

func _resolve_weapon(id: String,direction: Vector3):
	var slot=run.weapons[id];var data=slot.data
	var range_value=data.range*run.stats.attackRange*slot.range*BWData.UNIT
	var base=data.damage*run.stats.damage*slot.damage
	var behavior=data.get("behavior","singleProjectile")
	match behavior:
		"melee":
			slot.swings+=1
			# The shockwave upgrade turns every third swing into the crowd answer: full
			# circle, more bodies. Every other swing is a blade with a front and a limit.
			var wide=slot.shockwave>0 and slot.swings%3==0
			var radius=range_value+(slot.shockwave*BWData.UNIT if wide else 0.0)
			var hit=[]
			var blade="dagger" if id=="daggers" else "sword"
			for entry in _reachable(direction,radius,wide,SHOCKWAVE_TARGETS if wide else MELEE_TARGETS):
				var e=entry.enemy
				var roll=run.damage_roll(base);_damage_enemy(e,roll.damage,roll.critical,true,blade);hit.append(e)
				if e.hp>0:
					_stagger(e)
					if slot.bleed>0:e.bleed=3;e.bleed_dps=slot.bleed
			damage_area(player.position,radius,base)
			fx.slash(player.position,direction,radius,Color("ffca7a"))
			# A connecting swing is felt in the camera as well as on the body it hit.
			if not hit.is_empty():shake=maxf(shake,0.06)
			if not hit.is_empty() and slot.chain>0:_chain(hit[0].node.position,base*0.5,int(slot.chain),2.4,hit)
		"chain":_chain(player.position,base,int(data.get("chainCount",0)+slot.chain+1),range_value,[])
		_:
			var count=int(data.get("projectileCount",1))
			for i in count:
				var angle=(float(i)/maxi(1,count-1)-0.5)*0.5 if count>1 else 0.0
				var roll=run.damage_roll(base)
				var origin=player.position
				var shot_direction=direction.rotated(Vector3.UP,angle)
				if id=="magic_orb" and is_instance_valid(visual.hand_magic):
					var hand=visual.hand_magic.global_position
					var target=nearest(player.position,range_value)
					var destination=player.position+shot_direction*range_value+Vector3.UP*0.8
					if target!=null and (target.node.position-player.position).normalized().dot(shot_direction)>0.95:destination=target.node.position+Vector3.UP*0.8
					shot_direction=(destination-hand).normalized()
					# Clear the hand/body mesh - the orb used to spawn right at the palm and
					# visibly poke out of the model instead of appearing in front of it.
					origin=hand+shot_direction*0.45-Vector3.UP*0.8
				if i==0:fx.muzzle(origin+Vector3.UP*0.8,shot_direction,Color("8db8f4") if id=="magic_orb" else Color("ffce7a"))
				_bullet(origin,shot_direction,data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,int(data.get("pierceCount",0)+slot.pierce),id,slot.burn,0.35 if behavior=="piercing" and slot.burn<=0 else 0.0,roll.critical)
	# Melee already played its swing as the animation started; everything else
	# reports here, as the projectile leaves.
	if behavior!="melee":sound(WEAPON_SHOT.get(id,"gun_pistol"))

# Does the equipped rig carry the melee chain, or only a single swing? The
# warrior has all four links; the assassin has none of them yet.
func has_chain() -> bool:
	if not is_instance_valid(visual):return false
	for clip in COMBO:
		if visual.clips.has(clip):return true
	return false

# Does the equipped rig actually carry the spin clip? Only the warrior has it for
# now, and the HUD asks the same question before advertising the binding.
func has_heavy() -> bool:
	return is_instance_valid(visual) and visual.clips.has("spinattack")

# The spin trades the chain for one wide, slow, expensive hit: everything inside a
# wider circle, not just what is in front.
func _resolve_spin(id: String,direction: Vector3):
	var slot=run.weapons[id];var data=slot.data
	var radius=data.range*run.stats.attackRange*slot.range*BWData.UNIT*SPIN_RADIUS
	var base=data.damage*run.stats.damage*slot.damage*SPIN_DAMAGE
	var hit=[]
	for e in enemies.duplicate():
		if e.node.position.distance_to(player.position)<=radius+e.radius:
			var roll=run.damage_roll(base)
			_damage_enemy(e,roll.damage,roll.critical,true,"sword");hit.append(e)
			if e.hp>0:
				_stagger(e,1.5)
				if slot.bleed>0:e.bleed=3;e.bleed_dps=slot.bleed
	damage_area(player.position,radius,base)
	for turn in 3:
		fx.slash(player.position,direction.rotated(Vector3.UP,TAU*turn/3.0),radius,Color("ffd08a"))
	fx.shockwave(player.position,radius,Color("ffb066"),0.3,0.0,1.8)
	fx.radial_streaks(player.position,radius*1.05,Color("ffc27a"),9,0.26)
	fx.flash_light(player.position,Color("ff9a52"),2.2,radius*1.5,0.24)
	shake=maxf(shake,0.11 if hit.is_empty() else 0.16)

func _chain(origin: Vector3,base: float,count: int,radius: float,hit: Array):
	for i in count:
		var next=nearest(origin,radius,hit)
		if next==null:return
		var end=next.node.position;fx.beam(origin+Vector3.UP,end+Vector3.UP,Color("a5cfff"))
		# The arc earths itself on whatever it passes through.
		damage_area(end,1.0,base)
		var roll=run.damage_roll(base);_damage_enemy(next,roll.damage,roll.critical,true,"chain")
		if next.hp>0:next.burn=2;next.burn_dps=4
		hit.append(next);origin=end

# Project screen controls onto the ground without changing analog input length.
func screen_direction(input: Vector2) -> Vector3:
	var right=camera.basis.x;right.y=0
	var down=camera.basis.z;down.y=0
	return right.normalized()*input.x+down.normalized()*input.y

# Where a targeted skill lands, limited to its reach and the arena walls.
func ground_target(reach: float) -> Vector3:
	var point=player.position+aim*reach
	# Stick and touch aim win when they are live; the cursor only picks the spot
	# when nothing else is steering, or a controller player would be overridden
	# by wherever the mouse happens to be sitting.
	var stick=Input.get_vector("aim_left","aim_right","aim_up","aim_down")
	if not OS.has_feature("mobile") and touch_aim.length_squared()<=0.04 and stick.length_squared()<=0.04:
		var mouse=get_viewport().get_mouse_position();var plane=Plane(Vector3.UP,0)
		var hit=plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null:point=hit
	var offset=point-player.position;offset.y=0
	point=player.position+offset.limit_length(reach)
	point.x=clampf(point.x,-BWArena.EDGE,BWArena.EDGE);point.z=clampf(point.z,-BWArena.EDGE,BWArena.EDGE)
	point.y=0
	return point

# Which bodies one swing may actually cut: inside the blade's reach, in front of it
# unless the swing is the wide one, nearest first, and never more than the cap.
# Returned as records so the caller can damage them while enemies is being mutated.
func _reachable(direction: Vector3,radius: float,wide: bool,limit: int) -> Array:
	var found=[]
	var threshold=cos(deg_to_rad(MELEE_ARC*0.5))
	for e in enemies:
		if e.hp<=0:continue
		var offset=e.node.position-player.position;offset.y=0
		var gap=offset.length()-e.radius
		if gap>radius:continue
		# A body already against the player is cut whichever way the blade points -
		# there is no front to be outside of at that distance.
		if not wide and gap>0.5 and direction.dot(offset.normalized())<threshold:continue
		found.append({"enemy":e,"gap":gap})
	found.sort_custom(func(a,b):return a.gap<b.gap)
	return found.slice(0,limit)

# A hit has to land on the body, not only on its health bar. The blow stops it for a
# beat and shoves it back, which is what makes one enemy at a time readable.
func _stagger(e: Dictionary,force: float=1.0):
	if e.id=="boss":return
	var resist=0.5 if e.id in ARMORED or e.elite else 1.0
	e.stagger=maxf(e.stagger,STAGGER_TIME*resist*force)
	var away=e.node.position-player.position;away.y=0
	if away.length()<=0.01:return
	e.node.position=arena.push_out(e.node.position+away.normalized()*KNOCKBACK*resist*force,e.radius*0.8)

# A missile trooper's standing post: off to the player's left or right at its own
# reach, jittered along the depth axis so two of them do not share one spot.
func _flank_post(e: Dictionary,standoff: float) -> Vector3:
	var post=player.position+screen_direction(Vector2(e.hunt_side*standoff,(e.hunt_depth-0.5)*3.6))
	post.x=clampf(post.x,-BWArena.EDGE,BWArena.EDGE);post.z=clampf(post.z,-BWArena.EDGE,BWArena.EDGE)
	return arena.push_out(Vector3(post.x,0,post.z),e.radius)

# Movement towards that post. Closer than it wants to be, it hurries out: a caster
# being stood on has to be able to leave, or the answer to every caster is to hug it.
func _to_post(e: Dictionary,speed: float,distance: float,standoff: float) -> Vector3:
	var offset=_flank_post(e,standoff)-e.node.position;offset.y=0
	if offset.length()<=0.7:return Vector3.ZERO
	return arena.steer(e.node.position,offset.normalized(),e.radius)*speed*(1.5 if distance<3.0 else 1.0)

# Cast from a fixed spot. One short sidestep buys space, then a long planted
# interval lets the player catch the caster. Never chase a player-relative post.
func _mage_step(e: Dictionary,dt: float,distance: float) -> Vector3:
	e.step_cooldown=maxf(0.0,e.get("step_cooldown",0.0)-dt)
	e.step_left=maxf(0.0,e.get("step_left",0.0)-dt)
	if e.state=="cast" or (e.visual.lock_time>0 and e.visual.state in ["attack","cast"]):return Vector3.ZERO
	var speed=e.speed*BWData.UNIT*(1-e.slow_amount if e.slow>0 else 1)
	var toward=(player.position-e.node.position).normalized()
	if distance>e.data.attackRange*BWData.UNIT*0.95:
		return arena.steer(e.node.position,toward,e.radius)*speed
	if distance<3.0 and e.step_cooldown<=0:
		var side=toward.cross(Vector3.UP)*e.hunt_side
		e.step_target=arena.push_out(e.node.position+side*1.7-toward*0.5,e.radius)
		e.step_left=0.95;e.step_cooldown=4.5;e.hunt_side*=-1.0
	if e.step_left>0:
		var offset: Vector3=e.step_target-e.node.position;offset.y=0
		if offset.length()>0.2:return arena.steer(e.node.position,offset.normalized(),e.radius)*speed*0.8
		e.step_left=0.0
	return Vector3.ZERO

# A mage builds as well as casts. The rune is planted where the player is standing,
# burns a visible fuse, and then goes off - so the ground becomes something to read
# and leave. It can be broken first, which is the point of it: a swing spent on the
# rune is a swing not spent on the mage that planted it.
func _plant_rune(e: Dictionary):
	var spot=arena.push_out(player.position+Vector3(rng.randf_range(-0.5,0.5),0,rng.randf_range(-0.5,0.5)),0.6)
	var radius=float(e.data.get("runeRadius",150))*BWData.UNIT
	var fuse=float(e.data.get("runeFuse",2.3))
	var tone=Color("df45bc")
	# A primitive stand-in, the way every prop starts: one mesh with a known
	# footprint, so a built model replaces it by loading a scene here.
	var node=Node3D.new();add_child(node);node.position=spot
	var pylon=MeshInstance3D.new();var shard=PrismMesh.new();shard.size=Vector3(0.38,0.9,0.38)
	pylon.mesh=shard;pylon.position.y=0.39;pylon.rotation.y=PI*0.25
	var skin=StandardMaterial3D.new();skin.albedo_color=Color("2a1b3d")
	skin.emission_enabled=true;skin.emission=tone;skin.emission_energy_multiplier=1.6
	pylon.material_override=skin;pylon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(pylon)
	node.add_child(fx.glow_sprite(tone,0.9,1.4))
	var mark=fx.telegraph(spot,radius,tone,fuse)
	hazards.append({"node":node,"pos":spot,"radius":radius,"fuse":fuse,"life":fuse,
		"hp":maxf(8.0,e.maxHp*0.35),"damage":e.damage*float(e.data.get("runeDamage",1.7)),"tone":tone,"mark":mark})
	sound_at("orb_cast",spot,-2.0)

func _hazards(dt: float):
	for h in hazards.duplicate():
		h.fuse-=dt
		if is_instance_valid(h.node):
			# The fuse is shown on the structure itself: it rises and beats faster as
			# the time runs out, so leaving is a decision and not a surprise.
			var spent=1.0-clampf(h.fuse/h.life,0.0,1.0)
			var beat=1.0+0.18*sin(elapsed*(7.0+14.0*spent))*spent
			h.node.scale=Vector3(beat,1.0+spent*0.45,beat)
		if h.fuse<=0:_detonate(h,true)

func _detonate(h: Dictionary,blast: bool):
	if not hazards.has(h):return
	hazards.erase(h)
	if is_instance_valid(h.get("mark")):h.mark.queue_free()
	if blast:
		if player.position.distance_to(h.pos)<=h.radius+0.36:_hurt_player(h.damage)
		damage_area(h.pos,h.radius,h.damage)
		for e in enemies.duplicate():
			# A rune is a bomb, not an ally: whatever is standing over it takes it.
			if e.node.position.distance_to(h.pos)<=h.radius+e.radius:_damage_enemy(e,h.damage*0.5,false,true,"ability")
		fx.arcane_blast(h.pos,h.radius,h.tone,Color("de2851"))
		fx.spark(h.pos+Vector3.UP*0.4,h.tone,22)
		fx.flash_light(h.pos,h.tone,2.4,h.radius*1.6,0.28)
		shake=maxf(shake,0.1)
		sound_at("hit_heavy",h.pos)
	else:
		fx.spark(h.pos+Vector3.UP*0.5,h.tone,14)
		sound_at("sword_hit_armor",h.pos,-2.0)
	if is_instance_valid(h.node):h.node.queue_free()

# Anything the player lands on an area lands on what is standing in it. Breaking a
# rune before its fuse ends defuses it: it comes apart without the blast.
func damage_hazards(origin: Vector3,radius: float,amount: float):
	for h in hazards.duplicate():
		if origin.distance_to(h.pos)>radius+0.4:continue
		h.hp-=amount
		fx.spark(h.pos+Vector3.UP*0.5,h.tone,5)
		if h.hp<=0:_detonate(h,false)

# One call for "this blast covers this circle", so a new area attack cannot hit the
# scenery and miss the runes, or the other way round.
func damage_area(spot: Vector3,radius: float,amount: float) -> Array:
	damage_hazards(spot,radius,amount)
	return arena.damage_area(spot,radius,amount)

func clear_hazards():
	for h in hazards:
		if is_instance_valid(h.get("mark")):h.mark.queue_free()
		if is_instance_valid(h.node):h.node.queue_free()
	hazards.clear()

func _nearest_unhit(origin: Vector3,reach: float,hit_ids: Array):
	var best=null;var best_distance=reach*reach
	for e in enemies:
		if e.hp<=0 or hit_ids.has(e.node.get_instance_id()):continue
		var distance=origin.distance_squared_to(e.node.position)
		if distance<=best_distance:best=e;best_distance=distance
	return best














# The input layer and the suites talk to the world, not to the kit behind it.
func skill(index: int):
	skills.skill(index)

func ability():
	skills.ability()

func _bullet(origin: Vector3,direction: Vector3,speed: float,damage: float,distance: float,friendly: bool,pierce: int,weapon: String,burn: float,slow: float,critical: bool):
	if bullets.size()>=384:return
	# A projectile is a rig, not a single mesh: a small blown-out core for the bloom
	# to catch, one or two soft halos around it, and a world-space trail behind.
	var node=Node3D.new();add_child(node);node.position=origin+Vector3.UP*0.8
	var rich=quality=="PC"
	var orb=weapon in ["magic_orb","enemy_magic_orb"]
	var arcane_tone=Color("19cbff") if friendly else Color("ec45b5")
	var arcane_accent=Color("2448df") if friendly else Color("e02c50")
	var tone=arcane_tone if orb else (Color("ffd9a0") if friendly else Color("ff9d86"))
	var halo_tone=arcane_tone if orb else (Color("ffab4d") if friendly else Color("ff5a4a"))
	var core=MeshInstance3D.new();core.mesh=bullet_mesh
	var core_mat=bullet_material.duplicate();core_mat.albedo_color=tone*(1.0 if orb else 1.7)
	core.material_override=core_mat;core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)
	if orb:
		core.visible=false
		var rig=fx.orb_dressing(halo_tone,rich,arcane_accent)
		node.add_child(rig)
		var tail=fx.arcane_tail(halo_tone,arcane_accent);node.add_child(tail);fx.aim_along(tail,direction)
		# The spin has to be owned by the node it turns: a world-bound looping tween
		# outlives the projectile and keeps cycling against a freed target.
		var motes=rig.get_node_or_null("Motes")
		if motes!=null:motes.create_tween().set_loops().tween_property(motes,"rotation:y",TAU,0.9).from(0.0)
	else:
		fx.aim_along(core,direction);core.scale=Vector3(0.5,0.5,2.3)
		var streak=fx.flat_sprite(halo_tone,0.24,1.25,1.4);node.add_child(streak)
		fx.aim_along(streak,direction)
		node.add_child(fx.glow_sprite(tone,0.26,1.7))
	if rich and bullets.size()<20:
		var lamp=OmniLight3D.new();lamp.light_color=halo_tone
		lamp.light_energy=1.8 if orb else 1.0;lamp.omni_range=2.6 if orb else 1.5
		node.add_child(lamp)
		node.add_child(fx.trail_emitter(halo_tone,0.075 if orb else 0.045,0.32 if orb else 0.2,18 if orb else 12))
	var record={"node":node,"direction":direction.normalized(),"speed":speed,"damage":damage,"remaining":distance,"friendly":friendly,"pierce":pierce,"hit":[],"props":[],"weapon":weapon,"burn":burn,"slow":slow,"critical":critical,"radius":0.5 if weapon=="magic_orb" else 0.16}
	bullets.append(record)
	return record


func _projectiles(dt: float):
	for b in bullets.duplicate():
		var previous=b.node.position;var step=b.direction*b.speed*dt;b.node.position+=step;b.remaining-=step.length()
		# A shot breaks what it flies through. It is not stopped by a clay pot, so
		# pierce is untouched - the round carries on to whatever it was aimed at.
		if b.friendly:
			for prop in arena.breakables_on(previous,b.node.position,b.radius,b.props):
				b.props.append(prop.node.get_instance_id())
				arena.hurt_prop(prop,b.damage)
		var targets=enemies.duplicate() if b.friendly else [{"node":player,"radius":0.36,"hp":run.stats.hp}]
		for target in targets:
			if target.hp<=0 or b.hit.has(target.node.get_instance_id()):continue
			var p=target.node.position+Vector3.UP*0.8
			var closest=Geometry3D.get_closest_point_to_segment(p,previous,b.node.position)
			if p.distance_to(closest)<=target.radius+b.radius:
				b.hit.append(target.node.get_instance_id())
				if b.friendly:
					_damage_enemy(target,b.damage,b.critical)
					if target.hp>0:
						if b.burn>0:target.burn=3;target.burn_dps=b.burn
						if b.slow>0:target.slow=2;target.slow_amount=b.slow
				else:_hurt_player(b.damage)
				fx.impact(b.node.position,b.weapon,b.friendly)
				if b.friendly and b.get("bounces",0)>0:
					var next=_nearest_unhit(b.node.position,b.get("bounce_range",6.0),b.hit)
					if next!=null:
						b.bounces-=1
						b.direction=(next.node.position+Vector3.UP*0.8-b.node.position).normalized()
						b.remaining=b.get("bounce_range",6.0)
						fx.aim_along(b.node.get_child(0),b.direction)
						fx.beam(b.node.position,next.node.position+Vector3.UP*0.8,Color("ffe9bd"))
						break
				b.pierce-=1
				if b.pierce<0:b.remaining=-1;break
		if b.remaining<=0:b.node.queue_free();bullets.erase(b)

func _damage_enemy(e: Dictionary,damage: float,critical: bool=false,effects: bool=true,impact: String=""):
	if e.hp<=0:return
	if e.get("marked",false):damage*=1.35+0.1*mark_chain
	var actual=minf(e.hp,damage);e.hp-=damage
	if run.stats.hp>0:run.stats.hp=minf(run.stats.maxHp,run.stats.hp+actual*run.stats.lifesteal)
	if effects:
		fx.damage_text(e.node.position,damage,Color("ffe4a8") if critical else Color("d9dce2"))
		_impact_sound(e,impact,critical)
		e.visual.flash(0.14 if critical else 0.1)
		e.visual.hit_react(e.node.position-player.position,1.35 if critical else 1.0)
		fx.spark(e.node.position+Vector3.UP*0.9,Color("ffe0a6") if critical else Color("ffb072"),14 if critical else 7)
	if e.hp>0:return
	if e.id=="boss":BWBoss.clear_warning(e)
	enemies.erase(e);e.visual.action("death")
	if e.get("marked",false):
		var heir=nearest(e.node.position,9.0)
		if heir!=null:mark_chain+=1;skills._apply_mark(heir,e.get("mark_tone",Color("63bd9f")))
		else:mark_chain=0
	fx.spark(e.node.position+Vector3.UP*0.9,Color(ENEMY_COLORS[e.id]).lightened(0.4),24 if e.elite or e.id=="boss" else 16)
	run.kills+=1;run.gold+=int(e.data.goldReward*(4 if e.elite else 1)+run.stats.bonusGoldPerKill)
	_drop(e.node.position,"xp",int(e.data.xpReward*(4 if e.elite else 1)))
	var chance=1.0 if e.id=="boss" else 0.22 if e.elite else 0.08
	if rng.randf()<chance:_drop(e.node.position+Vector3(0.2,0,0),"health",70 if e.id=="boss" else 35 if e.elite else 18)
	if e.id=="boss":
		sound("boss_death")
		if audio!=null:audio.music("combat")
	else:sound_at("enemy_death",e.node.position,2.0 if e.elite else 0.0)
	var corpse=e.node
	get_tree().create_timer(2.5).timeout.connect(corpse.queue_free)
	changed.emit()

func _hurt_player(damage: float):
	# Out of reach while the leap is in the air - that window is what the skill buys.
	if airborne:return
	var actual=run.hurt(damage,rng.randf())
	if actual<=0:return
	if visual.fitted_timing and visual.state=="attack":pending_attacks.clear()
	fx.damage_text(player.position,actual,Color("ff8678"));visual.action("hit");shake=clampf(actual/100,0.04,0.18);sound("player_hit")
	hit_flash=clampf(actual/90,0.12,0.38);fx.spark(player.position+Vector3.UP*1.0,Color("ff8678"),8)
	changed.emit()

func _drop(pos: Vector3,kind: String,amount: int):
	var node=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=0.12;mesh.height=0.24;mesh.radial_segments=8;mesh.rings=4;node.mesh=mesh
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("85c8cf") if kind=="xp" else Color("eb665c");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat;add_child(node);node.position=pos+Vector3.UP*0.2
	pickups.append({"node":node,"kind":kind,"amount":amount})

func _pickups(dt: float):
	for p in pickups.duplicate():
		var target=player.position+Vector3.UP*0.2;var distance=p.node.position.distance_to(target)
		if distance<=run.stats.pickupRadius*BWData.UNIT:p.node.position=p.node.position.move_toward(target,dt*8)
		if distance<0.4:
			if p.kind=="xp":
				var before=run.level;run.add_xp(p.amount)
				if run.level>before:sound("level_up")
			else:run.stats.hp=minf(run.stats.maxHp,run.stats.hp+p.amount);sound("pickup_health")
			p.node.queue_free();pickups.erase(p);changed.emit()

func next_wave():
	for b in bullets:b.node.queue_free()
	bullets.clear();clear_hazards();run.wave+=1;spawned=0;spawn_timer=0;rest_time=4;running=true
	spawn_slot=0;spawn_bearing=rng.randf()*TAU
	sound("wave_start");wave_music();changed.emit()

func wave_music():
	if audio!=null:audio.music("boss" if run.wave%10==0 else "combat")









func sound(event: String,db_offset: float=0.0,variant: int=-1):
	if audio!=null:audio.play(event,db_offset,variant)

# Enemy-side sounds are placed in the world so a kill across the arena reads as
# distant and off to one side instead of arriving in the centre of the mix.
func sound_at(event: String,position: Vector3,db_offset: float=0.0):
	if audio!=null:audio.play_at(event,position,db_offset)

func _swing(weapon: String,step: int):
	sound("dagger_swing" if weapon=="daggers" else "sword_swing",0.0,step)

func _impact_sound(e: Dictionary,impact: String,critical: bool):
	if audio==null:return
	var position=e.node.position
	# Armour turns a cut into a clang; the flesh samples only fit unarmoured bodies.
	var armored=e.id in ARMORED or e.elite
	match impact:
		"sword":audio.play_at("sword_hit_armor" if armored else "sword_hit_flesh",position)
		"dagger":audio.play_at("dagger_hit",position,2.0 if critical else 0.0)
		"orb":audio.play_at("orb_impact",position)
		"chain":audio.play_at("lightning_chain",position)
		"ability":audio.play_at("hit_heavy",position)
		_:audio.play_at("hit_heavy" if critical else "hit_light",position)
