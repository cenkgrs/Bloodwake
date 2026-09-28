class_name BWWorld
extends Node3D

signal wave_cleared
signal run_ended
signal changed

var run: BWRun
var audio: BWAudio
var player: Node3D
var visual: BWVisual
var camera: Camera3D
var enemies: Array = []
var bullets: Array = []
var pickups: Array = []
var spawn_timer = 0.0
var spawned = 0
var running = true
var auto_fire = false
var move_input = Vector2.ZERO
var fire_input = false
var touch_aim = Vector2.ZERO
var aim = Vector3.FORWARD
var last_move = Vector3.FORWARD
var quality = "PC"
var elapsed = 0.0
var rest_time = 0.0
var hit_flash = 0.0
var flash_rect: ColorRect
var combo_step = 0
var mark_chain = 0
var combo_timer = 0.0
var glow_texture: GradientTexture2D
var ring_texture: GradientTexture2D
var shake = 0.0
var airborne = false
var pending_attacks: Array = []
var bullet_mesh: SphereMesh
var bullet_material: StandardMaterial3D
var rng = RandomNumberGenerator.new()
const ARENA_HALF = 24.0
const ARMORED = ["tank","boss"]
const WEAPON_SHOT = {"rapid_rifle":"gun_rifle","basic_pistol":"gun_pistol","shotgun":"gun_shotgun","magic_orb":"orb_cast","lightning":"lightning_cast"}
const HURT_FLASH_COLOR = Color("ff3b30")
const ENEMY_COLORS = {"grunt":"8b6256","archer":"9a789e","tank":"65463f","assassin":"667482","healer":"72b78e","commander":"c4a75e","boss":"8a3440"}

func start(state: BWRun,profile: String="PC",mixer: BWAudio=null):
	run=state;quality=profile;audio=mixer;rng.randomize()
	_environment()
	player=Node3D.new();player.name="Player";add_child(player)
	# Enemies read as 1.7-3.5 m (tanks/bosses run bigger on purpose); the player
	# was left at the 1.8 m rig default and looked undersized next to them.
	visual=BWVisual.new();player.add_child(visual);visual.configure(run.class_id,false,Color.WHITE,2.05)
	get_viewport().msaa_3d=Viewport.MSAA_4X if quality=="PC" else Viewport.MSAA_DISABLED
	var fill=OmniLight3D.new();fill.position=Vector3(0,2.5,1);fill.omni_range=4;fill.light_energy=1.0;fill.light_color=Color("d1def0");player.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=17
	camera.position=Vector3(0,16,12);camera.current=true;add_child(camera);camera.look_at(Vector3.ZERO)
	var flash_layer=CanvasLayer.new();flash_layer.layer=2;add_child(flash_layer)
	flash_rect=ColorRect.new();flash_rect.color=Color(HURT_FLASH_COLOR,0.0)
	flash_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	glow_texture=GradientTexture2D.new()
	glow_texture.fill=GradientTexture2D.FILL_RADIAL;glow_texture.fill_from=Vector2(0.5,0.5);glow_texture.fill_to=Vector2(0.5,1.0)
	glow_texture.width=96;glow_texture.height=96
	var ramp=Gradient.new()
	ramp.set_offset(0,0.0);ramp.set_color(0,Color(1,1,1,1))
	ramp.set_offset(1,1.0);ramp.set_color(1,Color(1,1,1,0))
	ramp.add_point(0.35,Color(1,1,1,0.55));ramp.add_point(0.7,Color(1,1,1,0.12))
	glow_texture.gradient=ramp
	ring_texture=GradientTexture2D.new()
	ring_texture.fill=GradientTexture2D.FILL_RADIAL;ring_texture.fill_from=Vector2(0.5,0.5);ring_texture.fill_to=Vector2(0.5,1.0)
	ring_texture.width=128;ring_texture.height=128
	var rim=Gradient.new()
	rim.set_offset(0,0.0);rim.set_color(0,Color(1,1,1,0))
	rim.set_offset(1,1.0);rim.set_color(1,Color(1,1,1,0))
	rim.add_point(0.55,Color(1,1,1,0.08));rim.add_point(0.8,Color(1,1,1,1.0));rim.add_point(0.92,Color(1,1,1,0.18))
	ring_texture.gradient=rim
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
	env_node.environment=env;add_child(env_node)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_color=Color("b4c7e0");sun.light_energy=1.5;sun.shadow_enabled=quality=="PC";sun.directional_shadow_max_distance=45;add_child(sun)
	var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(48,48);floor.mesh=plane
	var mat=StandardMaterial3D.new();mat.albedo_texture=load("res://assets/art/arena.png");mat.uv1_scale=Vector3(10,10,10);mat.roughness=0.95;mat.albedo_color=Color("555d67");floor.material_override=mat;add_child(floor)
	var stone=StandardMaterial3D.new();stone.albedo_color=Color("303844");stone.roughness=0.9
	for edge in 4:
		var wall=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(49,1.0,0.45);wall.mesh=box;wall.material_override=stone
		wall.position=Vector3(0,0.5,-24) if edge==0 else Vector3(0,0.5,24) if edge==1 else Vector3(-24,0.5,0) if edge==2 else Vector3(24,0.5,0)
		if edge>1:wall.rotation.y=PI/2
		add_child(wall)
	for i in 16:
		var angle=TAU*i/16;var pillar=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=0.28;cylinder.bottom_radius=0.36;cylinder.height=2.4;cylinder.radial_segments=8
		pillar.mesh=cylinder;pillar.material_override=stone;pillar.position=Vector3(cos(angle)*22.3,1.2,sin(angle)*22.3);add_child(pillar)
		var fire=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=0.15;sphere.height=0.35;fire.mesh=sphere;fire.position=pillar.position+Vector3.UP*1.35
		var glow=StandardMaterial3D.new();glow.albedo_color=Color("ff9b48");glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fire.material_override=glow;add_child(fire)
		if quality=="PC":
			var lamp=OmniLight3D.new();lamp.position=fire.position;lamp.light_color=Color("ff9854");lamp.light_energy=1.3;lamp.omni_range=4;add_child(lamp)

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
	visual.set_level_scale(1.0+minf(run.level-1,20)*0.015)
	var input=Input.get_vector("move_left","move_right","move_up","move_down")+move_input
	input=input.limit_length()
	var movement=Vector3(input.x,0,input.y)
	# A leap owns the body until it lands; steering mid-flight would fight its tween.
	if airborne:movement=Vector3.ZERO
	else:
		player.position+=movement*run.stats.moveSpeed*BWData.UNIT*dt
		player.position.x=clampf(player.position.x,-23.5,23.5);player.position.z=clampf(player.position.z,-23.5,23.5)
	if movement.length_squared()>0.001:last_move=movement.normalized()
	var aim_stick=Input.get_vector("aim_left","aim_right","aim_up","aim_down")
	if touch_aim.length_squared()>0.04:aim=Vector3(touch_aim.x,0,touch_aim.y).normalized()
	elif aim_stick.length_squared()>0.04:aim=Vector3(aim_stick.x,0,aim_stick.y).normalized()
	elif Input.is_action_pressed("fire") and not OS.has_feature("mobile"):
		var mouse=get_viewport().get_mouse_position();var plane=Plane(Vector3.UP,0)
		var hit=plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
		if hit!=null and player.position.distance_squared_to(hit)>0.01:aim=(hit-player.position).normalized()
	elif movement.length_squared()>0.001:aim=last_move
	var facing=aim if Input.is_action_pressed("fire") or aim_stick.length_squared()>0.04 else last_move
	if facing.length_squared()>0.01:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(facing.x,facing.z),minf(1,dt*16))
	visual.tick(dt,movement.length_squared()>0.001,run.stats.moveSpeed/BWData.stats(run.class_id).moveSpeed)
	var desired=player.position+Vector3(0,16,12);camera.position=camera.position.lerp(desired,1-exp(-dt*10))
	if shake>0:camera.position+=Vector3(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake),0);shake=move_toward(shake,0,dt*2)
	if combo_timer>0:combo_timer=maxf(0,combo_timer-dt)
	if hit_flash>0 or flash_rect.color.a>0:hit_flash=maxf(0,hit_flash-dt*1.9);flash_rect.color.a=hit_flash
	_pending_attacks(dt)
	if not airborne:_weapons(dt)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy.node):_enemy_tick(enemy,dt)
	_projectiles(dt)
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
			pickups.clear();pending_attacks.clear();running=false;wave_cleared.emit()
		return
	spawn_timer-=dt
	if spawn_timer>0 or enemies.size()>=rules.cap:return
	spawn_timer=rules.interval
	var id="boss"
	if not rules.boss:
		var pool=[]
		for row in BWData.rows("enemies"):
			if row.id!="boss" and run.wave>=row.get("unlockWave",1):
				for n in int(row.get("spawnWeight",1)):pool.append(row.id)
		id=pool[rng.randi_range(0,pool.size()-1)]
	var angle=rng.randf()*TAU;var pos=player.position+Vector3(cos(angle),0,sin(angle))*10.4
	pos.x=clampf(pos.x,-23,23);pos.z=clampf(pos.z,-23,23)
	spawn_enemy(id,pos,not rules.boss and rng.randf()<rules.elite,rules.multiplier if not rules.boss else 1.0)
	spawned+=1

