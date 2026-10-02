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

func bind(world: BWWorld):
	w=world

func skill(index: int):
	var ids=BWData.skills(w.run.class_id)
	if index<0 or index>=ids.size():return
	var id=ids[index]
	if not w.running or w.run.stats.hp<=0 or w.airborne or not w.run.skill_ready(id):return
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
	w.changed.emit()

# One round that refuses to stop: it redirects to the next body it has not touched.
# Rewards picking a lane through a crowd rather than spraying at the w.nearest target.
func _cast_ricochet(data: Dictionary):
	var reach=data.range*w.run.stats.attackRange*BWData.UNIT
	var heading=w.aim.normalized() if w.aim.length_squared()>0.01 else w.last_move
	if heading.length_squared()<0.01:heading=Vector3.FORWARD
	w.visual.rotation.y=atan2(heading.x,heading.z)
	w.visual.action("attack",0.26);w.sound("shoot_rifle")
	var accent=Color(data.get("accent","ffe9bd"))
	var roll=w.run.damage_roll(data.damage*w.run.stats.damage)
	var round_record=w._bullet(w.player.position,heading,data.projectileSpeed*BWData.UNIT,roll.damage,reach,true,0,"rapid_rifle",0,0,roll.critical)
	if round_record!=null:
		round_record["bounces"]=int(data.get("bounces",3))
		round_record["bounce_range"]=reach
	w.fx.muzzle(w.player.position+Vector3.UP*0.8,heading,accent)
	w.shake=maxf(w.shake,0.06)

# A charge lobbed onto the ground: it telegraphs, then throws everything off it.

func _cast_powder_charge(data: Dictionary,target: Vector3):
	var radius=data.blastRadius*w.run.stats.attackRange*BWData.UNIT
	var tone=Color(data.get("tone","ff9a4d"));var accent=Color(data.get("accent","ffd08a"))
	w.visual.rotation.y=atan2(target.x-w.player.position.x,target.z-w.player.position.z)
	w.visual.action("attack",0.26);w.sound("shoot_shotgun")
	var keg=w.fx.glow_sprite(tone,0.5,1.4);keg.position=w.player.position+Vector3.UP*0.9;add_child(keg)
	var fuse=0.45
	w.fx.telegraph(target,radius,tone,fuse)
	var lob=create_tween();lob.set_parallel(true)
	lob.tween_property(keg,"position",target+Vector3.UP*0.25,fuse).set_trans(Tween.TRANS_SINE)
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
		# shoved outward, clamped to the arena so nothing is pushed through a wall
		var shove=e.node.position+offset.normalized()*1.5
		shove.x=clampf(shove.x,-BWArena.EDGE,BWArena.EDGE);shove.z=clampf(shove.z,-BWArena.EDGE,BWArena.EDGE)
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
	# The authored whirl once the rig carries it, the plain swing until then, so the
	# cast still reads as an attack instead of standing the body still.
	var clip="whirl" if w.visual.clips.has("whirl") else "attack"
	var length=maxf(w.visual.clip_length(clip),0.3)
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
	retreat.x=clampf(retreat.x,-BWArena.EDGE,BWArena.EDGE);retreat.z=clampf(retreat.z,-BWArena.EDGE,BWArena.EDGE)
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
			if e.hp>0:e.slow=2;e.slow_amount=0.3
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
	if not w.running or w.run.ability_cd>0 or w.run.stats.hp<=0 or w.airborne:return
	var data=BWData.entry("abilities",BWData.CLASSES[w.run.class_id].ability)
	if w.run.class_id=="gunslinger":
		w.aim=w.skill_aim()
		w.visual.rotation.y=atan2(w.aim.x,w.aim.z)
	w.run.ability_cd=data.cooldown
	if w.visual.fitted_timing and w.visual.clips.has("ultimate"):
		w.pending_attacks.clear()
		w.visual.action("ultimate",0.9)
		w.pending_attacks.append({"time":0.45,"id":"ultimate","data":data})
		w.fx.surface(w.player.position+Vector3.UP*0.08,1.2,Color("19cbff"),0.45,3,0.8)
	else:
		_resolve_ability(data);w.visual.action("attack")
	w.changed.emit()

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
			strike_position.x=clampf(strike_position.x,-BWArena.EDGE,BWArena.EDGE);strike_position.z=clampf(strike_position.z,-BWArena.EDGE,BWArena.EDGE)
			create_tween().tween_property(w.player,"position",strike_position,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			range_value=65*w.run.stats.attackRange*BWData.UNIT
		w.damage_area(strike_position,range_value,data.damage*w.run.stats.damage)
		for e in w.enemies.duplicate():
			if e.node.position.distance_to(strike_position)<=range_value+e.radius:
				var roll=w.run.damage_roll(data.damage*w.run.stats.damage);w._damage_enemy(e,roll.damage,roll.critical,true,"ability")
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
