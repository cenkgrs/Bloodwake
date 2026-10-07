class_name BWSkills
extends Node3D

# The class kit: the two bound skills every class carries and the ultimate behind
# them. Each cast is self-contained - it reads the run, moves the body, spends the
# cooldown and draws itself - so the set reads as a catalogue of what the classes
# can do rather than as branches inside the combat loop.
#
# `w` is the world these casts act on: the body they move, the enemies they reach
# for and the effects they draw. Held as a plain reference rather than reached for
# through the tree, so a cast cannot quietly act on a world it was not given.
#
# Parked at the world's origin with an identity transform, like BWFx and for the
# same reason: the meteor and the powder keg are added here and positioned in
# world coordinates.

var w: BWWorld
var cast_active=false
var blood_cast: Tween

func bind(world: BWWorld):
	w=world

func skill(index: int):
	var ids=BWData.skills(w.run.class_id)
	if index<0 or index>=ids.size():return
	var id=ids[index]
	if not w.running or w.run.stats.hp<=0 or w.airborne or cast_active or not w.run.skill_ready(id):return
	if w.run.class_id=="gunslinger" and w.visual.lock_time>0 and w.visual.state in ["bombthrow","ultimate"]:return
	var data=BWData.entry("abilities",id)
	if data.is_empty():return
	if w.run.class_id=="gunslinger":w.aim=w.skill_aim()
	w.run.skill_cd[id]=data.cooldown
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	var target=w.ground_target(reach)
	match data.behavior:
		"meteor":_cast_meteor(data,target)
		"voidLeap":_cast_void_leap(data,target)
		"whirl":_cast_whirl(data)
		"backstepVolley":_cast_backstep_volley(data)
		"ricochet":_cast_ricochet(data)
		"powderCharge":_cast_powder_charge(data,target)
		"markOfRuin":_cast_mark(data)
		"bloodTeleport":_cast_blood_step(data,target)
	w.changed.emit()

func _begin_blood_cast():
	if blood_cast!=null:blood_cast.kill()
	cast_active=true
	w.pending_attacks.clear();w.swing_gate=0.0;w.combo_timer=0.0;w.dash_time=0.0
	w.visual.lock_time=0.0

func _end_blood_cast():
	if blood_cast!=null:blood_cast.kill();blood_cast=null
	cast_active=false;w.airborne=false
	if is_instance_valid(w.visual):w.visual.visible=true

func _blood_cast_live() -> bool:
	if not cast_active:return false
	if not w.running or w.run.stats.hp<=0:
		_end_blood_cast();return false
	return true

# Teleport may cross obstacles, but must land on free ground inside cast range.
# Back off toward the caster rather than pushing an obstructed endpoint farther
# away, which could put a blink outside the arena or beyond its range.
func blood_step_destination(target: Vector3,reach: float) -> Vector3:
	var start=w.player.position
	var end=start+(target-start).limit_length(reach);end.y=0
	end=w.arena.clamp_inside(end)
	var steps=maxi(1,ceili(start.distance_to(end)/0.1))
	for i in range(steps+1):
		var point=end.lerp(start,float(i)/steps)
		var clear=true
		for block in w.arena.blockers:
			if point.distance_to(block.pos)<block.radius+0.43:clear=false;break
		if clear and not w.arena.in_rect(point,0.43):return point
	return start

# Both casts follow the markers authored into the Revenant clips (BWVisual.REVENANT_EVENTS):
# the body vanishes, is moved while unseen, reappears and only then strikes.
func _blood_times(clip: String,events: Array,fallback: Array) -> Array:
	if not w.visual.clips.has(clip) or not String(w.visual.clips[clip]).begins_with("REV_"):return fallback
	var times=[]
	for event in events:times.append(BWVisual.revenant_time(clip,event))
	return times