func spawn_enemy(id: String,pos: Vector3,elite: bool=false,multiplier: float=1.0):
	var data=BWData.entry("enemies",id)
	var actor=Node3D.new();add_child(actor);actor.position=pos
	var art=BWVisual.new();actor.add_child(art)
	var color=Color(ENEMY_COLORS[id]);if elite:color=Color("c59857")
	art.configure(id,true,color,3.5 if id=="boss" else 2.3 if id=="tank" else 1.9 if elite else 1.7)
	var max_hp=data.maxHp*multiplier*(2.5 if elite else 1)
	var enemy={"id":id,"data":data,"node":actor,"visual":art,"hp":max_hp,"maxHp":max_hp,"damage":data.damage*multiplier*(1.4 if elite else 1),"speed":data.moveSpeed*(1.15 if elite else 1),"radius":data.radius*BWData.UNIT*(1.35 if elite else 1),"elite":elite,"cooldown":2.5 if id=="boss" else rng.randf()*0.7,"state":"chase","timer":0.0,"summon":7.0,"phase":1,"pending_phase":1,"aura":0.0,"slow":0.0,"slow_amount":0.0,"burn":0.0,"burn_dps":0.0,"bleed":0.0,"bleed_dps":0.0,"status_tick":0.0}
	enemies.append(enemy)
	return enemy

func _enemy_tick(e: Dictionary,dt: float):
	if e.hp<=0:return
	var node=e.node;var data=e.data
	e.aura=maxf(0,e.aura-dt);e.slow=maxf(0,e.slow-dt)
	for status in ["burn","bleed"]:
		if e[status]>0:
			e[status]=maxf(0,e[status]-dt)
			_damage_enemy(e,e[status+"_dps"]*dt,false,false)
			if e.hp<=0:return
	var delta=player.position-node.position;delta.y=0
	var distance=delta.length();var direction=delta.normalized()
	var speed=e.speed*BWData.UNIT*(1.22 if e.aura>0 else 1)*(1-e.slow_amount if e.slow>0 else 1)
	var move=Vector3.ZERO;e.cooldown-=dt
	var range_value=data.attackRange*BWData.UNIT
	match e.id:
		"archer":
			var preferred=data.preferredRange*BWData.UNIT
			if distance<preferred*0.75:move=-direction*speed
			elif distance>preferred*1.1:move=direction*speed
			if distance<=range_value and e.cooldown<=0:
				_bullet(node.position,direction,data.projectileSpeed*BWData.UNIT,e.damage*(1.25 if e.aura>0 else 1),range_value,false,0,"",0,0,false)
				e.cooldown=data.attackCooldown;e.visual.action("attack")
		"healer","commander":
			var preferred=data.preferredRange*BWData.UNIT
			if distance<preferred*(0.65 if e.id=="commander" else 1):move=-direction*speed
			elif distance>preferred*1.5:move=direction*speed*0.4
			if e.cooldown<=0:
				e.cooldown=data.attackCooldown
				var best={};var missing=0.0
				for ally in enemies:
					if ally==e or ally.node.position.distance_to(node.position)>data.supportRadius*BWData.UNIT:continue
					if e.id=="commander" and ally.id not in ["commander","boss"]:ally.aura=data.auraDuration
					elif e.id=="healer" and ally.maxHp-ally.hp>missing:best=ally;missing=ally.maxHp-ally.hp
				if not best.is_empty():best.hp=minf(best.maxHp,best.hp+data.healAmount*(2.5 if e.elite else 1))
				ring(node.position,data.supportRadius*BWData.UNIT,Color("619c82") if e.id=="healer" else Color("cfab53"),0.45)
		"assassin":
			e.timer-=dt
			match e.state:
				"chase":
					if distance<3.2:e.state="vanish";e.timer=0.35;e.visual.visible=false
					else:move=direction*speed
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
			var phase=1 if e.hp/e.maxHp>0.66 else 2 if e.hp/e.maxHp>0.33 else 3
			if phase!=e.phase:e.phase=phase;sound("boss_phase");shake=0.15
			if e.state=="telegraph":
				e.timer-=dt
				if e.timer<=0:
					match e.pending_phase:
						1:
							if distance<=1.4+0.36:_hurt_player(e.damage)
							e.cooldown=2.0
						2:
							for i in 3:_bullet(node.position,direction.rotated(Vector3.UP,(i-1)*0.3),5.2,e.damage*0.6,10.4,false,0,"",0,0,false)
							e.cooldown=1.6
						3:
							if distance<=3:_hurt_player(e.damage*0.75)
							e.cooldown=2.4
					e.visual.action("attack");e.state="chase"
			else:
				var preferred=1.4 if phase==1 else 6.24 if phase==2 else 4.5
				if distance>preferred:move=direction*speed*(1 if phase==1 else 0.5 if phase==2 else 0.3)
				if e.cooldown<=0:
					e.state="telegraph";e.timer=0.5;e.pending_phase=phase
					ring(node.position,1.4 if phase==1 else 0.52 if phase==2 else 3.0,Color("e3564d"),0.5)
			if phase==3:
				e.summon-=dt
				if e.summon<=0:
					e.summon=7
					for i in 2:
						if enemies.size()<24:spawn_enemy("grunt",node.position+Vector3(randf_range(-1.8,1.8),0,randf_range(-1.8,1.8)))
		_:
			if distance>range_value:move=direction*speed
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
	node.position.x=clampf(node.position.x,-23.5,23.5);node.position.z=clampf(node.position.z,-23.5,23.5)
	if distance>0.01:e.visual.rotation.y=lerp_angle(e.visual.rotation.y,atan2(direction.x,direction.z),minf(1,dt*10))
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
		if primary and visual.fitted_timing and visual.lock_time>0:continue
		var direction=aim if manual else (target.node.position-player.position).normalized()
		var cooldown=1.0/(data.attacksPerSecond*run.stats.attackSpeed*slot.speed)
		var melee=data.get("behavior","")=="melee"
		var next_step=0 if combo_timer<=0 or combo_step>=2 else combo_step+1
		# The swing is heard while the blade is still moving; impacts land later from
		# _damage_enemy, so a connecting hit reads as whoosh-then-bite rather than one blip.
		if melee:_swing(id,next_step)
		if primary and visual.fitted_timing:
			var duration=minf(0.45,cooldown*0.85)
			if melee:
				combo_step=next_step
				combo_timer=cooldown*2.2
				if combo_step==2:
					duration=minf(0.7,cooldown*1.35)
					visual.action("ultimate",duration)
					var finisher=BWData.entry("abilities",BWData.CLASSES[run.class_id].ability)
					_ability_effect(finisher.id,player.position,finisher.range*run.stats.attackRange*BWData.UNIT*0.5)
				else:visual.action("attack",duration,combo_step==1)
			else:visual.action("attack",duration)
			pending_attacks.append({"time":duration*0.32,"id":id,"direction":direction})
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
			if attack.id=="ultimate":_resolve_ability(attack.data)
			else:_resolve_weapon(attack.id,attack.direction)

