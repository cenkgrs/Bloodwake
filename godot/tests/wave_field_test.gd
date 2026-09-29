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

	# --- The tour. A run always walks the same districts in the same order, and a
	# boss is always held at the altar, so the map has somewhere to go.
	var districts=[]
	for wave in range(1,BWArena.ZONES.size()+1):
		run.wave=wave
		districts.append(world.wave_zone_id())
	check(districts.size()==districts.duplicate().size(),"the tour covers a district per wave")
	var seen={}
	for d in districts:seen[d]=true
	check(seen.size()==BWArena.ZONES.size(),"every district hosts a wave before any repeats")
	for wave in [10,20,50,100]:
		run.wave=wave
		check(world.wave_zone_id()=="altar","a boss wave is always held at the altar: "+str(wave))
	run.wave=1
	check(world.wave_zone_id()==world.current_zone().id,"the wave's district resolves to a real zone")
	for wave in range(1,25):
		run.wave=wave
		check(not world.current_zone().is_empty(),"every wave resolves to a district: "+str(wave))

	# --- The hint only speaks while the player is somewhere else. Standing in the
	# district is the condition for the wave to arrive at all.
	run.wave=1
	# The hint is silent outside a live wave, so asking while running is false would
	# pass the first check for the wrong reason.
	world.running=true
	var zone=world.current_zone()
	world.player.position=Vector3(zone.at.x,0,zone.at.y)
	check(world.zone_hint()=="","no hint while the player is where the wave is")
	world.player.position=Vector3(zone.at.x,0,zone.at.y)+Vector3(zone.radius+30.0,0,0)
	check(world.zone_hint()!="","the hint names the district once the player is away from it")
	check(world.zone_hint().contains(zone.name),"the hint names the district it is pointing at")

	# Standing elsewhere does not summon the wave.
	world.rest_time=0;world.spawned=0;world.spawn_timer=0
	for e in world.enemies.duplicate():world.enemies.erase(e);e.node.queue_free()
	world._spawn_tick(1.0)
	check(world.spawned==0,"a wave does not gather while the player is in another district")
	world.player.position=Vector3(zone.at.x,0,zone.at.y)
	world.spawn_timer=0
	world._spawn_tick(1.0)
	check(world.spawned==1,"the wave gathers once the player arrives")

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
			if wave==30:check(pool.size()==6,"a long run fields every ordinary type")

	# The districts must actually differ, or the garrison table is decoration. Each
	# one that declares a garrison weights its own theme above the neutral courtyard.
	var neutral=world.spawn_pool(30,"courtyard")
	for pairing in [["ossuary","grunt"],["ruins","archer"],["altar","healer"],["grove","assassin"]]:
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
		check(rules.cap>=5 and rules.cap<=20,"spawn cap stays in bounds: "+str(wave))
		check(rules.interval>=0.35 and rules.interval<=1.2,"spawn interval stays in bounds: "+str(wave))
		check(rules.elite>=0.0 and rules.elite<=0.35,"elite odds stay in bounds: "+str(wave))
		check(rules.multiplier>previous.multiplier,"waves keep getting harder: "+str(wave))
		if not rules.boss and not previous.boss:check(rules.quota>previous.quota,"the quota climbs between ordinary waves: "+str(wave))
		previous=rules

	# --- Elites. One flag has to move every number that makes an elite an elite.
	world.running=false
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