func _cast_blood_step(data: Dictionary,target: Vector3):
	_begin_blood_cast();w.airborne=true
	var start=w.player.position
	var landing=blood_step_destination(target,data.range*w.run.stats.attackRange*BWData.UNIT)
	var direction=(landing-start).normalized()
	if direction.length_squared()>0.01:w.visual.rotation.y=atan2(direction.x,direction.z)
	var t=_blood_times("teleport",["hide","move","show","damage","recover"],[0.12,0.18,0.24,0.34,0.6])
	w.visual.action("teleport",-1.0 if t[0]!=0.12 else 0.6)
	w.fx.blood_gate(start,1.0);w.sound("skill_leap_launch")
	var cast=create_tween();blood_cast=cast
	cast.tween_interval(t[0])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		w.visual.visible=false;w.fx.blood_travel(start,landing))
	cast.tween_interval(t[1]-t[0])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		w.player.position=landing)
	cast.tween_interval(t[2]-t[1])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		w.visual.visible=true;w.fx.blood_gate(landing,1.1))
	cast.tween_interval(t[3]-t[2])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		w.airborne=false
		var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
		_blood_damage(landing,radius,data.damage*w.run.stats.damage)
		w.fx.blood_burst(landing,radius,1.5)
		w.fx.revenant_claws(landing,direction,radius*0.65)
		w.sound_at("skill_leap_land",landing,1.0);w.shake=maxf(w.shake,0.12))
	# The cast (and its movement lock) ends where the recovery starts; steering
	# may cut the remaining recovery short.
	cast.tween_interval(t[4]-t[3]);cast.tween_callback(_end_blood_cast)

func _cast_blood_burst(data: Dictionary):
	_begin_blood_cast()
	var t=_blood_times("ultimate",["telegraph","damage","dissipate"],[0.0,0.5,1.1])
	w.visual.action("ultimate",-1.0 if t[1]!=0.5 else 1.1)
	var origin=w.player.position
	var radius=data.range*w.run.stats.attackRange*BWData.UNIT
	w.sound("skill_meteor_cast")
	var cast=create_tween();blood_cast=cast
	cast.tween_interval(t[0])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		w.fx.blood_charge(origin,radius,t[1]-t[0]))
	cast.tween_interval(t[1]-t[0])
	cast.tween_callback(func():
		if not _blood_cast_live():return
		_blood_damage(origin,radius,data.damage*w.run.stats.damage)
		w.fx.blood_burst(origin,radius,3.5)
		w.sound_at("skill_meteor_blast",origin,1.5);w.shake=maxf(w.shake,0.22))
	cast.tween_interval(t[2]-t[1]);cast.tween_callback(_end_blood_cast)

func _blood_damage(origin: Vector3,radius: float,damage: float):
	w.damage_area(origin,radius,damage)
	for e in w.enemies.duplicate():
		if e.node.position.distance_to(origin)>radius+e.radius:continue
		var roll=w.run.damage_roll(damage)
		w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
		w.fx.revenant_impact(e.node.position+Vector3.UP*0.9)
		if e.hp>0:w._stagger(e)

# One round that refuses to stop: it redirects to the next body it has not touched.
# Rewards picking a lane through a crowd rather than spraying at the w.nearest target.
func _cast_ricochet(data: Dictionary):
	var heading=w.aim.normalized() if w.aim.length_squared()>0.01 else w.last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	w.visual.rotation.y=atan2(heading.x,heading.z)
	w.pending_attacks.clear()
	w.visual.action("ricochet")
	w.pending_attacks.append({"time":9.0/60.0,"id":"bh_ricochet","data":data,"direction":heading})

func _release_ricochet(data: Dictionary,heading: Vector3):
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	w.sound("shoot_rifle")
	var accent=Color(data.get("accent","ffe9bd"))
	var roll=w.run.damage_roll(data.damage*w.run.stats.damage)
	var origin=w.visual.bloodhound_socket("R")
	var round_record=w._bullet(origin-Vector3.UP*0.8,heading,data.projectileSpeed*BWData.UNIT,roll.damage,reach,true,0,"rapid_rifle",0,0,roll.critical)
	if round_record!=null:
		round_record["body_capsule"]=true
		round_record["bounces"]=int(data.get("bounces",3))
		round_record["bounce_range"]=reach
	w.fx.muzzle(origin,heading,accent)
	w.shake=maxf(w.shake,0.06)