func _resolve_weapon(id: String,direction: Vector3):
	var slot=run.weapons[id];var data=slot.data
	var range_value=data.range*run.stats.attackRange*slot.range*BWData.UNIT
	var base=data.damage*run.stats.damage*slot.damage
	var behavior=data.get("behavior","singleProjectile")
	match behavior:
		"melee":
			slot.swings+=1
			var radius=range_value+(slot.shockwave*BWData.UNIT if slot.swings%3==0 else 0)
			var hit=[]
			var blade="dagger" if id=="daggers" else "sword"
			for e in enemies.duplicate():
				if e.node.position.distance_to(player.position)<=radius+e.radius:
					var roll=run.damage_roll(base);_damage_enemy(e,roll.damage,roll.critical,true,blade);hit.append(e)
					if e.hp>0 and slot.bleed>0:e.bleed=3;e.bleed_dps=slot.bleed
			slash(player.position,direction,radius,Color("ffca7a"))
			if not hit.is_empty():shake=maxf(shake,0.035)
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
				if i==0:muzzle(origin+Vector3.UP*0.8,shot_direction,Color("8db8f4") if id=="magic_orb" else Color("ffce7a"))
				_bullet(origin,shot_direction,data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,int(data.get("pierceCount",0)+slot.pierce),id,slot.burn,0.35 if behavior=="piercing" and slot.burn<=0 else 0.0,roll.critical)
	# Melee already played its swing as the animation started; everything else
	# reports here, as the projectile leaves.
	if behavior!="melee":sound(WEAPON_SHOT.get(id,"gun_pistol"))

func _chain(origin: Vector3,base: float,count: int,radius: float,hit: Array):
	for i in count:
		var next=nearest(origin,radius,hit)
		if next==null:return
		var end=next.node.position;beam(origin+Vector3.UP,end+Vector3.UP,Color("a5cfff"))
		var roll=run.damage_roll(base);_damage_enemy(next,roll.damage,roll.critical,true,"chain")
		if next.hp>0:next.burn=2;next.burn_dps=4
		hit.append(next);origin=end

# Where a targeted skill lands: the aimed point under the cursor/stick, pulled
# back to the skill's reach and kept inside the arena walls.
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
	point.x=clampf(point.x,-23.0,23.0);point.z=clampf(point.z,-23.0,23.0)
	point.y=0
	return point

func skill(index: int):
	var ids=BWData.skills(run.class_id)
	if index<0 or index>=ids.size():return
	var id=ids[index]
	if not running or run.stats.hp<=0 or airborne or not run.skill_ready(id):return
	var data=BWData.entry("abilities",id)
	if data.is_empty():return
	run.skill_cd[id]=data.cooldown
	var reach=data.range*run.stats.attackRange*BWData.UNIT
	var target=ground_target(reach)
	match data.behavior:
		"meteor":_cast_meteor(data,target)
		"voidLeap":_cast_void_leap(data,target)
		"thrust":_cast_thrust(data)
		"backstepVolley":_cast_backstep_volley(data)
		"ricochet":_cast_ricochet(data)
		"powderCharge":_cast_powder_charge(data,target)
		"markOfRuin":_cast_mark(data)
	changed.emit()

# A committed forward lunge: the warrior covers ground and spears everything in a
# narrow lane, so it rewards lining enemies up instead of standing in a crowd.
func _nearest_unhit(origin: Vector3,reach: float,hit_ids: Array):
	var best=null;var best_distance=reach*reach
	for e in enemies:
		if e.hp<=0 or hit_ids.has(e.node.get_instance_id()):continue
		var distance=origin.distance_squared_to(e.node.position)
		if distance<=best_distance:best=e;best_distance=distance
	return best

# One round that refuses to stop: it redirects to the next body it has not touched.
# Rewards picking a lane through a crowd rather than spraying at the nearest target.
func _cast_ricochet(data: Dictionary):
	var reach=data.range*run.stats.attackRange*BWData.UNIT
	var heading=aim.normalized() if aim.length_squared()>0.01 else last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	var first=nearest(player.position,reach)
	if first!=null:heading=(first.node.position-player.position).normalized()
	visual.rotation.y=atan2(heading.x,heading.z)
	visual.action("attack",0.26);sound("shoot_rifle")
	var accent=Color(data.get("accent","ffe9bd"))
	var roll=run.damage_roll(data.damage*run.stats.damage)
	var round_record=_bullet(player.position,heading,data.projectileSpeed*BWData.UNIT,roll.damage,reach,true,0,"rapid_rifle",0,0,roll.critical)
	if round_record!=null:
		round_record["bounces"]=int(data.get("bounces",3))
		round_record["bounce_range"]=reach
	muzzle(player.position+Vector3.UP*0.8,heading,accent)
	shake=maxf(shake,0.06)

