extends SceneTree

# The six bound skills the other suites do not reach. combat_flow_test already
# drives the mage's meteor and leap end to end; these are the warrior, gunslinger
# and assassin casts, which had no coverage at all.
var checks=0
var failures=0
func check(ok: bool,why: String):
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("suite")

# A cast needs a world that is live enough to move a body and reach an enemy, but
# not one that is also spawning waves on top of the test.
func arena(scene: Node,id: String) -> Array:
	scene.start_run(id);await process_frame
	var world=scene.world;var run=scene.run
	world.running=true;world.auto_fire=false;world.rest_time=999
	run.stats.dodgeChance=0;run.stats.armor=0;run.stats.criticalChance=0;run.stats.lifesteal=0
	return [world,run]

func dummy(world,at: Vector3,hp: float=2000.0) -> Dictionary:
	var e=world.spawn_enemy("tank",at);e.cooldown=1e9;e.hp=hp;e.maxHp=hp
	return e

func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://class_kit_test_progression.json"

	# Every class fields exactly two bound skills, and each one is a behaviour the
	# kit actually dispatches - a typo in a catalog behaviour would otherwise cast
	# nothing at all and still spend the cooldown.
	var behaviours=["meteor","voidLeap","whirl","backstepVolley","ricochet","powderCharge","markOfRuin"]
	for id in BWData.CLASSES:
		for skill_id in BWData.skills(id):
			var row=BWData.entry("abilities",skill_id)
			check(not row.is_empty(),"skill is catalogued: "+skill_id)
			check(row.behavior in behaviours,"skill behaviour is dispatched: "+skill_id+" / "+String(row.get("behavior","")))
			check(row.cooldown>0,"skill has a cooldown: "+skill_id)

	# --- Warrior Q: Sunder Leap. Shares voidLeap with the mage but is the shorter
	# jump into the wider crater, so what matters here is that it reaches its mark.
	var pair=await arena(scene,"warrior")
	var world=pair[0];var run=pair[1]
	world.aim=Vector3.FORWARD
	var sunder=BWData.entry("abilities","sunder_leap")
	var landing=world.ground_target(sunder.range*run.stats.attackRange*BWData.UNIT)
	var victim=dummy(world,landing)
	var launch=world.player.position
	world.skill(0)
	# Read the cooldown here: the world ticks it down through the flight below.
	check(run.skill_cd.sunder_leap==sunder.cooldown,"Sunder Leap spends its own cooldown")
	check(run.skill_ready("whirl"),"the warrior's second skill is untouched by the first")
	check(world.airborne,"Sunder Leap leaves the ground")
	check(victim.hp==2000,"Sunder Leap damage waits for the landing")
	var mid=run.stats.hp;world._hurt_player(30)
	check(run.stats.hp==mid,"the warrior cannot be hit mid-leap")
	await create_timer(0.9).timeout
	check(not world.airborne,"Sunder Leap lands")
	check(world.player.position.distance_to(landing)<0.05,"Sunder Leap arrives where it was aimed")
	check(launch.distance_to(world.player.position)>1.0,"Sunder Leap covers ground")
	check(victim.hp<2000,"Sunder Leap's crater damages what is standing in it")

	# --- Warrior E: Whirl. A circle, not a lane: the fighter turns on the spot, so
	# standing behind it is no safer than standing in front, and only being outside
	# the circle saves anything. The damage arrives in sweeps spread across the clip,
	# so the checks have to wait the clip out rather than read the first frame.
	run.skill_cd.sunder_leap=0.0;run.skill_cd.whirl=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var whirl=BWData.entry("abilities","whirl")
	var radius=whirl.blastRadius*run.stats.attackRange*BWData.UNIT
	var heading=world.aim.normalized()
	var behind=dummy(world,-heading*radius*0.5)
	var beside=dummy(world,heading.cross(Vector3.UP).normalized()*radius*0.5)
	var clear_of_it=dummy(world,heading*radius*3.0)
	world.skill(1)
	var whirl_clip="whirl" if world.visual.clips.has("whirl") else "attack"
	await create_timer(world.visual.clip_length(whirl_clip)+0.25).timeout
	check(behind.hp<2000,"Whirl catches what is behind the fighter")
	check(beside.hp<2000,"Whirl catches what is beside the fighter")
	check(clear_of_it.hp==2000,"Whirl spares what is outside the circle")

	# --- Gunslinger Q: Ricochet Round. One round, redirected: the point is that a
	# second body it never pointed at still takes the hit.
	pair=await arena(scene,"gunslinger")
	world=pair[0];run=pair[1]
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var first=dummy(world,Vector3(0,0,3.0))
	var second=dummy(world,Vector3(1.6,0,3.4))
	world.skill(0)
	check(world.bullets.size()==1,"Ricochet Round fires a single round")
	check(world.bullets[0].get("bounces",0)==BWData.entry("abilities","ricochet_round").bounces,"the round carries its bounce budget")
	for i in 90:
		world._projectiles(0.016)
		await process_frame
		if first.hp<2000 and second.hp<2000:break
	check(first.hp<2000,"the round hits what it was aimed at")
	check(second.hp<2000,"the round redirects into a body it was never pointed at")

	# --- Gunslinger E: Powder Charge. Telegraphs, then detonates: damage must not
	# land while the keg is still in the air.
	run.skill_cd.powder_charge=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	for b in world.bullets.duplicate():b.node.queue_free()
	world.bullets.clear()
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var charge=BWData.entry("abilities","powder_charge")
	var spot=world.ground_target(charge.range*run.stats.attackRange*BWData.UNIT)
	var caught=dummy(world,spot)
	var outside=dummy(world,spot+Vector3(charge.blastRadius*BWData.UNIT*3.0,0,0))
	world.skill(1)
	check(caught.hp==2000,"Powder Charge does not damage while the keg is still in the air")
	await create_timer(0.8).timeout
	check(caught.hp<2000,"Powder Charge detonates on what is standing on it")
	check(outside.hp==2000,"Powder Charge spares what is outside the blast")

	# --- Assassin Q: Phantom Volley. Retreats one way, throws blades the other.
	pair=await arena(scene,"assassin")
	world=pair[0];run=pair[1]
	world.player.position=Vector3.ZERO;world.aim=Vector3.FORWARD
	var pursuer=dummy(world,Vector3(0,0,2.4))
	var standing=world.player.position
	world.skill(0)
	await create_timer(0.35).timeout
	var retreated=world.player.position
	check(standing.distance_to(retreated)>1.0,"Phantom Volley breaks away from the body on top of it")
	check((retreated-standing).normalized().dot(world.aim)<-0.8,"Phantom Volley retreats opposite the blades it throws")
	check(world.bullets.size()>=3,"Phantom Volley answers with three blades")
	for i in 60:
		world._projectiles(0.016)
		await process_frame
		if pursuer.hp<2000:break
	check(pursuer.hp<2000,"the blades travel back toward what was chasing")

	# --- Assassin E: Mark of Ruin. The brand bites harder, and outlives its host.
	run.skill_cd.mark_of_ruin=0.0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	for b in world.bullets.duplicate():b.node.queue_free()
	world.bullets.clear()
	world.player.position=Vector3.ZERO
	var host=dummy(world,Vector3(0,0,2.0),100.0)
	var heir=dummy(world,Vector3(0.8,0,2.4),2000.0)
	world.skill(1)
	check(host.get("marked",false),"Mark of Ruin brands the nearest body")
	check(not heir.get("marked",false),"only one body carries the brand at a time")
	check(host.node.find_child("RuinMark",true,false)!=null,"the brand is drawn on its host")
	# A marked body takes more than an unmarked one from the same hit.
	var plain=dummy(world,Vector3(4.0,0,2.0),2000.0)
	world._damage_enemy(host,50.0,false,false)
	world._damage_enemy(plain,50.0,false,false)
	check(host.hp<plain.hp-1.0,"the brand makes every hit bite harder")
	# Killing the host must hand the brand on rather than lose it.
	world._damage_enemy(host,10000.0,false,false)
	check(heir.get("marked",false) or plain.get("marked",false),"the brand outlives its host and moves to the next body")
	check(world.mark_chain==1,"each jump deepens the chain")

	# --- A rig without chain clips must not be held to the chain's pace. The
	# assassin's one 2.1s swing was gating a 2.4/s weapon down to about 1.1.
	for id in BWData.CLASSES:
		var weapon=BWData.entry("weapons",BWData.CLASSES[id].weapon)
		if weapon.get("behavior","")!="melee":continue
		pair=await arena(scene,id)
		world=pair[0];run=pair[1]
		var chained=world.has_chain()
		var foe=dummy(world,Vector3(0,0,0.6))
		world.auto_fire=true;world.visual.lock_time=0;world.swing_gate=0.0;world.combo_timer=0.0
		run.weapons[weapon.id].cooldown=0.0
		world._weapons(0.016)
		var cooldown=1.0/(float(weapon.attacksPerSecond)*run.stats.attackSpeed)
		check(world.swing_gate>0.0,"a melee swing gates the next one: "+id)
		if chained:
			check(world.has_chain(),"the warrior keeps its chain: "+id)
		else:
			# Without a chain the swing is fitted to the weapon's own cadence, so the
			# gate cannot outlast the cooldown the catalogue asks for.
			check(world.swing_gate<=cooldown,"a chainless rig swings at the weapon's cadence, not the clip's: %s (gate %.3f vs cooldown %.3f)" % [id,world.swing_gate,cooldown])
			check(world.visual.lock_time<=cooldown,"and its clip is fitted to that cadence: "+id)
		check(world.pending_attacks.size()==1,"the swing queues its contact frame: "+id)
		var contact=world.pending_attacks[0].time
		check(contact<cooldown,"and lands within the weapon's own cadence: "+id)
		world._pending_attacks(contact+0.001)
		check(foe.hp<2000,"the swing connects: "+id)
		for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()

	# --- Breakables answer to every kind of damage, not just a sword swing. Only
	# the melee branch called damage_area, so a mage could not break a pot at all.
	#
	# This drives real urns that arena.build() placed, not a dict planted into the
	# breakables list: an earlier version of this check planted its own and passed
	# while the game was still broken, because it never exercised where a cast
	# actually lands. Two things have to be right for that, and both were wrong
	# the first time - a ground-targeted cast lands at its full reach, not next to
	# the caster, and ground_target reads the mouse unless a stick or touch is
	# live, which in headless silently aims everything at the origin.
	for id in BWData.CLASSES:
		for index in [0,1]:
			var skill_id=BWData.skills(id)[index]
			var data=BWData.entry("abilities",skill_id)
			pair=await arena(scene,id)
			world=pair[0];run=pair[1]
			check(not world.arena.breakables.is_empty(),"the arena builds breakables at all")
			if world.arena.breakables.is_empty():continue
			var urn=world.arena.breakables[0]
			var prop_reach=data.range*run.stats.attackRange*BWData.UNIT
			var behavior=String(data.behavior)
			# Where the cast puts its damage decides where the caster has to stand.
			var stand_off=prop_reach
			if behavior=="whirl":stand_off=prop_reach*0.5
			elif behavior in ["ricochet","backstepVolley","markOfRuin"]:stand_off=minf(prop_reach*0.5,3.0)
			var prop_heading=Vector3.FORWARD
			world.player.position=urn.pos-prop_heading*stand_off
			world.aim=prop_heading
			# Touch aim keeps ground_target off the headless mouse cursor.
			world.touch_aim=Vector2(prop_heading.x,prop_heading.z)
			var hp_before=urn.hp
			world.skill(index)
			await create_timer(1.2).timeout
			var damaged=not world.arena.breakables.has(urn) or urn.hp<hp_before
			# Mark of Ruin brands rather than damages, so it is the one cast that
			# legitimately leaves a pot standing. Everything else - blast, lane or
			# thrown round - has to clear it.
			if behavior=="markOfRuin":
				check(not damaged,"%s brands rather than damages, so the urn stands" % skill_id)
			else:
				check(damaged,"%s clears a real urn" % skill_id)
			for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()

	# --- A shot breaks what it flies through. Every class's normal attack had to be
	# able to clear a pot, and for the three ranged ones that meant projectiles,
	# which passed straight through until now.
	for id in BWData.CLASSES:
		pair=await arena(scene,id)
		world=pair[0];run=pair[1]
		var weapon_id=BWData.CLASSES[id].weapon
		var weapon_row=BWData.entry("weapons",weapon_id)
		var shot_urn=world.arena.breakables[0]
		var melee_weapon=weapon_row.get("behavior","")=="melee"
		# Stand a swing away for melee, a short flight away for anything thrown.
		var gap=0.6 if melee_weapon else 3.0
		world.player.position=shot_urn.pos-Vector3.FORWARD*gap
		world.aim=Vector3.FORWARD;world.touch_aim=Vector2(0,-1)
		# The mage fires from a hand bone, and a skeleton's global transform only
		# catches up on the next frame. Teleporting and firing in the same one
		# launched the orb from wherever the player used to be.
		await process_frame
		await process_frame
		var shot_hp=shot_urn.hp
		world.auto_fire=false;world.visual.lock_time=0;world.swing_gate=0.0;world.combo_timer=0.0
		run.weapons[weapon_id].cooldown=0.0
		world._resolve_weapon(weapon_id,Vector3.FORWARD)
		# Let a projectile cover the gap.
		for i in 120:
			world._projectiles(0.016)
			await process_frame
			if not world.arena.breakables.has(shot_urn) or shot_urn.hp<shot_hp:break
		check(not world.arena.breakables.has(shot_urn) or shot_urn.hp<shot_hp,
			"%s's normal attack (%s) damages a real urn" % [id,weapon_id])

	# The ultimates are area damage too, and land on the caster or a short dash away.
	for id in ["mage","warrior","assassin"]:
		pair=await arena(scene,id)
		world=pair[0];run=pair[1]
		var ult=BWData.entry("abilities",BWData.CLASSES[id].ability)
		if ult.id=="fan_shot":continue
		var urn_ult=world.arena.breakables[0]
		var dash=ult.range*BWData.UNIT*0.5 if ult.id=="shadow_strike" else 0.0
		world.player.position=urn_ult.pos-Vector3.FORWARD*dash
		world.aim=Vector3.FORWARD;world.touch_aim=Vector2(0,-1)
		var ult_hp=urn_ult.hp
		world.ability()
		world._pending_attacks(1.0)
		await create_timer(0.5).timeout
		check(not world.arena.breakables.has(urn_ult) or urn_ult.hp<ult_hp,"the %s ultimate puts its area damage into a real urn" % id)

	scene.queue_free();await process_frame
	await create_timer(1.0).timeout
	print("CLASS_KIT_TESTS ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)