# A charge lobbed onto the ground: it telegraphs, then throws everything off it.

func _cast_powder_charge(data: Dictionary,target: Vector3):
	w.pending_attacks.clear()
	w.visual.rotation.y=atan2(target.x-w.player.position.x,target.z-w.player.position.z)
	w.visual.action("bombthrow" if w.visual.clips.has("bombthrow") else "attack")
	w.pending_attacks.append({"time":19.0/60.0,"id":"bh_bomb","data":data,"target":target})

func _release_powder_charge(data: Dictionary,target: Vector3):
	w.bloodhound_event.emit("THROW_RELEASE")
	var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
	var tone=Color(data.get("tone","ff9a4d"));var accent=Color(data.get("accent","ffd08a"))
	w.sound("shoot_shotgun")
	var keg=w.fx.glow_sprite(tone,0.5,1.4);add_child(keg)
	var origin=w.visual.bloodhound_bomb_position();keg.position=origin
	var fuse=0.45
	w.fx.telegraph(target,radius,tone,fuse)
	var lob=create_tween();lob.set_parallel(true)
	lob.tween_method(func(t: float):keg.position=origin.lerp(target+Vector3.UP*0.25,t)+Vector3.UP*sin(PI*t)*0.8,0.0,1.0,fuse)
	lob.tween_property(keg,"scale",Vector3.ONE*1.5,fuse)
	lob.chain().tween_callback(func():
		if is_instance_valid(keg):keg.queue_free()
		_powder_blast(target,radius,data.damage*w.run.stats.damage,tone,accent))