# A charge lobbed onto the ground: it telegraphs, then throws everything off it.
func _cast_powder_charge(data: Dictionary,target: Vector3):
	var radius=data.blastRadius*run.stats.attackRange*BWData.UNIT
	var tone=Color(data.get("tone","ff9a4d"));var accent=Color(data.get("accent","ffd08a"))
	visual.rotation.y=atan2(target.x-player.position.x,target.z-player.position.z)
	visual.action("attack",0.26);sound("shoot_shotgun")
	var keg=glow_sprite(tone,0.5,1.4);keg.position=player.position+Vector3.UP*0.9;add_child(keg)
	var fuse=0.45
	telegraph(target,radius,tone,fuse)
	var lob=create_tween();lob.set_parallel(true)
	lob.tween_property(keg,"position",target+Vector3.UP*0.25,fuse).set_trans(Tween.TRANS_SINE)
	lob.tween_property(keg,"scale",Vector3.ONE*1.5,fuse)
	lob.chain().tween_callback(func():
		if is_instance_valid(keg):keg.queue_free()
		_powder_blast(target,radius,data.damage*run.stats.damage,tone,accent))

func _powder_blast(position: Vector3,radius: float,damage: float,tone: Color,accent: Color):
	sound_at("shoot_shotgun",position,3.0)
	for e in enemies.duplicate():
		var offset=e.node.position-position
		if offset.length()>radius+e.radius:continue
		var roll=run.damage_roll(damage)
		_damage_enemy(e,roll.damage,roll.critical,true,"ability")
		if e.hp<=0 or not is_instance_valid(e.node):continue
		# shoved outward, clamped to the arena so nothing is pushed through a wall
		var shove=e.node.position+offset.normalized()*1.5
		shove.x=clampf(shove.x,-23.5,23.5);shove.z=clampf(shove.z,-23.5,23.5)
		create_tween().tween_property(e.node,"position",shove,0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	shockwave(position,radius,tone,0.4,0.0,2.2)
	shockwave(position,radius*1.15,accent,0.48,0.1,1.5)
	radial_streaks(position,radius*1.1,accent,8,0.3)
	burst_ring(position,radius,accent,34,5.2,0.6)
	spark(position+Vector3.UP*0.8,tone,22)
	_flash_light(position,tone,3.4,radius*1.8,0.32)
	shake=maxf(shake,0.18)

# Paints a target; the mark survives its host and moves to the next body, and every
# jump makes it bite harder - the assassin's crit identity turned into a chain.
func _cast_mark(data: Dictionary):
	var reach=data.range*run.stats.attackRange*BWData.UNIT
	var victim=nearest(player.position,reach)
	if victim==null:return
	mark_chain=0
	_apply_mark(victim,Color(data.get("tone","63bd9f")))
	visual.action("attack",0.24)
	sound("skill_leap_launch")

func _apply_mark(e: Dictionary,tone: Color):
	for other in enemies:other["marked"]=false
	e["marked"]=true
	e["mark_tone"]=tone
	if is_instance_valid(e.node):
		var brand=glow_sprite(tone,1.1,1.6)
		brand.name="RuinMark";brand.position=Vector3.UP*2.1
		for old in e.node.get_children():
			if old.name=="RuinMark":old.queue_free()
		e.node.add_child(brand)
		var pulse=create_tween().set_loops()
		pulse.tween_property(brand,"scale",Vector3.ONE*1.35,0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(brand,"scale",Vector3.ONE,0.45).set_trans(Tween.TRANS_SINE)
	ring(e.node.position,0.9,tone,0.3)

func _cast_thrust(data: Dictionary):
	var reach=data.range*run.stats.attackRange*BWData.UNIT
	var lane=data.blastRadius*run.stats.attackRange*BWData.UNIT
	var heading=aim.normalized() if aim.length_squared()>0.01 else last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	visual.rotation.y=atan2(heading.x,heading.z)
	visual.action("attack",0.3);sound("sword_swing")
	var start=player.position
	var destination=start+heading*reach
	destination.x=clampf(destination.x,-23.5,23.5);destination.z=clampf(destination.z,-23.5,23.5)
	var tone=Color(data.get("tone","ffd08a"));var accent=Color(data.get("accent","ff9a4d"))
	create_tween().tween_property(player,"position",destination,0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	slash(start+heading*lane,heading,lane*1.6,accent)
	for step in 4:
		shockwave(start.lerp(destination,float(step)/3.0),lane*0.85,tone,0.26,step*0.035,1.7)
	var hit=[]
	for e in enemies.duplicate():
		var offset=e.node.position-start
		var along=offset.dot(heading)
		if along<-0.4 or along>reach+lane:continue
		if (offset-heading*along).length()>lane+e.radius:continue
		var roll=run.damage_roll(data.damage*run.stats.damage)
		_damage_enemy(e,roll.damage,roll.critical,true,"ability");hit.append(e)
	burst_ring(destination,lane,accent,22,4.0,0.5)
	_flash_light(destination,tone,2.4,lane*2.0,0.26)
	shake=maxf(shake,0.1 if hit.is_empty() else 0.15)

# Break away from whatever is on top of you, then answer with three blades the way
# you came - the dash and the daggers deliberately point opposite ways.
func _cast_backstep_volley(data: Dictionary):
	var reach=data.range*run.stats.attackRange*BWData.UNIT
	var heading=aim.normalized() if aim.length_squared()>0.01 else last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	visual.rotation.y=atan2(heading.x,heading.z)
	visual.action("attack",0.28)
	var tone=Color(data.get("tone","9d6bff"));var accent=Color(data.get("accent","d9c6ff"))
	var start=player.position
	var retreat=start-heading*(2.6*run.stats.attackRange)
	retreat.x=clampf(retreat.x,-23.5,23.5);retreat.z=clampf(retreat.z,-23.5,23.5)
	create_tween().tween_property(player,"position",retreat,0.17).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	sound("skill_leap_launch")
	shockwave(start,1.9,tone,0.3,0.0,1.6)
	burst_ring(start,1.7,accent,20,3.4,0.5)
	for i in range(-1,2):
		var roll=run.damage_roll(data.damage*run.stats.damage)
		_bullet(retreat,heading.rotated(Vector3.UP,i*0.17),data.projectileSpeed*BWData.UNIT,roll.damage,reach,true,1,"daggers",0,0,roll.critical)
	muzzle(retreat+Vector3.UP*0.8,heading,accent)
	shake=maxf(shake,0.08)

func _cast_meteor(data: Dictionary,target: Vector3):
	visual.action("attack",0.34)
	visual.rotation.y=atan2(target.x-player.position.x,target.z-player.position.z)
	sound("skill_meteor_cast")
	var origin=player.position+Vector3.UP*1.1
	if is_instance_valid(visual.hand_magic):origin=visual.hand_magic.global_position
	# The rock arcs in from above the target rather than travelling flat from the
	# hand, so the blast reads as something falling onto the ground. Distance sets
	# the timing, capped so a long throw still lands while the fight is in motion.
	var apex=target+Vector3.UP*6.0
	var travel=clampf(origin.distance_to(target)/(data.projectileSpeed*BWData.UNIT),0.26,0.55)
	var rock=Node3D.new();add_child(rock);rock.position=origin
	rock.add_child(glow_sprite(Color("c9a0ff"),1.5,1.6))
	rock.add_child(glow_sprite(Color("f0e2ff"),0.7,2.2))
	if quality=="PC":
		var lamp=OmniLight3D.new();lamp.light_color=Color("b07dff");lamp.light_energy=2.4;lamp.omni_range=4.0;rock.add_child(lamp)
		rock.add_child(trail_emitter(Color("b07dff"),0.09,0.36,22))
	var radius=data.blastRadius*run.stats.attackRange*BWData.UNIT
	telegraph(target,radius,Color("b07dff"),travel)
	var tween=create_tween()
	tween.tween_property(rock,"position",apex,travel*0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rock,"position",target+Vector3.UP*0.2,travel*0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		rock.queue_free()
		_meteor_blast(target,radius,data.damage*run.stats.damage))

func _meteor_blast(position: Vector3,radius: float,damage: float):
	sound_at("skill_meteor_blast",position,2.0)
	for e in enemies.duplicate():
		if e.node.position.distance_to(position)<=radius+e.radius:
			var roll=run.damage_roll(damage);_damage_enemy(e,roll.damage,roll.critical,true,"ability")
	shockwave(position,radius,Color("b07dff"),0.34,0.0,1.8)
	shockwave(position,radius*0.68,Color("f2e4ff"),0.22,0.05,2.0)
	radial_streaks(position,radius*1.1,Color("d9b8ff"),8,0.3)
	burst_ring(position,radius,Color("c9a0ff"),30,4.2,0.6)
	spark(position+Vector3.UP*0.4,Color("e9d4ff"),22)
	_flash_light(position,Color("b07dff"),2.8,radius*1.7,0.32)
	shake=maxf(shake,0.14)

func _cast_void_leap(data: Dictionary,target: Vector3):
	airborne=true
	visual.action("ultimate",0.7)
	visual.rotation.y=atan2(target.x-player.position.x,target.z-player.position.z)
	sound("skill_leap_launch")
	var start=player.position
	var radius=data.blastRadius*run.stats.attackRange*BWData.UNIT
	ring(start,2.0,Color(data.get("tone","7f6bff")),0.35)
	radial_streaks(start,2.4,Color(data.get("accent","cfc0ff")),6,0.26)
	var flight=clampf(start.distance_to(target)/16.0,0.26,0.6)
	telegraph(target,radius,Color(data.get("tone","7f6bff")),flight)
	var trail: Node=null
	if quality=="PC":
		trail=trail_emitter(Color("8f74ff"),0.1,0.42,26)
		player.add_child(trail)
	# Arc through the air: the model lifts on its own axis while the body travels,
	# so the landing has a visible drop instead of sliding along the floor.
	var lift=create_tween()
	lift.tween_property(visual,"position:y",2.6,flight*0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(visual,"position:y",0.0,flight*0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var travel=create_tween()
	travel.tween_property(player,"position",target,flight).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_callback(func():
		if trail!=null and is_instance_valid(trail):trail.queue_free()
		airborne=false
		_leap_land(target,radius,data.damage*run.stats.damage,Color(data.get("tone","8f74ff")),Color(data.get("accent","cfc0ff"))))

func _leap_land(position: Vector3,radius: float,damage: float,tone: Color=Color("8f74ff"),accent: Color=Color("cfc0ff")):
	sound_at("skill_leap_land",position,2.0)
	for e in enemies.duplicate():
		if e.node.position.distance_to(position)<=radius+e.radius:
			var roll=run.damage_roll(damage);_damage_enemy(e,roll.damage,roll.critical,true,"ability")
			if e.hp>0:e.slow=2;e.slow_amount=0.3
	shockwave(position,radius,tone,0.38,0.0,2.0)
	shockwave(position,radius*1.2,tone.darkened(0.35),0.46,0.09,1.5)
	radial_streaks(position,radius*1.15,accent,9,0.32)
	burst_ring(position,radius,accent.darkened(0.15),34,4.8,0.62)
	shards(position,radius*0.85,Color("b3a2ff"),10)
	_flash_light(position,Color("8f74ff"),3.2,radius*1.8,0.34)
	shake=maxf(shake,0.18)

func ability():
	if not running or run.ability_cd>0 or run.stats.hp<=0 or airborne:return
	var data=BWData.entry("abilities",BWData.CLASSES[run.class_id].ability)
	run.ability_cd=data.cooldown
	if visual.fitted_timing and visual.clips.has("ultimate"):
		pending_attacks.clear()
		visual.action("ultimate",0.9)
		pending_attacks.append({"time":0.45,"id":"ultimate","data":data})
	else:
		_resolve_ability(data);visual.action("attack")
	changed.emit()

func _resolve_ability(data: Dictionary):
	var range_value=data.range*run.stats.attackRange*BWData.UNIT
	if data.id=="fan_shot":
		_ability_effect(data.id,player.position,range_value)
		for i in range(-2,3):
			var roll=run.damage_roll(data.damage*run.stats.damage)
			_bullet(player.position,aim.rotated(Vector3.UP,i*0.16),data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,0,"rapid_rifle",0,0,roll.critical)
	else:
		var strike_position=player.position
		if data.id=="shadow_strike":
			# A fast dash reads better than a blink and disorients less - cover the
			# distance in a short tween instead of snapping player.position directly.
			strike_position=player.position+aim*data.range*BWData.UNIT*0.5
			strike_position.x=clampf(strike_position.x,-23.5,23.5);strike_position.z=clampf(strike_position.z,-23.5,23.5)
			create_tween().tween_property(player,"position",strike_position,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			range_value=65*run.stats.attackRange*BWData.UNIT
		for e in enemies.duplicate():
			if e.node.position.distance_to(strike_position)<=range_value+e.radius:
				var roll=run.damage_roll(data.damage*run.stats.damage);_damage_enemy(e,roll.damage,roll.critical,true,"ability")
				if e.hp>0 and data.id=="frost_nova":e.slow=3;e.slow_amount=0.45
		_ability_effect(data.id,strike_position,range_value)
	sound("ulti_"+data.id)

func radial_streaks(pos: Vector3,radius: float,color: Color,count: int,duration: float=0.26):
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.34,0.34)
		var reach=radius*rng.randf_range(0.5,1.15)
		var lance=flat_sprite(color,radius*rng.randf_range(0.07,0.15),reach*0.9,2.0)
		lance.position=pos+Vector3.UP*0.09;add_child(lance)
		lance.rotation.y=angle
		lance.get_child(0).position.z=-reach*0.5
		lance.scale=Vector3(1,1,0.25)
		var mat=lance.get_child(0).material_override
		var tween=create_tween();tween.set_parallel(true)
		tween.tween_property(lance,"scale",Vector3.ONE,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat,"albedo_color",Color(0,0,0),duration)
		tween.chain().tween_callback(lance.queue_free)

func _ability_effect(id: String,pos: Vector3,radius: float):
	match id:
		"frost_nova":
			shockwave(pos,radius,Color("8fd8ff"),0.34,0.0,1.9)
			shockwave(pos,radius*0.72,Color("dff2ff"),0.22,0.05,2.2)
			shards(pos,radius,Color("9ad6ff"),12)
			burst_ring(pos,radius,Color("cfeeff"),26,3.4,0.6)
			_flash_light(pos,Color("8fd8ff"),3.2,radius*1.6,0.3)
			shake=maxf(shake,0.05)
		"war_cry":
			shockwave(pos,radius,Color("ffb066"),0.3,0.0,2.2)
			shockwave(pos,radius*1.15,Color("ff7a4d"),0.38,0.1,1.6)
			radial_streaks(pos,radius*1.05,Color("ffc27a"),7,0.28)
			burst_ring(pos,radius,Color("ffc98a"),30,4.6,0.55)
			_flash_light(pos,Color("ff9a52"),2.6,radius*1.5,0.28)
			shake=maxf(shake,0.16)
		"shadow_strike":
			shockwave(pos,radius*1.15,Color("7a46d8"),0.28,0.0,1.3)
			radial_streaks(pos,radius*1.3,Color("e2d2ff"),4,0.2)
			slash(pos,aim.rotated(Vector3.UP,0.7),radius*1.4,Color("f0e6ff"))
			slash(pos,aim.rotated(Vector3.UP,-0.7),radius*1.4,Color("c9a6ff"))
			burst_ring(pos,radius,Color("a97dff"),22,3.0,0.5)
			_flash_light(pos,Color("8a5bff"),2.2,radius*1.5,0.26)
			shake=maxf(shake,0.07)
		"fan_shot":
			var cone=flat_sprite(Color("ffc46a"),1.9,1.5,2.4)
			cone.position=pos+Vector3.UP*0.85;add_child(cone)
			_aim_along(cone,aim);cone.get_child(0).position.z=-0.75
			var mat=cone.get_child(0).material_override
			var tween=create_tween();tween.set_parallel(true)
			tween.tween_property(cone,"scale",Vector3(1.6,1,1.5),0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat,"albedo_color",Color(0,0,0),0.16)
			tween.chain().tween_callback(cone.queue_free)
			spark(pos+aim*0.7+Vector3.UP*0.85,Color("ffcf8a"),20)
			_flash_light(pos+aim*0.6+Vector3.UP*0.85,Color("ffb761"),3.4,3.0,0.16)
			shake=maxf(shake,0.1)

func _flash_light(pos: Vector3,color: Color,energy: float,range_value: float,duration: float):
	if quality!="PC":return
	var lamp=OmniLight3D.new();lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=range_value
	lamp.position=pos+Vector3.UP*0.8;add_child(lamp)
	var tween=create_tween()
	tween.tween_property(lamp,"light_energy",0.0,duration)
	tween.tween_callback(lamp.queue_free)

func _bullet(origin: Vector3,direction: Vector3,speed: float,damage: float,distance: float,friendly: bool,pierce: int,weapon: String,burn: float,slow: float,critical: bool):
	if bullets.size()>=384:return
	# A projectile is a rig, not a single mesh: a small blown-out core for the bloom
	# to catch, one or two soft halos around it, and a world-space trail behind.
	var node=Node3D.new();add_child(node);node.position=origin+Vector3.UP*0.8
	var rich=quality=="PC"
	var orb=weapon=="magic_orb"
	var tone=Color("8ac8ff") if orb else (Color("ffd9a0") if friendly else Color("ff9d86"))
	var halo_tone=Color("6fa8ff") if orb else (Color("ffab4d") if friendly else Color("ff5a4a"))
	var core=MeshInstance3D.new();core.mesh=bullet_mesh
	var core_mat=bullet_material.duplicate();core_mat.albedo_color=tone*(1.0 if orb else 1.7)
	core.material_override=core_mat;core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)
	if orb:
		core.scale=Vector3.ONE*1.05
		var rig=_orb_dressing(halo_tone,rich)
		node.add_child(rig)
		# The spin has to be owned by the node it turns: a world-bound looping tween
		# outlives the projectile and keeps cycling against a freed target.
		var motes=rig.get_node_or_null("Motes")
		if motes!=null:motes.create_tween().set_loops().tween_property(motes,"rotation:y",TAU,0.9).from(0.0)
	else:
		_aim_along(core,direction);core.scale=Vector3(0.5,0.5,2.3)
		var streak=flat_sprite(halo_tone,0.24,1.25,1.4);node.add_child(streak)
		_aim_along(streak,direction)
		node.add_child(glow_sprite(tone,0.26,1.7))
	if rich and bullets.size()<20:
		var lamp=OmniLight3D.new();lamp.light_color=halo_tone
		lamp.light_energy=1.8 if orb else 1.0;lamp.omni_range=2.6 if orb else 1.5
		node.add_child(lamp)
		node.add_child(trail_emitter(halo_tone,0.075 if orb else 0.045,0.32 if orb else 0.2,18 if orb else 12))
	var record={"node":node,"direction":direction.normalized(),"speed":speed,"damage":damage,"remaining":distance,"friendly":friendly,"pierce":pierce,"hit":[],"weapon":weapon,"burn":burn,"slow":slow,"critical":critical,"radius":0.5 if weapon=="magic_orb" else 0.16}
	bullets.append(record)
	return record

func _orb_dressing(tone: Color,rich: bool) -> Node3D:
	var rig=Node3D.new()
	rig.add_child(glow_sprite(tone,1.3,1.1))
	rig.add_child(glow_sprite(Color("5ea8ff"),0.8,1.3))
	if not rich:return rig
	var motes=Node3D.new();motes.name="Motes";rig.add_child(motes)
	for i in 3:
		var mote=glow_sprite(Color("dce9ff"),0.24,1.7)
		mote.position=Vector3.RIGHT.rotated(Vector3.UP,TAU*i/3.0)*0.32
		motes.add_child(mote)
	return rig

func _projectiles(dt: float):
	for b in bullets.duplicate():
		var previous=b.node.position;var step=b.direction*b.speed*dt;b.node.position+=step;b.remaining-=step.length()
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
				_impact(b.node.position,b.weapon,b.friendly)
				if b.friendly and b.get("bounces",0)>0:
					var next=_nearest_unhit(b.node.position,b.get("bounce_range",6.0),b.hit)
					if next!=null:
						b.bounces-=1
						b.direction=(next.node.position+Vector3.UP*0.8-b.node.position).normalized()
						b.remaining=b.get("bounce_range",6.0)
						_aim_along(b.node.get_child(0),b.direction)
						beam(b.node.position,next.node.position+Vector3.UP*0.8,Color("ffe9bd"))
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
		damage_text(e.node.position,damage,Color("ffe4a8") if critical else Color("d9dce2"))
		_impact_sound(e,impact,critical)
		e.visual.flash(0.14 if critical else 0.1)
		e.visual.hit_react(e.node.position-player.position,1.35 if critical else 1.0)
		spark(e.node.position+Vector3.UP*0.9,Color("ffe0a6") if critical else Color("ffb072"),14 if critical else 7)
	if e.hp>0:return
	enemies.erase(e);e.visual.action("death")
	if e.get("marked",false):
		var heir=nearest(e.node.position,9.0)
		if heir!=null:mark_chain+=1;_apply_mark(heir,e.get("mark_tone",Color("63bd9f")))
		else:mark_chain=0
	spark(e.node.position+Vector3.UP*0.9,Color(ENEMY_COLORS[e.id]).lightened(0.4),24 if e.elite or e.id=="boss" else 16)
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
	damage_text(player.position,actual,Color("ff8678"));visual.action("hit");shake=clampf(actual/100,0.04,0.18);sound("player_hit")
	hit_flash=clampf(actual/90,0.12,0.38);spark(player.position+Vector3.UP*1.0,Color("ff8678"),8)
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
	bullets.clear();run.wave+=1;spawned=0;spawn_timer=0;rest_time=4;running=true
	sound("wave_start");wave_music();changed.emit()

func wave_music():
	if audio!=null:audio.music("boss" if run.wave%10==0 else "combat")

# A thin ground ring marking where an aimed skill will land, held until it does.
# ring() draws a filled glow, which at blast radius reads as a solid blob.
func telegraph(pos: Vector3,radius: float,color: Color,duration: float):
	var mark=flat_sprite(color,radius*2.3,radius*2.3,0.8,ring_texture)
	mark.position=pos+Vector3.UP*0.05;mark.scale=Vector3.ONE*0.9;add_child(mark)
	var mat=mark.get_child(0).material_override
	var fade=minf(0.14,duration*0.4)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(mark,"scale",Vector3.ONE,duration*0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat,"albedo_color",Color(0,0,0),fade).set_delay(maxf(0.0,duration-fade))
	tween.chain().tween_callback(mark.queue_free)

func ring(pos: Vector3,radius: float,color: Color,duration: float):
	var pulse=flat_sprite(color,radius*2.3,radius*2.3,1.3)
	pulse.position=pos+Vector3.UP*0.06;pulse.scale=Vector3.ONE*0.3;add_child(pulse)
	var mat=pulse.get_child(0).material_override
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(pulse,"scale",Vector3.ONE,maxf(duration*0.35,0.09)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat,"albedo_color",Color(0,0,0),maxf(duration*0.45,0.12)).set_delay(duration*0.55)
	tween.chain().tween_callback(pulse.queue_free)

# A swing reads as an arc swept in front of the fighter, not a circle drawn around it.
func slash(origin: Vector3,direction: Vector3,radius: float,color: Color):
	var pivot=Node3D.new();pivot.position=origin+Vector3.UP*0.55;add_child(pivot)
	_aim_along(pivot,direction)
	var arc=flat_sprite(color,radius*2.6,radius*1.35,2.6)
	arc.position=Vector3(0,0,-radius*0.6);pivot.add_child(arc)
	var mat=arc.get_child(0).material_override
	pivot.rotation.y+=0.6
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(pivot,"rotation:y",pivot.rotation.y-1.2,0.17).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat,"albedo_color",Color(0,0,0),0.17)
	tween.chain().tween_callback(pivot.queue_free)

func beam(a: Vector3,b: Vector3,color: Color):
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES);mesh.surface_add_vertex(a);mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex((a+b)*0.5+Vector3(0.1,0.2,0.1));mesh.surface_add_vertex(b);mesh.surface_end()
	var node=MeshInstance3D.new();node.mesh=mesh;var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mesh.surface_set_material(0,mat);node.material_override=mat;add_child(node)
	get_tree().create_timer(0.15).timeout.connect(node.queue_free)

# A soft additive billboard. Layering two or three of these at different sizes is
# what turns a flat coloured dot into something that reads as light.
func glow_sprite(color: Color,size: float,energy: float=1.0) -> MeshInstance3D:
	var quad=QuadMesh.new();quad.size=Vector2(size,size)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true
	mat.albedo_texture=glow_texture;mat.albedo_color=Color(color.r*energy,color.g*energy,color.b*energy)
	mat.disable_receive_shadows=true
	var node=MeshInstance3D.new();node.mesh=quad;node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# local_coords=false leaves emitted particles behind in world space, so a moving
# emitter draws a trail instead of dragging its particles along with it.
func trail_emitter(color: Color,radius: float,life: float,amount: int,drift: float=0.4) -> CPUParticles3D:
	var p=CPUParticles3D.new()
	p.amount=amount;p.lifetime=life;p.local_coords=false;p.explosiveness=0.0
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=radius
	p.direction=Vector3.UP;p.spread=180;p.initial_velocity_min=0.0;p.initial_velocity_max=drift
	p.gravity=Vector3.ZERO;p.damping_min=0.6;p.damping_max=1.2
	p.scale_amount_min=0.6;p.scale_amount_max=1.0
	var curve=Curve.new();curve.add_point(Vector2(0,1.0));curve.add_point(Vector2(1,0.0))
	var shrink=CurveTexture.new();shrink.curve=curve;p.scale_amount_curve=shrink
	var ramp=Gradient.new()
	ramp.set_offset(0,0.0);ramp.set_color(0,color)
	ramp.set_offset(1,1.0);ramp.set_color(1,Color(color.r,color.g,color.b,0.0))
	p.color_ramp=ramp
	var mesh=SphereMesh.new();mesh.radius=radius*0.9;mesh.height=radius*1.8;mesh.radial_segments=5;mesh.rings=3
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo=true;mat.albedo_color=color
	mesh.material=mat;p.mesh=mesh;p.material_override=mat
	p.emitting=true
	return p

func flat_sprite(color: Color,width: float,length: float,energy: float=1.0,texture: Texture2D=null) -> Node3D:
	var quad=QuadMesh.new();quad.size=Vector2(width,length)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture=texture if texture!=null else glow_texture
	mat.albedo_color=Color(color.r*energy,color.g*energy,color.b*energy)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.disable_receive_shadows=true
	var blade=MeshInstance3D.new();blade.mesh=quad;blade.material_override=mat
	blade.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.rotation.x=-PI*0.5
	var pivot=Node3D.new();pivot.add_child(blade)
	return pivot

# An expanding pressure front. Several of these staggered read as a blast rolling
# outwards rather than one circle appearing at full size.
func shockwave(pos: Vector3,radius: float,color: Color,duration: float,delay: float=0.0,energy: float=1.6):
	var wave=flat_sprite(color,radius*2.3,radius*2.3,energy,ring_texture)
	wave.position=pos+Vector3.UP*0.07;wave.scale=Vector3.ONE*0.18;add_child(wave)
	var mat=wave.get_child(0).material_override
	mat.albedo_color=Color(0,0,0)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(wave,"scale",Vector3.ONE,duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat,"albedo_color",color*energy,0.05).set_delay(delay)
	tween.tween_property(mat,"albedo_color",Color(0,0,0),duration*0.8).set_delay(delay+duration*0.25)
	tween.chain().tween_callback(wave.queue_free)

# Particles thrown outward along the ground from a ring, for dust and frost fronts.
func burst_ring(pos: Vector3,radius: float,color: Color,amount: int,speed: float=3.0,life: float=0.5):
	if quality!="PC" and rng.randf()>0.5:return
	var p=CPUParticles3D.new()
	p.amount=amount;p.lifetime=life;p.one_shot=true;p.explosiveness=0.95
	p.emission_shape=CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis=Vector3.UP;p.emission_ring_radius=radius*0.55;p.emission_ring_inner_radius=radius*0.2
	p.emission_ring_height=0.1
	p.direction=Vector3.UP;p.spread=25;p.initial_velocity_min=speed*0.3;p.initial_velocity_max=speed*0.6
	p.radial_accel_min=speed*1.6;p.radial_accel_max=speed*2.6
	p.gravity=Vector3(0,-3.0,0);p.damping_min=0.8;p.damping_max=1.6
	p.scale_amount_min=0.5;p.scale_amount_max=1.1
	var curve=Curve.new();curve.add_point(Vector2(0,1.0));curve.add_point(Vector2(1,0.0))
	var shrink=CurveTexture.new();shrink.curve=curve;p.scale_amount_curve=shrink
	var mesh=SphereMesh.new();mesh.radius=0.045;mesh.height=0.09;mesh.radial_segments=4;mesh.rings=2
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mat.albedo_color=color
	mesh.material=mat;p.mesh=mesh;p.material_override=mat
	p.position=pos;add_child(p);p.emitting=true
	get_tree().create_timer(life+0.25).timeout.connect(p.queue_free)

# Spikes driven up out of the ground around a radius - the frost nova's silhouette.
func shards(pos: Vector3,radius: float,color: Color,count: int):
	var mesh=CylinderMesh.new();mesh.top_radius=0.0;mesh.bottom_radius=0.12;mesh.height=1.0;mesh.radial_segments=5;mesh.rings=1
	var mat=StandardMaterial3D.new();mat.albedo_color=color
	mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=1.1
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=0.25
	for i in count:
		var angle=TAU*i/count+rng.randf_range(-0.16,0.16)
		var spike=MeshInstance3D.new();spike.mesh=mesh;spike.material_override=mat
		spike.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spike.position=pos+Vector3(cos(angle),0,sin(angle))*radius*rng.randf_range(0.55,0.95)
		spike.rotation=Vector3(rng.randf_range(-0.22,0.22),angle,rng.randf_range(-0.22,0.22))
		var tall=rng.randf_range(0.5,1.0)
		spike.scale=Vector3(1,0.05,1);add_child(spike)
		var tween=create_tween()
		tween.tween_property(spike,"scale",Vector3(1,tall,1),0.11).set_delay(i*0.012).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.2)
		tween.tween_property(spike,"scale",Vector3(0.2,0.02,0.2),0.22)
		tween.tween_callback(spike.queue_free)

func _impact(pos: Vector3,weapon: String,friendly: bool):
	var tone=Color("9fc6ff") if weapon=="magic_orb" else (Color("ffcf8a") if friendly else Color("ff8a72"))
	spark(pos,tone,16 if weapon=="magic_orb" else 9)
	var burst=glow_sprite(tone,0.95 if weapon=="magic_orb" else 0.6,1.15)
	burst.position=pos;add_child(burst)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(burst,"scale",Vector3.ONE*(1.7 if weapon=="magic_orb" else 1.4),0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst.material_override,"albedo_color",Color(0,0,0),0.18)
	tween.chain().tween_callback(burst.queue_free)
	if weapon=="magic_orb":ring(pos,0.9,Color("7fb0ff"),0.22)

func spark(pos: Vector3,color: Color,amount: int=8):
	if quality!="PC" and rng.randf()>0.45:return
	var node=CPUParticles3D.new();node.amount=amount;node.lifetime=0.3;node.one_shot=true;node.explosiveness=1.0
	node.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;node.emission_sphere_radius=0.09
	node.direction=Vector3.UP;node.spread=180;node.initial_velocity_min=1.3;node.initial_velocity_max=3.4
	node.gravity=Vector3(0,-5.5,0);node.scale_amount_min=0.45;node.scale_amount_max=1.0
	var mesh=SphereMesh.new();mesh.radius=0.028;mesh.height=0.056;mesh.radial_segments=4;mesh.rings=2
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color
	mesh.material=mat;node.mesh=mesh;node.material_override=mat
	node.position=pos;add_child(node);node.emitting=true
	get_tree().create_timer(node.lifetime+0.15).timeout.connect(node.queue_free)

func muzzle(pos: Vector3,direction: Vector3,color: Color):
	if quality!="PC":return
	var node=glow_sprite(color,0.7,1.5)
	node.position=pos;add_child(node)
	var mat=node.material_override
	_aim_along(node,direction);node.scale=Vector3(1.5,1,1)
	var lamp=OmniLight3D.new();lamp.light_color=color;lamp.light_energy=1.7;lamp.omni_range=1.5;node.add_child(lamp)
	var tween=create_tween();tween.set_parallel(true)
	tween.tween_property(node,"scale",Vector3(0.2,0.2,0.5),0.07)
	tween.tween_property(mat,"albedo_color:a",0.0,0.07)
	tween.chain().tween_callback(node.queue_free)

# look_at needs a target that is not colinear with UP; aim vectors are horizontal
# here, but guard anyway so a stray vertical direction cannot spam errors.
func _aim_along(node: Node3D,direction: Vector3):
	if direction.length_squared()<0.0001:return
	var d=direction.normalized()
	if absf(d.y)>0.99:return
	node.rotation=Vector3(0,atan2(-d.x,-d.z),0)

func damage_text(pos: Vector3,amount: float,color: Color):
	if quality!="PC" and randf()>0.4:return
	var label=Label3D.new();label.text=str(int(round(amount)));label.font_size=38;label.pixel_size=0.008;label.modulate=color;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=pos+Vector3(rng.randf_range(-0.2,0.2),2.0,0);add_child(label)
	var tween=create_tween();tween.set_parallel(true);tween.tween_property(label,"position:y",label.position.y+0.6,0.55);tween.tween_property(label,"modulate:a",0.0,0.55);tween.chain().tween_callback(label.queue_free)

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
