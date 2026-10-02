extends SceneTree
var checks=0
var failures=0
func check(ok: bool, message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("suite")
func suite():
	var scene=load("res://scenes/main.tscn").instantiate();root.add_child(scene)
	await process_frame
	scene.start_run("warrior");await process_frame
	var world=scene.world;world.running=false;world.auto_fire=false
	world.run.stats.maxHp=10000;world.run.stats.hp=10000
	world.run.stats.armor=0;world.run.stats.dodgeChance=0;world.run.stats.lifesteal=0
	# An empty patch keeps these attack tests independent of decorative obstacles.
	world.arena.blockers.clear()
	var boss=world.spawn_enemy("boss",Vector3.ZERO)
	await process_frame
	check(not scene.boss_label.text.contains("PHASE"),"HUD no longer reads health phases")
	check(boss.visual.enemy_asset,"boss uses its own rig")
	check(boss.damage==65,"boss base damage punishes mistakes")
	check(boss.maxHp==3240 and boss.hp==3240,"boss includes the twenty percent health increase")
	check(boss.visual.clips.size()==10,"boss has locomotion, six attacks, hit and death")
	for name in BWBoss.PATTERN:check(boss.visual.clips.has(name),"distinct boss clip: "+name)
	for health in [1.0,0.5,0.1]:
		boss.hp=boss.maxHp*health;boss.pattern_index=0
		var observed=[]
		for i in 6:
			boss.state="chase";boss.cooldown=0;boss.visual.lock_time=0
			world.player.position=boss.node.position+Vector3(0,0,2)
			world._enemy_tick(boss,0.01)
			observed.append(boss.boss_attack)
			BWBoss.clear_warning(boss)
		check(observed==BWBoss.PATTERN,"all six attacks at health ratio "+str(health))
	boss.hp=boss.maxHp
	for attack in ["attack","slam","sweep"]:
		boss.node.position=Vector3.ZERO;boss.visual.lock_time=0
		world.player.position=Vector3(0,0,2)
		var hp=world.run.stats.hp
		BWBoss.begin(world,boss,attack)
		check(is_instance_valid(boss.warning),attack+" displays warning")
		world._enemy_tick(boss,BWBoss.ATTACKS[attack].windup-0.01)
		check(world.run.stats.hp==hp,attack+" cannot hurt during preparation")
		world._enemy_tick(boss,0.02)
		check(is_equal_approx(hp-world.run.stats.hp,boss.damage*BWBoss.ATTACKS[attack].damage),attack+" hits exactly once at contact")
		world._enemy_tick(boss,0.1)
		check(is_equal_approx(hp-world.run.stats.hp,boss.damage*BWBoss.ATTACKS[attack].damage),attack+" recovery does not repeat damage")
	check(not BWBoss.in_sector(Vector3(0,0,-2),Vector3.ZERO,Vector3.BACK,2.8,70),"quick attack has a safe rear")
	check(BWBoss.in_sector(Vector3(3,0,0),Vector3.ZERO,Vector3.BACK,3.8,270),"sweep catches flank")
	check(not BWBoss.in_sector(Vector3(0,0,-3),Vector3.ZERO,Vector3.BACK,3.8,270),"sweep leaves a rear escape")
	# Moving after the tell has committed must genuinely dodge the frontal hit.
	boss.visual.lock_time=0;world.player.position=Vector3(0,0,2)
	BWBoss.begin(world,boss,"attack");world.player.position=Vector3(0,0,-2)
	var hp=world.run.stats.hp;world._enemy_tick(boss,0.4)
	check(world.run.stats.hp==hp,"boss cannot rotate quick hit into an escaping player")
	# Charge traverses the lane, with continuous collision and one hit per lunge.
	boss.node.position=Vector3.ZERO;world.player.position=Vector3(0,0,4)
	BWBoss.begin(world,boss,"charge");world._enemy_tick(boss,0.91)
	hp=world.run.stats.hp
	for i in 40:world._enemy_tick(boss,0.016)
	check(is_equal_approx(hp-world.run.stats.hp,boss.damage*1.35),"charge deals one swept hit")
	check(absf(boss.node.position.x)<0.01 and is_equal_approx(boss.node.position.z,8.0),"charge travels exactly its committed lane")
	boss.node.position=Vector3.ZERO;world.player.position=Vector3(0,0,4)
	BWBoss.begin(world,boss,"charge");world.player.position=Vector3(3,0,4)
	world._enemy_tick(boss,0.91);hp=world.run.stats.hp
	for i in 40:world._enemy_tick(boss,0.016)
	check(world.run.stats.hp==hp,"charge can be dodged sideways")
	# Casting has a distinct performance, emits nothing before contact and freezes aim.
	boss.node.position=Vector3.ZERO;world.player.position=Vector3(0,0,6)
	BWBoss.begin(world,boss,"cast");var count=world.bullets.size()
	await process_frame
	check(scene.boss_label.text=="THE BLOOD WARDEN   ·   %d / %d" % [ceili(boss.hp),int(boss.maxHp)],"HUD shows health only during attack")
	world._enemy_tick(boss,0.9)
	check(world.bullets.size()==count and boss.visual.state=="cast","cast visibly prepares before firing")
	world.player.position=Vector3(5,0,0);world._enemy_tick(boss,0.11)
	check(world.bullets.size()==count+3,"cast releases three projectiles")
	check(world.bullets[-2].direction.is_equal_approx(Vector3.BACK),"cast direction cannot track after warning")
	# Summoning belongs to the pattern, not a hidden periodic spawn timer.
	BWBoss.begin(world,boss,"summon");count=world.enemies.size()
	check(boss.warning.get_child_count()==maxi(0,BWData.ENCOUNTER_CAP-count),"summon shows only available destination portals")
	world._enemy_tick(boss,1.4);check(world.enemies.size()==count,"no grunt spawns during summon tell")
	world._enemy_tick(boss,0.11);check(world.enemies.size()==BWData.ENCOUNTER_CAP,"roar fills available enemy slots at contact")
	world._enemy_tick(boss,0.2);check(world.enemies.size()==BWData.ENCOUNTER_CAP,"summon cannot duplicate during recovery")
	for repeat in 2:
		BWBoss.begin(world,boss,"summon");world._enemy_tick(boss,1.51)
	check(world.enemies.size()==BWData.ENCOUNTER_CAP,"repeated summons respect the five-enemy cap")
	# Attacking a boss must not erase the cast telegraph animation; killing must cancel it.
	BWBoss.begin(world,boss,"cast");world._damage_enemy(boss,1)
	check(boss.visual.state=="cast","damage cannot interrupt a committed boss performance")
	var before=world.bullets.size();world._damage_enemy(boss,boss.hp+1,false,false)
	check(boss.warning==null and boss.visual.dead,"death clears warning and starts death clip")
	world._enemy_tick(boss,10)
	check(world.bullets.size()==before,"dead boss cannot finish a pending cast")
	scene.queue_free();await process_frame
	print("BOSS_PATTERN_TEST checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