func _powder_blast(position: Vector3,radius: float,damage: float,tone: Color,accent: Color):
	w.sound_at("shoot_shotgun",position,3.0)
	w.damage_area(position,radius,damage)
	for e in w.enemies.duplicate():
		var offset=e.node.position-position
		if offset.length()>radius+e.radius:continue
		var roll=w.run.damage_roll(damage)
		w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
		if e.hp<=0 or not is_instance_valid(e.node):continue
		w._stagger(e,1.5,0.0)
		# shoved outward, clamped to the arena so nothing is pushed through a wall
		var shove=e.node.position+offset.normalized()*1.5
		shove=w.arena.clamp_inside(shove)
		create_tween().tween_property(e.node,"position",shove,0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	w.fx.shockwave(position,radius,tone,0.4,0.0,2.2)
	w.fx.shockwave(position,radius*1.15,accent,0.48,0.1,1.5)
	w.fx.radial_streaks(position,radius*1.1,accent,8,0.3)
	w.fx.burst_ring(position,radius,accent,34,5.2,0.6)
	w.fx.spark(position+Vector3.UP*0.8,tone,22)
	w.fx.flash_light(position,tone,3.4,radius*1.8,0.32)
	w.shake=maxf(w.shake,0.18)

# Paints a target; the mark survives its host and moves to the next body, and every
# jump makes it bite harder - the assassin's crit identity turned into a chain.

func _cast_mark(data: Dictionary):
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	var victim=w.nearest(w.player.position,reach)
	if victim==null:return
	w.mark_chain=0
	_apply_mark(victim,Color(data.get("tone","63bd9f")))
	w.visual.action("attack",0.24)
	w.sound("skill_leap_launch")

func _apply_mark(e: Dictionary,tone: Color):
	for other in w.enemies:other["marked"]=false
	e["marked"]=true
	e["mark_tone"]=tone
	if is_instance_valid(e.node):
		var brand=w.fx.glow_sprite(tone,1.1,1.6)
		brand.name="RuinMark";brand.position=Vector3.UP*2.1
		for old in e.node.get_children():
			if old.name=="RuinMark":old.queue_free()
		e.node.add_child(brand)
		# bound to the brand, not the world: the host is freed when its corpse is
		# cleaned up, and a world-bound loop would keep stepping on a dead target
		var pulse=brand.create_tween().set_loops()
		pulse.tween_property(brand,"scale",Vector3.ONE*1.35,0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(brand,"scale",Vector3.ONE,0.45).set_trans(Tween.TRANS_SINE)
	w.fx.ring(e.node.position,0.9,tone,0.3)

# The whirl gives up the lunge's reach for a circle the fighter stands inside, and
# it lands in sweeps rather than one hit - so a body that steps in halfway is still
# caught, and standing behind the warrior stops being safe.
#
# It deliberately does not reuse the heavy-attack spin: that one is a single wide
# instant hit the swing pays for, this one is a cooldown ability that bleeds its
# damage out over the clip. Same shape on screen, different thing to play against.
const WHIRL_SWEEPS = 3

func _cast_whirl(data: Dictionary):
	var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
	var tone=Color(data.get("tone","ffd08a"));var accent=Color(data.get("accent","ff9a4d"))
	# A whirl has to turn the body. The rig has no clip of that name, and falling
	# back to the plain swing played a single overhead cut on the spot while the
	# rings spun round it, so the authored spin is the fallback, at the heavy
	# attack's pace; the plain swing is left only for a rig with neither.
	var clip="whirl" if w.visual.clips.has("whirl") else ("spinattack" if w.visual.clips.has("spinattack") else "attack")
	var length=maxf(w.visual.clip_length(clip)/(BWWorld.spin_pace if clip=="spinattack" else 1.0),0.3)
	w.visual.action(clip,length);w.sound("sword_swing")
	var share=data.damage*w.run.stats.damage/float(WHIRL_SWEEPS)
	var tween=create_tween()
	for sweep in WHIRL_SWEEPS:
		# Spaced inside the clip rather than at its ends: the first sweep wants the
		# blade already moving, and the last wants it still moving.
		tween.tween_interval(length/float(WHIRL_SWEEPS+1))
		tween.tween_callback(_whirl_sweep.bind(radius,share,tone,accent))

# Each sweep reads the body's position again instead of the one it was cast from,
# so a warrior who keeps walking drags the circle along rather than leaving it.
func _whirl_sweep(radius: float,share: float,tone: Color,accent: Color):
	if not is_instance_valid(w.player):return
	var origin=w.player.position
	var heading=w.aim.normalized() if w.aim.length_squared()>0.01 else w.last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	var hit=[]
	for e in w.enemies.duplicate():
		if origin.distance_to(e.node.position)>radius+e.radius:continue
		var roll=w.run.damage_roll(share)
		w._damage_enemy(e,roll.damage,roll.critical,true,"ability");hit.append(e)
		if e.hp>0:w._stagger(e,1.5)
	w.damage_area(origin,radius,share)
	for turn in 3:
		w.fx.slash(origin,heading.rotated(Vector3.UP,TAU*turn/3.0),radius,accent)
	w.fx.shockwave(origin,radius,tone,0.24,0.0,1.6)
	w.shake=maxf(w.shake,0.08 if hit.is_empty() else 0.13)

func _cast_backstep_volley(data: Dictionary):
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	var heading=w.aim.normalized() if w.aim.length_squared()>0.01 else w.last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	w.visual.rotation.y=atan2(heading.x,heading.z)
	w.visual.action("attack",0.28)
	var tone=Color(data.get("tone","9d6bff"));var accent=Color(data.get("accent","d9c6ff"))
	var start=w.player.position
	var retreat=start-heading*(2.6*w.run.stats.attackRange)
	retreat=w.arena.clamp_inside(retreat)
	create_tween().tween_property(w.player,"position",retreat,0.17).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	w.sound("skill_leap_launch")
	w.fx.shockwave(start,1.9,tone,0.3,0.0,1.6)
	w.fx.burst_ring(start,1.7,accent,20,3.4,0.5)
	for i in range(-1,2):
		var roll=w.run.damage_roll(data.damage*w.run.stats.damage)
		w._bullet(retreat,heading.rotated(Vector3.UP,i*0.17),data.projectileSpeed*BWData.UNIT,roll.damage,reach,true,1,"daggers",0,0,roll.critical)
	w.fx.muzzle(retreat+Vector3.UP*0.8,heading,accent)
	w.shake=maxf(w.shake,0.08)

func _cast_meteor(data: Dictionary,target: Vector3):
	w.visual.action("attack",0.34)
	w.visual.rotation.y=atan2(target.x-w.player.position.x,target.z-w.player.position.z)
	w.sound("skill_meteor_cast")
	var origin=w.player.position+Vector3.UP*1.1
	if is_instance_valid(w.visual.hand_magic):origin=w.visual.hand_magic.global_position
	# The rock arcs in from above the target rather than travelling flat from the
	# hand, so the blast reads as something falling onto the ground. Distance sets
	# the timing, capped so a long throw still lands while the fight is in motion.
	var apex=target+Vector3.UP*6.0
	var travel=clampf(origin.distance_to(target)/(data.projectileSpeed*BWData.UNIT),0.26,0.55)
	var rock=Node3D.new();add_child(rock);rock.position=origin
	rock.add_child(w.fx.arcane_core(Color("248fff"),0.32))
	rock.add_child(w.fx.glow_sprite(Color("19bfff"),1.1,0.85))
	rock.add_child(w.fx.glow_sprite(Color("b5f5ff"),0.48,0.65))
	if w.quality=="PC":
		var lamp=OmniLight3D.new();lamp.light_color=Color("248fff");lamp.light_energy=2.4;lamp.omni_range=4.0;rock.add_child(lamp)
		rock.add_child(w.fx.trail_emitter(Color("248fff"),0.09,0.36,22))
	var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
	w.fx.telegraph(target,radius,Color("248fff"),travel)
	var tween=create_tween()
	tween.tween_property(rock,"position",apex,travel*0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rock,"position",target+Vector3.UP*0.2,travel*0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		rock.queue_free()
		_meteor_blast(target,radius,data.damage*w.run.stats.damage))

func _meteor_blast(position: Vector3,radius: float,damage: float):
	w.sound_at("skill_meteor_blast",position,2.0)
	w.damage_area(position,radius,damage)
	for e in w.enemies.duplicate():
		if e.node.position.distance_to(position)<=radius+e.radius:
			var roll=w.run.damage_roll(damage);w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
			if e.hp>0:w._stagger(e,1.5)
	w.fx.arcane_blast(position,radius,Color("19cbff"),Color("2448df"))
	w.fx.spark(position+Vector3.UP*0.4,Color("91ebff"),18)
	w.shake=maxf(w.shake,0.14)

func _cast_void_leap(data: Dictionary,target: Vector3):
	w.airborne=true
	w.visual.action("ultimate",0.7)
	w.visual.rotation.y=atan2(target.x-w.player.position.x,target.z-w.player.position.z)
	w.sound("skill_leap_launch")
	var start=w.player.position
	var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
	w.fx.ring(start,2.0,Color(data.get("tone","7f6bff")),0.35)
	w.fx.radial_streaks(start,2.4,Color(data.get("accent","cfc0ff")),6,0.26)
	var flight=clampf(start.distance_to(target)/16.0,0.26,0.6)
	w.fx.telegraph(target,radius,Color(data.get("tone","7f6bff")),flight)
	var trail: Node=null
	if w.quality=="PC":
		trail=w.fx.trail_emitter(Color("8f74ff"),0.1,0.42,26)
		w.player.add_child(trail)
	# Arc through the air: the model lifts on its own axis while the body travels,
	# so the landing has a visible drop instead of sliding along the floor.
	var lift=create_tween()
	lift.tween_property(w.visual,"position:y",2.6,flight*0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift.tween_property(w.visual,"position:y",0.0,flight*0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var travel=create_tween()
	travel.tween_property(w.player,"position",target,flight).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_callback(func():
		if trail!=null and is_instance_valid(trail):trail.queue_free()
		w.airborne=false
		_leap_land(target,radius,data.damage*w.run.stats.damage,Color(data.get("tone","8f74ff")),Color(data.get("accent","cfc0ff"))))

func _leap_land(position: Vector3,radius: float,damage: float,tone: Color=Color("8f74ff"),accent: Color=Color("cfc0ff")):
	w.sound_at("skill_leap_land",position,2.0)
	w.damage_area(position,radius,damage)
	for e in w.enemies.duplicate():
		if e.node.position.distance_to(position)<=radius+e.radius:
			var roll=w.run.damage_roll(damage);w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
			if e.hp>0:e.slow=2;e.slow_amount=0.3;w._stagger(e,1.5)
	if w.run.class_id=="warrior":
		w.fx.ground_impact(position,radius)
	else:
		w.fx.shockwave(position,radius,tone,0.38,0.0,2.0)
		w.fx.shockwave(position,radius*1.2,tone.darkened(0.35),0.46,0.09,1.5)
		w.fx.radial_streaks(position,radius*1.15,accent,9,0.32)
		w.fx.burst_ring(position,radius,accent.darkened(0.15),34,4.8,0.62)
		w.fx.shards(position,radius*0.85,Color("b3a2ff"),10)
		w.fx.flash_light(position,Color("8f74ff"),3.2,radius*1.8,0.34)
	w.shake=maxf(w.shake,0.18)

func ability():
	if not w.running or w.run.ability_cd>0 or w.run.stats.hp<=0 or w.airborne or cast_active:return
	if w.run.class_id=="gunslinger" and w.visual.lock_time>0 and w.visual.state in ["bombthrow","ultimate"]:return
	var data=BWData.entry("abilities",BWData.CLASSES[w.run.class_id].ability)
	if data.behavior=="bloodBurst":
		w.run.ability_cd=data.cooldown;_cast_blood_burst(data);w.changed.emit();return
	if w.run.class_id=="gunslinger":
		w.aim=w.skill_aim()
		w.visual.rotation.y=atan2(w.aim.x,w.aim.z)
	if data.id=="ember_dash":
		w.run.ability_cd=data.cooldown
		w.dash_direction=w.last_move.normalized()
		if w.dash_direction.length_squared()<0.01:w.dash_direction=w.aim.normalized()
		w.dash_time=0.16
		w.pending_attacks.clear();w.swing_gate=0.0;w.visual.lock_time=0.0
		w.visual.rotation.y=atan2(w.dash_direction.x,w.dash_direction.z)
		w.visual.action("dash",0.28)
		for id in w.run.weapons:w.run.weapons[id].cooldown=0.0
		w.fx.slash(w.player.position,w.dash_direction,2.2,Color("ffb45c"))
		w.sound("dagger_swing");w.changed.emit()
		return
	w.run.ability_cd=data.cooldown
	if w.run.class_id=="gunslinger" and w.visual.clips.has("ultimate"):
		w.pending_attacks.clear()
		w.visual.action("ultimate")
		for index in 9:
			var frame=30+index*6
			w.pending_attacks.append({"time":float(frame-1)/60.0,"id":"bh_ultimate","index":index,"data":data,"direction":w.aim.rotated(Vector3.UP,TAU*float(frame-30)/52.0)})
		w.changed.emit()
		return
	if w.visual.fitted_timing and w.visual.clips.has("ultimate"):
		w.pending_attacks.clear()
		w.visual.action("ultimate",0.9)
		w.pending_attacks.append({"time":0.45,"id":"ultimate","data":data})
		w.fx.surface(w.player.position+Vector3.UP*0.08,1.2,Color("19cbff"),0.45,3,0.8)
	else:
		_resolve_ability(data);w.visual.action("attack")
	w.changed.emit()

func _bloodhound_salvo(event: Dictionary):
	w.bloodhound_event.emit("ULT_FIRE_%02d" % (event.index+1))
	var data=event.data
	var origin=w.visual.bloodhound_socket("R" if event.index%2==0 else "L")
	var roll=w.run.damage_roll(data.damage*w.run.stats.damage*5.0/9.0)
	var projectile=w._bullet(origin-Vector3.UP*0.8,event.direction,data.projectileSpeed*BWData.UNIT,roll.damage,data.range*w.run.stats.attackRange*BWData.UNIT,true,0,"rapid_rifle",0,0,roll.critical)
	if projectile!=null:projectile["body_capsule"]=true
	w.fx.muzzle(origin,event.direction,Color("ffc46a"))
	w.sound("gun_pistol")
	w.shake=maxf(w.shake,0.05)

func _resolve_ability(data: Dictionary):
	var range_value=data.range*w.run.stats.attackRange*BWData.UNIT
	if data.id=="fan_shot":
		_ability_effect(data.id,w.player.position,range_value)
		for i in range(-2,3):
			var roll=w.run.damage_roll(data.damage*w.run.stats.damage)
			w._bullet(w.player.position,w.aim.rotated(Vector3.UP,i*0.16),data.projectileSpeed*BWData.UNIT,roll.damage,range_value,true,0,"rapid_rifle",0,0,roll.critical)
	else:
		var strike_position=w.player.position
		if data.id=="shadow_strike":
			# A fast dash reads better than a blink and disorients less - cover the
			# distance in a short tween instead of snapping w.player.position directly.
			strike_position=w.player.position+w.aim*data.range*BWData.UNIT*0.5
			strike_position=w.arena.clamp_inside(strike_position)
			create_tween().tween_property(w.player,"position",strike_position,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			range_value=65*w.run.stats.attackRange*BWData.UNIT
		w.damage_area(strike_position,range_value,data.damage*w.run.stats.damage)
		for e in w.enemies.duplicate():
			if e.node.position.distance_to(strike_position)<=range_value+e.radius:
				var roll=w.run.damage_roll(data.damage*w.run.stats.damage);w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
				if e.hp>0:w._stagger(e,1.5)
				if e.hp>0 and data.id=="frost_nova":e.slow=3;e.slow_amount=0.45
		_ability_effect(data.id,strike_position,range_value)
	w.sound("ulti_"+data.id)

func _ability_effect(id: String,pos: Vector3,radius: float):
	match id:
		"frost_nova":
			w.fx.arcane_blast(pos,radius,Color("19cbff"),Color("168cda"))
			w.shake=maxf(w.shake,0.05)
		"war_cry":
			w.fx.ground_impact(pos,radius)
			w.fx.flash_light(pos,Color("bf956b"),0.8,radius,0.16)
			w.shake=maxf(w.shake,0.16)
		"shadow_strike":
			w.fx.shockwave(pos,radius*1.15,Color("7a46d8"),0.28,0.0,1.3)
			w.fx.radial_streaks(pos,radius*1.3,Color("e2d2ff"),4,0.2)
			w.fx.slash(pos,w.aim.rotated(Vector3.UP,0.7),radius*1.4,Color("f0e6ff"))
			w.fx.slash(pos,w.aim.rotated(Vector3.UP,-0.7),radius*1.4,Color("c9a6ff"))
			w.fx.burst_ring(pos,radius,Color("a97dff"),22,3.0,0.5)
			w.fx.flash_light(pos,Color("8a5bff"),2.2,radius*1.5,0.26)
			w.shake=maxf(w.shake,0.07)
		"fan_shot":
			var cone=w.fx.flat_sprite(Color("ffc46a"),1.9,1.5,2.4)
			cone.position=pos+Vector3.UP*0.85;add_child(cone)
			w.fx.aim_along(cone,w.aim);cone.get_child(0).position.z=-0.75
			var mat=cone.get_child(0).material_override
			var tween=create_tween();tween.set_parallel(true)
			tween.tween_property(cone,"scale",Vector3(1.6,1,1.5),0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat,"albedo_color",Color(0,0,0),0.16)
			tween.chain().tween_callback(cone.queue_free)
			w.fx.spark(pos+w.aim*0.7+Vector3.UP*0.85,Color("ffcf8a"),20)
			w.fx.flash_light(pos+w.aim*0.6+Vector3.UP*0.85,Color("ffb761"),3.4,3.0,0.16)
			w.shake=maxf(w.shake,0.1)
