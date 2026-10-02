extends SceneTree

# The rules that decide where a wave is, what it is made of and what a status
# effect does to a body once it lands. All of it was running untested.
var checks=0
var failures=0
func check(ok: bool,why: String):
	checks+=1
	if not ok:failures+=1;push_error(why)
func _initialize():call_deferred("suite")

func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene);await process_frame
	scene.meta=BWMeta.new();scene.meta.path="user://wave_field_test_progression.json"
	scene.start_run("warrior");await process_frame
	var world=scene.world;var run=scene.run
	world.running=false;world.auto_fire=false
	run.stats.dodgeChance=0;run.stats.armor=0;run.stats.lifesteal=0;run.stats.regenPerSecond=0

	# --- The district is wherever the player is standing. It decides what turns up,
	# not whether anything does: the wave forms around the player either way.
	for district in BWArena.ZONES:
		world.player.position=Vector3(district.at.x,0,district.at.y)
		check(world.wave_zone_id()==district.id,"the district under the player is the wave's district: "+district.id)
		check(world.current_zone().id==district.id,"the zone resolves from the player's position: "+district.id)
	world.running=true
	for district in BWArena.ZONES:
		world.player.position=Vector3(district.at.x,0,district.at.y)
		check(world.zone_hint()==district.name,"the hint names where the player is, and sends them nowhere: "+district.id)
		check(not world.zone_hint().contains("GATHERING"),"the hint no longer points somewhere else: "+district.id)

	# The wave arrives wherever the player stands - including a corner of the map
	# that is no district's centre. Hunting for a wave was the thing being fixed.
	for spot in [Vector3.ZERO,Vector3(-BWArena.EDGE+2,0,-BWArena.EDGE+2),Vector3(BWArena.EDGE-2,0,BWArena.EDGE-2),Vector3(-30,0,28)]:
		world.player.position=spot
		world.rest_time=0;world.spawned=0;world.spawn_timer=0
		for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
		world._spawn_tick(1.0)
		check(world.spawned==1,"the wave gathers where the player is standing: "+str(spot))
		check(world.enemies.size()==1,"and puts a body on the field")
		var arrival=world.enemies[0].node.position
		check(arrival.distance_to(spot)<BWWorld.SPAWN_RING+2.5,"a body arrives close enough to find: "+str(arrival.distance_to(spot)))
		check(absf(arrival.x)<=BWArena.EDGE+0.01 and absf(arrival.z)<=BWArena.EDGE+0.01,"and inside the arena")

	# --- Surrounded, not queued. A run of spawns has to come from all round the
	# player rather than piling onto one side and leaving an open back.
	world.player.position=Vector3.ZERO
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	world.spawned=0;world.spawn_timer=0;world.spawn_slot=0;world.spawn_bearing=0.0
	var quadrants={}
	for i in 8:
		world.spawn_timer=0
		world._spawn_tick(1.0)
	check(world.enemies.size()==5,"five spawns land and further arrivals stop")
	for e in world.enemies:
		var bearing=atan2(e.node.position.z,e.node.position.x)
		quadrants[int(floor((bearing+PI)/(PI*0.5)))%4]=true
	check(quadrants.size()>=3,"five arrivals occupy at least three sides")
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()

	# --- A horde closes. A body far away hurries in; one already in your face does
	# not, or the approach boost would quietly make melee harder than it is tuned to.
	world.running=false
	world.player.position=Vector3.ZERO
	var far=world.spawn_enemy("grunt",Vector3(0,0,9.0));far.cooldown=1e9
	var near=world.spawn_enemy("grunt",Vector3(0,0,1.5));near.cooldown=1e9
	var far_before=far.node.position.distance_to(world.player.position)
	var near_before=near.node.position.distance_to(world.player.position)
	world._enemy_tick(far,0.2);world._enemy_tick(near,0.2)
	var far_closed=far_before-far.node.position.distance_to(world.player.position)
	var near_closed=near_before-near.node.position.distance_to(world.player.position)
	check(far_closed>near_closed,"a distant body closes faster than one already in contact")
	check(far_closed<=far_before,"and does not overshoot the player")
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()

	# --- The spawn pool. Enemy types are gated by wave, so wave one cannot field a
	# commander and a long run must be able to field everything.
	for wave in [1,2,3,4,5,6,30]:
		for district in BWArena.ZONES:
			var pool=world.spawn_pool(wave,district.id)
			for row in BWData.rows("enemies"):
				if row.id=="boss":continue
				var unlocked=wave>=row.get("unlockWave",1)
				check(pool.has(row.id)==unlocked,"spawn pool gate: %s at wave %d in %s" % [row.id,wave,district.id])
			check(not pool.has("boss"),"the boss never joins an ordinary wave: "+str(wave))
			# A district flavours the mix; it must never make an unlocked type
			# unreachable, or leave a wave with nothing to draw.
			check(not pool.is_empty(),"a district always has something to field: "+district.id)
			for id in pool:check(pool[id]>0.0,"every unlocked type stays drawable: %s in %s" % [id,district.id])
			if wave==1:check(pool.size()==1 and pool.has("grunt"),"wave one fields grunts alone")
			if wave==30:check(pool.size()==BWData.rows("enemies").size()-1,"a long run fields every ordinary type")

	# The districts must actually differ, or the garrison table is decoration. Each
	# one that declares a garrison weights its own theme above the neutral courtyard.
	var neutral=world.spawn_pool(30,"courtyard")
	for pairing in [["ossuary","grunt"],["ruins","archer"],["altar","healer"],["altar","mage"],["grove","assassin"]]:
		var district_pool=world.spawn_pool(30,pairing[0])
		check(district_pool[pairing[1]]>neutral[pairing[1]],"%s fields more %s than the courtyard" % pairing)
	check(world.spawn_pool(30,"courtyard").hash()==neutral.hash(),"the courtyard stays the neutral mix")

	# A draw always returns something the pool actually offers.
	for i in 200:
		var drawn=world._draw_from(world.spawn_pool(30,"grove"))
		check(neutral.has(drawn),"a draw returns a type from the pool")
		if not neutral.has(drawn):break

	# --- Wave shaping. These are formulas, not tables, so they must stay monotone
	# and stay inside their bounds however far a run goes.
	var previous=BWData.wave_rules(1)
	for wave in range(2,120):
		var rules=BWData.wave_rules(wave)
		check(rules.cap==5,"spawn cap stays in bounds: "+str(wave))
		check(rules.interval>=0.45 and rules.interval<=0.95,"spawn interval stays in bounds: "+str(wave))
		check(rules.elite>=0.0 and rules.elite<=0.35,"elite odds stay in bounds: "+str(wave))
		check(rules.multiplier>previous.multiplier,"waves keep getting harder: "+str(wave))
		if not rules.boss and not previous.boss:check(rules.quota==5,"ordinary waves retain five authored enemies: "+str(wave))
		previous=rules

	# --- Elites. One flag has to move every number that makes an elite an elite.
	world.running=false
	world.player.position=Vector3.ZERO
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	var plain=world.spawn_enemy("grunt",Vector3(6,0,0),false,1.0)
	var elite=world.spawn_enemy("grunt",Vector3(8,0,0),true,1.0)
	check(elite.maxHp>plain.maxHp,"an elite carries more health")
	check(elite.damage>plain.damage,"an elite hits harder")
	check(elite.speed>plain.speed,"an elite moves faster")
	check(elite.radius>plain.radius,"an elite is bigger")
	check(elite.elite and not plain.elite,"the elite flag is set once")
	var scaled=world.spawn_enemy("grunt",Vector3(10,0,0),false,2.0)
	check(scaled.maxHp==plain.maxHp*2.0,"the wave multiplier scales health")
	check(scaled.damage==plain.damage*2.0,"the wave multiplier scales damage")

	# --- Status effects. Burn and bleed tick over time; a slow is a movement cut
	# that expires. Each drains the timer it was given and then stops.
	var burning=world.spawn_enemy("tank",Vector3(14,0,0));burning.cooldown=1e9
	burning.hp=1000;burning.maxHp=1000;burning.burn=2.0;burning.burn_dps=10.0
	world._enemy_tick(burning,0.5)
	check(is_equal_approx(burning.hp,995.0),"burn damages over time, not all at once")
	check(is_equal_approx(burning.burn,1.5),"burn drains its own timer")
	world._enemy_tick(burning,2.0)
	check(burning.burn==0.0,"burn expires")
	var after_burn=burning.hp
	world._enemy_tick(burning,1.0)
	check(burning.hp==after_burn,"an expired burn stops damaging")

	var bleeding=world.spawn_enemy("tank",Vector3(16,0,0));bleeding.cooldown=1e9
	bleeding.hp=1000;bleeding.maxHp=1000;bleeding.bleed=2.0;bleeding.bleed_dps=8.0
	world._enemy_tick(bleeding,0.5)
	check(is_equal_approx(bleeding.hp,996.0),"bleed damages over time")
	check(is_equal_approx(bleeding.bleed,1.5),"bleed drains its own timer")

	# A status that kills must resolve the death rather than leave a body on zero.
	var doomed=world.spawn_enemy("grunt",Vector3(18,0,0));doomed.cooldown=1e9
	doomed.hp=5.0;doomed.burn=3.0;doomed.burn_dps=100.0
	var kills=run.kills
	world._enemy_tick(doomed,0.5)
	check(doomed.hp<=0 and run.kills==kills+1,"a body burned to death is counted as a kill")
	check(not world.enemies.has(doomed),"a body burned to death leaves the field")

	var slowed=world.spawn_enemy("grunt",Vector3(20,0,0));slowed.cooldown=1e9
	slowed.slow=1.0;slowed.slow_amount=0.5
	world._enemy_tick(slowed,0.5)
	check(is_equal_approx(slowed.slow,0.5),"a slow drains its own timer")
	world._enemy_tick(slowed,1.0)
	check(slowed.slow==0.0,"a slow expires")

	# --- The player's own defences, which the combat suite never exercises.
	run.stats.hp=100.0;run.stats.armor=0.5;run.stats.dodgeChance=0.0
	check(run.hurt(40.0,1.0)==20.0,"armour halves what lands")
	run.stats.armor=0.0;run.stats.dodgeChance=0.5
	check(run.hurt(40.0,0.1)==0.0,"a dodged hit lands nothing")
	check(run.hurt(40.0,0.9)==40.0,"a roll past the dodge chance lands in full")

	scene.queue_free();await process_frame
	await create_timer(1.0).timeout
	print("WAVE_FIELD_TESTS ",checks," checks / ",failures," failures")
	quit(1 if failures>0 else 0)
